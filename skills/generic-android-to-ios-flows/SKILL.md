---
name: generic-android-to-ios-flows
description: Migrates Kotlin Flow patterns (flow builders, operators, flowOn, collect) to iOS equivalents (AsyncSequence, AsyncStream, Combine publishers)
type: generic
---

# generic-android-to-ios-flows

## Context

Kotlin Flow is the standard reactive stream API on Android, providing cold streams with rich operator support. iOS has two main equivalents: AsyncSequence (modern Swift Concurrency) and Combine (Apple's reactive framework). This skill covers migrating Flow patterns to idiomatic iOS code, with emphasis on AsyncSequence as the preferred modern approach.

## Android Best Practices (Source Patterns)

### Flow Builders

```kotlin
// flow { } builder — cold stream, emits on collect
fun observeItems(): Flow<List<Item>> = flow {
    while (currentCoroutineContext().isActive) {
        val items = repository.fetchItems()
        emit(items)
        delay(30_000)
    }
}

// flowOf — single or fixed values
val staticFlow = flowOf("A", "B", "C")

// asFlow — convert collections or sequences
val listFlow = listOf(1, 2, 3).asFlow()

// callbackFlow — bridge callback APIs to Flow
fun observeLocation(): Flow<Location> = callbackFlow {
    val callback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            trySend(result.lastLocation)
        }
    }
    locationClient.requestUpdates(callback)
    awaitClose { locationClient.removeUpdates(callback) }
}
```

### Flow Operators

```kotlin
repository.observeItems()
    .map { items -> items.filter { it.isActive } }
    .filter { it.isNotEmpty() }
    .distinctUntilChanged()
    .debounce(300)
    .catch { e -> emit(emptyList()) }
    .flowOn(Dispatchers.IO)
    .collect { items ->
        _state.value = UiState.Success(items)
    }
```

### Combine and Transform

```kotlin
// combine — merge latest values from multiple flows
combine(
    userFlow,
    settingsFlow,
    notificationsFlow
) { user, settings, notifications ->
    DashboardState(user, settings, notifications)
}.collect { state ->
    _dashboardState.value = state
}

// flatMapLatest — switch to new flow, cancel previous
searchQueryFlow
    .debounce(300)
    .flatMapLatest { query ->
        if (query.isEmpty()) flowOf(emptyList())
        else repository.search(query)
    }
    .collect { results ->
        _searchResults.value = results
    }

// zip — pair elements 1:1
flow1.zip(flow2) { a, b -> Pair(a, b) }
```

### Error Handling

```kotlin
repository.observeData()
    .catch { e ->
        // Catches upstream errors, can emit recovery values
        emit(cachedData)
        // or rethrow: throw e
    }
    .onCompletion { cause ->
        // Called when flow completes (normally or with error)
        if (cause != null) logError(cause)
    }
    .collect { data -> processData(data) }

// retry
repository.fetchData()
    .retry(3) { cause ->
        cause is IOException
    }
    .collect { data -> handleData(data) }
```

### flowOn (Context Switching)

```kotlin
// flowOn changes the upstream context only
repository.heavyComputation()
    .flowOn(Dispatchers.Default) // upstream runs on Default
    .map { transform(it) }       // this runs on collector's context
    .flowOn(Dispatchers.IO)      // upstream (map) runs on IO
    .collect { updateUi(it) }    // runs on Main (viewModelScope)
```

## iOS Best Practices (Target Patterns)

### AsyncSequence (Preferred Modern Approach)

```swift
// AsyncStream — equivalent to flow { } builder
func observeItems() -> AsyncStream<[Item]> {
    AsyncStream { continuation in
        let task = Task {
            while !Task.isCancelled {
                let items = try? await repository.fetchItems()
                continuation.yield(items ?? [])
                try? await Task.sleep(for: .seconds(30))
            }
        }
        continuation.onTermination = { _ in
            task.cancel()
        }
    }
}

// AsyncThrowingStream — equivalent to flow { } with errors
func observeItems() -> AsyncThrowingStream<[Item], Error> {
    AsyncThrowingStream { continuation in
        let task = Task {
            while !Task.isCancelled {
                do {
                    let items = try await repository.fetchItems()
                    continuation.yield(items)
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    continuation.finish(throwing: error)
                    return
                }
            }
        }
        continuation.onTermination = { _ in
            task.cancel()
        }
    }
}
```

### Bridging Callbacks (Equivalent to callbackFlow)

```swift
func observeLocation() -> AsyncStream<CLLocation> {
    AsyncStream { continuation in
        let delegate = LocationDelegate(
            onLocation: { location in
                continuation.yield(location)
            }
        )
        locationManager.delegate = delegate

        continuation.onTermination = { _ in
            locationManager.stopUpdatingLocation()
        }

        locationManager.startUpdatingLocation()
    }
}
```

### AsyncSequence Operators

```swift
// map, filter — built into AsyncSequence protocol
let activeItems = repository.observeItems()
    .map { items in items.filter { $0.isActive } }
    .filter { !$0.isEmpty }

// Consume with for-await
for await items in activeItems {
    state = .success(items)
}

// compactMap — filter nil values
let validItems = stream.compactMap { $0 }

// prefix — take first N elements (equivalent to take)
let firstThree = stream.prefix(3)

// dropFirst — skip first N elements (equivalent to drop)
let afterFirst = stream.dropFirst(1)
```

### Combine Framework (Alternative)

```swift
import Combine

// Publisher — equivalent to Flow
let itemsPublisher: AnyPublisher<[Item], Error> = URLSession.shared
    .dataTaskPublisher(for: url)
    .map(\.data)
    .decode(type: [Item].self, decoder: JSONDecoder())
    .eraseToAnyPublisher()

// Operators
itemsPublisher
    .map { items in items.filter { $0.isActive } }
    .filter { !$0.isEmpty }
    .removeDuplicates()
    .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
    .catch { _ in Just([]) }
    .receive(on: DispatchQueue.main) // equivalent to flowOn
    .sink { items in
        self.state = .success(items)
    }
    .store(in: &cancellables)
```

### Combine: combineLatest and merge

```swift
// combineLatest — equivalent to combine()
Publishers.CombineLatest3(
    userPublisher,
    settingsPublisher,
    notificationsPublisher
)
.map { user, settings, notifications in
    DashboardState(user: user, settings: settings, notifications: notifications)
}
.sink { state in
    self.dashboardState = state
}
.store(in: &cancellables)

// merge — equivalent to merge()
Publishers.Merge(publisher1, publisher2)
    .sink { value in handleValue(value) }
    .store(in: &cancellables)

// switchToLatest — equivalent to flatMapLatest
searchQueryPublisher
    .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
    .map { query in
        query.isEmpty
            ? Just([]).eraseToAnyPublisher()
            : self.repository.search(query).eraseToAnyPublisher()
    }
    .switchToLatest()
    .sink { results in
        self.searchResults = results
    }
    .store(in: &cancellables)
```

### AsyncSequence: Combining Streams

```swift
// Merge multiple AsyncSequences (swift-async-algorithms)
import AsyncAlgorithms

for await value in merge(stream1, stream2) {
    handle(value)
}

// combineLatest (swift-async-algorithms)
for await (user, settings) in combineLatest(userStream, settingsStream) {
    state = DashboardState(user: user, settings: settings)
}

// zip (swift-async-algorithms)
for await (a, b) in zip(stream1, stream2) {
    process(a, b)
}

// Manual combine with TaskGroup
func combinedStream() async {
    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            for await user in self.userStream {
                await self.updateUser(user)
            }
        }
        group.addTask {
            for await settings in self.settingsStream {
                await self.updateSettings(settings)
            }
        }
    }
}
```

## Operator Mapping Reference

| Kotlin Flow                    | AsyncSequence                         | Combine                                |
|-------------------------------|---------------------------------------|----------------------------------------|
| `map { }`                    | `.map { }`                            | `.map { }`                             |
| `filter { }`                 | `.filter { }`                         | `.filter { }`                          |
| `flatMapLatest { }`          | Manual with Task cancellation          | `.map { }.switchToLatest()`            |
| `combine()`                  | `combineLatest()` (async-algorithms)  | `Publishers.CombineLatest()`           |
| `zip()`                      | `zip()` (async-algorithms)            | `Publishers.Zip()`                     |
| `merge()`                    | `merge()` (async-algorithms)          | `Publishers.Merge()`                   |
| `distinctUntilChanged()`     | `removeDuplicates()` (async-alg.)     | `.removeDuplicates()`                  |
| `debounce(ms)`               | `debounce(for:)` (async-algorithms)   | `.debounce(for:scheduler:)`            |
| `catch { }`                  | `do/catch` in `for await`             | `.catch { }`                           |
| `onEach { }`                 | No built-in; use `map` + side effect  | `.handleEvents(receiveOutput:)`        |
| `take(n)`                    | `.prefix(n)`                          | `.prefix(n)`                           |
| `drop(n)`                    | `.dropFirst(n)`                       | `.dropFirst(n)`                        |
| `first()`                    | `.first(where: { _ in true })`       | `.first()`                             |
| `toList()`                   | `reduce(into: []) { $0.append($1) }` | `.collect()`                           |
| `flowOn(dispatcher)`         | Context managed by Swift runtime      | `.receive(on: scheduler)`              |
| `onCompletion { }`           | Handle after `for await` loop exits   | `.handleEvents(receiveCompletion:)`    |
| `retry(n)`                   | Manual retry loop                      | `.retry(n)`                            |
| `buffer()`                   | AsyncStream with buffer policy         | `.buffer(size:prefetch:whenFull:)`     |

## Cold vs Hot Streams

### Android
- **Cold**: `flow { }` — new execution per collector
- **Hot**: `StateFlow`, `SharedFlow` — single source, multiple collectors

### iOS
- **Cold (AsyncSequence)**: Each `for await` creates a new stream execution
- **Cold (Combine)**: Each `.sink` triggers a new subscription
- **Hot (AsyncSequence)**: `AsyncStream` with shared continuation (manual)
- **Hot (Combine)**: `CurrentValueSubject`, `PassthroughSubject`, `.share()`

**Note**: See the `generic-android-to-ios-stateflow` skill for hot stream migration.

## Error Handling

### Android
```kotlin
flow { emit(fetchData()) }
    .catch { e -> emit(fallbackData) }
    .collect { data -> process(data) }
```

### iOS (AsyncSequence)
```swift
do {
    for try await data in dataStream {
        process(data)
    }
} catch {
    process(fallbackData)
}
```

### iOS (Combine)
```swift
dataPublisher
    .catch { _ in Just(fallbackData) }
    .sink { data in process(data) }
    .store(in: &cancellables)
```

## Backpressure

### Android
```kotlin
// Flow is inherently sequential — producer suspends until consumer processes
flow {
    for (item in largeList) {
        emit(item) // suspends if downstream is slow
    }
}

// buffer() — decouple producer/consumer
flow.buffer(capacity = 64, onBufferOverflow = BufferOverflow.DROP_OLDEST)

// conflate() — skip intermediate values, keep latest
flow.conflate()
```

### iOS (AsyncStream)
```swift
// AsyncStream supports buffer policies
let stream = AsyncStream<Item>(bufferingPolicy: .bufferingNewest(64)) { continuation in
    for item in largeList {
        continuation.yield(item) // non-blocking
    }
    continuation.finish()
}

// Buffering policies:
// .unbounded         — unlimited buffer
// .bufferingOldest(n) — keep first N, drop new (equivalent to SUSPEND)
// .bufferingNewest(n) — keep latest N, drop old (equivalent to DROP_OLDEST)
```

## Testing

### Android
```kotlin
@Test
fun `observeItems emits correct values`() = runTest {
    val repo = FakeRepository()
    val results = repo.observeItems().take(3).toList()
    assertEquals(3, results.size)
}

// Using Turbine library
@Test
fun `flow emits loading then success`() = runTest {
    viewModel.state.test {
        assertEquals(UiState.Loading, awaitItem())
        assertEquals(UiState.Success(items), awaitItem())
        cancelAndIgnoreRemainingEvents()
    }
}
```

### iOS (AsyncSequence)
```swift
@Test func observeItemsEmitsCorrectValues() async {
    let repo = FakeRepository()
    var results: [[Item]] = []
    for await items in repo.observeItems().prefix(3) {
        results.append(items)
    }
    #expect(results.count == 3)
}
```

### iOS (Combine)
```swift
@Test func publisherEmitsValues() {
    let expectation = XCTestExpectation()
    var received: [[Item]] = []

    repo.itemsPublisher
        .prefix(3)
        .collect()
        .sink { items in
            received = items
            expectation.fulfill()
        }
        .store(in: &cancellables)

    wait(for: [expectation], timeout: 5)
    XCTAssertEqual(received.count, 3)
}
```

## Common Pitfalls

1. **AsyncSequence operators are limited**: Unlike Flow's rich operator set, AsyncSequence has few built-in operators. Use the `swift-async-algorithms` package for `combineLatest`, `merge`, `debounce`, `throttle`, and more.
2. **No `flatMapLatest` in AsyncSequence**: You must manually cancel the previous Task when a new value arrives. Combine's `switchToLatest()` is the closest built-in equivalent.
3. **Combine `sink` requires storing `AnyCancellable`**: Forgetting to store in `cancellables` causes the subscription to be immediately cancelled.
4. **`flowOn` has no direct AsyncSequence equivalent**: Swift Concurrency manages threading automatically. If you need specific thread control, use actors or `MainActor.run`.
5. **AsyncStream continuation is not thread-safe by default**: Always access continuation from a single context or use proper synchronization.
6. **Combine is not deprecated but AsyncSequence is preferred**: For new code targeting iOS 15+, prefer AsyncSequence. Use Combine when you need its rich operator set or are working with existing Combine codebases.
7. **Memory leaks with Combine**: Always use `[weak self]` in `sink` closures to avoid retain cycles.

## Migration Checklist

- [ ] Identify all `Flow` declarations and their usage (cold vs hot)
- [ ] Choose target API: AsyncSequence (preferred for iOS 15+) or Combine
- [ ] Convert `flow { }` builders to `AsyncStream` or `AsyncThrowingStream`
- [ ] Convert `callbackFlow` to `AsyncStream` with `onTermination`
- [ ] Map Flow operators to AsyncSequence/Combine equivalents
- [ ] Add `swift-async-algorithms` package if using `combineLatest`, `merge`, `debounce`
- [ ] Replace `flowOn` with actor isolation or `@MainActor`
- [ ] Convert `collect` calls to `for await` loops or Combine `sink`
- [ ] Handle backpressure with appropriate `bufferingPolicy`
- [ ] Replace `flatMapLatest` with manual Task cancellation or Combine `switchToLatest`
- [ ] Convert Flow test patterns to AsyncSequence `.prefix(n)` or Combine test patterns
- [ ] Ensure `AnyCancellable` storage for all Combine subscriptions
