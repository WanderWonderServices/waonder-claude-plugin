---
name: generic-android-to-ios-coroutines
description: Use when migrating Kotlin Coroutines patterns (suspend, launch, async, Dispatchers, structured concurrency) to Swift Concurrency equivalents (async/await, Task, TaskGroup, actors, MainActor)
type: generic
---

# generic-android-to-ios-coroutines

## Context

Kotlin Coroutines and Swift Concurrency share the same goal — structured, lightweight concurrency without callback hell — but differ in API surface and runtime model. Kotlin uses `suspend` functions, `CoroutineScope`, and `Dispatchers`. Swift uses `async` functions, `Task`, and actors. This skill provides a comprehensive migration guide between the two.

## Android Best Practices (Source Patterns)

### Suspend Functions

```kotlin
// Basic suspend function
suspend fun fetchUser(id: String): User {
    return apiService.getUser(id) // suspends, does not block
}

// Calling from a coroutine
viewModelScope.launch {
    val user = fetchUser("123")
    _state.value = UiState.Success(user)
}
```

### Launch vs Async

```kotlin
// launch — fire-and-forget, returns Job
viewModelScope.launch {
    repository.syncData()
}

// async — returns Deferred<T>, use .await() to get result
viewModelScope.launch {
    val userDeferred = async { fetchUser("123") }
    val postsDeferred = async { fetchPosts("123") }
    val user = userDeferred.await()
    val posts = postsDeferred.await()
    _state.value = UiState.Success(user, posts)
}
```

### withContext (Dispatcher Switching)

```kotlin
suspend fun loadImage(url: String): Bitmap = withContext(Dispatchers.IO) {
    val bytes = httpClient.download(url)
    BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
}

// Dispatchers
// Dispatchers.Main       — main/UI thread
// Dispatchers.IO         — I/O-optimized thread pool
// Dispatchers.Default    — CPU-optimized thread pool
// Dispatchers.Unconfined — no confinement (resumes in caller's context)
```

### CoroutineScope & Structured Concurrency

```kotlin
@HiltViewModel
class ItemsViewModel @Inject constructor(
    private val repository: ItemsRepository
) : ViewModel() {

    // viewModelScope is automatically cancelled when ViewModel is cleared
    fun loadItems() {
        viewModelScope.launch {
            try {
                _state.value = UiState.Loading
                val items = repository.getItems()
                _state.value = UiState.Success(items)
            } catch (e: CancellationException) {
                throw e // always rethrow CancellationException
            } catch (e: Exception) {
                _state.value = UiState.Error(e.message)
            }
        }
    }
}

// Custom scope with SupervisorJob
class DataSyncManager {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun startSync() {
        scope.launch { syncUsers() }
        scope.launch { syncPosts() } // failure here doesn't cancel syncUsers
    }

    fun cancel() {
        scope.cancel()
    }
}
```

### Coroutine Cancellation

```kotlin
suspend fun fetchWithTimeout() {
    withTimeout(5000L) {
        val data = repository.fetchData()
        ensureActive() // check cancellation manually
        processData(data)
    }
}
```

## iOS Best Practices (Target Patterns)

### Async Functions

```swift
// Basic async function (equivalent to suspend fun)
func fetchUser(id: String) async throws -> User {
    try await apiService.getUser(id)
}

// Calling from a Task (equivalent to launch)
func loadUser() {
    Task {
        let user = try await fetchUser(id: "123")
        self.state = .success(user)
    }
}
```

### Task (Equivalent to launch)

```swift
// Unstructured Task — equivalent to viewModelScope.launch
func loadItems() {
    Task { @MainActor in
        state = .loading
        do {
            let items = try await repository.getItems()
            state = .success(items)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

// Detached Task — equivalent to launch with a different dispatcher
Task.detached(priority: .background) {
    await repository.syncData()
}
```

### TaskGroup (Equivalent to async/await)

```swift
// Parallel execution — equivalent to multiple async { }.await()
func loadUserAndPosts(id: String) async throws -> (User, [Post]) {
    async let user = fetchUser(id: id)
    async let posts = fetchPosts(userId: id)
    return try await (user, posts)
}

// Dynamic parallelism — equivalent to coroutineScope + multiple async
func loadAllItems(ids: [String]) async throws -> [Item] {
    try await withThrowingTaskGroup(of: Item.self) { group in
        for id in ids {
            group.addTask {
                try await self.fetchItem(id: id)
            }
        }
        var results: [Item] = []
        for try await item in group {
            results.append(item)
        }
        return results
    }
}
```

### Actors (Thread Safety)

```swift
// actor — equivalent to single-threaded dispatcher confinement
actor DataSyncManager {
    private var isSyncing = false

    func startSync() async throws {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        try await syncUsers()
        try await syncPosts()
    }
}

// @MainActor — equivalent to Dispatchers.Main / withContext(Dispatchers.Main)
@MainActor
@Observable
final class ItemsViewModel {
    var state: UiState<[Item]> = .idle

    func loadItems() async {
        state = .loading
        do {
            let items = try await repository.getItems()
            state = .success(items)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
```

### Cancellation

```swift
// Task cancellation — equivalent to Job.cancel()
let task = Task {
    try await fetchData()
}
task.cancel()

// Check cancellation — equivalent to ensureActive()
func processItems(_ items: [Item]) async throws {
    for item in items {
        try Task.checkCancellation() // throws CancellationError
        await process(item)
    }
}

// Cooperative cancellation check
if Task.isCancelled {
    return partialResult
}

// withTaskCancellationHandler — cleanup on cancel
func fetchData() async throws -> Data {
    let handle = startNetworkRequest()
    return try await withTaskCancellationHandler {
        try await handle.result()
    } onCancel: {
        handle.cancel()
    }
}
```

## Dispatcher to Executor Mapping

| Kotlin Dispatcher         | Swift Equivalent                              | Notes                                    |
|---------------------------|-----------------------------------------------|------------------------------------------|
| `Dispatchers.Main`        | `@MainActor` / `MainActor.run { }`           | UI thread                                |
| `Dispatchers.IO`          | Default async context (cooperative pool)       | Swift runtime manages I/O automatically  |
| `Dispatchers.Default`     | Default async context                          | Swift uses a shared cooperative pool      |
| `Dispatchers.Unconfined`  | No direct equivalent                           | Use `Task.detached` for unconfined-like   |
| Custom dispatcher         | Custom `SerialExecutor` or `actor`             | Actors serialize access                  |

**Key difference**: Swift Concurrency uses a single cooperative thread pool. There is no separate I/O vs CPU pool. The runtime manages thread allocation. CPU-intensive work should use `Task.detached(priority: .utility)` to avoid blocking the cooperative pool.

## Structured Concurrency Comparison

| Kotlin                              | Swift                                          |
|-------------------------------------|------------------------------------------------|
| `coroutineScope { }`               | `withThrowingTaskGroup { }`                    |
| `supervisorScope { }`              | `withThrowingTaskGroup` (individual catch)     |
| `viewModelScope`                    | `Task` stored in ViewModel, cancelled in deinit|
| `lifecycleScope`                    | `.task { }` modifier in SwiftUI                |
| `launch { }`                        | `Task { }`                                     |
| `async { }.await()`                | `async let x = ...; await x`                  |
| `SupervisorJob()`                  | TaskGroup with per-child error handling         |
| `Job.cancel()`                     | `Task.cancel()`                                |
| `withTimeout(ms)`                  | `withThrowingTimeout` or custom `Task.sleep`   |

## ViewModel Lifecycle Mapping

### Android
```kotlin
@HiltViewModel
class MyViewModel @Inject constructor(
    private val repo: Repository
) : ViewModel() {
    init {
        viewModelScope.launch {
            repo.observeData().collect { data ->
                _state.value = data
            }
        }
    }
    // viewModelScope automatically cancelled on onCleared()
}
```

### iOS
```swift
@MainActor
@Observable
final class MyViewModel {
    private let repo: RepositoryProtocol
    private var observeTask: Task<Void, Never>?

    var data: [Item] = []

    init(repo: RepositoryProtocol) {
        self.repo = repo
        observeTask = Task { [weak self] in
            guard let stream = self?.repo.observeData() else { return }
            for await items in stream {
                self?.data = items
            }
        }
    }

    deinit {
        observeTask?.cancel()
    }
}

// Or in SwiftUI, use .task modifier (auto-cancelled on view disappear)
struct MyScreen: View {
    @State private var viewModel: MyViewModel

    var body: some View {
        List(viewModel.data) { item in
            Text(item.name)
        }
        .task {
            await viewModel.startObserving()
        }
    }
}
```

## Error Handling

### Android
```kotlin
viewModelScope.launch {
    try {
        val result = repository.fetchData()
        _state.value = UiState.Success(result)
    } catch (e: CancellationException) {
        throw e // MUST rethrow
    } catch (e: HttpException) {
        _state.value = UiState.Error("Network error: ${e.code()}")
    } catch (e: IOException) {
        _state.value = UiState.Error("Connection error")
    }
}
```

### iOS
```swift
func loadData() async {
    do {
        let result = try await repository.fetchData()
        state = .success(result)
    } catch is CancellationError {
        return // CancellationError is automatically propagated if not caught
    } catch let error as URLError {
        state = .error("Network error: \(error.code.rawValue)")
    } catch {
        state = .error("Connection error: \(error.localizedDescription)")
    }
}
```

## Testing

### Android
```kotlin
@Test
fun `loadItems updates state`() = runTest {
    val fakeRepo = FakeRepository(items = listOf(Item("1")))
    val vm = ItemsViewModel(fakeRepo)

    vm.loadItems()
    advanceUntilIdle()

    assertEquals(UiState.Success(listOf(Item("1"))), vm.state.value)
}
```

### iOS
```swift
@Test func loadItemsUpdatesState() async {
    let fakeRepo = FakeRepository(items: [Item(id: "1")])
    let vm = await ItemsViewModel(repo: fakeRepo)

    await vm.loadItems()

    await #expect(vm.state == .success([Item(id: "1")]))
}
```

## Common Pitfalls

1. **No `viewModelScope` equivalent**: Swift has no built-in scope tied to ViewModel lifecycle. Store `Task` references and cancel them in `deinit`, or use SwiftUI's `.task` modifier.
2. **Forgetting `@MainActor`**: Unlike `Dispatchers.Main`, Swift does not automatically switch to the main thread for UI updates. Annotate ViewModels or state-mutating code with `@MainActor`.
3. **Catching `CancellationError`**: In Kotlin you must rethrow `CancellationException`. In Swift, `CancellationError` propagates naturally through `throws`, but catching it with a bare `catch` can silently swallow cancellation.
4. **`Task.detached` overuse**: `Task.detached` does not inherit the parent actor context. Use it only when you explicitly need to escape `@MainActor` confinement.
5. **Missing `[weak self]` in long-lived Tasks**: Unstructured `Task { }` captures `self` strongly. Use `[weak self]` for tasks that outlive the ViewModel.
6. **No `withTimeout` in stdlib**: Swift does not have a built-in `withTimeout`. Use `Task.sleep` with a cancellation pattern or a third-party utility.
7. **Blocking the cooperative pool**: Never call `Thread.sleep()` or synchronous blocking APIs inside an async context. Use `Task.sleep(nanoseconds:)` instead.

## Migration Checklist

- [ ] Convert all `suspend fun` to `async throws` functions
- [ ] Replace `viewModelScope.launch` with `Task { }` (store reference for cancellation)
- [ ] Replace `async { }.await()` with `async let` or `TaskGroup`
- [ ] Replace `withContext(Dispatchers.Main)` with `@MainActor`
- [ ] Replace `withContext(Dispatchers.IO)` — usually not needed; Swift manages threads
- [ ] Replace `withTimeout` with custom timeout using `Task.sleep` + cancellation
- [ ] Map `CoroutineScope` lifecycle to `Task` lifecycle with proper cancellation in `deinit`
- [ ] Add `@MainActor` to all ViewModels that update UI state
- [ ] Replace `ensureActive()` with `try Task.checkCancellation()`
- [ ] Use `withTaskCancellationHandler` for cleanup on cancellation (network handles, etc.)
- [ ] Convert `runTest` / `TestCoroutineDispatcher` tests to Swift Testing `async` tests
- [ ] Audit for `[weak self]` in long-lived `Task` closures
