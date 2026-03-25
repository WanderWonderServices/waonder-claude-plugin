---
name: generic-android-to-ios-viewmodel
description: Guides migration of Android ViewModel patterns (androidx.lifecycle.ViewModel, viewModelScope, SavedStateHandle) to iOS equivalents (@Observable, ObservableObject, @StateObject, @EnvironmentObject) with lifecycle-awareness, scope management, state preservation, and DI integration
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

    init {
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

    private var loadTask: Task<Void, Never>?

    init(getUserUseCase: GetUserUseCaseProtocol) {
        self.getUserUseCase = getUserUseCase
        loadUser()
    }

    func loadUser() {
        loadTask?.cancel()
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
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

    func onNameChanged(_ name: String) {
        uiState.draftName = name
    }

    deinit {
        loadTask?.cancel()
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

    private var loadTask: Task<Void, Never>?

    init(getUserUseCase: GetUserUseCaseProtocol) {
        self.getUserUseCase = getUserUseCase
        loadUser()
    }

    @MainActor
    func loadUser() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
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

    deinit {
        loadTask?.cancel()
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
        ProfileContent(state: viewModel.uiState, onRetry: viewModel.loadUser)
    }
}

// iOS 15-16 equivalent
struct ProfileViewLegacy: View {
    @StateObject private var viewModel: ProfileViewModel

    init(getUserUseCase: GetUserUseCaseProtocol) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(getUserUseCase: getUserUseCase))
    }

    var body: some View {
        ProfileContent(state: viewModel.uiState, onRetry: viewModel.loadUser)
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
| `viewModelScope.launch` | `Task { }` + manual cancellation in `deinit` | Same |
| `StateFlow<T>` | `var` property (auto-tracked by `@Observable`) | `@Published var` |
| `MutableStateFlow` | Direct mutation of `var` | Direct mutation of `@Published var` |
| `Channel` (one-shot events) | Optional `event` property + `.onChange`/`.task` | Same, or PassthroughSubject |
| `SavedStateHandle` | `@SceneStorage` / `@AppStorage` | Same |
| `by viewModels()` | `@State private var viewModel` | `@StateObject private var viewModel` |
| `by activityViewModels()` | `.environment(vm)` + `@Environment(VM.self)` | `.environmentObject(vm)` + `@EnvironmentObject` |
| `navGraphViewModels()` | `.environment()` on NavigationStack | `.environmentObject()` on NavigationStack |
| `ViewModelProvider.Factory` | Init injection via `State(initialValue:)` | `StateObject(wrappedValue:)` |
| Hilt `@Inject` | Manual DI container or Swinject/Factory | Same |

## Common Pitfalls

1. **Recreating the ViewModel on every view redraw** — On iOS 15-16, use `@StateObject`, never `@ObservedObject`, for owned ViewModels. On iOS 17+, use `@State` with `@Observable` classes. Using `@ObservedObject` or bare `let` causes the ViewModel to be re-created on parent redraws.

2. **Forgetting task cancellation** — Android's `viewModelScope` auto-cancels. On iOS, you must cancel `Task` references manually in `deinit` or use `.task { }` view modifier which auto-cancels when the view disappears.

3. **Publishing changes off the main actor** — `@Published` property changes must happen on the main thread. Use `@MainActor` on the ViewModel class or on individual methods that mutate published state.

4. **Overusing @EnvironmentObject for non-shared state** — Only use environment injection for genuinely shared state (like Android's `activityViewModels`). View-owned state should use `@State`/`@StateObject`.

5. **One-shot events** — Android's `Channel`-based events do not have a direct SwiftUI equivalent. Avoid using `@Published` for events since new subscribers replay the last value. Use an optional property that is nil-ed out after consumption, or use a callback-based approach.

6. **SavedStateHandle misunderstanding** — `@SceneStorage` only works with value types (String, Int, Double, Bool, Data, URL). For complex objects, serialize to Data first. Unlike SavedStateHandle, it only works inside SwiftUI views, not inside ViewModel classes.

## Migration Checklist

- [ ] Identify all ViewModel classes and their dependencies
- [ ] Replace `ViewModel()` base class with `@Observable` (iOS 17+) or `ObservableObject` (iOS 15-16)
- [ ] Convert `StateFlow`/`MutableStateFlow` to plain properties or `@Published`
- [ ] Replace `viewModelScope.launch` with `Task` and add cancellation in `deinit`
- [ ] Convert `SavedStateHandle` usage to `@SceneStorage` or `@AppStorage` in the View layer
- [ ] Map Hilt/Dagger injection to your chosen iOS DI approach (manual, Swinject, Factory, or swift-dependencies)
- [ ] Convert `by viewModels()` scoping to `@State`/`@StateObject` ownership
- [ ] Convert `by activityViewModels()` scoping to `@Environment`/`@EnvironmentObject` sharing
- [ ] Replace `Channel`-based one-shot events with optional event properties or callbacks
- [ ] Ensure all state mutations occur on `@MainActor`
- [ ] Add `deinit` with task cancellation to every ViewModel that launches async work
- [ ] Write unit tests using Swift Testing or XCTest, injecting mock use cases via protocols
