---
name: generic-android-to-ios-composable
description: Migrates Android Composable function patterns (@Composable, remember, LaunchedEffect, SideEffect, slots, content lambdas) to iOS SwiftUI equivalents (View structs, @ViewBuilder, @State, .task, .onAppear)
type: generic
---

# generic-android-to-ios-composable

## Context

Beyond the framework-level layout and modifier system, Compose and SwiftUI each have distinct patterns for defining reusable components, managing side effects, handling lifecycle events, and composing UI through slot APIs. This skill focuses on the function-level and component-level patterns: how individual `@Composable` functions with `remember`, `LaunchedEffect`, `DisposableEffect`, slot parameters, and content lambdas translate to SwiftUI's `View` structs with `@State`, `.task`, `.onAppear`, `@ViewBuilder`, and related APIs.

Use this skill when migrating individual composable functions and their internal patterns to SwiftUI views. For framework-level layout and modifier migration, see `generic-android-to-ios-compose`. For state management details, see `generic-android-to-ios-state-management`.

## Concept Mapping

| Jetpack Compose | SwiftUI |
|----------------|---------|
| `@Composable fun MyComponent()` | `struct MyComponent: View { var body: some View }` |
| `@Composable` content lambda (slot) | `@ViewBuilder` closure parameter |
| `remember { mutableStateOf(x) }` | `@State private var x` |
| `remember(key) { computation }` | Computed property or manual caching |
| `rememberSaveable { }` | `@SceneStorage` or `@AppStorage` |
| `LaunchedEffect(key) { }` | `.task(id: key) { }` |
| `LaunchedEffect(Unit) { }` | `.task { }` (runs once on appear) |
| `DisposableEffect(key) { onDispose { } }` | `.onAppear { } / .onDisappear { }` or `.task { }` with cancellation |
| `SideEffect { }` | No direct equivalent; use `.onChange(of:)` or computed properties |
| `derivedStateOf { }` | Computed property on `@Observable` class |
| `produceState { }` | `@State` + `.task { }` |
| `snapshotFlow { }` | Combine publisher or AsyncSequence observation |
| `key(value) { }` | `.id(value)` modifier |
| `CompositionLocalProvider` | `.environment(\.key, value)` |
| `LocalLifecycleOwner` | No equivalent; SwiftUI manages lifecycle implicitly |
| `Lifecycle.repeatOnLifecycle` | `.task { }` (auto-cancels on disappear) |
| `rememberCoroutineScope()` | Not needed; `.task` provides structured concurrency |
| `@Stable` / `@Immutable` | `Equatable` / `Sendable` conformance |

## Android Best Practices (Kotlin, Jetpack Compose, 2024-2025)

- Use `remember` for expensive computations that should survive recomposition.
- Use `LaunchedEffect` for coroutine-based side effects tied to a key. When the key changes, the previous coroutine is cancelled and a new one launches.
- Use `DisposableEffect` when you need cleanup logic (e.g., removing listeners).
- Use `SideEffect` for non-suspending side effects that must run on every successful recomposition.
- Use slot APIs (content lambdas) for flexible, composable component design.
- Mark stable classes with `@Stable` or `@Immutable` to help the Compose compiler skip recomposition.
- Use `derivedStateOf` to avoid unnecessary recompositions when computing values from other state.

```kotlin
// Android: Composable with remember, LaunchedEffect, and slot API
@Composable
fun SearchScreen(
    viewModel: SearchViewModel = hiltViewModel(),
    bottomBar: @Composable () -> Unit = {}
) {
    val query = remember { mutableStateOf("") }
    val results by viewModel.results.collectAsStateWithLifecycle()

    // Debounced search: relaunches coroutine when query changes
    LaunchedEffect(query.value) {
        delay(300)
        viewModel.search(query.value)
    }

    Column {
        TextField(
            value = query.value,
            onValueChange = { query.value = it },
            placeholder = { Text("Search...") }
        )
        LazyColumn(modifier = Modifier.weight(1f)) {
            items(results, key = { it.id }) { result ->
                ResultRow(result)
            }
        }
        bottomBar()
    }
}
```

```kotlin
// Android: DisposableEffect for lifecycle-aware listener
@Composable
fun LocationTracker(onLocationUpdate: (Location) -> Unit) {
    val context = LocalContext.current

    DisposableEffect(Unit) {
        val locationManager = context.getSystemService<LocationManager>()
        val listener = LocationListener { location ->
            onLocationUpdate(location)
        }
        locationManager?.requestLocationUpdates(
            LocationManager.GPS_PROVIDER, 1000L, 10f, listener
        )
        onDispose {
            locationManager?.removeUpdates(listener)
        }
    }
}
```

```kotlin
// Android: Reusable composable with content slot
@Composable
fun Card(
    title: String,
    modifier: Modifier = Modifier,
    actions: @Composable RowScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit
) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(12.dp),
        tonalElevation = 2.dp
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = title, style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
            content()
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                actions()
            }
        }
    }
}
```

```kotlin
// Android: derivedStateOf to avoid unnecessary recomposition
@Composable
fun FilteredList(items: List<Item>) {
    var searchQuery by remember { mutableStateOf("") }

    val filteredItems by remember(items) {
        derivedStateOf {
            if (searchQuery.isBlank()) items
            else items.filter { it.name.contains(searchQuery, ignoreCase = true) }
        }
    }

    Column {
        TextField(value = searchQuery, onValueChange = { searchQuery = it })
        LazyColumn {
            items(filteredItems, key = { it.id }) { item ->
                ItemRow(item)
            }
        }
    }
}
```

## iOS Best Practices (Swift, SwiftUI, 2024-2025)

- Define each reusable component as a `View` struct.
- Use `@State` for view-private mutable state. It is the closest equivalent to `remember { mutableStateOf() }`.
- Use `.task { }` (iOS 15+) for async work that should run when the view appears and cancel when it disappears. Use `.task(id:)` to relaunch when a value changes (equivalent to `LaunchedEffect(key)`).
- Use `.onAppear` and `.onDisappear` for non-async lifecycle hooks.
- Use `@ViewBuilder` closures for slot-style APIs.
- Use `@Observable` (iOS 17+) or `ObservableObject` for shared state with derived/computed properties.
- Use `.onChange(of:)` to react to state changes (equivalent to `SideEffect` or `snapshotFlow`).

```swift
// iOS: SwiftUI equivalent of SearchScreen
struct SearchView: View {
    @State private var query = ""
    @State private var results: [SearchResult] = []
    let bottomBar: AnyView?

    init(bottomBar: some View = EmptyView()) {
        self.bottomBar = AnyView(bottomBar)
    }

    var body: some View {
        VStack {
            TextField("Search...", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            List(results) { result in
                ResultRow(result: result)
            }
            .listStyle(.plain)

            if let bottomBar {
                bottomBar
            }
        }
        // .task(id:) relaunches when query changes, cancelling the previous task
        .task(id: query) {
            do {
                try await Task.sleep(for: .milliseconds(300))
                results = await SearchService.search(query: query)
            } catch {
                // Task was cancelled due to query change -- expected behavior
            }
        }
    }
}
```

```swift
// iOS: Equivalent of DisposableEffect for CLLocationManager
struct LocationTracker: View {
    let onLocationUpdate: (CLLocation) -> Void
    @State private var locationDelegate = LocationDelegate()

    var body: some View {
        Color.clear
            .onAppear {
                locationDelegate.onUpdate = onLocationUpdate
                locationDelegate.startTracking()
            }
            .onDisappear {
                locationDelegate.stopTracking()
            }
    }
}

// Or using .task for automatic cancellation:
struct LocationTrackerAsync: View {
    let onLocationUpdate: (CLLocation) -> Void

    var body: some View {
        Color.clear
            .task {
                let stream = CLLocationUpdate.liveUpdates()
                for try await update in stream {
                    if let location = update.location {
                        onLocationUpdate(location)
                    }
                }
            }
    }
}
```

```swift
// iOS: Reusable View with @ViewBuilder slot API
struct CardView<Actions: View, Content: View>: View {
    let title: String
    @ViewBuilder let actions: () -> Actions
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        @ViewBuilder actions: @escaping () -> Actions = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.actions = actions
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            content()

            HStack {
                Spacer()
                actions()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// Usage:
// CardView(title: "Profile") {
//     Button("Edit") { }
// } content: {
//     Text("User details here")
// }
```

```swift
// iOS: Filtered list with computed property (equivalent to derivedStateOf)
struct FilteredListView: View {
    let items: [Item]
    @State private var searchQuery = ""

    private var filteredItems: [Item] {
        if searchQuery.isEmpty { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    var body: some View {
        VStack {
            TextField("Filter...", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            List(filteredItems) { item in
                ItemRow(item: item)
            }
            .listStyle(.plain)
        }
    }
}
```

## Side Effect Translation Guide

### LaunchedEffect(Unit) -- Run once on appear

```kotlin
// Android
LaunchedEffect(Unit) {
    viewModel.loadInitialData()
}
```

```swift
// iOS
.task {
    await viewModel.loadInitialData()
}
```

### LaunchedEffect(key) -- Re-run when key changes

```kotlin
// Android
LaunchedEffect(userId) {
    viewModel.loadUser(userId)
}
```

```swift
// iOS
.task(id: userId) {
    await viewModel.loadUser(userId)
}
```

### DisposableEffect -- Setup and teardown

```kotlin
// Android
DisposableEffect(key) {
    val observer = setupObserver()
    onDispose { observer.remove() }
}
```

```swift
// iOS - Option 1: onAppear/onDisappear
.onAppear { observer = setupObserver() }
.onDisappear { observer?.remove() }

// iOS - Option 2: .task with automatic cancellation
.task {
    let observer = setupObserver()
    defer { observer.remove() }
    // Keep alive until task is cancelled
    await withCheckedContinuation { _ in }
}
```

### SideEffect -- Run on every successful recomposition

```kotlin
// Android
SideEffect {
    analytics.setUserProperty("screen", screenName)
}
```

```swift
// iOS - No direct equivalent; use .onChange or call in body
var body: some View {
    content
        .onChange(of: screenName) { _, newValue in
            analytics.setUserProperty("screen", value: newValue)
        }
        .onAppear {
            analytics.setUserProperty("screen", value: screenName)
        }
}
```

### produceState -- Async state production

```kotlin
// Android
val user by produceState<User?>(initialValue = null, userId) {
    value = repository.getUser(userId)
}
```

```swift
// iOS
@State private var user: User?

var body: some View {
    content
        .task(id: userId) {
            user = await repository.getUser(userId)
        }
}
```

## Common Pitfalls and Gotchas

1. **`remember` is not `@State`** -- `remember` only survives recomposition. `@State` survives view body re-evaluation AND view identity changes within the same parent. `@State` is closer to `rememberSaveable` in behavior. Migrating `remember` to a plain local variable will lose state between re-evaluations.

2. **LaunchedEffect cancellation vs. .task cancellation** -- Both cancel automatically, but `LaunchedEffect` cancels when the composable leaves the composition, while `.task` cancels when the view disappears. This is usually equivalent, but edge cases around animation or transition can differ.

3. **Content lambda type erasure** -- Compose content lambdas are simply `@Composable () -> Unit`. SwiftUI requires generic type parameters for `@ViewBuilder` content (`<Content: View>`), which makes the type signatures more complex. Use `some View` return types and generic constraints.

4. **No `rememberCoroutineScope` equivalent** -- Compose uses `rememberCoroutineScope()` to launch coroutines from callbacks (e.g., button taps). In SwiftUI, use `Task { }` directly inside action closures. The task will not be automatically cancelled, so manage cancellation manually if needed.

5. **`key()` vs `.id()`** -- Compose's `key()` controls identity within a composition. SwiftUI's `.id()` modifier forces a view to be treated as a new view when the id changes, destroying and recreating all state. Use `.id()` carefully as it is more aggressive than `key()`.

6. **Slot API ergonomics** -- Compose slot APIs use trailing lambdas naturally. SwiftUI `@ViewBuilder` closures require generic type parameters and sometimes `@escaping`, making the API surface more verbose. Consider using `AnyView` type erasure sparingly for simplicity, or use `some View` with generics for performance.

7. **No `SideEffect` equivalent** -- SwiftUI has no hook that runs on every successful body evaluation. Use `.onChange(of:)` to react to specific state changes, or use computed properties to derive values without side effects.

8. **DisposableEffect key changes** -- When a `DisposableEffect` key changes, it calls `onDispose` then re-runs setup. SwiftUI's `.task(id:)` similarly cancels and relaunches, but `.onAppear`/`.onDisappear` only fire on actual appear/disappear events, not on state changes. Choose `.task(id:)` for key-based lifecycle.

9. **`@Composable` function vs. View struct lifecycle** -- A `@Composable` function has no persistent identity beyond its position in the call tree. A SwiftUI `View` struct is a value type recreated on every parent body evaluation, but SwiftUI preserves its `@State` based on structural identity. This distinction matters for understanding when state is preserved vs. reset.

10. **Conditional composables vs. conditional views** -- In Compose, wrapping a composable in `if` creates/destroys it on toggle, resetting `remember` state. In SwiftUI, `if/else` branches create different structural identities, resetting `@State`. Use `.opacity(condition ? 1 : 0)` to hide without destroying.

## Migration Checklist

1. **Inventory all @Composable functions** -- List every `@Composable` function in the feature. Categorize as screen-level, component-level, or utility.
2. **Convert to View structs** -- Create a `View` struct for each composable. Move parameters to struct properties. Move the composable body to the `body` computed property.
3. **Migrate `remember { mutableStateOf() }`** -- Replace with `@State private var`. Ensure the initial value is set in the property declaration or initializer.
4. **Migrate `LaunchedEffect`** -- Replace `LaunchedEffect(Unit)` with `.task { }`. Replace `LaunchedEffect(key)` with `.task(id: key) { }`.
5. **Migrate `DisposableEffect`** -- Replace with `.onAppear`/`.onDisappear` pairs, or `.task` with `defer` cleanup.
6. **Migrate `derivedStateOf`** -- Replace with computed properties on the view or on an `@Observable` model.
7. **Migrate `produceState`** -- Replace with `@State` + `.task(id:)` that assigns the state.
8. **Migrate slot APIs** -- Replace `@Composable () -> Unit` parameters with `@ViewBuilder` generic parameters. Add `Content: View` generic constraints.
9. **Migrate `rememberCoroutineScope` usage** -- Replace with `Task { }` inside event handlers. Add cancellation logic if needed.
10. **Migrate `CompositionLocal`** -- Replace with `@Environment` and custom `EnvironmentKey` definitions.
11. **Test state preservation** -- Verify that `@State` is preserved correctly during navigation and view updates. Check that conditional views preserve/reset state as expected.
12. **Test async cancellation** -- Verify that `.task` blocks are properly cancelled on view disappearance. Check that debounce patterns work with `.task(id:)`.
