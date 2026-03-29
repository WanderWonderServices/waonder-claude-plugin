---
name: generic-android-to-ios-viewmodel
description: Use when migrating Android ViewModel patterns (androidx.lifecycle.ViewModel, viewModelScope, SavedStateHandle) to iOS equivalents (@Observable, ObservableObject, @StateObject, @EnvironmentObject) with lifecycle-awareness, scope management, state preservation, and DI integration
type: generic
---

# generic-android-to-ios-viewmodel

## Context

Android's `androidx.lifecycle.ViewModel` is the backbone of modern Android UI architecture. It survives configuration changes, scopes coroutines via `viewModelScope`, and integrates with SavedStateHandle for process-death restoration. On iOS, SwiftUI's observation system serves a similar purpose but with fundamentally different mechanics. This skill provides a systematic mapping from Android ViewModel patterns to their idiomatic iOS equivalents, ensuring the migration preserves lifecycle safety, testability, and separation of concerns.

## Android Best Practices (Source Patterns)

### Core ViewModel Structure

```kotlin
class ProfileViewModel(
    private val getUserUseCase: GetUserUseCase,
    private val savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    private val _events = Channel<ProfileEvent>(Channel.BUFFERED)
    val events: Flow<ProfileEvent> = _events.receiveAsFlow()

    private var started = false

    fun start() {
        if (started) return
        started = true
        loadUser()
    }

    fun loadUser() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            getUserUseCase()
                .onSuccess { user ->
                    _uiState.update { it.copy(user = user, isLoading = false) }
                }
                .onFailure { error ->
                    _uiState.update { it.copy(error = error.message, isLoading = false) }
                    _events.send(ProfileEvent.ShowError(error.message ?: "Unknown error"))
                }
        }
    }

    fun onNameChanged(name: String) {
        savedStateHandle["draft_name"] = name
        _uiState.update { it.copy(draftName = name) }
    }
}

// In Compose — trigger start from the UI lifecycle:
@Composable
fun ProfileScreen(viewModel: ProfileViewModel = hiltViewModel()) {
    LaunchedEffect(Unit) {
        viewModel.start()
    }
    // ...
}

data class ProfileUiState(
    val user: User? = null,
    val draftName: String = "",
    val isLoading: Boolean = false,
    val error: String? = null
)

sealed interface ProfileEvent {
    data class ShowError(val message: String) : ProfileEvent
}
```

### ViewModel Scoping and DI (Hilt)

```kotlin
@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val getUserUseCase: GetUserUseCase,
    private val savedStateHandle: SavedStateHandle
) : ViewModel()

// In Fragment/Activity
val viewModel: ProfileViewModel by viewModels()

// Shared ViewModel scoped to Activity
val sharedViewModel: SharedViewModel by activityViewModels()

// Scoped to Navigation graph
val navViewModel: CheckoutViewModel by navGraphViewModels(R.id.checkout_graph)
```

### Key Android Patterns to Recognize

- `viewModelScope.launch` — auto-cancelled coroutine scope tied to ViewModel lifecycle
- `SavedStateHandle` — survives process death, stores primitive/Parcelable data
- `MutableStateFlow` / `StateFlow` — observable state container with conflation
- `Channel` — one-shot events (snackbars, navigation)
- `ViewModelProvider.Factory` — custom construction with dependencies
- `by viewModels()` / `by activityViewModels()` — scoping delegates

## iOS Best Practices (Target Patterns)

### iOS 17+ with @Observable (Preferred)

```swift
import SwiftUI

@Observable
final class ProfileViewModel {
    private let getUserUseCase: GetUserUseCaseProtocol

    var uiState = ProfileUiState()
    var event: ProfileEvent?

    private var started = false

    init(getUserUseCase: GetUserUseCaseProtocol) {
        self.getUserUseCase = getUserUseCase
        // NO side effects here — see "ViewModel Initialization" section below
    }

    /// Call from .task { await viewModel.start() } in the View.
    /// Idempotent — safe to call on every .task re-entry.
    @MainActor
    func start() async {
        guard !started else { return }
        started = true
        await loadUser()
    }

    @MainActor
    func loadUser() async {
        uiState.isLoading = true
        do {
            let user = try await getUserUseCase.execute()
            uiState.user = user
            uiState.isLoading = false
        } catch {
            guard !Task.isCancelled else { return }
            uiState.error = error.localizedDescription
            uiState.isLoading = false
            event = .showError(error.localizedDescription)
        }
    }

    func onNameChanged(_ name: String) {
        uiState.draftName = name
    }
}

struct ProfileUiState {
    var user: User?
    var draftName: String = ""
    var isLoading: Bool = false
    var error: String?
}

enum ProfileEvent: Equatable {
    case showError(String)
}
```

### iOS 15-16 with ObservableObject

```swift
import SwiftUI
import Combine

final class ProfileViewModel: ObservableObject {
    private let getUserUseCase: GetUserUseCaseProtocol

    @Published var uiState = ProfileUiState()
    @Published var event: ProfileEvent?

    private var started = false

    init(getUserUseCase: GetUserUseCaseProtocol) {
        self.getUserUseCase = getUserUseCase
        // NO side effects here — see "ViewModel Initialization" section below
    }

    @MainActor
    func start() async {
        guard !started else { return }
        started = true
        await loadUser()
    }

    @MainActor
    func loadUser() async {
        uiState.isLoading = true
        do {
            let user = try await getUserUseCase.execute()
            uiState.user = user
            uiState.isLoading = false
        } catch {
            guard !Task.isCancelled else { return }
            uiState.error = error.localizedDescription
            uiState.isLoading = false
            event = .showError(error.localizedDescription)
        }
    }
}
```

### View Integration and Scoping

```swift
// Owned by the view (equivalent to by viewModels())
struct ProfileView: View {
    @State private var viewModel: ProfileViewModel  // iOS 17+ @Observable

    init(getUserUseCase: GetUserUseCaseProtocol) {
        _viewModel = State(initialValue: ProfileViewModel(getUserUseCase: getUserUseCase))
    }

    var body: some View {
        ProfileContent(state: viewModel.uiState, onRetry: { Task { await viewModel.loadUser() } })
            .task { await viewModel.start() }  // Trigger startup from view lifecycle
    }
}

// iOS 15-16 equivalent
struct ProfileViewLegacy: View {
    @StateObject private var viewModel: ProfileViewModel

    init(getUserUseCase: GetUserUseCaseProtocol) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(getUserUseCase: getUserUseCase))
    }

    var body: some View {
        ProfileContent(state: viewModel.uiState, onRetry: { Task { await viewModel.loadUser() } })
            .task { await viewModel.start() }  // Trigger startup from view lifecycle
    }
}

// Shared ViewModel (equivalent to activityViewModels / navGraphViewModels)
struct CheckoutFlowView: View {
    @State private var sharedViewModel = CheckoutViewModel()

    var body: some View {
        NavigationStack {
            CartView()
                .environment(sharedViewModel) // iOS 17+
        }
    }
}

struct CartView: View {
    @Environment(CheckoutViewModel.self) private var viewModel
    // ...
}
```

### State Preservation (SavedStateHandle Equivalent)

```swift
// Using @SceneStorage for process-death survival
struct ProfileView: View {
    @SceneStorage("draft_name") private var draftName: String = ""
    @State private var viewModel: ProfileViewModel

    var body: some View {
        TextField("Name", text: $draftName)
            .onChange(of: draftName) { _, newValue in
                viewModel.onNameChanged(newValue)
            }
    }
}

// Using @AppStorage for UserDefaults-backed persistence
struct SettingsViewModel {
    @AppStorage("theme") var selectedTheme: String = "system"
}
```

## Migration Mapping Table

| Android | iOS 17+ | iOS 15-16 |
|---|---|---|
| `ViewModel` | `@Observable class` | `ObservableObject` class |
| `viewModelScope.launch` | `async` method called from `.task { }` view modifier | Same |
| `init { loadData() }` | `start()` method triggered via `.task { await vm.start() }` | Same |
| `StateFlow<T>` | `var` property (auto-tracked by `@Observable`) | `@Published var` |
| `MutableStateFlow` | Direct mutation of `var` | Direct mutation of `@Published var` |
| `Channel` (one-shot events) | Optional `event` property + `.onChange`/`.task` | Same, or PassthroughSubject |
| `SavedStateHandle` | `@SceneStorage` / `@AppStorage` | Same |
| `by viewModels()` | `@State private var viewModel` | `@StateObject private var viewModel` |
| `by activityViewModels()` | `.environment(vm)` + `@Environment(VM.self)` | `.environmentObject(vm)` + `@EnvironmentObject` |
| `navGraphViewModels()` | `.environment()` on NavigationStack | `.environmentObject()` on NavigationStack |
| `ViewModelProvider.Factory` | Init injection via `State(initialValue:)` | `StateObject(wrappedValue:)` |
| Hilt `@Inject` | Manual DI container or Swinject/Factory | Same |

## ViewModel Initialization — No Side Effects in init

**Rule**: ViewModel constructors (`init`) must be pure — no network calls, no database reads, no `Task` launches, no `viewModelScope.launch`. All startup work goes in an explicit `start()` method that the View triggers from its lifecycle.

### Why This Matters

On iOS, SwiftUI can create and immediately discard `@Observable` instances during view diffing and body re-evaluation. If `init` launches a `Task`, that task runs on a zombie instance — one SwiftUI has already thrown away. The zombie task can corrupt shared state (repositories, caches, analytics), fire duplicate network requests, and cause subtle bugs that are nearly impossible to reproduce.

On Android, while `ViewModel` instances are stable (scoped to `ViewModelStoreOwner`), keeping `init` side-effect-free ensures **platform parity** and makes the code easier to test — you can construct a ViewModel without triggering real work.

### The `start()` Pattern

Both platforms should use an idempotent `start()` method guarded by a `started` flag:

**Android (Kotlin)**:
```kotlin
class ChatViewModel(
    private val loadMessagesUseCase: LoadMessagesUseCase
) : ViewModel() {
    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    private var started = false

    fun start() {
        if (started) return
        started = true
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val messages = loadMessagesUseCase()
            _uiState.update { it.copy(messages = messages, isLoading = false) }
        }
    }
}

// In Compose:
@Composable
fun ChatScreen(viewModel: ChatViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) {
        viewModel.start()
    }
    // ...
}
```

**iOS (Swift, iOS 17+)**:
```swift
@Observable
final class ChatViewModel {
    private let loadMessagesUseCase: LoadMessagesUseCaseProtocol

    var uiState = ChatUiState()
    private var started = false

    init(loadMessagesUseCase: LoadMessagesUseCaseProtocol) {
        self.loadMessagesUseCase = loadMessagesUseCase
        // NOTHING else here
    }

    @MainActor
    func start() async {
        guard !started else { return }
        started = true
        uiState.isLoading = true
        let messages = await loadMessagesUseCase.execute()
        uiState.messages = messages
        uiState.isLoading = false
    }
}

// In SwiftUI:
struct ChatScreen: View {
    @State private var viewModel: ChatViewModel

    init(loadMessagesUseCase: LoadMessagesUseCaseProtocol) {
        _viewModel = State(initialValue: ChatViewModel(loadMessagesUseCase: loadMessagesUseCase))
    }

    var body: some View {
        ChatContent(state: viewModel.uiState)
            .task { await viewModel.start() }
    }
}
```

### Key Properties of `start()`

- **Idempotent**: The `started` flag ensures it only executes once, even if `.task` re-fires (e.g., after a tab switch).
- **Lifecycle-bound on iOS**: `.task { }` automatically cancels when the view disappears. The `start()` body uses structured concurrency (`async`), so cancellation propagates naturally.
- **Lifecycle-bound on Android**: `LaunchedEffect(Unit)` runs once when the composable enters composition. `viewModelScope` auto-cancels when the ViewModel is cleared.
- **Testable**: Unit tests can construct the ViewModel without triggering side effects, then call `start()` explicitly.

## Common Pitfalls

1. **`@Observable` macro conflicts with `lazy var` (CRITICAL)** — Swift's `@Observable` macro synthesizes property accessors for all stored properties. `lazy var` conflicts with this because it needs its own storage mechanism. When migrating Kotlin `by lazy { }` delegates inside a ViewModel:
   - If the lazy property is a dependency that never changes, convert it to a regular `let` or `var` initialized in `init`
   - If it must remain lazily initialized, annotate it with `@ObservationIgnored lazy var`
   - If it holds observable state that the view reads, refactor it to a regular `var` (not lazy) and initialize in `init`

```swift
// WRONG
@Observable final class FooViewModel {
    lazy var formatter = DateFormatter()  // ERROR
}

// CORRECT
@Observable final class FooViewModel {
    @ObservationIgnored lazy var formatter = DateFormatter()
}
```

2. **Swift requires explicit argument labels** — Kotlin function calls use positional arguments by default (`loadUser("abc")`). Swift requires labels at the call site (`loadUser(userId: "abc")`). When migrating ViewModel methods, decide for each parameter whether to keep the label (default) or suppress with `_`. Convention: single-parameter actions often suppress (`func onNameChanged(_ name: String)`), multi-parameter methods keep labels.

3. **Missing framework imports** — Kotlin auto-imports; Swift requires explicit `import` statements. Commonly missed: `import UIKit` (for `UIApplication`, `UIColor`), `import Combine` (for `PassthroughSubject`), `import SwiftUI`.

4. **Recreating the ViewModel on every view redraw** — On iOS 15-16, use `@StateObject`, never `@ObservedObject`, for owned ViewModels. On iOS 17+, use `@State` with `@Observable` classes. Using `@ObservedObject` or bare `let` causes the ViewModel to be re-created on parent redraws.

5. **Forgetting task cancellation** — Android's `viewModelScope` auto-cancels. On iOS, you must cancel `Task` references manually in `deinit` or use `.task { }` view modifier which auto-cancels when the view disappears.

6. **Publishing changes off the main actor** — `@Published` property changes must happen on the main thread. Use `@MainActor` on the ViewModel class or on individual methods that mutate published state.

7. **Overusing @EnvironmentObject for non-shared state** — Only use environment injection for genuinely shared state (like Android's `activityViewModels`). View-owned state should use `@State`/`@StateObject`.

8. **One-shot events** — Android's `Channel`-based events do not have a direct SwiftUI equivalent. Avoid using `@Published` for events since new subscribers replay the last value. Use an optional property that is nil-ed out after consumption, or use a callback-based approach.

9. **SavedStateHandle misunderstanding** — `@SceneStorage` only works with value types (String, Int, Double, Bool, Data, URL). For complex objects, serialize to Data first. Unlike SavedStateHandle, it only works inside SwiftUI views, not inside ViewModel classes.

10. **Launching Tasks in `@Observable` init creates zombie side effects (CRITICAL)** — SwiftUI can create and discard `@Observable` instances during view diffing without ever displaying them. If `init` launches a `Task` (directly or via a helper method), the zombie instance fires network requests, writes to repositories, and corrupts shared state. **Always** use the `start()` pattern: keep `init` pure and trigger startup work from the View lifecycle via `.task { await viewModel.start() }` on iOS or `LaunchedEffect(Unit) { viewModel.start() }` on Android.

## Migration Checklist

- [ ] Identify all ViewModel classes and their dependencies
- [ ] Replace `ViewModel()` base class with `@Observable` (iOS 17+) or `ObservableObject` (iOS 15-16)
- [ ] Convert `StateFlow`/`MutableStateFlow` to plain properties or `@Published`
- [ ] Move all `init {}` side effects to an idempotent `start()` method guarded by a `started` flag
- [ ] Replace `viewModelScope.launch` with `async` methods called from `.task { }` in the View
- [ ] Convert `SavedStateHandle` usage to `@SceneStorage` or `@AppStorage` in the View layer
- [ ] Map Hilt/Dagger injection to your chosen iOS DI approach (manual, Swinject, Factory, or swift-dependencies)
- [ ] Convert `by viewModels()` scoping to `@State`/`@StateObject` ownership
- [ ] Convert `by activityViewModels()` scoping to `@Environment`/`@EnvironmentObject` sharing
- [ ] Replace `Channel`-based one-shot events with optional event properties or callbacks
- [ ] Ensure all state mutations occur on `@MainActor`
- [ ] Add `deinit` with task cancellation to every ViewModel that launches async work
- [ ] Write unit tests using Swift Testing or XCTest, injecting mock use cases via protocols
