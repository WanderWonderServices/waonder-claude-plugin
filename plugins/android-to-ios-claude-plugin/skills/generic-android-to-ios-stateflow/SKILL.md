---
name: generic-android-to-ios-stateflow
description: Use when migrating Kotlin StateFlow and SharedFlow patterns (UI state holders, event channels) to iOS equivalents (@Observable, @Published, CurrentValueSubject, PassthroughSubject)
type: generic
---

# generic-android-to-ios-stateflow

## Context

StateFlow and SharedFlow are Kotlin's hot stream primitives for UI state management and event broadcasting. StateFlow holds a current value and emits updates (like a reactive property), while SharedFlow broadcasts events to multiple collectors without retaining state. iOS has several equivalents depending on the target version: `@Observable` (iOS 17+), `ObservableObject` with `@Published` (iOS 13+), and Combine subjects. This skill covers the migration of both state-holding and event-broadcasting patterns.

## Android Best Practices (Source Patterns)

### StateFlow (State Holder)

```kotlin
@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val repository: ProfileRepository
) : ViewModel() {

    // Private mutable, public immutable
    private val _state = MutableStateFlow(ProfileUiState())
    val state: StateFlow<ProfileUiState> = _state.asStateFlow()

    fun loadProfile(userId: String) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }
            try {
                val profile = repository.getProfile(userId)
                _state.update { it.copy(isLoading = false, profile = profile) }
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }
}

data class ProfileUiState(
    val isLoading: Boolean = false,
    val profile: Profile? = null,
    val error: String? = null
)

// Collecting in Compose
@Composable
fun ProfileScreen(viewModel: ProfileViewModel) {
    val state by viewModel.state.collectAsState()

    when {
        state.isLoading -> CircularProgressIndicator()
        state.error != null -> ErrorView(state.error!!)
        state.profile != null -> ProfileContent(state.profile!!)
    }
}
```

### SharedFlow (Event Broadcasting)

```kotlin
@HiltViewModel
class CheckoutViewModel @Inject constructor(
    private val checkout: CheckoutUseCase
) : ViewModel() {

    // One-shot events — SharedFlow with replay = 0
    private val _events = MutableSharedFlow<CheckoutEvent>()
    val events: SharedFlow<CheckoutEvent> = _events.asSharedFlow()

    // State
    private val _state = MutableStateFlow(CheckoutUiState())
    val state: StateFlow<CheckoutUiState> = _state.asStateFlow()

    fun placeOrder() {
        viewModelScope.launch {
            _state.update { it.copy(isProcessing = true) }
            try {
                val order = checkout.execute()
                _events.emit(CheckoutEvent.OrderPlaced(order.id))
            } catch (e: Exception) {
                _events.emit(CheckoutEvent.ShowError(e.message ?: "Unknown error"))
            } finally {
                _state.update { it.copy(isProcessing = false) }
            }
        }
    }
}

sealed class CheckoutEvent {
    data class OrderPlaced(val orderId: String) : CheckoutEvent()
    data class ShowError(val message: String) : CheckoutEvent()
}

// Collecting events in Fragment
viewLifecycleOwner.lifecycleScope.launch {
    viewModel.events.collect { event ->
        when (event) {
            is CheckoutEvent.OrderPlaced -> navigateToConfirmation(event.orderId)
            is CheckoutEvent.ShowError -> showSnackbar(event.message)
        }
    }
}
```

### StateFlow with Multiple Sources

```kotlin
class DashboardViewModel @Inject constructor(
    userRepo: UserRepository,
    statsRepo: StatsRepository
) : ViewModel() {

    val dashboardState: StateFlow<DashboardUiState> = combine(
        userRepo.observeUser(),
        statsRepo.observeStats()
    ) { user, stats ->
        DashboardUiState(user = user, stats = stats)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = DashboardUiState()
    )
}
```

### MutableStateFlow.update (Atomic Updates)

```kotlin
// update {} is atomic — safe for concurrent modifications
_state.update { currentState ->
    currentState.copy(
        items = currentState.items + newItem,
        count = currentState.items.size + 1
    )
}
```

## iOS Best Practices (Target Patterns)

### @Observable (iOS 17+ — Preferred)

```swift
// Direct equivalent of StateFlow in a ViewModel
@MainActor
@Observable
final class ProfileViewModel {
    // Properties are automatically observed — no wrapper needed
    // Equivalent to StateFlow: always has a current value, UI re-renders on change
    private(set) var isLoading = false
    private(set) var profile: Profile?
    private(set) var error: String?

    private let repository: ProfileRepositoryProtocol

    init(repository: ProfileRepositoryProtocol) {
        self.repository = repository
    }

    func loadProfile(userId: String) async {
        isLoading = true
        error = nil
        do {
            profile = try await repository.getProfile(userId: userId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// SwiftUI automatically observes @Observable properties
struct ProfileScreen: View {
    @State private var viewModel: ProfileViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                ErrorView(message: error)
            } else if let profile = viewModel.profile {
                ProfileContent(profile: profile)
            }
        }
        .task {
            await viewModel.loadProfile(userId: "123")
        }
    }
}
```

### @Published + ObservableObject (iOS 13+ — Legacy)

```swift
// Equivalent to StateFlow pattern with ObservableObject
@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var state = ProfileUiState()

    private let repository: ProfileRepositoryProtocol

    init(repository: ProfileRepositoryProtocol) {
        self.repository = repository
    }

    func loadProfile(userId: String) async {
        state = ProfileUiState(isLoading: true)
        do {
            let profile = try await repository.getProfile(userId: userId)
            state = ProfileUiState(profile: profile)
        } catch {
            state = ProfileUiState(error: error.localizedDescription)
        }
    }
}

struct ProfileUiState: Equatable {
    var isLoading: Bool = false
    var profile: Profile? = nil
    var error: String? = nil
}

// SwiftUI view with ObservableObject
struct ProfileScreen: View {
    @StateObject private var viewModel: ProfileViewModel

    var body: some View {
        // same as above
    }
}
```

### Event Handling (Equivalent to SharedFlow)

#### Option 1: AsyncStream for Events

```swift
@MainActor
@Observable
final class CheckoutViewModel {
    private(set) var isProcessing = false

    // Event stream — equivalent to SharedFlow
    private let eventContinuation: AsyncStream<CheckoutEvent>.Continuation
    let events: AsyncStream<CheckoutEvent>

    private let checkout: CheckoutUseCaseProtocol

    init(checkout: CheckoutUseCaseProtocol) {
        self.checkout = checkout
        var continuation: AsyncStream<CheckoutEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventContinuation = continuation
    }

    func placeOrder() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let order = try await checkout.execute()
            eventContinuation.yield(.orderPlaced(orderId: order.id))
        } catch {
            eventContinuation.yield(.showError(message: error.localizedDescription))
        }
    }
}

enum CheckoutEvent {
    case orderPlaced(orderId: String)
    case showError(message: String)
}

// Consuming events in SwiftUI
struct CheckoutScreen: View {
    @State private var viewModel: CheckoutViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // UI content
        CheckoutContent(isProcessing: viewModel.isProcessing) {
            Task { await viewModel.placeOrder() }
        }
        .task {
            for await event in viewModel.events {
                switch event {
                case .orderPlaced(let orderId):
                    navigateToConfirmation(orderId)
                case .showError(let message):
                    showAlert(message)
                }
            }
        }
    }
}
```

#### Option 2: Combine PassthroughSubject for Events

```swift
import Combine

@MainActor
final class CheckoutViewModel: ObservableObject {
    @Published private(set) var isProcessing = false

    // PassthroughSubject — equivalent to SharedFlow(replay = 0)
    let events = PassthroughSubject<CheckoutEvent, Never>()

    func placeOrder() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let order = try await checkout.execute()
            events.send(.orderPlaced(orderId: order.id))
        } catch {
            events.send(.showError(message: error.localizedDescription))
        }
    }
}

// Consuming with .onReceive
struct CheckoutScreen: View {
    @StateObject private var viewModel: CheckoutViewModel

    var body: some View {
        CheckoutContent(isProcessing: viewModel.isProcessing)
            .onReceive(viewModel.events) { event in
                switch event {
                case .orderPlaced(let id): navigateToConfirmation(id)
                case .showError(let msg): showAlert(msg)
                }
            }
    }
}
```

### Combining Multiple Sources (Equivalent to stateIn + combine)

#### With @Observable (iOS 17+)

```swift
@MainActor
@Observable
final class DashboardViewModel {
    private(set) var user: User?
    private(set) var stats: Stats?

    var dashboardState: DashboardUiState {
        DashboardUiState(user: user, stats: stats)
    }

    private let userRepo: UserRepositoryProtocol
    private let statsRepo: StatsRepositoryProtocol

    func startObserving() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                for await user in self.userRepo.observeUser() {
                    self.user = user
                }
            }
            group.addTask { @MainActor in
                for await stats in self.statsRepo.observeStats() {
                    self.stats = stats
                }
            }
        }
    }
}
```

#### With Combine

```swift
@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var dashboardState = DashboardUiState()

    private var cancellables = Set<AnyCancellable>()

    init(userRepo: UserRepositoryProtocol, statsRepo: StatsRepositoryProtocol) {
        // Equivalent to combine().stateIn()
        Publishers.CombineLatest(
            userRepo.userPublisher,
            statsRepo.statsPublisher
        )
        .map { user, stats in DashboardUiState(user: user, stats: stats) }
        .receive(on: DispatchQueue.main)
        .assign(to: &$dashboardState)
    }
}
```

## Mapping Reference

| Android (Kotlin)                             | iOS (@Observable, iOS 17+)                     | iOS (Combine)                           |
|----------------------------------------------|------------------------------------------------|-----------------------------------------|
| `MutableStateFlow(initialValue)`             | `var property = initialValue` (in @Observable) | `@Published var property = value`       |
| `StateFlow<T>`                               | Read via `@Observable` property                | `AnyPublisher<T, Never>`               |
| `state.collectAsState()`                     | Automatic with `@Observable`                   | `@StateObject` / `@ObservedObject`      |
| `_state.update { ... }`                      | Direct property assignment on `@MainActor`     | Direct `@Published` assignment          |
| `MutableSharedFlow<T>()`                     | `AsyncStream<T>` with continuation             | `PassthroughSubject<T, Never>`          |
| `SharedFlow<T>`                              | `AsyncStream<T>`                               | `AnyPublisher<T, Never>`               |
| `SharedFlow(replay = 1)`                     | `AsyncStream` with `.bufferingNewest(1)`       | `CurrentValueSubject<T, Never>`         |
| `stateIn(scope, started, initial)`           | Computed property + `TaskGroup` observation     | `Publishers.CombineLatest` + `assign`   |
| `SharingStarted.WhileSubscribed(5000)`       | `.task` modifier (auto-cancel on disappear)    | `.share()` or `autoconnect()`           |
| `SharingStarted.Eagerly`                     | Start observation in `init`                    | `share().autoconnect()`                 |
| `SharingStarted.Lazily`                      | Start observation on first access              | `share()` with manual connect           |

## State vs Events Pattern

### The Problem
StateFlow replays the latest value to new collectors. SharedFlow (replay=0) does not. This distinction is critical for separating persistent UI state from one-shot events (navigation, toasts, snackbars).

### Android Pattern
```kotlin
// STATE — persists across configuration changes, replays on resubscribe
val state: StateFlow<UiState>

// EVENTS — fire-once, not replayed
val events: SharedFlow<UiEvent>
```

### iOS Pattern
```swift
// STATE — @Observable properties, always current, SwiftUI observes automatically
@Observable
final class MyViewModel {
    // State (equivalent to StateFlow)
    private(set) var items: [Item] = []
    private(set) var isLoading = false

    // Events (equivalent to SharedFlow)
    private let eventContinuation: AsyncStream<UiEvent>.Continuation
    let events: AsyncStream<UiEvent>

    init() {
        var continuation: AsyncStream<UiEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventContinuation = continuation
    }

    func deleteItem(_ item: Item) async {
        // Update state
        items.removeAll { $0.id == item.id }
        // Fire event
        eventContinuation.yield(.showUndoSnackbar(item: item))
    }
}
```

## Testing

### Android
```kotlin
@Test
fun `state updates correctly on load`() = runTest {
    val vm = ProfileViewModel(FakeRepository())

    val states = mutableListOf<ProfileUiState>()
    val job = launch { vm.state.collect { states.add(it) } }

    vm.loadProfile("123")
    advanceUntilIdle()

    assertEquals(false, states.last().isLoading)
    assertNotNull(states.last().profile)

    job.cancel()
}

@Test
fun `emits navigation event on success`() = runTest {
    val vm = CheckoutViewModel(FakeCheckout())

    val events = mutableListOf<CheckoutEvent>()
    val job = launch { vm.events.collect { events.add(it) } }

    vm.placeOrder()
    advanceUntilIdle()

    assertTrue(events.first() is CheckoutEvent.OrderPlaced)
    job.cancel()
}
```

### iOS (@Observable)
```swift
@Test func stateUpdatesOnLoad() async {
    let vm = await ProfileViewModel(repository: FakeRepository())

    await vm.loadProfile(userId: "123")

    await #expect(vm.isLoading == false)
    await #expect(vm.profile != nil)
}

@Test func emitsNavigationEvent() async {
    let vm = await CheckoutViewModel(checkout: FakeCheckoutUseCase())

    // Collect events in parallel
    async let eventTask: CheckoutEvent? = {
        for await event in vm.events {
            return event
        }
        return nil
    }()

    await vm.placeOrder()

    let event = await eventTask
    #expect(event == .orderPlaced(orderId: "order-1"))
}
```

## Common Pitfalls

1. **StateFlow always has a value; @Observable properties always have a value**: This is a natural mapping. Do not use Optional types unless the initial state genuinely has no value.
2. **SharedFlow events can be lost**: If no collector is active when `emit()` is called, the event is dropped (replay=0). The same applies to `AsyncStream` — if no `for await` loop is consuming, events buffer or drop per policy. Design accordingly.
3. **`collectAsState()` vs `@Observable`**: In Android, you must explicitly collect. With `@Observable`, SwiftUI automatically tracks property access — no explicit subscription needed.
4. **`stateIn` with `WhileSubscribed`**: This pattern manages upstream lifecycle. In iOS, use `.task` modifier for equivalent behavior (task starts on appear, cancels on disappear).
5. **Atomic updates**: `MutableStateFlow.update {}` is thread-safe/atomic. In iOS with `@MainActor`, property assignments are serial on the main actor — inherently safe.
6. **Do not use `@Published` with `@Observable`**: These are separate observation systems. `@Observable` uses the Observation framework. `@Published` uses Combine. Do not mix them.
7. **Event deduplication**: StateFlow uses `equals` to deduplicate. `@Observable` triggers updates on every assignment. Use `@Observable` with computed properties or manual checks for deduplication if needed.
8. **`@Observable` + `lazy var` conflict** — StateFlow migrations often produce `@Observable` classes with lazy-initialized dependencies. The `@Observable` macro conflicts with `lazy var`. Use `@ObservationIgnored lazy var` or initialize eagerly in `init`.

## Migration Checklist

- [ ] Identify all `StateFlow` declarations and their initial values
- [ ] Identify all `SharedFlow` declarations and their replay/buffer configs
- [ ] Choose iOS target: `@Observable` (iOS 17+) or `ObservableObject` (iOS 13+)
- [ ] Convert `MutableStateFlow` properties to `@Observable` properties with `private(set)`
- [ ] Convert `SharedFlow` events to `AsyncStream` with continuation or `PassthroughSubject`
- [ ] Replace `collectAsState()` with direct property access in SwiftUI views
- [ ] Replace `combine().stateIn()` with `TaskGroup` observation or `Publishers.CombineLatest`
- [ ] Map `SharingStarted` strategy to SwiftUI `.task` modifier lifecycle
- [ ] Add `@MainActor` to all ViewModels with UI state
- [ ] Replace `_state.update { }` with direct property mutations on `@MainActor`
- [ ] Convert StateFlow/SharedFlow tests to async Swift tests
- [ ] Verify events are consumed before they can be lost (buffer policy for AsyncStream)
