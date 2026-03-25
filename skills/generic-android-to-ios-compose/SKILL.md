---
name: generic-android-to-ios-compose
description: Migrates Android Jetpack Compose UI framework patterns (Modifier chains, recomposition, theming, layouts) to iOS SwiftUI equivalents (View protocol, ViewModifier, view body re-evaluation, environment)
type: generic
---

# generic-android-to-ios-compose

## Context

Jetpack Compose and SwiftUI are the modern declarative UI frameworks for Android and iOS respectively. Both share the same philosophical foundation -- UI is a function of state -- but differ significantly in their APIs, composition models, and runtime behavior. This skill covers the framework-level migration: how Compose's `@Composable` tree, `Modifier` system, layout composables, and recomposition model translate to SwiftUI's `View` protocol, modifier chains, layout containers, and view body re-evaluation.

Use this skill when migrating Compose-based screens and components to SwiftUI at the framework level. For individual composable function patterns (remember, LaunchedEffect, slots), see `generic-android-to-ios-composable`. For state management specifically, see `generic-android-to-ios-state-management`.

## Concept Mapping

| Jetpack Compose | SwiftUI |
|----------------|---------|
| `@Composable` function | `View` struct (with `body` property) |
| `Modifier` chain | SwiftUI modifier chain |
| `Modifier.padding()` | `.padding()` |
| `Modifier.fillMaxWidth()` | `.frame(maxWidth: .infinity)` |
| `Modifier.fillMaxSize()` | `.frame(maxWidth: .infinity, maxHeight: .infinity)` |
| `Modifier.size(dp)` | `.frame(width:height:)` |
| `Modifier.background()` | `.background()` |
| `Modifier.clickable {}` | `.onTapGesture {}` or `Button` |
| `Modifier.clip(shape)` | `.clipShape(shape)` |
| `Modifier.border()` | `.overlay(RoundedRectangle().stroke())` or `.border()` |
| `Column` | `VStack` |
| `Row` | `HStack` |
| `Box` | `ZStack` |
| `LazyColumn` | `List` or `LazyVStack` inside `ScrollView` |
| `LazyRow` | `LazyHStack` inside `ScrollView` |
| `LazyVerticalGrid` | `LazyVGrid` |
| `Scaffold` | `NavigationStack` + `.toolbar` + content |
| `TopAppBar` | `.navigationTitle()` + `.toolbar` |
| `BottomNavigation` / `NavigationBar` | `TabView` |
| `FloatingActionButton` | `.overlay` positioned button or `.toolbar` |
| `Spacer()` | `Spacer()` |
| `Divider()` | `Divider()` |
| `Text()` | `Text()` |
| `Image()` | `Image()` |
| `TextField()` | `TextField()` |
| `Button()` | `Button()` |
| `Switch()` | `Toggle()` |
| `Checkbox()` | `Toggle()` with custom style |
| `AlertDialog()` | `.alert()` modifier |
| `ModalBottomSheet()` | `.sheet()` modifier |
| `Snackbar` | No built-in equivalent; use custom overlay or third-party |
| `NavHost` + `composable()` | `NavigationStack` + `NavigationLink` + `.navigationDestination` |
| `CompositionLocal` | `@Environment` / `EnvironmentKey` |
| `LocalContext.current` | Not needed (no Context concept in iOS) |
| `Recomposition` | View body re-evaluation |
| `remember {}` | No direct equivalent; use `@State` for view-local state |
| `key()` | Explicit `id()` modifier |

## Android Best Practices (Kotlin, Jetpack Compose, 2024-2025)

- Structure screens as a root `@Composable` that receives state and callbacks (unidirectional data flow).
- Use `Modifier` parameter as the first optional parameter for reusable composables.
- Order modifiers intentionally -- `padding` before `background` applies padding outside the background; after applies it inside.
- Use `LazyColumn`/`LazyRow` for lists. Never use `Column` with `forEach` for large datasets.
- Use `Arrangement` and `Alignment` for spacing and cross-axis alignment.
- Extract complex modifier chains into extension functions.
- Use `CompositionLocalProvider` sparingly for truly cross-cutting concerns (theming, locale).

```kotlin
// Android: Compose screen with Modifier chain and layout
@Composable
fun UserProfileScreen(
    user: User,
    onEditClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        AsyncImage(
            model = user.avatarUrl,
            contentDescription = "Avatar",
            modifier = Modifier
                .size(100.dp)
                .clip(CircleShape)
        )
        Text(
            text = user.name,
            style = MaterialTheme.typography.headlineMedium
        )
        Text(
            text = user.email,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Button(onClick = onEditClick) {
            Text("Edit Profile")
        }
    }
}
```

```kotlin
// Android: LazyColumn with items
@Composable
fun UserList(
    users: List<User>,
    onUserClick: (User) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(
            items = users,
            key = { it.id }
        ) { user ->
            UserRow(user = user, onClick = { onUserClick(user) })
        }
    }
}
```

## iOS Best Practices (Swift, SwiftUI, 2024-2025)

- Define each screen as a `View` struct with an explicit `body` computed property.
- Accept data via initializer parameters and callbacks via closures for unidirectional data flow.
- Use `List` for standard scrolling lists with built-in cell styling. Use `LazyVStack` inside `ScrollView` for custom layouts.
- Prefer `NavigationStack` (iOS 16+) over the deprecated `NavigationView`.
- Use `.task {}` instead of `.onAppear` for async work -- it automatically cancels on disappear.
- Modifier order matters in SwiftUI too -- `.padding()` before `.background()` gives different results than the reverse.
- Use `ViewModifier` protocol for reusable modifier bundles.
- Use `@ViewBuilder` to accept composable child content, analogous to Compose slot APIs.

```swift
// iOS: SwiftUI equivalent of UserProfileScreen
struct UserProfileView: View {
    let user: User
    let onEditTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            AsyncImage(url: URL(string: user.avatarUrl)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())

            Text(user.name)
                .font(.headline)

            Text(user.email)
                .font(.body)
                .foregroundStyle(.secondary)

            Button("Edit Profile", action: onEditTap)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}
```

```swift
// iOS: List equivalent of LazyColumn
struct UserListView: View {
    let users: [User]
    let onUserTap: (User) -> Void

    var body: some View {
        List(users) { user in
            UserRow(user: user)
                .onTapGesture { onUserTap(user) }
        }
        .listStyle(.plain)
    }
}

// Alternative with LazyVStack for custom styling
struct UserListCustomView: View {
    let users: [User]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(users) { user in
                    UserRow(user: user)
                }
            }
            .padding(16)
        }
    }
}
```

## Modifier Chain Translation

Compose modifier ordering and SwiftUI modifier ordering follow similar logical rules but differ in syntax.

```kotlin
// Android: Modifier chain
Modifier
    .padding(8.dp)           // outer padding
    .background(Color.Blue)  // background inside outer padding
    .padding(16.dp)          // inner padding
    .clip(RoundedCornerShape(8.dp))
```

```swift
// iOS: Equivalent modifier chain
SomeView()
    .padding(8)              // outer padding
    .background(Color.blue)  // background inside outer padding
    .padding(16)             // inner padding
    .clipShape(RoundedRectangle(cornerRadius: 8))
```

## Custom Modifier / ViewModifier

```kotlin
// Android: Custom Modifier extension
fun Modifier.cardStyle(): Modifier = this
    .fillMaxWidth()
    .clip(RoundedCornerShape(12.dp))
    .background(MaterialTheme.colorScheme.surface)
    .padding(16.dp)
```

```swift
// iOS: Custom ViewModifier
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
```

## Navigation

```kotlin
// Android: Navigation with NavHost
@Composable
fun AppNavigation() {
    val navController = rememberNavController()
    NavHost(navController = navController, startDestination = "home") {
        composable("home") {
            HomeScreen(onNavigateToProfile = { userId ->
                navController.navigate("profile/$userId")
            })
        }
        composable("profile/{userId}") { backStackEntry ->
            val userId = backStackEntry.arguments?.getString("userId") ?: return@composable
            ProfileScreen(userId = userId)
        }
    }
}
```

```swift
// iOS: Navigation with NavigationStack (iOS 16+)
struct AppNavigation: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(onNavigateToProfile: { userId in
                path.append(userId)
            })
            .navigationDestination(for: String.self) { userId in
                ProfileView(userId: userId)
            }
        }
    }
}
```

## Common Pitfalls and Gotchas

1. **Recomposition vs. body re-evaluation** -- Compose can recompose individual composables independently thanks to the Compose compiler's slot table. SwiftUI re-evaluates `body` properties but uses its own diffing to minimize actual view updates. Do not assume the same granularity of updates.

2. **Modifier.fillMaxSize() is not `.frame(maxWidth: .infinity, maxHeight: .infinity)`** -- They behave similarly but not identically. In SwiftUI, the frame modifier proposes a size to its child but does not force it. Some views ignore proposed sizes.

3. **LazyColumn keys vs. List identity** -- Compose uses `key = { }` in `items()`. SwiftUI uses `Identifiable` conformance or explicit `id:` parameter in `ForEach`. Always provide stable identifiers for both.

4. **Compose `remember` is not SwiftUI `@State`** -- `remember` survives recomposition but not configuration changes by default. `@State` survives view body re-evaluation and is tied to the view's identity in the view tree. Use `rememberSaveable` for the closest equivalent to `@State` persistence.

5. **Scaffold vs. NavigationStack** -- Compose's `Scaffold` provides a slot-based structure (top bar, bottom bar, FAB, content). SwiftUI has no single `Scaffold` equivalent. Use `NavigationStack` + `.toolbar` + `TabView` to achieve the same layout.

6. **CompositionLocal vs. @Environment** -- Both inject values down the tree. But SwiftUI's environment is more pervasive and is the standard way to pass system values (color scheme, size class, locale). Compose uses `CompositionLocal` more sparingly.

7. **Preview differences** -- `@Preview` in Compose and `#Preview` in SwiftUI serve the same purpose but have different capabilities. SwiftUI previews can be more finicky with complex dependency chains.

8. **No `Modifier` parameter in SwiftUI** -- Compose best practice passes a `Modifier` parameter to allow external customization. SwiftUI views are customized by chaining modifiers at the call site. Do not try to replicate the `modifier: Modifier` pattern.

9. **Animation defaults** -- Compose requires explicit `animateContentSize()` or `AnimatedVisibility`. SwiftUI implicitly animates many changes when wrapped in `withAnimation {}` or using `.animation()` modifier. Be cautious of unintended animations.

10. **Text styling** -- Compose uses `TextStyle` and `MaterialTheme.typography`. SwiftUI uses `.font()` with `Font.TextStyle` presets (`.headline`, `.body`, etc.) that automatically support Dynamic Type.

## Migration Checklist

1. **Map the screen hierarchy** -- Identify each `@Composable` function in the Android feature. Determine which become standalone SwiftUI `View` structs and which become extracted sub-views.
2. **Translate the root layout** -- Convert `Column` to `VStack`, `Row` to `HStack`, `Box` to `ZStack`. Preserve `Arrangement` spacing as `VStack(spacing:)` / `HStack(spacing:)`.
3. **Convert Modifier chains** -- Translate each `Modifier` call to its SwiftUI equivalent. Pay attention to ordering. Remove `Modifier` parameters from function signatures.
4. **Port lazy lists** -- Replace `LazyColumn` with `List` or `ScrollView { LazyVStack }`. Replace `items()` with `ForEach`. Ensure models conform to `Identifiable`.
5. **Migrate navigation** -- Replace `NavHost` + `composable()` routes with `NavigationStack` + `.navigationDestination`. Replace `navController.navigate()` with path-based or value-based navigation.
6. **Convert Scaffold** -- Replace `Scaffold` with the combination of `NavigationStack`, `.toolbar`, `.navigationTitle`, and `TabView` as needed.
7. **Port custom modifiers** -- Convert `Modifier` extension functions to `ViewModifier` structs with `.modifier()` call or `View` extension methods.
8. **Handle CompositionLocals** -- Replace `CompositionLocalProvider` with SwiftUI `.environment()` modifier and `@Environment` property wrapper. Define custom `EnvironmentKey` for custom values.
9. **Add previews** -- Convert `@Preview` composables to `#Preview` macros. Provide mock data for each preview variant.
10. **Verify modifier ordering** -- Manually verify that padding, background, border, and clip modifiers produce the same visual output as the Android version.
11. **Test scroll performance** -- Profile `List` and `LazyVStack` performance with large datasets. SwiftUI's lazy loading behavior may differ from Compose's.
12. **Verify accessibility** -- Ensure `.accessibilityLabel()`, `.accessibilityHint()`, and `.accessibilityValue()` match the Compose `semantics {}` block content.
