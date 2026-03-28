---
name: generic-android-to-ios-fragments
description: Use when migrating Android Fragment patterns (FragmentManager, FragmentTransaction, ViewPager2, BottomSheetDialogFragment) to iOS child UIViewController, SwiftUI subviews, TabView, .sheet/.fullScreenCover
type: generic
---

# generic-android-to-ios-fragments

## Context

Android's `Fragment` is a modular UI component with its own lifecycle, hosted within an `Activity`. Fragments enable reusable UI sections, multi-pane layouts, ViewPager tabs, bottom sheets, and dialog-style presentations. iOS has no direct `Fragment` equivalent. In UIKit, child `UIViewController` serves a similar purpose. In SwiftUI, views are inherently composable and lightweight -- any `View` struct acts like a fragment. This skill covers migrating fragment patterns, lifecycle management, communication, container views, and modal presentations.

## Concept Mapping

| Android | iOS (SwiftUI) | iOS (UIKit) |
|---|---|---|
| `Fragment` | `View` struct (any SwiftUI view) | Child `UIViewController` |
| `FragmentManager` | SwiftUI view hierarchy (automatic) | `addChild()` / `removeFromParent()` |
| `FragmentTransaction.add/replace` | Conditional view rendering / `NavigationStack` | Container view controller pattern |
| `FragmentTransaction.addToBackStack` | `NavigationPath` | `UINavigationController` |
| `FragmentContainerView` | Container `View` with conditional content | `UIView` container + child VC |
| `ViewPager2` + `FragmentStateAdapter` | `TabView(.page)` | `UIPageViewController` |
| `BottomSheetDialogFragment` | `.sheet` modifier | Custom `UIPresentationController` |
| `DialogFragment` | `.alert` / `.confirmationDialog` / `.sheet` | `UIAlertController` / custom modal |
| `Fragment.setFragmentResult` | `@Binding` / closure / `@Environment` | Delegate / `NotificationCenter` |
| `Fragment.setFragmentResultListener` | `.onChange(of:)` / closure callback | Delegate / `NotificationCenter` |
| `childFragmentManager` | Nested `View` composition | Child VC within child VC |
| `parentFragmentManager` | `@Environment` / `@Binding` to parent | `parent` property |
| `Fragment` lifecycle | `onAppear` / `onDisappear` / `.task` | `viewDidLoad` / `viewDidAppear` etc. |
| `savedInstanceState` in Fragment | `@SceneStorage` / `@State` | `encodeRestorableState` |
| `by viewModels()` in Fragment | `@State` on `@Observable` class | Property / DI |
| `by activityViewModels()` | `@Environment` injected from ancestor | Parent VC property |

## Code Patterns

### Basic Fragment to SwiftUI View

**Android:**
```kotlin
class ProfileFragment : Fragment() {
    private val viewModel: ProfileViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        return ComposeView(requireContext()).apply {
            setContent {
                val state by viewModel.uiState.collectAsStateWithLifecycle()
                ProfileContent(state = state)
            }
        }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        val userId = arguments?.getString("userId") ?: return
        viewModel.loadProfile(userId)
    }
}
```

**iOS (SwiftUI):**
```swift
struct ProfileView: View {
    let userId: String
    @State private var viewModel: ProfileViewModel

    init(userId: String) {
        self.userId = userId
        self._viewModel = State(wrappedValue: ProfileViewModel())
    }

    var body: some View {
        ProfileContent(state: viewModel.uiState)
            .task {
                await viewModel.loadProfile(userId)
            }
    }
}
```

### FragmentManager Replace/Add Operations

**Android:**
```kotlin
// Replace fragment in container
supportFragmentManager.commit {
    replace(R.id.fragment_container, DetailFragment.newInstance(itemId))
    addToBackStack("detail")
}

// Add fragment (overlay)
supportFragmentManager.commit {
    add(R.id.overlay_container, OverlayFragment())
    addToBackStack("overlay")
}

// Pop back
supportFragmentManager.popBackStack()
```

**iOS (SwiftUI):**
```swift
// Replace: use NavigationStack for push/pop navigation
struct ContainerView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: AppDestination.self) { dest in
                    switch dest {
                    case .detail(let id): DetailView(itemId: id)
                    }
                }
        }
    }

    // Push (equivalent to replace + addToBackStack)
    func showDetail(_ id: String) {
        path.append(AppDestination.detail(id: id))
    }

    // Pop (equivalent to popBackStack)
    func goBack() {
        path.removeLast()
    }
}

// Add (overlay): use ZStack or .overlay
struct ContainerWithOverlay: View {
    @State private var showOverlay = false

    var body: some View {
        ZStack {
            MainContentView()
            if showOverlay {
                OverlayView(onDismiss: { showOverlay = false })
                    .transition(.opacity)
            }
        }
    }
}
```

### ViewPager2 with Tabs

**Android:**
```kotlin
class TabsFragment : Fragment() {
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        val viewPager = view.findViewById<ViewPager2>(R.id.viewPager)
        val tabLayout = view.findViewById<TabLayout>(R.id.tabLayout)

        viewPager.adapter = object : FragmentStateAdapter(this) {
            override fun getItemCount() = 3
            override fun createFragment(position: Int): Fragment {
                return when (position) {
                    0 -> OverviewFragment()
                    1 -> StatsFragment()
                    2 -> HistoryFragment()
                    else -> throw IllegalArgumentException()
                }
            }
        }

        TabLayoutMediator(tabLayout, viewPager) { tab, position ->
            tab.text = when (position) {
                0 -> "Overview"
                1 -> "Stats"
                2 -> "History"
                else -> ""
            }
        }.attach()
    }
}
```

**iOS (SwiftUI):**
```swift
struct TabsView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar at top (like TabLayout)
            Picker("Tabs", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Stats").tag(1)
                Text("History").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Page content (like ViewPager2)
            TabView(selection: $selectedTab) {
                OverviewView().tag(0)
                StatsView().tag(1)
                HistoryView().tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}
```

### BottomSheetDialogFragment

**Android:**
```kotlin
class FilterBottomSheet : BottomSheetDialogFragment() {
    private var onFilterApplied: ((Filter) -> Unit)? = null

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        return ComposeView(requireContext()).apply {
            setContent {
                FilterContent(
                    onApply = { filter ->
                        onFilterApplied?.invoke(filter)
                        dismiss()
                    }
                )
            }
        }
    }

    companion object {
        fun newInstance(callback: (Filter) -> Unit): FilterBottomSheet {
            return FilterBottomSheet().apply {
                onFilterApplied = callback
            }
        }
    }
}

// Show it
FilterBottomSheet.newInstance { filter ->
    applyFilter(filter)
}.show(supportFragmentManager, "filter")
```

**iOS (SwiftUI):**
```swift
struct ContentView: View {
    @State private var showFilter = false
    @State private var currentFilter = Filter()

    var body: some View {
        Button("Show Filters") { showFilter = true }
            .sheet(isPresented: $showFilter) {
                FilterSheet(filter: $currentFilter)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: currentFilter) { _, newFilter in
                applyFilter(newFilter)
            }
    }
}

struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: Filter
    @State private var draft: Filter

    init(filter: Binding<Filter>) {
        self._filter = filter
        self._draft = State(wrappedValue: filter.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            FilterContent(filter: $draft)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") {
                            filter = draft
                            dismiss()
                        }
                    }
                }
        }
    }
}
```

### DialogFragment

**Android:**
```kotlin
class ConfirmDialog : DialogFragment() {
    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        return AlertDialog.Builder(requireContext())
            .setTitle("Confirm Delete")
            .setMessage("Are you sure you want to delete this item?")
            .setPositiveButton("Delete") { _, _ ->
                setFragmentResult("confirm", bundleOf("confirmed" to true))
            }
            .setNegativeButton("Cancel", null)
            .create()
    }
}
```

**iOS (SwiftUI):**
```swift
struct ContentView: View {
    @State private var showDeleteConfirmation = false

    var body: some View {
        Button("Delete") { showDeleteConfirmation = true }
            .confirmationDialog(
                "Confirm Delete",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    performDelete()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this item?")
            }
    }
}

// Or using .alert for simple confirmations
.alert("Confirm Delete", isPresented: $showAlert) {
    Button("Delete", role: .destructive) { performDelete() }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("Are you sure you want to delete this item?")
}
```

### Fragment Communication (setFragmentResult)

**Android:**
```kotlin
// Child fragment sends result
setFragmentResult("requestKey", bundleOf("bundleKey" to "value"))

// Parent fragment listens
setFragmentResultListener("requestKey") { _, bundle ->
    val result = bundle.getString("bundleKey")
    handleResult(result)
}
```

**iOS (SwiftUI -- using @Binding):**
```swift
// Parent
struct ParentView: View {
    @State private var selectedValue: String = ""

    var body: some View {
        ChildView(selectedValue: $selectedValue)
            .onChange(of: selectedValue) { _, newValue in
                handleResult(newValue)
            }
    }
}

// Child
struct ChildView: View {
    @Binding var selectedValue: String

    var body: some View {
        Button("Select") {
            selectedValue = "chosen_value"
        }
    }
}
```

**iOS (SwiftUI -- using closure callback):**
```swift
struct ParentView: View {
    var body: some View {
        ChildView { result in
            handleResult(result)
        }
    }
}

struct ChildView: View {
    let onResult: (String) -> Void

    var body: some View {
        Button("Select") {
            onResult("chosen_value")
        }
    }
}
```

**iOS (SwiftUI -- using @Environment for deeply nested communication):**
```swift
// Define an environment key
struct SelectionHandlerKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    var onSelection: (String) -> Void {
        get { self[SelectionHandlerKey.self] }
        set { self[SelectionHandlerKey.self] = newValue }
    }
}

// Parent
struct ParentView: View {
    var body: some View {
        DeeplyNestedContent()
            .environment(\.onSelection) { value in
                handleResult(value)
            }
    }
}

// Deeply nested child
struct DeeplyNestedChild: View {
    @Environment(\.onSelection) private var onSelection

    var body: some View {
        Button("Select") { onSelection("value") }
    }
}
```

### Fragment Lifecycle Mapping

**Android:**
```kotlin
class MyFragment : Fragment() {
    override fun onCreate(savedInstanceState: Bundle?) { /* init */ }
    override fun onCreateView(...): View { /* create UI */ }
    override fun onViewCreated(...) { /* UI ready, safe to access views */ }
    override fun onStart() { /* visible */ }
    override fun onResume() { /* interactive */ }
    override fun onPause() { /* losing focus */ }
    override fun onStop() { /* not visible */ }
    override fun onDestroyView() { /* view destroyed, fragment may be retained */ }
    override fun onDestroy() { /* fragment destroyed */ }
}
```

**iOS (SwiftUI):**
```swift
struct MyView: View {
    // onCreate + onCreateView: body property evaluation (view construction)

    var body: some View {
        Content()
            .onAppear {
                // onStart + onResume equivalent
                // Called when view appears in the hierarchy
            }
            .onDisappear {
                // onPause + onStop equivalent
                // Called when view leaves the hierarchy
            }
            .task {
                // Async work started on appear, cancelled on disappear
                // Good replacement for lifecycle-aware coroutine launches
            }
            .task(id: someValue) {
                // Re-launched when someValue changes
                // Good for reacting to argument changes
            }
    }

    // No explicit onDestroyView/onDestroy -- handled by ARC and SwiftUI lifecycle
}
```

### Multi-Pane Layout (Master-Detail)

**Android:**
```kotlin
class MasterDetailFragment : Fragment() {
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        if (resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE) {
            // Show both panes side by side
            childFragmentManager.commit {
                replace(R.id.master_container, ListFragment())
                replace(R.id.detail_container, DetailFragment())
            }
        } else {
            // Show master only, navigate to detail on click
            childFragmentManager.commit {
                replace(R.id.master_container, ListFragment())
            }
        }
    }
}
```

**iOS (SwiftUI):**
```swift
struct MasterDetailView: View {
    @State private var selectedItem: Item?

    var body: some View {
        // NavigationSplitView handles adaptive layout automatically
        NavigationSplitView {
            ListView(selectedItem: $selectedItem)
        } detail: {
            if let item = selectedItem {
                DetailView(item: item)
            } else {
                Text("Select an item")
            }
        }
    }
}

// On compact (iPhone): behaves like push navigation
// On regular (iPad): shows side-by-side master-detail
```

## Best Practices

1. **Every Android Fragment is just a SwiftUI View** -- Do not try to create a Fragment-like abstraction layer. SwiftUI views are value types, composed declaratively, and do not need lifecycle management classes.
2. **Use `@Binding` for parent-child communication** -- This replaces `setFragmentResult` for adjacent views. For deeply nested communication, use `@Environment` or `@Observable` objects.
3. **Use `NavigationSplitView` for master-detail** -- It handles adaptive layout automatically, showing side-by-side on iPad and push navigation on iPhone.
4. **Use `.sheet` with `presentationDetents` for bottom sheets** -- `.presentationDetents([.medium, .large])` gives the iOS equivalent of a `BottomSheetDialogFragment` with draggable heights.
5. **Scope view models correctly** -- Use `@State` for view-private state, and inject shared state via `.environment()` from a common ancestor.
6. **Use `TabView(.page)` for ViewPager** -- Combined with a segmented `Picker` for tab headers, this replicates `ViewPager2` + `TabLayout`.
7. **Prefer composition over nesting** -- Instead of child fragments within parent fragments, compose SwiftUI views directly. There is no `childFragmentManager` needed.

## Common Pitfalls

- **Retained fragments have no equivalent** -- SwiftUI views are value types and cannot be retained. Use `@State` or `@Observable` objects to persist state across view re-renders.
- **Fragment transactions are not needed** -- SwiftUI handles view insertion/removal declaratively. Conditional rendering (`if`/`switch`) replaces `add`/`replace` transactions.
- **`onDisappear` is not `onDestroyView`** -- `onDisappear` fires when the view leaves the visible hierarchy but may still exist in memory (e.g., when navigating forward). It can fire multiple times.
- **`@StateObject` vs `@State` for observable objects** -- In iOS 17+, use `@State` with `@Observable` classes. In iOS 16 and earlier, use `@StateObject` with `ObservableObject`. Do not use `@ObservedObject` as a replacement for `by viewModels()` -- it does not own the object.
- **Sheet presentation is not navigation** -- `.sheet` creates a separate presentation context, not a navigation push. Do not nest sheets or use `.sheet` where `NavigationStack` push is appropriate.

## Migration Checklist

- [ ] Replace each `Fragment` class with a SwiftUI `View` struct
- [ ] Replace `FragmentManager.commit { replace() }` with `NavigationStack` navigation or conditional rendering
- [ ] Replace `ViewPager2` + `FragmentStateAdapter` with `TabView(.page)`
- [ ] Replace `BottomSheetDialogFragment` with `.sheet` + `.presentationDetents`
- [ ] Replace `DialogFragment` with `.alert` or `.confirmationDialog`
- [ ] Replace `setFragmentResult` / `setFragmentResultListener` with `@Binding` or closures
- [ ] Replace `by viewModels()` with `@State` on `@Observable` class
- [ ] Replace `by activityViewModels()` with `@Environment` injected from ancestor
- [ ] Replace fragment lifecycle callbacks with `onAppear` / `onDisappear` / `.task`
- [ ] Replace `childFragmentManager` nested fragments with composed SwiftUI views
- [ ] Replace master-detail fragment layouts with `NavigationSplitView`
- [ ] Replace `FragmentTransaction.setCustomAnimations` with SwiftUI `.transition()` and `.animation()`
- [ ] Verify all fragment argument passing uses typed properties or `Hashable` destinations
- [ ] Test sheet presentation with proper detent configuration
