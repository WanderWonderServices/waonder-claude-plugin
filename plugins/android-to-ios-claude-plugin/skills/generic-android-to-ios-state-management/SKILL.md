---
name: generic-android-to-ios-state-management
description: Use when migrating Android Compose state management patterns (remember, mutableStateOf, State<T>, derivedStateOf, rememberSaveable, ViewModel) to iOS SwiftUI equivalents (@State, @Binding, @Observable, @Environment, @AppStorage, and architecture patterns)
type: generic
---

# generic-android-to-ios-state-management

## Context

State management is the core of both Jetpack Compose and SwiftUI. Both frameworks follow the principle that UI is a function of state, but they differ substantially in their state primitives, observation mechanisms, and architectural patterns. Android uses `remember`, `mutableStateOf`, `State<T>`, `derivedStateOf`, and `ViewModel` with `StateFlow`/`SharedFlow`. iOS uses `@State`, `@Binding`, `@Observable` (iOS 17+), `@ObservedObject`/`@StateObject` (legacy), `@Environment`, and `@AppStorage`.

This skill provides a comprehensive guide for migrating state management patterns from Android Compose to SwiftUI, including both view-level state and app-level architecture (ViewModel equivalents, dependency injection, state restoration).

## Concept Mapping

| Android Compose | SwiftUI |
|----------------|---------|
| `remember { mutableStateOf(value) }` | `@State private var value` |
| `var x by remember { mutableStateOf(v) }` | `@State private var x = v` |
| `State<T>` (read-only) | Binding via `let value: T` (passed down) |
| `MutableState<T>` | `@State` (owned) or `@Binding` (borrowed) |
| `derivedStateOf { }` | Computed property |
| `rememberSaveable { }` | `@SceneStorage` (per-scene) or `@AppStorage` (global) |
| `snapshotFlow { state }` | Combine publisher or `AsyncStream` from `@Observable` |
| `mutableStateListOf<T>()` | `@State private var items: [T] = []` |
| `mutableStateMapOf<K,V>()` | `@State private var map: [K: V] = [:]` |
| `ViewModel` | `@Observable` class (iOS 17+) or `ObservableObject` class |
| `viewModel()` / `hiltViewModel()` | `@State private var viewModel = ViewModel()` or `@Environment` |
| `StateFlow<T>` | `@Published var` (in `ObservableObject`) or property in `@Observable` |
| `SharedFlow<T>` | `AsyncStream` or Combine `PassthroughSubject` |
| `collectAsStateWithLifecycle()` | Automatic observation (iOS 17 `@Observable`) or `.onReceive()` |
| `CompositionLocalProvider` | `.environment(\.key, value)` |
| `CompositionLocal` | `@Environment(\.key)` |
| `SavedStateHandle` | `@SceneStorage` or `Codable` + `UserDefaults` |
| Hilt / Koin DI | `@Environment` with custom `EnvironmentKey` or Swift DI container |

## View-Level State

### Basic Mutable State

```kotlin
// Android: Local mutable state
@Composable
fun Counter() {
    var count by remember { mutableStateOf(0) }

    Button(onClick = { count++ }) {
        Text("Count: $count")
    }
}
```

```swift
// iOS: @State for local mutable state
struct Counter: View {
    @State private var count = 0

    var body: some View {
        Button("Count: \(count)") {
            count += 1
        }
    }
}
```

### Passing State Down (State Hoisting)

```kotlin
// Android: State hoisting pattern
@Composable
fun ParentScreen() {
    var text by remember { mutableStateOf("") }
    SearchBar(
        query = text,
        onQueryChange = { text = it }
    )
}

@Composable
fun SearchBar(
    query: String,
    onQueryChange: (String) -> Unit
) {
    TextField(
        value = query,
        onValueChange = onQueryChange,
        placeholder = { Text("Search...") }
    )
}
```

```swift
// iOS: @Binding for state hoisting
struct ParentScreen: View {
    @State private var text = ""

    var body: some View {
        SearchBar(query: $text)
    }
}

struct SearchBar: View {
    @Binding var query: String

    var body: some View {
        TextField("Search...", text: $query)
            .textFieldStyle(.roundedBorder)
    }
}
```

### Derived State

```kotlin
// Android: derivedStateOf
@Composable
fun ItemCounter(items: List<Item>) {
    var filterText by remember { mutableStateOf("") }

    val filteredCount by remember(items) {
        derivedStateOf {
            items.count { it.name.contains(filterText, ignoreCase = true) }
        }
    }

    Column {
        TextField(value = filterText, onValueChange = { filterText = it })
        Text("Matching items: $filteredCount")
    }
}
```

```swift
// iOS: Computed property (no wrapper needed)
struct ItemCounter: View {
    let items: [Item]
    @State private var filterText = ""

    private var filteredCount: Int {
        items.filter { $0.name.localizedCaseInsensitiveContains(filterText) }.count
    }

    var body: some View {
        VStack {
            TextField("Filter", text: $filterText)
                .textFieldStyle(.roundedBorder)
            Text("Matching items: \(filteredCount)")
        }
    }
}
```

### Collection State

```kotlin
// Android: Mutable state list
@Composable
fun TodoList() {
    val items = remember { mutableStateListOf<TodoItem>() }

    Column {
        Button(onClick = { items.add(TodoItem("New item")) }) {
            Text("Add")
        }
        LazyColumn {
            items(items, key = { it.id }) { item ->
                Text(item.title)
            }
        }
    }
}
```

```swift
// iOS: @State with array
struct TodoList: View {
    @State private var items: [TodoItem] = []

    var body: some View {
        VStack {
            Button("Add") {
                items.append(TodoItem(title: "New item"))
            }
            List(items) { item in
                Text(item.title)
            }
        }
    }
}
```

## ViewModel / App-Level State

### ViewModel Pattern (iOS 17+ with @Observable)

```kotlin
// Android: ViewModel with StateFlow
class ProfileViewModel @Inject constructor(
    private val userRepository: UserRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            val user = userRepository.getUser()
            _uiState.update { it.copy(user = user, isLoading = false) }
        }
    }

    fun onNameChanged(name: String) {
        _uiState.update { it.copy(user = it.user?.copy(name = name)) }
    }

    fun saveProfile() {
        viewModelScope.launch {
            _uiState.update { it.copy(isSaving = true) }
            uiState.value.user?.let { userRepository.saveUser(it) }
            _uiState.update { it.copy(isSaving = false) }
        }
    }
}

data class ProfileUiState(
    val user: User? = null,
    val isLoading: Boolean = true,
    val isSaving: Boolean = false
)

// Usage in Compose:
@Composable
fun ProfileScreen(viewModel: ProfileViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    if (uiState.isLoading) {
        CircularProgressIndicator()
    } else {
        ProfileContent(
            user = uiState.user!!,
            onNameChanged = viewModel::onNameChanged,
            onSave = viewModel::saveProfile
        )
    }
}
```

```swift
// iOS (iOS 17+): @Observable class replaces ViewModel + StateFlow
@Observable
class ProfileViewModel {
    var user: User?
    var isLoading = true
    var isSaving = false

    private let userRepository: UserRepository

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    func loadProfile() async {
        isLoading = true
        user = await userRepository.getUser()
        isLoading = false
    }

    func onNameChanged(_ name: String) {
        user?.name = name
    }

    func saveProfile() async {
        isSaving = true
        if let user {
            await userRepository.saveUser(user)
        }
        isSaving = false
    }
}

// Usage in SwiftUI:
struct ProfileScreen: View {
    @State private var viewModel: ProfileViewModel

    init(userRepository: UserRepository) {
        _viewModel = State(initialValue: ProfileViewModel(userRepository: userRepository))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let user = viewModel.user {
                ProfileContent(
                    user: user,
                    onNameChanged: viewModel.onNameChanged,
                    onSave: { Task { await viewModel.saveProfile() } }
                )
            }
        }
        .task {
            await viewModel.loadProfile()
        }
    }
}
```

### ViewModel Pattern (Pre-iOS 17 with ObservableObject)

```swift
// iOS (iOS 14-16): ObservableObject + @Published
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = true
    @Published var isSaving = false

    private let userRepository: UserRepository

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    @MainActor
    func loadProfile() async {
        isLoading = true
        user = await userRepository.getUser()
        isLoading = false
    }

    @MainActor
    func saveProfile() async {
        isSaving = true
        if let user {
            await userRepository.saveUser(user)
        }
        isSaving = false
    }
}

// Usage: use @StateObject for ownership, @ObservedObject for borrowing
struct ProfileScreen: View {
    @StateObject private var viewModel: ProfileViewModel

    init(userRepository: UserRepository) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(userRepository: userRepository))
    }

    var body: some View {
        // same as above
    }
}
```

## State Persistence and Restoration

### rememberSaveable to @SceneStorage / @AppStorage

```kotlin
// Android: rememberSaveable survives process death
@Composable
fun SearchScreen() {
    var query by rememberSaveable { mutableStateOf("") }
    var selectedTab by rememberSaveable { mutableIntStateOf(0) }

    // query and selectedTab survive configuration changes and process death
}
```

```swift
// iOS: @SceneStorage for per-scene persistence (survives app relaunch)
struct SearchScreen: View {
    @SceneStorage("search_query") private var query = ""
    @SceneStorage("selected_tab") private var selectedTab = 0

    var body: some View {
        // query and selectedTab persist across app launches for this scene
    }
}

// iOS: @AppStorage for global persistence (UserDefaults-backed)
struct SettingsScreen: View {
    @AppStorage("notifications_enabled") private var notificationsEnabled = true
    @AppStorage("theme_mode") private var themeMode = "system"

    var body: some View {
        Toggle("Notifications", isOn: $notificationsEnabled)
        Picker("Theme", selection: $themeMode) {
            Text("System").tag("system")
            Text("Light").tag("light")
            Text("Dark").tag("dark")
        }
    }
}
```

## Environment / Dependency Injection

### CompositionLocal to @Environment

```kotlin
// Android: Custom CompositionLocal
val LocalAnalytics = compositionLocalOf<AnalyticsService> {
    error("No AnalyticsService provided")
}

// Providing
CompositionLocalProvider(LocalAnalytics provides analyticsService) {
    AppContent()
}

// Consuming
@Composable
fun SomeScreen() {
    val analytics = LocalAnalytics.current
    analytics.trackEvent("screen_viewed")
}
```

```swift
// iOS: Custom EnvironmentKey
private struct AnalyticsServiceKey: EnvironmentKey {
    static let defaultValue: AnalyticsService = NoOpAnalyticsService()
}

extension EnvironmentValues {
    var analyticsService: AnalyticsService {
        get { self[AnalyticsServiceKey.self] }
        set { self[AnalyticsServiceKey.self] = newValue }
    }
}

// Providing
ContentView()
    .environment(\.analyticsService, liveAnalyticsService)

// Consuming
struct SomeScreen: View {
    @Environment(\.analyticsService) private var analytics

    var body: some View {
        Text("Hello")
            .onAppear {
                analytics.trackEvent("screen_viewed")
            }
    }
}
```

### iOS 17+ @Observable with @Environment

```swift
// iOS 17+: Inject @Observable objects via environment
@Observable
class AppState {
    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
}

// Providing (at app root)
@main
struct MyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}

// Consuming (anywhere in the view tree)
struct ProfileView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if let user = appState.currentUser {
            Text(user.name)
        }
    }
}
```

## One-Time Events / Side Effects

### SharedFlow (Events) to AsyncStream

```kotlin
// Android: One-time events via SharedFlow
class CheckoutViewModel : ViewModel() {
    private val _events = MutableSharedFlow<CheckoutEvent>()
    val events: SharedFlow<CheckoutEvent> = _events.asSharedFlow()

    fun placeOrder() {
        viewModelScope.launch {
            try {
                orderRepository.placeOrder()
                _events.emit(CheckoutEvent.OrderPlaced)
            } catch (e: Exception) {
                _events.emit(CheckoutEvent.Error(e.message ?: "Unknown error"))
            }
        }
    }
}

sealed interface CheckoutEvent {
    data object OrderPlaced : CheckoutEvent
    data class Error(val message: String) : CheckoutEvent
}

// Consuming in Compose:
@Composable
fun CheckoutScreen(viewModel: CheckoutViewModel = hiltViewModel()) {
    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is CheckoutEvent.OrderPlaced -> { /* navigate */ }
                is CheckoutEvent.Error -> { /* show snackbar */ }
            }
        }
    }
}
```

```swift
// iOS: One-time events via callback or @Observable property
@Observable
class CheckoutViewModel {
    var lastEvent: CheckoutEvent?

    private let orderRepository: OrderRepository

    init(orderRepository: OrderRepository) {
        self.orderRepository = orderRepository
    }

    func placeOrder() async {
        do {
            try await orderRepository.placeOrder()
            lastEvent = .orderPlaced
        } catch {
            lastEvent = .error(error.localizedDescription)
        }
    }
}

enum CheckoutEvent: Equatable {
    case orderPlaced
    case error(String)
}

// Consuming in SwiftUI:
struct CheckoutScreen: View {
    @State private var viewModel: CheckoutViewModel
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CheckoutContent(onPlaceOrder: {
            Task { await viewModel.placeOrder() }
        })
        .onChange(of: viewModel.lastEvent) { _, event in
            switch event {
            case .orderPlaced:
                dismiss()
            case .error(let message):
                errorMessage = message
                showError = true
            case nil:
                break
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
}

// Alternative: Use AsyncStream for true fire-and-forget events
@Observable
class CheckoutViewModel2 {
    private let eventContinuation: AsyncStream<CheckoutEvent>.Continuation
    let events: AsyncStream<CheckoutEvent>

    init(orderRepository: OrderRepository) {
        var continuation: AsyncStream<CheckoutEvent>.Continuation!
        events = AsyncStream { continuation = $0 }
        eventContinuation = continuation
        // store orderRepository...
    }

    func placeOrder() async {
        // ...
        eventContinuation.yield(.orderPlaced)
    }
}

// Consume with .task:
.task {
    for await event in viewModel.events {
        // handle event
    }
}
```

## Android Best Practices (Kotlin, 2024-2025)

- Use `collectAsStateWithLifecycle()` instead of `collectAsState()` to be lifecycle-aware.
- Prefer `StateFlow` over `LiveData` for new Compose code.
- Use `derivedStateOf` to avoid recompositions from intermediate state changes.
- Follow unidirectional data flow: state flows down, events flow up.
- Use `SavedStateHandle` in ViewModel for process-death restoration.
- Use `@Stable` and `@Immutable` annotations to help the Compose compiler optimize recomposition.

## iOS Best Practices (Swift, SwiftUI, 2024-2025)

- Use `@Observable` (iOS 17+) instead of `ObservableObject` for better performance -- it tracks property-level access, not object-level changes.
- Use `@State` for view-owned state, `@Binding` for borrowed state, `@Environment` for injected dependencies.
- Use computed properties instead of `derivedStateOf` -- SwiftUI will only re-evaluate body when accessed properties change (with `@Observable`).
- Follow unidirectional data flow: pass data down via init parameters, events up via closures.
- Use `@AppStorage` for simple preferences, `@SceneStorage` for per-scene state restoration.
- Use `@MainActor` on observable classes to ensure thread safety for UI state.
- Prefer `async/await` and structured concurrency over Combine for new code.

## Common Pitfalls and Gotchas

1. **`@State` ownership** -- `@State` must be declared `private` and owned by the view that declares it. Never pass a `@State` property to a child view as `@State` -- use `@Binding` instead. The equivalent mistake on Android would be passing a `MutableState` directly instead of hoisting state.

2. **`@StateObject` vs `@ObservedObject` (pre-iOS 17)** -- `@StateObject` creates and owns the instance (survives body re-evaluation). `@ObservedObject` borrows it (may be recreated). This distinction does not exist in Compose's `viewModel()` which always returns the same instance. On iOS 17+, use `@State` with `@Observable` for ownership.

3. **`@Observable` granularity** -- `@Observable` tracks individual property access. Only properties read in `body` trigger re-evaluation. This is more granular than `ObservableObject` which triggers on any `@Published` change. This behavior is closer to Compose's snapshot state system.

4. **No `remember` equivalent in SwiftUI** -- Compose's `remember` caches a value across recompositions without it being "state." SwiftUI has no equivalent. Use `@State` for mutable values or a computed property for derived values. For expensive one-time computations, use a lazy property on an `@Observable` class.

5. **Process death vs. app termination** -- Android's `rememberSaveable`/`SavedStateHandle` survive process death. iOS `@SceneStorage` survives app termination for that scene. `@AppStorage` persists to `UserDefaults` and survives app deletion reinstalls (unless the user clears data). These have different reliability guarantees.

6. **StateFlow `.value` vs. @Observable property** -- In Android, reading `stateFlow.value` gives the current value without subscribing. In SwiftUI, reading an `@Observable` property in `body` automatically subscribes. Reading it outside `body` (e.g., in a function) does not subscribe. This implicit subscription is a key difference.

7. **SharedFlow event loss** -- Android's `SharedFlow` can lose events if no collector is active. The iOS equivalent (`.onChange(of:)` with a property) can similarly miss rapid changes. For critical events, use `AsyncStream` with buffering or a queue.

8. **ViewModel scoping** -- Android's `ViewModel` is scoped to a `ViewModelStoreOwner` (Activity, Fragment, NavBackStackEntry). SwiftUI has no built-in equivalent. `@State` on a parent view keeps the model alive as long as that parent view exists. Use `@Environment` for app-scoped dependencies.

9. **Thread safety** -- Compose state (`mutableStateOf`) is thread-safe for reads/writes from the snapshot system. SwiftUI `@State` must be modified on the main thread. Mark `@Observable` classes with `@MainActor` to enforce this.

10. **Two-way binding with ViewModel** -- Compose uses `onValueChange` callbacks for two-way binding. SwiftUI uses `@Binding` which provides `$property` syntax for direct two-way binding. When using `@Observable`, create computed `Binding` values using `Binding(get:set:)` or use `@Bindable`.

11. **`@Bindable` (iOS 17+)** -- To create bindings from `@Observable` properties, use `@Bindable var viewModel` in the view. This is required because `@Observable` does not automatically provide `$` binding syntax like `@State` does.

```swift
// iOS 17+: @Bindable for creating bindings from @Observable
struct EditProfileView: View {
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        TextField("Name", text: $viewModel.userName)
        Toggle("Notifications", isOn: $viewModel.notificationsEnabled)
    }
}
```

12. **Combine vs. async/await** -- Older iOS code uses Combine (`Publishers`, `sink`, `assign`). Modern iOS code (2024-2025) prefers `async/await` and `AsyncSequence`. When migrating from Android's coroutine-based `Flow`, use `AsyncStream` or `AsyncSequence` rather than Combine.

13. **⚠️ `@Observable` is incompatible with `lazy var` (CRITICAL — 69% of migration build errors)** -- The `@Observable` macro generates access-tracking wrappers for every stored property. `lazy var` requires its own synthesized backing storage, which conflicts. Any Kotlin `by lazy { }` inside a class that becomes `@Observable` must either be converted to a non-lazy property or annotated with `@ObservationIgnored`.

14. **⚠️ Missing `Equatable` conformance for SwiftUI** -- Kotlin `data class` auto-generates `equals()`. Swift structs do not. Any type used with `.onChange(of:)`, `ForEach` identity, or `@Observable` properties must conform to `Equatable`. When migrating `data class` or `sealed class` used in UI state, always add `: Equatable`. For simple structs, Swift can synthesize it automatically — just declare conformance.

## Migration Checklist

1. **Inventory all state holders** -- List every `remember { mutableStateOf() }`, `rememberSaveable`, `derivedStateOf`, `ViewModel`, `StateFlow`, and `SharedFlow` in the Android feature.
2. **Categorize state by scope** -- Separate into view-local state (becomes `@State`), shared state (becomes `@Binding` or `@Observable`), and app-global state (becomes `@Environment`).
3. **Convert `remember { mutableStateOf() }`** -- Replace with `@State private var`. Ensure initial values are set.
4. **Convert `derivedStateOf`** -- Replace with computed properties on the view or `@Observable` class.
5. **Convert `rememberSaveable`** -- Replace with `@SceneStorage` for UI state restoration or `@AppStorage` for persistent preferences.
6. **Create `@Observable` classes** -- Convert each `ViewModel` to an `@Observable` class. Replace `StateFlow` properties with plain `var` properties. Replace `MutableStateFlow.update {}` with direct property assignment.
7. **Convert `collectAsStateWithLifecycle()`** -- Remove entirely. SwiftUI automatically observes `@Observable` properties read in `body`.
8. **Convert coroutine launches** -- Replace `viewModelScope.launch {}` with `async` methods called from `.task {}` or `Task {}` in action handlers.
9. **Convert SharedFlow events** -- Replace with `@Observable` event properties consumed via `.onChange(of:)`, or `AsyncStream` consumed via `.task { for await }`.
10. **Set up dependency injection** -- Replace Hilt/Koin `@Inject` with custom `EnvironmentKey` definitions and `.environment()` modifiers at the app root.
11. **Add `@MainActor`** -- Mark all `@Observable` classes with `@MainActor` to ensure thread safety.
12. **Convert state hoisting** -- Replace Compose state hoisting (value + onValueChange callbacks) with `@Binding` parameters in child views.
13. **Test state preservation** -- Verify `@SceneStorage` and `@AppStorage` persist across app termination and relaunch. Test with different scenes on iPad.
14. **Test observation granularity** -- Verify that only views reading changed properties re-evaluate. Use `Self._printChanges()` in `body` during development to debug unnecessary re-evaluations.
15. **Add `Equatable` conformance to all migrated state types used in SwiftUI observation** -- Any `data class` or `sealed class` used in UI state (e.g., with `.onChange(of:)`, `ForEach`, or `@Observable` properties) must conform to `Equatable` in Swift.
