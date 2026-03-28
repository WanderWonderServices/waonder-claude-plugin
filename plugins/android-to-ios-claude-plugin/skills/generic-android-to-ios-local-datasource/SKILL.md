---
name: generic-android-to-ios-local-datasource
description: Use when migrating Android local data source pattern (interface + Room/DataStore implementation) to iOS local data source pattern (protocol + SwiftData/UserDefaults implementation) with caching and data mapping
type: generic
---

# generic-android-to-ios-local-datasource

## Context
The local data source pattern provides an abstraction layer between the repository and the concrete persistence mechanism (Room, DataStore, file system). On Android this is typically an interface with a Room or DataStore-backed implementation. On iOS the equivalent is a Swift protocol with an implementation backed by SwiftData, Core Data, UserDefaults, or the file system.

This pattern is critical for testability (swap in-memory implementations in tests), separation of concerns (the repository does not know which storage engine is used), and caching strategies (the local data source can serve as a cache for remote data).

## Android Best Practices (Local Data Source)
- Define the local data source as an interface in the domain/data layer boundary.
- The interface exposes domain-oriented methods (not SQL or storage-specific concepts).
- The implementation wraps Room DAOs or DataStore, mapping between entities and domain models.
- Use suspend functions for one-shot operations and `Flow<T>` for observable data.
- Inject the data source via Hilt/Dagger with `@Binds` or `@Provides`.
- Keep entity-to-domain mapping in extension functions or dedicated mapper classes.
- The local data source should handle storage-specific error cases and translate them to domain exceptions.

### Kotlin Patterns

```kotlin
// --- Domain model ---
data class Landmark(
    val id: String,
    val name: String,
    val location: LatLng,
    val category: LandmarkCategory,
    val isFavorite: Boolean = false
)

// --- Local data source interface ---
interface LandmarkLocalDataSource {
    fun observeAll(): Flow<List<Landmark>>
    fun observeFavorites(): Flow<List<Landmark>>
    suspend fun getById(id: String): Landmark?
    suspend fun upsert(landmark: Landmark)
    suspend fun upsertAll(landmarks: List<Landmark>)
    suspend fun delete(id: String)
    suspend fun deleteAll()
    suspend fun isCacheValid(): Boolean
}

// --- Room-backed implementation ---
class RoomLandmarkLocalDataSource @Inject constructor(
    private val dao: LandmarkDao,
    private val clock: Clock
) : LandmarkLocalDataSource {

    override fun observeAll(): Flow<List<Landmark>> =
        dao.observeAll().map { entities -> entities.map { it.toDomain() } }

    override fun observeFavorites(): Flow<List<Landmark>> =
        dao.observeFavorites().map { entities -> entities.map { it.toDomain() } }

    override suspend fun getById(id: String): Landmark? =
        dao.getById(id)?.toDomain()

    override suspend fun upsert(landmark: Landmark) {
        dao.upsert(landmark.toEntity())
    }

    override suspend fun upsertAll(landmarks: List<Landmark>) {
        dao.upsertAll(landmarks.map { it.toEntity() })
    }

    override suspend fun delete(id: String) {
        dao.deleteById(id)
    }

    override suspend fun deleteAll() {
        dao.deleteAll()
    }

    override suspend fun isCacheValid(): Boolean {
        val lastUpdate = dao.getLastUpdateTimestamp() ?: return false
        return clock.now() - lastUpdate < CACHE_TTL
    }

    companion object {
        private val CACHE_TTL = 30.minutes
    }
}

// --- Entity mapping ---
fun LandmarkEntity.toDomain() = Landmark(
    id = id,
    name = name,
    location = LatLng(latitude, longitude),
    category = LandmarkCategory.valueOf(category),
    isFavorite = isFavorite
)

fun Landmark.toEntity() = LandmarkEntity(
    id = id,
    name = name,
    latitude = location.latitude,
    longitude = location.longitude,
    category = category.name,
    isFavorite = isFavorite
)

// --- DI module ---
@Module
@InstallIn(SingletonComponent::class)
abstract class DataSourceModule {
    @Binds
    @Singleton
    abstract fun bindLandmarkLocalDataSource(
        impl: RoomLandmarkLocalDataSource
    ): LandmarkLocalDataSource
}
```

## iOS Best Practices (Local Data Source)
- Define the local data source as a Swift protocol.
- Use `async throws` for one-shot operations and `AsyncSequence` or Combine publishers for observation.
- The implementation wraps SwiftData `ModelContext`, Core Data `NSManagedObjectContext`, or `UserDefaults`.
- Map between persistence models (`@Model` / `NSManagedObject`) and domain models at the data source boundary.
- Register the protocol-to-implementation binding in your DI container (e.g., Factory, Swinject, or a manual container).
- Handle persistence-specific errors and translate them to domain-level errors.
- Use `@ModelActor` for thread-safe SwiftData access outside of SwiftUI views.

### Swift Patterns

```swift
// --- Domain model ---
struct Landmark: Equatable, Identifiable, Sendable {
    let id: String
    var name: String
    var location: Coordinate
    var category: LandmarkCategory
    var isFavorite: Bool = false
}

struct Coordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

// --- Local data source protocol ---
protocol LandmarkLocalDataSource: Sendable {
    func observeAll() -> AsyncStream<[Landmark]>
    func observeFavorites() -> AsyncStream<[Landmark]>
    func getById(_ id: String) async throws -> Landmark?
    func upsert(_ landmark: Landmark) async throws
    func upsertAll(_ landmarks: [Landmark]) async throws
    func delete(id: String) async throws
    func deleteAll() async throws
    func isCacheValid() async -> Bool
}

// --- SwiftData-backed implementation ---
@ModelActor
actor SwiftDataLandmarkLocalDataSource: LandmarkLocalDataSource {
    private let cacheTTL: TimeInterval = 30 * 60 // 30 minutes

    func observeAll() -> AsyncStream<[Landmark]> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    let descriptor = FetchDescriptor<LandmarkModel>(
                        sortBy: [SortDescriptor(\.name)]
                    )
                    let models = (try? modelContext.fetch(descriptor)) ?? []
                    continuation.yield(models.map { $0.toDomain() })
                    try? await Task.sleep(for: .seconds(1))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func observeFavorites() -> AsyncStream<[Landmark]> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    let predicate = #Predicate<LandmarkModel> { $0.isFavorite }
                    let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.name)])
                    let models = (try? modelContext.fetch(descriptor)) ?? []
                    continuation.yield(models.map { $0.toDomain() })
                    try? await Task.sleep(for: .seconds(1))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func getById(_ id: String) async throws -> Landmark? {
        let predicate = #Predicate<LandmarkModel> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try modelContext.fetch(descriptor).first?.toDomain()
    }

    func upsert(_ landmark: Landmark) async throws {
        let predicate = #Predicate<LandmarkModel> { $0.id == landmark.id }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let existing = try modelContext.fetch(descriptor).first {
            existing.update(from: landmark)
        } else {
            modelContext.insert(LandmarkModel(from: landmark))
        }
        try modelContext.save()
    }

    func upsertAll(_ landmarks: [Landmark]) async throws {
        for landmark in landmarks {
            try await upsert(landmark)
        }
    }

    func delete(id: String) async throws {
        let predicate = #Predicate<LandmarkModel> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let model = try modelContext.fetch(descriptor).first {
            modelContext.delete(model)
            try modelContext.save()
        }
    }

    func deleteAll() async throws {
        try modelContext.delete(model: LandmarkModel.self)
        try modelContext.save()
    }

    func isCacheValid() async -> Bool {
        let descriptor = FetchDescriptor<CacheMetadata>(
            predicate: #Predicate { $0.key == "landmarks_last_update" }
        )
        guard let metadata = try? modelContext.fetch(descriptor).first else { return false }
        return Date().timeIntervalSince(metadata.timestamp) < cacheTTL
    }
}

// --- SwiftData model ---
@Model
final class LandmarkModel {
    @Attribute(.unique) var id: String
    var name: String
    var latitude: Double
    var longitude: Double
    var categoryRaw: String
    var isFavorite: Bool
    var lastUpdated: Date

    init(from domain: Landmark) {
        self.id = domain.id
        self.name = domain.name
        self.latitude = domain.location.latitude
        self.longitude = domain.location.longitude
        self.categoryRaw = domain.category.rawValue
        self.isFavorite = domain.isFavorite
        self.lastUpdated = .now
    }

    func update(from domain: Landmark) {
        name = domain.name
        latitude = domain.location.latitude
        longitude = domain.location.longitude
        categoryRaw = domain.category.rawValue
        isFavorite = domain.isFavorite
        lastUpdated = .now
    }

    func toDomain() -> Landmark {
        Landmark(
            id: id,
            name: name,
            location: Coordinate(latitude: latitude, longitude: longitude),
            category: LandmarkCategory(rawValue: categoryRaw) ?? .general,
            isFavorite: isFavorite
        )
    }
}

@Model
final class CacheMetadata {
    @Attribute(.unique) var key: String
    var timestamp: Date

    init(key: String, timestamp: Date = .now) {
        self.key = key
        self.timestamp = timestamp
    }
}

// --- DI registration (using Factory pattern) ---
import Factory

extension Container {
    var landmarkLocalDataSource: Factory<LandmarkLocalDataSource> {
        Factory(self) {
            let container = try! ModelContainer(for: LandmarkModel.self, CacheMetadata.self)
            return SwiftDataLandmarkLocalDataSource(modelContainer: container)
        }
        .singleton
    }
}

// --- In-memory implementation for testing ---
actor InMemoryLandmarkLocalDataSource: LandmarkLocalDataSource {
    private var storage: [String: Landmark] = [:]
    private var lastUpdate: Date?

    func observeAll() -> AsyncStream<[Landmark]> {
        AsyncStream { continuation in
            continuation.yield(Array(storage.values))
            continuation.finish()
        }
    }

    func observeFavorites() -> AsyncStream<[Landmark]> {
        AsyncStream { continuation in
            continuation.yield(storage.values.filter(\.isFavorite))
            continuation.finish()
        }
    }

    func getById(_ id: String) async throws -> Landmark? { storage[id] }

    func upsert(_ landmark: Landmark) async throws {
        storage[landmark.id] = landmark
        lastUpdate = .now
    }

    func upsertAll(_ landmarks: [Landmark]) async throws {
        for l in landmarks { storage[l.id] = l }
        lastUpdate = .now
    }

    func delete(id: String) async throws { storage.removeValue(forKey: id) }

    func deleteAll() async throws { storage.removeAll() }

    func isCacheValid() async -> Bool {
        guard let lastUpdate else { return false }
        return Date().timeIntervalSince(lastUpdate) < 1800
    }
}
```

## Concept Mapping

| Android | iOS | Notes |
|---|---|---|
| Interface (data source contract) | Protocol | Both provide abstraction for testing |
| `@Inject constructor` | Factory / Swinject / manual DI | No built-in DI on iOS |
| `Flow<List<T>>` | `AsyncStream<[T]>` / Combine `Publisher` | AsyncStream for async/await codebases |
| `suspend fun` | `async throws` | Direct equivalent |
| Room entity mapping | `@Model` mapping | Map at data source boundary |
| `@Binds` (Hilt) | Factory `.singleton` | Register protocol binding |
| In-memory DAO (test) | In-memory actor (test) | Both implement same interface/protocol |
| `Clock` injection | `Date` injection / `TimeProvider` protocol | For testable cache expiry |

## Common Pitfalls
1. **Leaking persistence types**: Never expose `@Model` or `NSManagedObject` through the protocol. Always map to domain models at the data source boundary. Managed objects are tied to their context and cannot safely cross boundaries.
2. **Observation gaps**: Room `Flow` queries automatically re-emit when data changes. SwiftData has no built-in equivalent outside of `@Query` in SwiftUI. The `AsyncStream` polling pattern shown above is a pragmatic solution; alternatively, use `NotificationCenter` to observe `ModelContext.didSave`.
3. **Thread isolation**: SwiftData `ModelContext` is not thread-safe. Always use `@ModelActor` for data source implementations. Never pass `@Model` objects across actor boundaries.
4. **Cache invalidation**: Store cache metadata (last-fetch timestamp) alongside the data. Both platforms need explicit cache TTL logic; neither Room nor SwiftData provides built-in cache expiry.
5. **Batch operations**: Room supports `@Insert(onConflict = REPLACE)` for efficient bulk upserts. SwiftData requires manual fetch-then-insert loops. For large datasets, batch the saves to avoid excessive I/O.
6. **Testing**: Always provide an in-memory implementation of the protocol for unit tests. On iOS, you can also create an in-memory `ModelContainer` with `ModelConfiguration(isStoredInMemoryOnly: true)`.

## Migration Checklist
- [ ] Identify all Android local data source interfaces and their method signatures
- [ ] Create equivalent Swift protocols with `async throws` methods and `AsyncStream` return types
- [ ] Map Room entity classes to SwiftData `@Model` classes (or Core Data `NSManagedObject`)
- [ ] Implement entity-to-domain and domain-to-entity mappers as methods on the model classes
- [ ] Create `@ModelActor`-based implementations of each protocol
- [ ] Set up cache metadata storage and TTL validation
- [ ] Register protocol-to-implementation bindings in the DI container
- [ ] Create in-memory test implementations for all protocols
- [ ] Write unit tests covering CRUD operations, cache expiry, and observation
- [ ] Verify that no persistence types leak through the protocol boundary
- [ ] Confirm thread safety by testing concurrent access patterns
