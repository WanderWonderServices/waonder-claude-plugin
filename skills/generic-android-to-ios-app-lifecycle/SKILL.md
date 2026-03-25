---
name: generic-android-to-ios-app-lifecycle
description: Guides migration of Android Application class lifecycle (custom Application subclass, onCreate initialization, Startup library) to iOS equivalents (@main App struct, UIApplicationDelegate, SceneDelegate, app initialization order), covering dependency setup, multi-window support, and scene-based lifecycle
type: generic
---

# generic-android-to-ios-app-lifecycle

## Context

Android uses a custom `Application` subclass as the single entry point for app-wide initialization, with `onCreate` executing before any Activity is created. The AndroidX Startup library provides lazy component initialization. iOS has evolved through multiple app lifecycle models: the traditional `UIApplicationDelegate`, the scene-based `UISceneDelegate` (iOS 13+), and the SwiftUI `@main App` struct (iOS 14+). This skill maps Android's app-level initialization patterns to their iOS equivalents, covering initialization order, dependency injection setup, multi-window support, and scene-based lifecycle management.

## Initialization Order Comparison

```
Android                                    iOS (SwiftUI App)
=======                                    =================
Application.attachBaseContext()            (process launch)
ContentProvider.onCreate()                 (static initializers — avoid)
Application.onCreate()            ->       @main App.init()
  - DI container setup                       - DI container setup
  - Logging init                             - Logging init
  - Crash reporting                          - Crash reporting
  - Analytics                                - Analytics
Activity.onCreate()               ->       WindowGroup { RootView() }
                                           Scene body evaluation

Android (Startup Library)                  iOS (UIKit App)
=========================                  ===============
InitializationProvider.onCreate()          application(_:willFinishLaunchingWithOptions:)
Initializer<T>.create(context)             application(_:didFinishLaunchingWithOptions:)
  (dependency graph resolved)              scene(_:willConnectTo:options:)
```

## Android Best Practices (Source Patterns)

### Custom Application Class

```kotlin
class WaonderApplication : Application() {

    lateinit var appContainer: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()

        // Initialize crash reporting first (catches init crashes)
        CrashReporter.initialize(this)

        // Setup DI container
        appContainer = AppContainer(applicationContext)

        // Initialize logging
        if (BuildConfig.DEBUG) {
            Timber.plant(Timber.DebugTree())
        } else {
            Timber.plant(CrashReportingTree())
        }

        // Setup analytics
        Analytics.initialize(this, BuildConfig.ANALYTICS_KEY)

        // Configure image loading
        Coil.setImageLoader {
            ImageLoader.Builder(this)
                .crossfade(true)
                .diskCachePolicy(CachePolicy.ENABLED)
                .build()
        }

        // Register activity lifecycle callbacks
        registerActivityLifecycleCallbacks(AppLifecycleTracker())
    }
}
```

### Hilt Application Setup

```kotlin
@HiltAndroidApp
class WaonderApplication : Application() {

    @Inject lateinit var crashReporter: CrashReporter
    @Inject lateinit var analytics: Analytics
    @Inject lateinit var workerFactory: HiltWorkerFactory

    override fun onCreate() {
        super.onCreate()
        crashReporter.initialize()
        analytics.initialize()
    }

    override fun getWorkManagerConfiguration(): Configuration {
        return Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()
    }
}
```

### AndroidX Startup Library

```kotlin
// Lazy initialization with dependency graph
class AnalyticsInitializer : Initializer<Analytics> {
    override fun create(context: Context): Analytics {
        val analytics = Analytics(context, BuildConfig.ANALYTICS_KEY)
        analytics.initialize()
        return analytics
    }

    override fun dependencies(): List<Class<out Initializer<*>>> {
        return listOf(CrashReporterInitializer::class.java) // Must init first
    }
}

class CrashReporterInitializer : Initializer<CrashReporter> {
    override fun create(context: Context): CrashReporter {
        return CrashReporter(context).also { it.initialize() }
    }

    override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
}

// AndroidManifest.xml
// <provider android:name="androidx.startup.InitializationProvider" ...>
//     <meta-data android:name=".AnalyticsInitializer" android:value="androidx.startup" />
// </provider>
```

### Key Android Patterns to Recognize

- `Application.onCreate()` — single app-wide initialization entry point
- `@HiltAndroidApp` — DI container generated at compile time
- `Initializer<T>` — lazy initialization with dependency ordering
- `registerActivityLifecycleCallbacks` — global activity monitoring
- `applicationContext` — long-lived context for singletons
- `ContentProvider.onCreate()` — runs before Application.onCreate (library initialization hack)

## iOS Best Practices (Target Patterns)

### SwiftUI @main App Struct (Preferred)

```swift
import SwiftUI

@main
struct WaonderApp: App {
    // DI container initialized at app launch
    private let container: AppContainer

    // UIApplicationDelegate bridge for push notifications, deep links
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Equivalent to Application.onCreate()
        // Order matters — crash reporting first
        CrashReporter.shared.initialize()

        // Setup logging
        #if DEBUG
        Logger.configure(level: .debug)
        #else
        Logger.configure(level: .error)
        #endif

        // Initialize DI container
        container = AppContainer()

        // Configure global appearance
        configureAppearance()
    }

    var body: some Scene {
        // WindowGroup is the entry point for UI — equivalent to Activity launch
        WindowGroup {
            RootView()
                .environment(container.authService)
                .environment(container.analyticsService)
                .environment(container.networkMonitor)
        }
    }

    private func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = navAppearance
    }
}
```

### AppDelegate Bridge (for UIKit Integrations)

```swift
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {

    // Equivalent to Application.onCreate() for UIKit-dependent setup
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Push notification registration
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()

        // Firebase, third-party SDK init that requires UIApplication
        FirebaseApp.configure()

        return true
    }

    // Push token registration
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        PushTokenService.shared.update(token: token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Logger.error("Push registration failed: \(error)")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .badge, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        DeepLinkHandler.shared.handle(response.notification)
    }
}
```

### DI Container Setup

```swift
// Equivalent to Hilt AppContainer / Application-scoped dependencies
@Observable
final class AppContainer {
    let authService: AuthService
    let analyticsService: AnalyticsService
    let networkMonitor: NetworkMonitor
    let imageCache: ImageCache

    init() {
        // Initialization order mirrors Android dependency graph
        let networkClient = NetworkClient()
        self.networkMonitor = NetworkMonitor()
        self.authService = AuthService(networkClient: networkClient)
        self.analyticsService = AnalyticsService(apiKey: Config.analyticsKey)
        self.imageCache = ImageCache(maxSize: 100_000_000) // 100MB
    }
}

// Inject via SwiftUI Environment — equivalent to @Inject
struct ProfileView: View {
    @Environment(AuthService.self) private var authService

    var body: some View {
        // Use authService
    }
}
```

### Multi-Window / Scene Support

```swift
@main
struct WaonderApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        // Primary window — equivalent to launcher Activity
        WindowGroup {
            ContentView()
        }

        // Secondary window type — equivalent to separate Activity with different task affinity
        WindowGroup("Settings", id: "settings", for: UUID.self) { $id in
            SettingsView()
        }

        #if os(macOS)
        Settings {
            PreferencesView()
        }
        #endif
    }
}

// Scene-based lifecycle — equivalent to Activity-level lifecycle across multiple windows
// Each WindowGroup instance gets independent scenePhase tracking
```

### Lazy Initialization (Startup Library Equivalent)

```swift
// Swift has no direct equivalent to AndroidX Startup, but lazy properties
// and actor-based singletons serve the same purpose

// Lazy singleton with thread safety — equivalent to Initializer<T>
actor DatabaseService {
    static let shared = DatabaseService()

    private var isInitialized = false

    func initialize() async throws {
        guard !isInitialized else { return }
        try await performMigrations()
        isInitialized = true
    }
}

// Lazy initialization via property wrapper
@propertyWrapper
struct LazyInitialized<Value> {
    private var storage: Value?
    private let initializer: () -> Value

    init(wrappedValue initializer: @autoclosure @escaping () -> Value) {
        self.initializer = initializer
    }

    var wrappedValue: Value {
        mutating get {
            if storage == nil {
                storage = initializer()
            }
            return storage!
        }
    }
}

// Usage in App container
final class ServiceLocator {
    static let shared = ServiceLocator()

    lazy var database: DatabaseService = {
        DatabaseService()
    }()

    lazy var analytics: AnalyticsService = {
        AnalyticsService(apiKey: Config.analyticsKey)
    }()
}
```

## Migration Mapping Reference

| Android Concept | iOS SwiftUI | iOS UIKit |
|---|---|---|
| `Application` subclass | `@main App` struct | `@UIApplicationMain` / `AppDelegate` |
| `Application.onCreate()` | `App.init()` | `didFinishLaunchingWithOptions` |
| `@HiltAndroidApp` | `AppContainer` + `@Environment` | Manual DI or Swinject |
| `Initializer<T>` (Startup) | `lazy var` / `actor` singleton | `lazy var` / dispatch_once |
| `registerActivityLifecycleCallbacks` | No direct equivalent | `UIApplication` notifications |
| `applicationContext` | No equivalent needed (no Context) | `UIApplication.shared` |
| `ContentProvider.onCreate()` | Static initializers (avoid) | `+load` / `+initialize` (avoid) |
| Single Activity | `WindowGroup` (single) | Single `UIWindow` |
| Multiple Activities (tasks) | Multiple `WindowGroup` with ids | Multiple `UIScene` configurations |
| `android:launchMode` | Scene configuration | `UISceneConfiguration` |
| `BuildConfig.DEBUG` | `#if DEBUG` | `#if DEBUG` |
| `AndroidManifest.xml` app config | `Info.plist` | `Info.plist` |

## Common Pitfalls

### 1. Heavy Work in App.init()
Android's `Application.onCreate()` runs on the main thread and blocks app start. The same is true for SwiftUI's `App.init()`. Keep initialization minimal and defer heavy work.

```swift
// BAD — blocks app launch
@main
struct WaonderApp: App {
    init() {
        DatabaseService.shared.runMigrations() // Synchronous, slow
    }
}

// GOOD — defer heavy initialization
@main
struct WaonderApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    await DatabaseService.shared.initialize() // Async, non-blocking
                }
        }
    }
}
```

### 2. Missing AppDelegate for Push Notifications
SwiftUI's `@main App` does not handle push notification registration directly. You must use `@UIApplicationDelegateAdaptor` to bridge UIKit delegate methods.

### 3. Assuming Single Window
Android developers often assume one Activity at a time. On iPad (and macOS), multiple `WindowGroup` instances can exist simultaneously. Design state management to be scene-scoped, not app-global.

```swift
// BAD — global singleton state
class AppState {
    static let shared = AppState()
    var currentUser: User? // Shared across all windows
}

// GOOD — scene-scoped state via @Environment
@Observable
class SceneState {
    var navigationPath = NavigationPath()
    var selectedTab: Tab = .home
}
```

### 4. No Direct Context Equivalent
Android's `Context` is pervasive (needed for resources, system services, databases). iOS has no equivalent — system services are accessed directly via singletons or framework APIs. Do not create a "context" abstraction on iOS.

### 5. Initialization Order Differences
Android's `ContentProvider.onCreate()` runs before `Application.onCreate()`, which is exploited by libraries like Firebase. On iOS, `AppDelegate.didFinishLaunchingWithOptions` is the earliest reliable hook. Static initializers (`+load`) are discouraged by Apple.

## Migration Checklist

- [ ] Move `Application.onCreate()` initialization logic to `App.init()` or `didFinishLaunchingWithOptions`
- [ ] Replace `@HiltAndroidApp` with manual DI container injected via `@Environment`
- [ ] Add `@UIApplicationDelegateAdaptor` for push notifications, deep links, and UIKit SDK setup
- [ ] Replace `Initializer<T>` (Startup library) with `lazy var` or async initialization in `.task`
- [ ] Replace `BuildConfig.DEBUG` checks with `#if DEBUG` compiler directives
- [ ] Move `AndroidManifest.xml` app configuration to `Info.plist`
- [ ] Design state management for multi-window support on iPad
- [ ] Remove all `Context` parameter passing — iOS APIs do not require it
- [ ] Ensure third-party SDK initialization happens in `didFinishLaunchingWithOptions` if they require `UIApplication`
- [ ] Test app launch performance — profile with Instruments Time Profiler
