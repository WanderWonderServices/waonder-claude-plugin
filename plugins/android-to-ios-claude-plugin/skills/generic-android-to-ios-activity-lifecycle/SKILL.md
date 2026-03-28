---
name: generic-android-to-ios-activity-lifecycle
description: Use when migrating Android Activity/Fragment lifecycle (onCreate, onStart, onResume, onPause, onStop, onDestroy) to iOS UIViewController lifecycle (viewDidLoad, viewWillAppear, viewDidAppear, viewWillDisappear, viewDidDisappear, deinit) and SwiftUI equivalents (.onAppear, .onDisappear, .task), including configuration changes, state restoration, and rotation handling
type: generic
---

# generic-android-to-ios-activity-lifecycle

## Context

Android's Activity and Fragment lifecycle is the foundation of screen-level state management. Activities progress through a well-defined sequence (onCreate -> onStart -> onResume -> onPause -> onStop -> onDestroy), with configuration changes triggering full destruction and recreation by default. iOS UIViewController has a parallel but structurally different lifecycle, and SwiftUI replaces imperative callbacks with declarative modifiers. This skill provides a systematic mapping between the two, covering state preservation, configuration change equivalents, and rotation handling.

## Lifecycle State Diagram Mapping

```
Android Activity              iOS UIViewController           SwiftUI View
==============               ====================           ============
                              init()                         init (body eval)
onCreate(Bundle?)     ->      viewDidLoad()            ->    .onAppear (first)
onStart()             ->      viewWillAppear(_:)       ->    .onAppear
onResume()            ->      viewDidAppear(_:)        ->    (no direct equiv)
onPause()             ->      viewWillDisappear(_:)    ->    .onDisappear
onStop()              ->      viewDidDisappear(_:)     ->    .onDisappear
onDestroy()           ->      deinit                   ->    (view removed)

Config change         ->      viewWillTransition(to:)  ->    automatic re-render
(recreate Activity)            traitCollectionDidChange
                               (no recreation)

savedInstanceState    ->      NSCoder (storyboard)     ->    @SceneStorage
                              State restoration API          @AppStorage
```

## Android Best Practices (Source Patterns)

### Full Activity Lifecycle

```kotlin
class ProfileActivity : AppCompatActivity() {

    private lateinit var binding: ActivityProfileBinding
    private val viewModel: ProfileViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityProfileBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // One-time setup: observers, click listeners, RecyclerView adapters
        setupObservers()
        setupClickListeners()

        // Restore transient UI state
        savedInstanceState?.let {
            binding.scrollView.scrollY = it.getInt("scroll_position", 0)
        }
    }

    override fun onStart() {
        super.onStart()
        // Become visible — register broadcast receivers, start animations
        registerLocationUpdates()
    }

    override fun onResume() {
        super.onResume()
        // Fully interactive — resume camera, sensors, refresh stale data
        viewModel.refreshIfStale()
        analytics.trackScreenView("profile")
    }

    override fun onPause() {
        super.onPause()
        // Losing focus — pause camera, commit draft saves
        viewModel.saveDraft()
    }

    override fun onStop() {
        super.onStop()
        // No longer visible — unregister receivers, stop animations
        unregisterLocationUpdates()
    }

    override fun onDestroy() {
        super.onDestroy()
        // Final cleanup — release heavy resources not tied to ViewModel
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putInt("scroll_position", binding.scrollView.scrollY)
    }
}
```

### Fragment Lifecycle (Additional Callbacks)

```kotlin
class ProfileFragment : Fragment(R.layout.fragment_profile) {

    private var _binding: FragmentProfileBinding? = null
    private val binding get() = _binding!!
    private val viewModel: ProfileViewModel by viewModels()

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        _binding = FragmentProfileBinding.bind(view)

        // Use viewLifecycleOwner for UI observations
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { state ->
                    updateUI(state)
                }
            }
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null // Prevent memory leaks
    }
}
```

### Configuration Change Handling

```kotlin
// AndroidManifest.xml — handle manually (skip recreation)
// android:configChanges="orientation|screenSize|screenLayout|smallestScreenSize"

class MapActivity : AppCompatActivity() {
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        when (newConfig.orientation) {
            Configuration.ORIENTATION_LANDSCAPE -> switchToLandscapeLayout()
            Configuration.ORIENTATION_PORTRAIT -> switchToPortraitLayout()
        }
    }
}

// Default behavior: Activity destroyed and recreated
// ViewModel survives; savedInstanceState is delivered to new onCreate
```

### Key Android Patterns to Recognize

- `onCreate(savedInstanceState)` — one-time setup with optional state restoration
- `onStart/onStop` — visibility-driven resource management
- `onResume/onPause` — foreground focus, camera/sensor control
- `onSaveInstanceState(Bundle)` — transient UI state survival across config changes
- `viewLifecycleOwner` — Fragment-specific lifecycle for UI-bound work
- `configChanges` manifest attribute — opt out of recreation
- `by viewModels()` — survives config changes without `onSaveInstanceState`

## iOS Best Practices (Target Patterns)

### UIViewController Lifecycle (UIKit)

```swift
import UIKit

final class ProfileViewController: UIViewController {

    private let viewModel: ProfileViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // Equivalent to onCreate — called once when view hierarchy is loaded
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }

    // Equivalent to onStart — view is about to become visible
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // Equivalent to onResume — view is fully visible and interactive
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.refreshIfStale()
        Analytics.shared.trackScreenView("profile")
    }

    // Equivalent to onPause — view is about to lose visibility
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.saveDraft()
    }

    // Equivalent to onStop — view is no longer visible
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopLocationUpdates()
    }

    // No direct onDestroy equivalent — use deinit
    deinit {
        // Release any non-ARC resources
    }

    // Configuration change equivalent — no recreation needed
    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateLayoutForSize(size)
        })
    }

    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColorsForCurrentTheme()
        }
    }

    private func setupBindings() {
        // Combine bindings — equivalent to Flow collection in repeatOnLifecycle
        viewModel.$uiState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUI(with: state)
            }
            .store(in: &cancellables)
    }
}
```

### SwiftUI View Lifecycle (Preferred for New Code)

```swift
import SwiftUI

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel
    @SceneStorage("profile_scroll_position") private var scrollPosition: CGFloat = 0
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: ProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            profileContent
        }
        // Equivalent to onStart/onStop (visibility-based)
        .onAppear {
            viewModel.onScreenAppeared()
            Analytics.shared.trackScreenView("profile")
        }
        .onDisappear {
            viewModel.saveDraft()
        }
        // Equivalent to onCreate with async work — auto-cancelled on disappear
        .task {
            await viewModel.loadInitialData()
        }
        // Equivalent to onResume/onPause (foreground focus)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                viewModel.refreshIfStale()
            case .inactive:
                viewModel.saveDraft()
            default:
                break
            }
        }
    }
}
```

### SwiftUI Lifecycle with Task Cancellation

```swift
struct LiveDataView: View {
    @State private var viewModel: LiveDataViewModel

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else {
                dataContent
            }
        }
        // .task is cancelled when view disappears — mirrors repeatOnLifecycle(STARTED)
        .task {
            await viewModel.observeLiveUpdates()
        }
        // .task(id:) restarts when the id changes — mirrors collectLatest
        .task(id: viewModel.selectedCategory) {
            await viewModel.loadItems(for: viewModel.selectedCategory)
        }
    }
}
```

### Rotation Handling in SwiftUI

```swift
struct AdaptiveLayoutView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        // Automatic re-render on rotation — no configuration change needed
        if horizontalSizeClass == .regular {
            landscapeLayout
        } else {
            portraitLayout
        }
    }

    private var landscapeLayout: some View {
        HStack {
            sidePanel
            mainContent
        }
    }

    private var portraitLayout: some View {
        VStack {
            mainContent
        }
    }
}
```

### State Restoration (savedInstanceState Equivalent)

```swift
// @SceneStorage — survives app termination per scene (like savedInstanceState)
struct EditorView: View {
    @SceneStorage("editor_draft_text") private var draftText: String = ""
    @SceneStorage("editor_selected_tab") private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TextEditor(text: $draftText)
                .tag(0)
            PreviewView(text: draftText)
                .tag(1)
        }
    }
}

// @AppStorage — persists across launches (like SharedPreferences, not savedInstanceState)
struct SettingsView: View {
    @AppStorage("notifications_enabled") private var notificationsEnabled = true
}
```

## Migration Mapping Reference

| Android Concept | iOS UIKit | iOS SwiftUI |
|---|---|---|
| `onCreate(Bundle?)` | `viewDidLoad()` | `.onAppear` (first), `.task` |
| `onStart()` | `viewWillAppear(_:)` | `.onAppear` |
| `onResume()` | `viewDidAppear(_:)` | `.onChange(of: scenePhase)` `.active` |
| `onPause()` | `viewWillDisappear(_:)` | `.onChange(of: scenePhase)` `.inactive` |
| `onStop()` | `viewDidDisappear(_:)` | `.onDisappear` |
| `onDestroy()` | `deinit` | View removed from hierarchy |
| `onSaveInstanceState` | `encodeRestorableState(with:)` | `@SceneStorage` |
| `savedInstanceState` | `decodeRestorableState(with:)` | `@SceneStorage` (automatic) |
| Config change recreation | No recreation (handled in place) | Automatic re-render |
| `onConfigurationChanged` | `viewWillTransition(to:with:)` | `@Environment(\.horizontalSizeClass)` |
| `configChanges` manifest | Not needed (no recreation) | Not needed |
| `viewLifecycleOwner` | View controller itself | View struct lifetime |
| `Fragment.onDestroyView` | N/A (no split ownership) | N/A |
| `_binding = null` | N/A (ARC handles cleanup) | N/A (value types) |

## Common Pitfalls

### 1. Assuming iOS Views Are Recreated on Rotation
Android recreates Activities on configuration changes by default. iOS never recreates view controllers on rotation. Do not implement "restoration" logic that is unnecessary on iOS. SwiftUI views re-evaluate their `body` automatically when environment values like `horizontalSizeClass` change.

### 2. Conflating onAppear with onCreate
SwiftUI's `.onAppear` can be called multiple times (e.g., when a tab is re-selected or a NavigationStack pops back). Use a boolean guard or `.task` for one-time initialization.

```swift
struct ProfileView: View {
    @State private var hasAppeared = false

    var body: some View {
        content
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                // One-time setup (like onCreate)
            }
    }

    // Or better: use .task which is naturally one-shot per view identity
    // .task { await viewModel.loadOnce() }
}
```

### 3. Missing Fragment View Lifecycle Null Safety
Android's Fragment has `onDestroyView` where you null out `_binding`. In iOS, ARC handles this. Do not add manual nil-setting patterns. Instead, ensure `cancellables` are tied to the view controller lifecycle (cleared in `deinit` automatically via `Set<AnyCancellable>`).

### 4. Forgetting That savedInstanceState Survives Process Death
`@SceneStorage` is the closest SwiftUI equivalent, but it only persists simple types (String, Int, Double, Bool, URL, Data). For complex state, serialize to Data. `@AppStorage` persists to UserDefaults and is more analogous to SharedPreferences.

### 5. Leaking Subscriptions Across Appear/Disappear Cycles
In UIKit, if you subscribe in `viewWillAppear`, unsubscribe in `viewWillDisappear`. In SwiftUI, `.task` handles this automatically by cancelling on disappear.

```swift
// UIKit — manual management
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    locationCancellable = locationService.updates
        .sink { [weak self] location in self?.updateMap(location) }
}

override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    locationCancellable?.cancel()
}

// SwiftUI — automatic via .task
.task {
    for await location in locationService.updates {
        updateMap(location)
    }
}
```

## Migration Checklist

- [ ] Map each `onCreate` setup block to either `viewDidLoad()` (UIKit) or `.onAppear`/`.task` (SwiftUI)
- [ ] Move `onResume`/`onPause` sensor/camera logic to `viewDidAppear`/`viewWillDisappear` or `scenePhase` observation
- [ ] Replace `onSaveInstanceState(Bundle)` with `@SceneStorage` for transient UI state
- [ ] Remove all configuration-change workarounds (no recreation happens on iOS)
- [ ] Replace `configChanges` manifest handling with `viewWillTransition(to:with:)` or `@Environment` size classes
- [ ] Convert `viewLifecycleOwner.repeatOnLifecycle` collection to `.task` in SwiftUI
- [ ] Ensure `.onAppear` guards for one-time work or prefer `.task`
- [ ] Null-out binding patterns (`_binding = null`) are not needed — remove them
- [ ] Validate that Combine subscriptions or async tasks are properly scoped to view lifetime
- [ ] Test rotation, multitasking (Split View), and background/foreground transitions
