---
name: generic-android-to-ios-room-database
description: Use when migrating Android Room database layer (entities, DAOs, migrations, TypeConverters, Flow queries) to iOS SwiftData (iOS 17+) or Core Data (older targets)
type: generic
---

# generic-android-to-ios-room-database

## Context
Room is Android's recommended abstraction over SQLite, providing compile-time verified queries, reactive data access via Kotlin Flow, and structured migrations. On iOS the closest modern equivalent is SwiftData (iOS 17+), which offers a similarly declarative model layer with `@Model`, `@Query`, and `ModelContainer`. For projects that must support iOS 16 or earlier, Core Data with `NSManagedObject` and `NSFetchedResultsController` is the standard approach.

This skill guides the migration of the entire Room database layer -- schema definitions, data access objects, database configuration, migrations, type converters, relationships, and reactive queries -- to idiomatic iOS equivalents.

## Android Best Practices (Room)
- Define entities with `@Entity`, primary keys with `@PrimaryKey(autoGenerate = true)`, and indices with `@ColumnInfo`.
- Use `@Dao` interfaces with suspend functions for one-shot operations and `Flow<List<T>>` for observable queries.
- Centralise the database in a single `@Database` abstract class with a version number and entity list.
- Handle schema changes via `Migration` objects registered on the database builder.
- Use `@TypeConverter` for non-primitive types (enums, dates, JSON blobs).
- Keep DAO methods small and composable; prefer SQL queries over in-memory filtering.
- Use `@Transaction` for operations that span multiple tables.
- Always access the database off the main thread (Room enforces this by default).

### Kotlin Patterns

```kotlin
// --- Entity ---
@Entity(tableName = "landmarks")
data class LandmarkEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    @ColumnInfo(name = "name") val name: String,
    @ColumnInfo(name = "latitude") val latitude: Double,
    @ColumnInfo(name = "longitude") val longitude: Double,
    @ColumnInfo(name = "category") val category: LandmarkCategory,
    @ColumnInfo(name = "created_at") val createdAt: Long = System.currentTimeMillis()
)

// --- TypeConverter ---
class Converters {
    @TypeConverter
    fun fromCategory(value: LandmarkCategory): String = value.name

    @TypeConverter
    fun toCategory(value: String): LandmarkCategory =
        LandmarkCategory.valueOf(value)
}

// --- DAO ---
@Dao
interface LandmarkDao {
    @Query("SELECT * FROM landmarks ORDER BY created_at DESC")
    fun observeAll(): Flow<List<LandmarkEntity>>

    @Query("SELECT * FROM landmarks WHERE id = :id")
    suspend fun getById(id: Long): LandmarkEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(landmark: LandmarkEntity): Long

    @Delete
    suspend fun delete(landmark: LandmarkEntity)

    @Transaction
    @Query("SELECT * FROM landmarks WHERE category = :category")
    fun observeByCategory(category: LandmarkCategory): Flow<List<LandmarkEntity>>
}

// --- Database ---
@Database(
    entities = [LandmarkEntity::class],
    version = 2,
    exportSchema = true
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun landmarkDao(): LandmarkDao
}

// --- Migration ---
val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE landmarks ADD COLUMN category TEXT NOT NULL DEFAULT 'GENERAL'")
    }
}

// --- Builder ---
Room.databaseBuilder(context, AppDatabase::class.java, "waonder.db")
    .addMigrations(MIGRATION_1_2)
    .build()
```

## iOS Best Practices

### SwiftData (iOS 17+)
- Annotate model classes with `@Model`; SwiftData infers the schema from stored properties.
- Use `@Attribute(.unique)` for unique constraints and `@Relationship` for object graphs.
- Access data reactively via `@Query` in SwiftUI views or `ModelContext.fetch()` in non-UI code.
- Register the `ModelContainer` at the app entry point and inject it via the environment.
- Use `VersionedSchema` and `SchemaMigrationPlan` for structured migrations.
- SwiftData handles threading via `ModelActor` for background work.

### Core Data (iOS 15/16)
- Define the schema in a `.xcdatamodeld` file or programmatically with `NSManagedObjectModel`.
- Subclass `NSManagedObject` with `@NSManaged` properties.
- Use `NSPersistentContainer` (or `NSPersistentCloudKitContainer` for CloudKit sync).
- Observe changes with `NSFetchedResultsController` or Combine publishers.
- Perform background work on private-queue contexts via `performBackgroundTask`.
- Use lightweight migration when possible; fall back to mapping models for complex changes.

### Swift Patterns -- SwiftData

```swift
// --- Model ---
import SwiftData

@Model
final class Landmark {
    @Attribute(.unique) var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var category: LandmarkCategory
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        category: LandmarkCategory = .general,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.createdAt = createdAt
    }
}

// Enum must be Codable for SwiftData
enum LandmarkCategory: String, Codable, CaseIterable {
    case general, nature, historical, cultural
}

// --- Container setup ---
@main
struct WaonderApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
            .modelContainer(for: [Landmark.self])
    }
}

// --- Querying in SwiftUI ---
struct LandmarkListView: View {
    @Query(sort: \Landmark.createdAt, order: .reverse)
    private var landmarks: [Landmark]

    var body: some View {
        List(landmarks) { landmark in
            Text(landmark.name)
        }
    }
}

// --- CRUD operations ---
struct LandmarkDetailView: View {
    @Environment(\.modelContext) private var context

    func upsert(_ landmark: Landmark) {
        context.insert(landmark) // SwiftData merges on unique id
        try? context.save()
    }

    func delete(_ landmark: Landmark) {
        context.delete(landmark)
        try? context.save()
    }

    func fetchByCategory(_ category: LandmarkCategory) throws -> [Landmark] {
        let predicate = #Predicate<Landmark> { $0.category == category }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor)
    }
}

// --- Background work with ModelActor ---
@ModelActor
actor BackgroundLandmarkActor {
    func importLandmarks(_ dtos: [LandmarkDTO]) throws {
        for dto in dtos {
            let landmark = Landmark(
                name: dto.name,
                latitude: dto.latitude,
                longitude: dto.longitude,
                category: LandmarkCategory(rawValue: dto.category) ?? .general
            )
            modelContext.insert(landmark)
        }
        try modelContext.save()
    }
}

// --- Migration ---
enum LandmarkSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Landmark.self] }

    @Model final class Landmark {
        var id: UUID
        var name: String
        var latitude: Double
        var longitude: Double
        var createdAt: Date
        init(id: UUID, name: String, latitude: Double, longitude: Double, createdAt: Date) {
            self.id = id; self.name = name; self.latitude = latitude
            self.longitude = longitude; self.createdAt = createdAt
        }
    }
}

enum LandmarkSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Landmark.self] }
    // Landmark now includes `category`
}

enum LandmarkMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LandmarkSchemaV1.self, LandmarkSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: LandmarkSchemaV1.self,
        toVersion: LandmarkSchemaV2.self
    ) { context in
        // Custom migration logic
        let landmarks = try context.fetch(FetchDescriptor<LandmarkSchemaV2.Landmark>())
        for landmark in landmarks {
            landmark.category = .general
        }
        try context.save()
    }
}
```

### Swift Patterns -- Core Data (iOS 15/16)

```swift
// --- NSManagedObject subclass ---
@objc(LandmarkMO)
public class LandmarkMO: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var categoryRaw: String
    @NSManaged public var createdAt: Date

    var category: LandmarkCategory {
        get { LandmarkCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }
}

// --- NSPersistentContainer ---
class CoreDataStack {
    static let shared = CoreDataStack()
    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "Waonder")
        container.loadPersistentStores { _, error in
            if let error { fatalError("Core Data failed: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func performBackground(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }
}

// --- NSFetchedResultsController ---
class LandmarkListViewModel: NSObject, NSFetchedResultsControllerDelegate {
    private let frc: NSFetchedResultsController<LandmarkMO>

    override init() {
        let request = LandmarkMO.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LandmarkMO.createdAt, ascending: false)]
        frc = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: CoreDataStack.shared.container.viewContext,
            sectionNameKeyPath: nil, cacheName: nil
        )
        super.init()
        frc.delegate = self
        try? frc.performFetch()
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        // Notify UI of changes
    }
}
```

## Concept Mapping

| Android (Room) | iOS (SwiftData) | iOS (Core Data) |
|---|---|---|
| `@Entity` | `@Model` | `NSManagedObject` subclass |
| `@PrimaryKey` | `@Attribute(.unique)` | Unique constraint in model editor |
| `@ColumnInfo` | Property declaration | `@NSManaged` property |
| `@Dao` | `ModelContext` / `@Query` | `NSFetchRequest` / `NSFetchedResultsController` |
| `@Database` | `ModelContainer` | `NSPersistentContainer` |
| `@TypeConverter` | `Codable` conformance | Value transformer / computed property |
| `Migration(from, to)` | `SchemaMigrationPlan` | Lightweight / mapping model migration |
| `Flow<List<T>>` | `@Query` (SwiftUI) | `NSFetchedResultsController` + delegate |
| `@Transaction` | Implicit in `ModelContext.save()` | `context.perform { }` |
| `@Embedded` | Nested `Codable` struct | Transformable attribute |
| `@Relation` | `@Relationship` | Core Data relationships |

## Common Pitfalls
1. **Auto-increment IDs**: Room uses `autoGenerate = true` on `Long`. SwiftData typically uses `UUID`. If the Android schema uses sequential integer IDs, either keep an integer `id` property or migrate to UUIDs with a mapping table for server sync.
2. **Enum storage**: Room stores enums via TypeConverters (usually as String). SwiftData requires enums to be `Codable` (use `RawRepresentable` with `String` or `Int`). Core Data stores them as raw values in a String/Int16 attribute.
3. **Reactive queries**: Room returns `Flow<List<T>>` from DAO methods. In SwiftData, `@Query` provides automatic observation in SwiftUI views only. For non-UI observation, use `ModelContext.fetch()` combined with manual notification or a `@ModelActor`.
4. **Threading**: Room forbids main-thread access by default. SwiftData's `ModelContext` is main-actor-isolated unless you use `@ModelActor`. Core Data uses `perform {}` / `performBackgroundTask {}`. Never pass managed objects across threads.
5. **Migration complexity**: Room migrations are raw SQL. SwiftData's `SchemaMigrationPlan` is more structured but less flexible. For complex migrations, use a `.custom` stage. Core Data lightweight migrations handle simple changes automatically.
6. **Relationships**: Room uses `@Relation` with a junction entity for many-to-many. SwiftData uses `@Relationship` with inverse relationships. Forgetting the inverse in SwiftData can cause data loss.
7. **Export schema**: Room's `exportSchema = true` generates JSON schema files for CI verification. SwiftData has no direct equivalent; rely on `VersionedSchema` definitions.

## Migration Checklist
- [ ] Inventory all `@Entity` classes and map each to a `@Model` class (SwiftData) or `NSManagedObject` subclass (Core Data)
- [ ] Convert `@TypeConverter` types to `Codable`-conforming enums or structs
- [ ] Map each `@Dao` method to the equivalent `ModelContext` operation or `NSFetchRequest`
- [ ] Translate `Flow<List<T>>` queries to `@Query` properties or `NSFetchedResultsController`
- [ ] Replicate Room migrations as `SchemaMigrationPlan` stages or Core Data mapping models
- [ ] Set up `ModelContainer` / `NSPersistentContainer` in the app entry point
- [ ] Move background database operations to `@ModelActor` or `performBackgroundTask`
- [ ] Map `@Relation` / `@Junction` to `@Relationship` with explicit inverses
- [ ] Add unit tests using in-memory model containers / in-memory persistent stores
- [ ] Verify data integrity after migration with sample data roundtrip tests
- [ ] Handle `@Embedded` objects by converting to `Codable` structs stored inline
- [ ] Confirm cascade delete rules match Room's `@ForeignKey(onDelete = CASCADE)`
