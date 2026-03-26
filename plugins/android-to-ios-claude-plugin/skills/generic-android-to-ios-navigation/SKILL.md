---
name: generic-android-to-ios-navigation
description: Migrate Android Jetpack Navigation Component and Navigation Compose patterns to iOS NavigationStack, NavigationPath, and programmatic navigation (iOS 16+)
type: generic
---

# generic-android-to-ios-navigation

## Context

Android uses Jetpack Navigation Component (XML-based NavGraph or Navigation Compose with NavHost/NavController) to manage in-app navigation, argument passing, and back stack behavior. iOS 16+ introduced NavigationStack with NavigationPath for equivalent value-type-driven, programmatic navigation. This skill covers the full migration of navigation patterns from Android to iOS, including nested graphs, tab-based navigation, deep link routing, argument passing, and back stack management.

## Concept Mapping

| Android | iOS (SwiftUI, iOS 16+) |
|---|---|
| `NavHost` | `NavigationStack` |
| `NavController` | `NavigationPath` / `@Environment(\.dismiss)` |
| `NavGraph` (nested) | Nested `NavigationStack` or custom router |
| `composable("route")` destination | `.navigationDestination(for:)` |
| `NavBackStackEntry` | NavigationPath internal stack |
| `navigate("route")` | `path.append(value)` |
| `popBackStack()` | `path.removeLast()` |
| `popUpTo` / `inclusive` | `path.removeLast(n)` or `path = NavigationPath()` |
| Safe Args / type-safe args | `Hashable` enum or struct as navigation value |
| `BottomNavigation` + `NavHost` | `TabView` + per-tab `NavigationStack` |
| `NavDeepLink` | `.onOpenURL` + router |
| `savedStateHandle` in ViewModel | `@State` / `@SceneStorage` persistence |

## Code Patterns

### Basic Navigation Setup

**Android (Navigation Compose):**
```kotlin
// Define routes
sealed class Screen(val route: String) {
    object Home : Screen("home")
    object Detail : Screen("detail/{itemId}") {
        fun createRoute(itemId: String) = "detail/$itemId"
    }
    object Settings : Screen("settings")
}

@Composable
fun AppNavigation() {
    val navController = rememberNavController()

    NavHost(navController = navController, startDestination = Screen.Home.route) {
        composable(Screen.Home.route) {
            HomeScreen(
                onItemClick = { itemId ->
                    navController.navigate(Screen.Detail.createRoute(itemId))
                }
            )
        }
        composable(
            route = Screen.Detail.route,
            arguments = listOf(navArgument("itemId") { type = NavType.StringType })
        ) { backStackEntry ->
            val itemId = backStackEntry.arguments?.getString("itemId") ?: ""
            DetailScreen(itemId = itemId)
        }
        composable(Screen.Settings.route) {
            SettingsScreen()
        }
    }
}
```

**iOS (SwiftUI, iOS 16+):**
```swift
// Define navigation destinations as Hashable types
enum AppDestination: Hashable {
    case detail(itemId: String)
    case settings
}

struct AppNavigation: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(onItemTap: { itemId in
                path.append(AppDestination.detail(itemId: itemId))
            })
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .detail(let itemId):
                    DetailScreen(itemId: itemId)
                case .settings:
                    SettingsScreen()
                }
            }
        }
    }
}
```

### Type-Safe Arguments

**Android (Type-Safe Args with Navigation Compose 2.8+):**
```kotlin
@Serializable
data class DetailRoute(val itemId: String, val category: String)

NavHost(navController = navController, startDestination = HomeRoute) {
    composable<HomeRoute> {
        HomeScreen(onNavigate = { id, cat ->
            navController.navigate(DetailRoute(itemId = id, category = cat))
        })
    }
    composable<DetailRoute> { backStackEntry ->
        val args = backStackEntry.toRoute<DetailRoute>()
        DetailScreen(itemId = args.itemId, category = args.category)
    }
}
```

**iOS:**
```swift
// Navigation values are inherently type-safe via Hashable conformance
struct DetailDestination: Hashable {
    let itemId: String
    let category: String
}

NavigationStack(path: $path) {
    HomeScreen(onNavigate: { id, category in
        path.append(DetailDestination(itemId: id, category: category))
    })
    .navigationDestination(for: DetailDestination.self) { dest in
        DetailScreen(itemId: dest.itemId, category: dest.category)
    }
}
```

### Tab-Based Navigation with Independent Stacks

**Android:**
```kotlin
@Composable
fun MainScreen() {
    val navController = rememberNavController()
    Scaffold(
        bottomBar = {
            NavigationBar {
                val currentDestination = navController
                    .currentBackStackEntryAsState().value?.destination
                bottomNavItems.forEach { item ->
                    NavigationBarItem(
                        selected = currentDestination?.hierarchy
                            ?.any { it.route == item.route } == true,
                        onClick = {
                            navController.navigate(item.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(item.icon, contentDescription = item.label) },
                        label = { Text(item.label) }
                    )
                }
            }
        }
    ) { padding ->
        NavHost(navController, startDestination = "home", Modifier.padding(padding)) {
            composable("home") { HomeScreen(navController) }
            composable("search") { SearchScreen(navController) }
            composable("profile") { ProfileScreen(navController) }
        }
    }
}
```

**iOS:**
```swift
enum Tab: String, CaseIterable {
    case home, search, profile
}

struct MainScreen: View {
    @State private var selectedTab: Tab = .home
    // Each tab maintains its own navigation stack
    @State private var homePath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var profilePath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                HomeScreen(path: $homePath)
                    .navigationDestination(for: HomeDestination.self) { dest in
                        // handle home sub-navigation
                    }
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(Tab.home)

            NavigationStack(path: $searchPath) {
                SearchScreen(path: $searchPath)
                    .navigationDestination(for: SearchDestination.self) { dest in
                        // handle search sub-navigation
                    }
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(Tab.search)

            NavigationStack(path: $profilePath) {
                ProfileScreen(path: $profilePath)
                    .navigationDestination(for: ProfileDestination.self) { dest in
                        // handle profile sub-navigation
                    }
            }
            .tabItem { Label("Profile", systemImage: "person") }
            .tag(Tab.profile)
        }
    }
}
```

### Nested Navigation Graphs

**Android:**
```kotlin
NavHost(navController, startDestination = "main") {
    navigation(startDestination = "login", route = "auth") {
        composable("login") { LoginScreen(navController) }
        composable("register") { RegisterScreen(navController) }
        composable("forgot_password") { ForgotPasswordScreen(navController) }
    }
    navigation(startDestination = "home", route = "main") {
        composable("home") { HomeScreen(navController) }
        composable("detail/{id}") { DetailScreen(navController) }
    }
}
```

**iOS:**
```swift
// Use a Router/Coordinator to group related flows
enum AuthDestination: Hashable {
    case login
    case register
    case forgotPassword
}

enum MainDestination: Hashable {
    case detail(id: String)
}

struct RootView: View {
    @State private var isAuthenticated = false

    var body: some View {
        if isAuthenticated {
            MainFlow(onLogout: { isAuthenticated = false })
        } else {
            AuthFlow(onAuthenticated: { isAuthenticated = true })
        }
    }
}

struct AuthFlow: View {
    @State private var path = NavigationPath()
    var onAuthenticated: () -> Void

    var body: some View {
        NavigationStack(path: $path) {
            LoginScreen(
                onRegisterTap: { path.append(AuthDestination.register) },
                onForgotTap: { path.append(AuthDestination.forgotPassword) },
                onLoginSuccess: { onAuthenticated() }
            )
            .navigationDestination(for: AuthDestination.self) { dest in
                switch dest {
                case .login: LoginScreen(/* ... */)
                case .register: RegisterScreen()
                case .forgotPassword: ForgotPasswordScreen()
                }
            }
        }
    }
}
```

### Programmatic Back Stack Management

**Android:**
```kotlin
// Pop to a specific destination
navController.popBackStack("home", inclusive = false)

// Pop and navigate (replace current)
navController.navigate("newScreen") {
    popUpTo("home") { inclusive = true }
}

// Clear entire back stack
navController.navigate("home") {
    popUpTo(navController.graph.id) { inclusive = true }
}

// Single top (avoid duplicate)
navController.navigate("screen") {
    launchSingleTop = true
}
```

**iOS:**
```swift
// Pop to root
path = NavigationPath()

// Pop one level
path.removeLast()

// Pop N levels
path.removeLast(3)

// Pop to a specific point (requires tracking count)
let targetDepth = 2
if path.count > targetDepth {
    path.removeLast(path.count - targetDepth)
}

// Replace current (pop then push)
if !path.isEmpty {
    path.removeLast()
}
path.append(newDestination)
```

### Centralized Router Pattern (Recommended for Large Apps)

**iOS:**
```swift
@Observable
final class AppRouter {
    var path = NavigationPath()
    var selectedTab: Tab = .home

    // Per-tab paths for independent stacks
    var tabPaths: [Tab: NavigationPath] = [
        .home: NavigationPath(),
        .search: NavigationPath(),
        .profile: NavigationPath()
    ]

    func navigate(to destination: any Hashable) {
        tabPaths[selectedTab]?.append(destination)
    }

    func popToRoot() {
        tabPaths[selectedTab] = NavigationPath()
    }

    func pop() {
        guard let count = tabPaths[selectedTab]?.count, count > 0 else { return }
        tabPaths[selectedTab]?.removeLast()
    }

    func switchTab(_ tab: Tab, resetStack: Bool = false) {
        selectedTab = tab
        if resetStack {
            tabPaths[tab] = NavigationPath()
        }
    }
}

// Inject via environment
struct ContentView: View {
    @State private var router = AppRouter()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            // tabs using router.tabPaths[.home] etc.
        }
        .environment(router)
    }
}
```

### NavigationLink (Declarative Navigation)

**iOS:**
```swift
// Value-based NavigationLink (preferred, iOS 16+)
NavigationLink(value: AppDestination.detail(itemId: "123")) {
    Text("Go to Detail")
}

// This works automatically with .navigationDestination(for:)
// No binding or isActive needed — the value is appended to the path
```

## Deep Linking Integration (Navigation Level)

**Android:**
```kotlin
composable(
    route = "detail/{itemId}",
    deepLinks = listOf(
        navDeepLink { uriPattern = "https://example.com/items/{itemId}" }
    )
) { backStackEntry ->
    DetailScreen(backStackEntry.arguments?.getString("itemId") ?: "")
}
```

**iOS:**
```swift
// Handle at the NavigationStack level via .onOpenURL
NavigationStack(path: $path) {
    HomeScreen()
        .navigationDestination(for: AppDestination.self) { /* ... */ }
}
.onOpenURL { url in
    if let itemId = parseItemId(from: url) {
        path.append(AppDestination.detail(itemId: itemId))
    }
}
```

## Best Practices

1. **Use `NavigationPath` over `@State` arrays** -- `NavigationPath` is type-erased and supports heterogeneous destination types in a single stack.
2. **One `NavigationStack` per tab** -- Never nest `NavigationStack` inside another `NavigationStack`. Each tab in a `TabView` should own exactly one.
3. **Prefer value-based `NavigationLink`** -- Use `NavigationLink(value:)` with `.navigationDestination(for:)` instead of the older `NavigationLink(destination:)` which eagerly evaluates the destination view.
4. **Centralize routing** -- For apps with more than a few screens, use a router/coordinator `@Observable` class injected via `.environment()`.
5. **Avoid stringly-typed routes** -- Android's string-based routes are error-prone. iOS's `Hashable` enum/struct approach is inherently type-safe; leverage it fully.
6. **State restoration** -- Use `Codable` conformance on navigation values and persist `NavigationPath` via `@SceneStorage` or manual encoding for state restoration.
7. **Modal presentation is separate** -- Sheets and full-screen covers are not part of `NavigationStack`. Use `.sheet`, `.fullScreenCover`, or `.alert` independently.

## Common Pitfalls

- **Nested NavigationStack** -- Placing a `NavigationStack` inside another `NavigationStack` causes double navigation bars and broken back behavior. Always ensure only one stack per navigation hierarchy.
- **Using `NavigationView` instead of `NavigationStack`** -- `NavigationView` is deprecated in iOS 16. Always use `NavigationStack`.
- **Forgetting `Hashable` conformance** -- All navigation destination types must conform to `Hashable`. If using classes, this requires manual implementation.
- **NavigationPath is reference-type-like but value-type** -- Mutations to `NavigationPath` must go through the `@State` binding. Copying it and mutating the copy will not update the UI.
- **Tab switching resets stacks** -- By default, SwiftUI `TabView` preserves tab state. But if you recreate `NavigationStack` on tab switch (e.g., via conditional rendering), the stack resets. Use persistent `@State` paths per tab.

## Migration Checklist

- [ ] Replace `NavHost` with `NavigationStack(path:)`
- [ ] Replace string routes with `Hashable` enum/struct destination types
- [ ] Replace `navController.navigate()` with `path.append(destination)`
- [ ] Replace `popBackStack()` with `path.removeLast()`
- [ ] Replace `popUpTo` root with `path = NavigationPath()`
- [ ] Replace `BottomNavigation` + single `NavHost` with `TabView` + per-tab `NavigationStack`
- [ ] Replace nested `navigation()` graphs with separate flow views or coordinator pattern
- [ ] Replace `NavDeepLink` with `.onOpenURL` routing into `NavigationPath`
- [ ] Replace Safe Args with `Hashable` structs carrying typed properties
- [ ] Verify no nested `NavigationStack` exists in the view hierarchy
- [ ] Implement state restoration for `NavigationPath` if needed
- [ ] Test deep link handling opens correct screen and builds proper back stack
