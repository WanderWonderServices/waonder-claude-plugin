---
name: generic-android-to-ios-repository
description: Use when migrating Android Repository patterns (single source of truth, Flow-based APIs, local+remote coordination) to iOS equivalents (Swift protocols, async/await, AsyncSequence) with offline-first, caching, error handling, and testing strategies
type: generic
---

# generic-android-to-ios-repository

## Context

The Repository pattern in Android acts as the single source of truth, mediating between local database (Room), remote API (Retrofit), and in-memory cache. It exposes reactive `Flow`-based APIs so ViewModels observe data changes automatically. On iOS, the same pattern translates to Swift protocols with `async/await` and `AsyncSequence` APIs, backed by Core Data/SwiftData, URLSession, and actor-based caches. This skill provides a comprehensive mapping for migrating Android repositories to idiomatic iOS implementations.

## Android Best Practices (Source Patterns)

### Standard Repository with Offline-First

```kotlin
interface UserRepository {
    fun observeUser(userId: String): Flow<User>
    suspend fun refreshUser(userId: String): Result<User>
    suspend fun updateUser(user: User): Result<Unit>
    fun observeUsers(): Flow<List<User>>
}

class UserRepositoryImpl @Inject constructor(
    private val userApi: UserApi,
    private val userDao: UserDao,
    private val dispatchers: DispatcherProvider
) : UserRepository {

    override fun observeUser(userId: String): Flow<User> {
        return userDao.observeUser(userId)
            .onStart { refreshUser(userId) }
            .flowOn(dispatchers.io)
    }

    override suspend fun refreshUser(userId: String): Result<User> {
        return withContext(dispatchers.io) {
            runCatching {
                val remoteUser = userApi.getUser(userId)
                userDao.upsert(remoteUser.toEntity())
                remoteUser.toDomain()
            }
        }
    }

    override suspend fun updateUser(user: User): Result<Unit> {
        return withContext(dispatchers.io) {
            runCatching {
                userDao.upsert(user.toEntity())
                userApi.updateUser(user.toDto())
            }
        }
    }

    override fun observeUsers(): Flow<List<User>> {
        return userDao.observeAll()
            .map { entities -> entities.map { it.toDomain() } }
            .onStart { refreshAllUsers() }
            .flowOn(dispatchers.io)
    }

    private suspend fun refreshAllUsers() {
        runCatching {
            val remoteUsers = userApi.getUsers()
            userDao.upsertAll(remoteUsers.map { it.toEntity() })
        }
    }
}
```

### Caching Strategy with NetworkBoundResource

```kotlin
inline fun <ResultType, RequestType> networkBoundResource(
    crossinline query: () -> Flow<ResultType>,
    crossinline fetch: suspend () -> RequestType,
    crossinline saveFetchResult: suspend (RequestType) -> Unit,
    crossinline shouldFetch: (ResultType) -> Boolean = { true }
): Flow<Resource<ResultType>> = flow {
    val data = query().first()
    val flow = if (shouldFetch(data)) {
        emit(Resource.Loading(data))
        try {
            saveFetchResult(fetch())
            query().map { Resource.Success(it) }
        } catch (throwable: Throwable) {
            query().map { Resource.Error(throwable, it) }
        }
    } else {
        query().map { Resource.Success(it) }
    }
    emitAll(flow)
}

sealed class Resource<T>(val data: T?, val error: Throwable?) {
    class Success<T>(data: T) : Resource<T>(data, null)
    class Error<T>(error: Throwable, data: T? = null) : Resource<T>(data, error)
    class Loading<T>(data: T? = null) : Resource<T>(data, null)
}
```

### Room DAO Pattern

```kotlin
@Dao
interface UserDao {
    @Query("SELECT * FROM users WHERE id = :userId")
    fun observeUser(userId: String): Flow<UserEntity>

    @Query("SELECT * FROM users")
    fun observeAll(): Flow<List<UserEntity>>

    @Upsert
    suspend fun upsert(user: UserEntity)

    @Upsert
    suspend fun upsertAll(users: List<UserEntity>)

    @Query("DELETE FROM users WHERE id = :userId")
    suspend fun delete(userId: String)
}
```

### Key Android Patterns to Recognize

- `Flow`-based observation from Room DAOs — database as single source of truth
- `onStart { refresh() }` — trigger network fetch when observation begins
- `flowOn(Dispatchers.IO)` — thread confinement for I/O operations
- `runCatching` / `Result<T>` — structured error handling
- `NetworkBoundResource` — conditional fetch + cache pattern
- Entity/DTO/Domain model separation with mapper extensions

## iOS Best Practices (Target Patterns)

### Standard Repository with Offline-First

```swift
protocol UserRepository: Sendable {
    func observeUser(userId: String) -> AsyncThrowingStream<User, Error>
    func refreshUser(userId: String) async throws -> User
    func updateUser(_ user: User) async throws
    func observeUsers() -> AsyncThrowingStream<[User], Error>
}

final class UserRepositoryImpl: UserRepository, Sendable {
    private let userAPI: UserAPIProtocol
    private let userStore: UserStoreProtocol  // Core Data / SwiftData wrapper

    init(userAPI: UserAPIProtocol, userStore: UserStoreProtocol) {
        self.userAPI = userAPI
        self.userStore = userStore
    }

    func observeUser(userId: String) -> AsyncThrowingStream<User, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                // Trigger refresh in background
                Task { try? await refreshUser(userId: userId) }

                do {
                    for try await user in userStore.observe(userId: userId) {
                        continuation.yield(user)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @discardableResult
    func refreshUser(userId: String) async throws -> User {
        let remoteUser = try await userAPI.getUser(userId: userId)
        try await userStore.upsert(remoteUser)
        return remoteUser
    }

    func updateUser(_ user: User) async throws {
        try await userStore.upsert(user)
        try await userAPI.updateUser(user)
    }

    func observeUsers() -> AsyncThrowingStream<[User], Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                Task { try? await refreshAllUsers() }

                do {
                    for try await users in userStore.observeAll() {
                        continuation.yield(users)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func refreshAllUsers() async throws {
        let remoteUsers = try await userAPI.getUsers()
        try await userStore.upsertAll(remoteUsers)
    }
}
```

### NetworkBoundResource Equivalent

```swift
enum ResourceState<T: Sendable>: Sendable {
    case loading(cached: T?)
    case success(T)
    case error(Error, cached: T?)
}

func networkBoundResource<T: Sendable>(
    query: @Sendable @escaping () -> AsyncThrowingStream<T, Error>,
    fetch: @Sendable @escaping () async throws -> T,
    saveFetchResult: @Sendable @escaping (T) async throws -> Void,
    shouldFetch: @Sendable @escaping (T) -> Bool = { _ in true }
) -> AsyncThrowingStream<ResourceState<T>, Error> {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                var iterator = query().makeAsyncIterator()
                guard let cachedData = try await iterator.next() else {
                    continuation.finish()
                    return
                }

                if shouldFetch(cachedData) {
                    continuation.yield(.loading(cached: cachedData))
                    do {
                        let fetched = try await fetch()
                        try await saveFetchResult(fetched)
                    } catch {
                        continuation.yield(.error(error, cached: cachedData))
                    }
                }

                // Continue observing the local store
                for try await data in query() {
                    continuation.yield(.success(data))
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
```

### SwiftData Store (Room DAO Equivalent)

```swift
protocol UserStoreProtocol: Sendable {
    func observe(userId: String) -> AsyncThrowingStream<User, Error>
    func observeAll() -> AsyncThrowingStream<[User], Error>
    func upsert(_ user: User) async throws
    func upsertAll(_ users: [User]) async throws
    func delete(userId: String) async throws
}

@ModelActor
actor UserStore: UserStoreProtocol {
    func observe(userId: String) -> AsyncThrowingStream<User, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [modelExecutor] in
                let context = ModelContext(modelExecutor.modelContainer)
                while !Task.isCancelled {
                    let descriptor = FetchDescriptor<UserModel>(
                        predicate: #Predicate { $0.id == userId }
                    )
                    if let model = try? context.fetch(descriptor).first {
                        continuation.yield(model.toDomain())
                    }
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func upsert(_ user: User) async throws {
        let descriptor = FetchDescriptor<UserModel>(
            predicate: #Predicate { $0.id == user.id }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.update(from: user)
        } else {
            modelContext.insert(UserModel(from: user))
        }
        try modelContext.save()
    }

    func upsertAll(_ users: [User]) async throws {
        for user in users {
            try await upsert(user)
        }
    }

    func delete(userId: String) async throws {
        let descriptor = FetchDescriptor<UserModel>(
            predicate: #Predicate { $0.id == userId }
        )
        if let model = try modelContext.fetch(descriptor).first {
            modelContext.delete(model)
            try modelContext.save()
        }
    }
}
```

### API Layer (Retrofit Equivalent)

```swift
protocol UserAPIProtocol: Sendable {
    func getUser(userId: String) async throws -> User
    func getUsers() async throws -> [User]
    func updateUser(_ user: User) async throws
}

struct UserAPI: UserAPIProtocol {
    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder

    func getUser(userId: String) async throws -> User {
        let url = baseURL.appendingPathComponent("users/\(userId)")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        return try decoder.decode(UserDTO.self, from: data).toDomain()
    }
}
```

## Migration Mapping Table

| Android | iOS |
|---|---|
| `Flow<T>` from Room | `AsyncThrowingStream<T, Error>` |
| `Room @Dao` | `@ModelActor` with SwiftData / Core Data actor |
| `Retrofit` interface | `URLSession` + protocol |
| `@Inject constructor` | `init` with protocol dependencies |
| `flowOn(Dispatchers.IO)` | Actor isolation or `Task` (Swift concurrency handles threads) |
| `runCatching { }` | `do { try await } catch { }` |
| `Result<T>` | `throws` (or explicit `Result<T, Error>` when needed) |
| `Flow.map { }` | `AsyncThrowingStream` + `.map` via AsyncAlgorithms |
| `Flow.onStart { }` | Launch a background `Task` inside the stream builder |
| `@Upsert` | Manual fetch + insert/update in ModelContext |
| Entity / DTO / Domain mappers | `@Model` / Codable DTO / Domain struct + extensions |
| `NetworkBoundResource` | Custom `AsyncThrowingStream` builder (see above) |

## Caching Strategies

### Time-Based Cache Invalidation

```swift
actor CachePolicy {
    private var lastFetchTimestamps: [String: Date] = [:]
    private let maxAge: TimeInterval

    init(maxAge: TimeInterval = 300) { // 5 minutes
        self.maxAge = maxAge
    }

    func shouldFetch(key: String) -> Bool {
        guard let lastFetch = lastFetchTimestamps[key] else { return true }
        return Date().timeIntervalSince(lastFetch) > maxAge
    }

    func recordFetch(key: String) {
        lastFetchTimestamps[key] = Date()
    }
}
```

### In-Memory Cache with Actor

```swift
actor InMemoryCache<Key: Hashable & Sendable, Value: Sendable> {
    private var storage: [Key: CacheEntry<Value>] = [:]
    private let maxAge: TimeInterval

    struct CacheEntry<V> {
        let value: V
        let timestamp: Date
    }

    init(maxAge: TimeInterval = 300) {
        self.maxAge = maxAge
    }

    func get(_ key: Key) -> Value? {
        guard let entry = storage[key],
              Date().timeIntervalSince(entry.timestamp) <= maxAge else {
            storage[key] = nil
            return nil
        }
        return entry.value
    }

    func set(_ key: Key, value: Value) {
        storage[key] = CacheEntry(value: value, timestamp: Date())
    }

    func invalidate(_ key: Key) {
        storage[key] = nil
    }

    func invalidateAll() {
        storage.removeAll()
    }
}
```

## Error Handling

```swift
enum RepositoryError: Error, LocalizedError {
    case networkUnavailable
    case serverError(statusCode: Int)
    case decodingFailed(underlying: Error)
    case localStoreFailed(underlying: Error)
    case notFound

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: "No network connection available"
        case .serverError(let code): "Server returned error \(code)"
        case .decodingFailed: "Failed to decode response"
        case .localStoreFailed: "Local database operation failed"
        case .notFound: "Requested resource not found"
        }
    }
}
```

## Testing

```swift
// Mock for unit testing
final class MockUserStore: UserStoreProtocol {
    var usersToReturn: [User] = []
    var upsertedUsers: [User] = []
    var deletedIds: [String] = []

    func observe(userId: String) -> AsyncThrowingStream<User, Error> {
        AsyncThrowingStream { continuation in
            if let user = usersToReturn.first(where: { $0.id == userId }) {
                continuation.yield(user)
            }
            continuation.finish()
        }
    }

    func observeAll() -> AsyncThrowingStream<[User], Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(usersToReturn)
            continuation.finish()
        }
    }

    func upsert(_ user: User) async throws {
        upsertedUsers.append(user)
    }

    func upsertAll(_ users: [User]) async throws {
        upsertedUsers.append(contentsOf: users)
    }

    func delete(userId: String) async throws {
        deletedIds.append(userId)
    }
}

// Test example
@Test func refreshUser_savesToLocalStore() async throws {
    let mockAPI = MockUserAPI()
    let mockStore = MockUserStore()
    let repo = UserRepositoryImpl(userAPI: mockAPI, userStore: mockStore)

    mockAPI.userToReturn = User(id: "1", name: "Alice")

    let user = try await repo.refreshUser(userId: "1")

    #expect(user.name == "Alice")
    #expect(mockStore.upsertedUsers.count == 1)
    #expect(mockStore.upsertedUsers.first?.id == "1")
}
```

## Common Pitfalls

1. **Not using the local store as single source of truth** — Always write remote data to the local store first, then observe the local store. Never return remote data directly to the ViewModel.

2. **Blocking the main actor** — Repository methods should not be `@MainActor`. Let them run on default (cooperative) concurrency or actor-isolated contexts. Only ViewModel state mutations need `@MainActor`.

3. **AsyncThrowingStream not cancelling properly** — Always set `onTermination` on your continuation to cancel inner tasks. Forgetting this causes task leaks.

4. **Ignoring Sendable** — Repository implementations must be `Sendable` since they are shared across concurrency domains. Use actors for mutable state, or ensure the class is truly immutable.

5. **Over-fetching from network** — Without cache policies, every observation triggers a network call. Implement time-based or event-based cache invalidation.

6. **SwiftData context threading** — `ModelContext` is not `Sendable`. Use `@ModelActor` to safely interact with SwiftData from concurrent contexts.

## Migration Checklist

- [ ] Define Swift protocol for each Repository interface
- [ ] Create concrete implementation with protocol-based dependencies (API + Store)
- [ ] Convert `Flow`-based APIs to `AsyncThrowingStream`
- [ ] Convert `suspend` functions to `async throws`
- [ ] Implement local store using SwiftData `@ModelActor` or Core Data
- [ ] Implement API layer using `URLSession` + `Codable`
- [ ] Create domain model, DTO (Codable), and `@Model` types with mappers
- [ ] Implement cache invalidation strategy (time-based, event-based, or manual)
- [ ] Set up proper error types replacing `runCatching`/`Result`
- [ ] Ensure all repository types are `Sendable`
- [ ] Write mock implementations of Store and API protocols for unit testing
- [ ] Write repository unit tests verifying offline-first flow
- [ ] Verify `AsyncThrowingStream` continuations handle cancellation correctly
