---
name: generic-android-to-ios-channels
description: Use when migrating Kotlin Channel patterns (rendezvous, buffered, conflated, produce/consumeEach) to iOS equivalents (AsyncChannel, AsyncStream.Continuation, actor-based patterns)
type: generic
---

# generic-android-to-ios-channels

## Context

Kotlin Channels provide a way to transfer values between coroutines — they are the coroutine equivalent of blocking queues. Unlike Flow (cold, declarative), Channels are hot and imperative: values are sent and received explicitly. iOS has no direct stdlib equivalent, but `AsyncChannel` from swift-async-algorithms, `AsyncStream.Continuation`, and actor-based patterns cover the same use cases. This skill guides the migration of Channel patterns to idiomatic iOS code.

## Android Best Practices (Source Patterns)

### Channel Types

```kotlin
// Rendezvous (default) — capacity 0, sender suspends until receiver is ready
val rendezvous = Channel<Int>()

// Buffered — fixed buffer, sender suspends when full
val buffered = Channel<Int>(capacity = 64)

// Unlimited — unlimited buffer, sender never suspends (OOM risk)
val unlimited = Channel<Int>(Channel.UNLIMITED)

// Conflated — keeps only the latest value, overwrites previous
val conflated = Channel<Int>(Channel.CONFLATED)
```

### Basic Send/Receive

```kotlin
val channel = Channel<String>()

// Producer
launch {
    channel.send("Hello")
    channel.send("World")
    channel.close()
}

// Consumer
launch {
    for (value in channel) {
        println(value)
    }
    // Loop ends when channel is closed
}
```

### produce Builder

```kotlin
// produce — creates a ReceiveChannel with structured concurrency
fun CoroutineScope.produceNumbers(): ReceiveChannel<Int> = produce {
    var x = 1
    while (true) {
        send(x++)
        delay(1000)
    }
}

// Consuming
val numbers = produceNumbers()
numbers.consumeEach { number ->
    println(number)
}
```

### Fan-Out (One Producer, Multiple Consumers)

```kotlin
val channel = Channel<Task>(capacity = 10)

// Single producer
launch {
    for (task in tasks) {
        channel.send(task)
    }
    channel.close()
}

// Multiple consumers — each task is processed by exactly one consumer
repeat(3) { workerId ->
    launch {
        for (task in channel) {
            processTask(workerId, task)
        }
    }
}
```

### Fan-In (Multiple Producers, One Consumer)

```kotlin
val channel = Channel<Event>()

// Multiple producers
launch { sensorA.events().collect { channel.send(it) } }
launch { sensorB.events().collect { channel.send(it) } }

// Single consumer
launch {
    for (event in channel) {
        processEvent(event)
    }
}
```

### One-Shot Events via Channel

```kotlin
@HiltViewModel
class FormViewModel @Inject constructor(
    private val submitForm: SubmitFormUseCase
) : ViewModel() {

    // Channel for one-shot navigation/UI events
    private val _navigationEvents = Channel<NavigationEvent>(Channel.BUFFERED)
    val navigationEvents = _navigationEvents.receiveAsFlow()

    fun onSubmit() {
        viewModelScope.launch {
            try {
                submitForm.execute()
                _navigationEvents.send(NavigationEvent.GoToSuccess)
            } catch (e: Exception) {
                _navigationEvents.send(NavigationEvent.ShowError(e.message))
            }
        }
    }
}

// Collecting in Fragment (guaranteed delivery — buffered channel)
viewLifecycleOwner.lifecycleScope.launch {
    viewModel.navigationEvents.collect { event ->
        when (event) {
            NavigationEvent.GoToSuccess -> findNavController().navigate(...)
            is NavigationEvent.ShowError -> showSnackbar(event.message)
        }
    }
}
```

### Channel with Select

```kotlin
select<Unit> {
    channel1.onReceive { value -> handleFromChannel1(value) }
    channel2.onReceive { value -> handleFromChannel2(value) }
}
```

## iOS Best Practices (Target Patterns)

### AsyncChannel (swift-async-algorithms)

```swift
import AsyncAlgorithms

// AsyncChannel — equivalent to Channel (rendezvous by default)
let channel = AsyncChannel<String>()

// Producer
Task {
    await channel.send("Hello")
    await channel.send("World")
    channel.finish()
}

// Consumer
Task {
    for await value in channel {
        print(value)
    }
}
```

### AsyncStream.Continuation (Buffered Channel Equivalent)

```swift
// Buffered channel equivalent using AsyncStream
func makeBufferedChannel<T>(
    bufferSize: Int = 64
) -> (stream: AsyncStream<T>, continuation: AsyncStream<T>.Continuation) {
    var continuation: AsyncStream<T>.Continuation!
    let stream = AsyncStream<T>(bufferingPolicy: .bufferingOldest(bufferSize)) { cont in
        continuation = cont
    }
    return (stream, continuation)
}

// Usage
let (stream, continuation) = makeBufferedChannel<String>(bufferSize: 64)

// Producer
Task {
    continuation.yield("Hello")
    continuation.yield("World")
    continuation.finish()
}

// Consumer
Task {
    for await value in stream {
        print(value)
    }
}
```

### Channel Type Mapping with AsyncStream

```swift
// Rendezvous — use AsyncChannel from swift-async-algorithms
let rendezvous = AsyncChannel<Int>()

// Buffered — AsyncStream with bufferingOldest
let buffered = AsyncStream<Int>(bufferingPolicy: .bufferingOldest(64)) { continuation in
    // store continuation for later use
}

// Unlimited — AsyncStream with unbounded buffer
let unlimited = AsyncStream<Int>(bufferingPolicy: .unbounded) { continuation in
    // store continuation
}

// Conflated — AsyncStream with bufferingNewest(1)
let conflated = AsyncStream<Int>(bufferingPolicy: .bufferingNewest(1)) { continuation in
    // store continuation — only latest value kept
}
```

### Producer-Consumer Pattern (Equivalent to produce)

```swift
// Structured producer — equivalent to produce { }
func produceNumbers() -> AsyncStream<Int> {
    AsyncStream { continuation in
        let task = Task {
            var x = 1
            while !Task.isCancelled {
                continuation.yield(x)
                x += 1
                try? await Task.sleep(for: .seconds(1))
            }
        }
        continuation.onTermination = { _ in
            task.cancel()
        }
    }
}

// Consuming — equivalent to consumeEach
Task {
    for await number in produceNumbers() {
        print(number)
    }
}
```

### Fan-Out (One Producer, Multiple Consumers)

```swift
// Fan-out with actor-based work distribution
actor WorkDistributor<T: Sendable> {
    private var items: [T] = []
    private var waiters: [CheckedContinuation<T?, Never>] = []

    func enqueue(_ item: T) {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume(returning: item)
        } else {
            items.append(item)
        }
    }

    func dequeue() async -> T? {
        if !items.isEmpty {
            return items.removeFirst()
        }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func finish() {
        for waiter in waiters {
            waiter.resume(returning: nil)
        }
        waiters.removeAll()
    }
}

// Usage
let distributor = WorkDistributor<WorkTask>()

// Producer
Task {
    for task in tasks {
        await distributor.enqueue(task)
    }
    await distributor.finish()
}

// Multiple consumers
for workerId in 0..<3 {
    Task {
        while let task = await distributor.dequeue() {
            await processTask(workerId: workerId, task: task)
        }
    }
}
```

### Fan-In (Multiple Producers, One Consumer)

```swift
import AsyncAlgorithms

// Using merge from swift-async-algorithms
let merged = merge(sensorA.events(), sensorB.events())
for await event in merged {
    processEvent(event)
}

// Or with a shared AsyncStream continuation
let (stream, continuation) = makeBufferedChannel<Event>()

// Multiple producers write to the same continuation
Task { for await event in sensorA.events() { continuation.yield(event) } }
Task { for await event in sensorB.events() { continuation.yield(event) } }

// Single consumer
Task {
    for await event in stream {
        processEvent(event)
    }
}
```

### One-Shot Events (Equivalent to Channel + receiveAsFlow)

```swift
@MainActor
@Observable
final class FormViewModel {
    private let eventContinuation: AsyncStream<NavigationEvent>.Continuation
    let navigationEvents: AsyncStream<NavigationEvent>

    private let submitForm: SubmitFormUseCaseProtocol

    init(submitForm: SubmitFormUseCaseProtocol) {
        self.submitForm = submitForm
        var continuation: AsyncStream<NavigationEvent>.Continuation!
        self.navigationEvents = AsyncStream(
            bufferingPolicy: .bufferingOldest(10)  // buffered to avoid losing events
        ) { continuation = $0 }
        self.eventContinuation = continuation
    }

    func onSubmit() async {
        do {
            try await submitForm.execute()
            eventContinuation.yield(.goToSuccess)
        } catch {
            eventContinuation.yield(.showError(message: error.localizedDescription))
        }
    }
}

enum NavigationEvent: Sendable {
    case goToSuccess
    case showError(message: String)
}

// Consuming in SwiftUI
struct FormScreen: View {
    @State private var viewModel: FormViewModel
    @State private var showError: String?

    var body: some View {
        FormContent {
            Task { await viewModel.onSubmit() }
        }
        .alert("Error", isPresented: .constant(showError != nil)) {
            Button("OK") { showError = nil }
        } message: {
            Text(showError ?? "")
        }
        .task {
            for await event in viewModel.navigationEvents {
                switch event {
                case .goToSuccess:
                    // navigate
                    break
                case .showError(let message):
                    showError = message
                }
            }
        }
    }
}
```

### Actor-Based Channel Pattern

```swift
// Actor as a typed channel — full control over buffering and backpressure
actor MessageChannel<T: Sendable> {
    private var buffer: [T] = []
    private var isFinished = false
    private var awaiter: CheckedContinuation<T?, Never>?

    func send(_ value: T) {
        if let awaiter {
            self.awaiter = nil
            awaiter.resume(returning: value)
        } else {
            buffer.append(value)
        }
    }

    func receive() async -> T? {
        if !buffer.isEmpty {
            return buffer.removeFirst()
        }
        if isFinished { return nil }
        return await withCheckedContinuation { continuation in
            awaiter = continuation
        }
    }

    func finish() {
        isFinished = true
        if let awaiter {
            self.awaiter = nil
            awaiter.resume(returning: nil)
        }
    }
}

// Usage — equivalent to Kotlin Channel usage
let channel = MessageChannel<String>()

Task {
    await channel.send("Hello")
    await channel.send("World")
    await channel.finish()
}

Task {
    while let value = await channel.receive() {
        print(value)
    }
}
```

## Mapping Reference

| Kotlin Channel                          | iOS Equivalent                                         |
|-----------------------------------------|--------------------------------------------------------|
| `Channel<T>()`  (rendezvous)           | `AsyncChannel<T>()` (swift-async-algorithms)           |
| `Channel<T>(capacity)`                 | `AsyncStream<T>(bufferingPolicy: .bufferingOldest(n))` |
| `Channel<T>(UNLIMITED)`               | `AsyncStream<T>(bufferingPolicy: .unbounded)`          |
| `Channel<T>(CONFLATED)`               | `AsyncStream<T>(bufferingPolicy: .bufferingNewest(1))` |
| `channel.send(value)`                  | `continuation.yield(value)` / `channel.send(value)`   |
| `channel.receive()`                    | `for await value in stream` / `channel.next()`        |
| `channel.close()`                      | `continuation.finish()` / `channel.finish()`           |
| `channel.trySend(value)`              | `continuation.yield(value)` (non-suspending)           |
| `channel.tryReceive()`                | No direct equivalent; use actor with non-async method  |
| `produce { }`                          | Function returning `AsyncStream<T>`                    |
| `consumeEach { }`                      | `for await value in stream { }`                        |
| `channel.receiveAsFlow()`             | Use `AsyncStream` directly (already async-iterable)    |
| `select { onReceive { } }`            | No direct equivalent; use `merge` or `TaskGroup`       |

## Buffering Strategies Comparison

| Strategy        | Kotlin                     | iOS (AsyncStream)              | Behavior                              |
|-----------------|----------------------------|--------------------------------|---------------------------------------|
| Rendezvous      | `Channel(0)`               | `AsyncChannel` (async-alg)    | Sender waits for receiver             |
| Fixed buffer    | `Channel(n)`               | `.bufferingOldest(n)`          | Buffer N items, then suspend/drop     |
| Unlimited       | `Channel(UNLIMITED)`       | `.unbounded`                   | Never suspends, risk OOM              |
| Conflated       | `Channel(CONFLATED)`       | `.bufferingNewest(1)`          | Only latest value kept                |
| Drop oldest     | `onBufferOverflow.DROP_OLDEST` | `.bufferingNewest(n)`       | Drop oldest when full                 |
| Drop latest     | `onBufferOverflow.DROP_LATEST` | `.bufferingOldest(n)`       | Drop newest when full                 |

## Testing

### Android
```kotlin
@Test
fun `channel delivers events in order`() = runTest {
    val channel = Channel<Int>(Channel.BUFFERED)

    launch {
        channel.send(1)
        channel.send(2)
        channel.send(3)
        channel.close()
    }

    val results = channel.toList()
    assertEquals(listOf(1, 2, 3), results)
}

@Test
fun `navigation event sent on submit`() = runTest {
    val vm = FormViewModel(FakeSubmitForm())

    val events = mutableListOf<NavigationEvent>()
    val job = launch { vm.navigationEvents.collect { events.add(it) } }

    vm.onSubmit()
    advanceUntilIdle()

    assertEquals(NavigationEvent.GoToSuccess, events.first())
    job.cancel()
}
```

### iOS
```swift
@Test func channelDeliversEventsInOrder() async {
    let channel = AsyncChannel<Int>()

    Task {
        await channel.send(1)
        await channel.send(2)
        await channel.send(3)
        channel.finish()
    }

    var results: [Int] = []
    for await value in channel {
        results.append(value)
    }
    #expect(results == [1, 2, 3])
}

@Test func navigationEventSentOnSubmit() async {
    let vm = await FormViewModel(submitForm: FakeSubmitForm())

    // Collect first event
    async let firstEvent: NavigationEvent? = {
        for await event in vm.navigationEvents {
            return event
        }
        return nil
    }()

    await vm.onSubmit()

    let event = await firstEvent
    #expect(event == .goToSuccess)
}
```

## Common Pitfalls

1. **AsyncStream is single-consumer**: Unlike Kotlin Channel which supports multiple receivers (fan-out), `AsyncStream` can only be iterated by one consumer. For fan-out, use an actor-based distributor or create multiple streams.
2. **AsyncStream continuation is not Sendable-safe by default**: When sharing a continuation across tasks, ensure thread safety. Store it in an actor or use `@Sendable` closures carefully.
3. **No `select` in Swift**: Kotlin's `select` expression for receiving from multiple channels has no direct Swift equivalent. Use `merge` from swift-async-algorithms or `TaskGroup` to monitor multiple sources.
4. **Buffering policy mismatch**: Kotlin's `SUSPEND` overflow policy (default for buffered channels) suspends the sender. AsyncStream's `.bufferingOldest(n)` drops new values when full. For true backpressure (sender suspension), use `AsyncChannel`.
5. **Forgetting `onTermination`**: When creating `AsyncStream` with a background task producer, always set `continuation.onTermination` to cancel the producer task. Otherwise the task leaks.
6. **Channel vs Flow confusion**: In Android, `Channel` is for imperative send/receive between coroutines. `Flow` is for declarative reactive streams. In iOS, `AsyncStream` covers both. Be clear about which pattern you are migrating.
7. **Event loss with single-element buffer**: Using `.bufferingNewest(1)` (conflated) for one-shot events can lose events if they arrive faster than they are consumed. Use `.bufferingOldest(n)` with a reasonable buffer size for event channels.

## Migration Checklist

- [ ] Identify all `Channel` declarations and their capacity/type (rendezvous, buffered, unlimited, conflated)
- [ ] Add `swift-async-algorithms` package if using `AsyncChannel` or `merge`
- [ ] Convert rendezvous channels to `AsyncChannel`
- [ ] Convert buffered channels to `AsyncStream` with appropriate `bufferingPolicy`
- [ ] Convert `produce { }` to functions returning `AsyncStream`
- [ ] Convert `consumeEach` to `for await` loops
- [ ] Convert `channel.receiveAsFlow()` usage — `AsyncStream` is already iterable
- [ ] Map fan-out patterns to actor-based work distributors
- [ ] Map fan-in patterns to `merge` or shared `AsyncStream.Continuation`
- [ ] Convert one-shot event channels to `AsyncStream` with buffered policy
- [ ] Replace `select { onReceive { } }` with `merge` or `TaskGroup`
- [ ] Set `continuation.onTermination` for all `AsyncStream` instances with background producers
- [ ] Verify single-consumer constraint: ensure each `AsyncStream` has exactly one `for await` consumer
- [ ] Write tests using `AsyncChannel` or prefix-limited `AsyncStream` iteration
