---
name: generic-android-to-ios-process-lifecycle
description: Use when migrating Android ProcessLifecycleOwner (app-level foreground/background tracking, Lifecycle.Event) to iOS equivalents (ScenePhase in SwiftUI, UIApplication.State, willResignActive/didBecomeActive notifications), covering app-level state tracking, analytics session management, connection management, and timer handling
type: generic
---

# generic-android-to-ios-process-lifecycle

## Context

Android's `ProcessLifecycleOwner` provides a single lifecycle that represents the entire app's foreground/background state, independent of individual Activities. It fires `ON_START` when the first Activity becomes visible and `ON_STOP` when the last Activity disappears. This is essential for analytics sessions, WebSocket management, and global resource control. On iOS, SwiftUI's `scenePhase` and UIKit's `UIApplication` state notifications serve a similar purpose, but with scene-level granularity on iPad.

## State Mapping

```
Android ProcessLifecycleOwner          iOS (SwiftUI)             iOS (UIKit)
===============================        =============             ===========
Lifecycle.State.INITIALIZED           (app not launched)         .inactive (initial)
Lifecycle.State.CREATED                ScenePhase.background     .background
Lifecycle.State.STARTED                ScenePhase.inactive       .inactive
Lifecycle.State.RESUMED                ScenePhase.active         .active

Lifecycle.Event.ON_CREATE              (app launch)              didFinishLaunching
Lifecycle.Event.ON_START               .background -> .inactive  willEnterForeground
Lifecycle.Event.ON_RESUME              .inactive -> .active      didBecomeActive
Lifecycle.Event.ON_PAUSE               .active -> .inactive      willResignActive
Lifecycle.Event.ON_STOP                .inactive -> .background  didEnterBackground
Lifecycle.Event.ON_DESTROY             (never called for         (app terminated)
                                        ProcessLifecycleOwner)
```

## Android Best Practices (Source Patterns)

### ProcessLifecycleOwner Observer

```kotlin
class AppLifecycleObserver @Inject constructor(
    private val analytics: Analytics,
    private val webSocketManager: WebSocketManager,
    private val syncManager: SyncManager
) : DefaultLifecycleObserver {

    private var sessionStartTime: Long = 0

    override fun onStart(owner: LifecycleOwner) {
        // App moved to foreground (at least one Activity visible)
        Timber.d("App foregrounded")
        analytics.startSession()
        sessionStartTime = System.currentTimeMillis()
        webSocketManager.connect()
        syncManager.startPeriodicSync()
    }

    override fun onStop(owner: LifecycleOwner) {
        // App moved to background (no Activities visible)
        Timber.d("App backgrounded")
        val duration = System.currentTimeMillis() - sessionStartTime
        analytics.endSession(durationMs = duration)
        webSocketManager.disconnect()
        syncManager.stopPeriodicSync()
    }
}

// Registration in Application.onCreate()
class WaonderApplication : Application() {
    @Inject lateinit var appLifecycleObserver: AppLifecycleObserver

    override fun onCreate() {
        super.onCreate()
        ProcessLifecycleOwner.get().lifecycle.addObserver(appLifecycleObserver)
    }
}
```

### Lifecycle-Aware Connection Manager

```kotlin
class WebSocketManager @Inject constructor(
    private val client: OkHttpClient,
    private val tokenProvider: TokenProvider
) : DefaultLifecycleObserver {

    private var webSocket: WebSocket? = null
    private val _messages = MutableSharedFlow<WebSocketMessage>()
    val messages: SharedFlow<WebSocketMessage> = _messages.asSharedFlow()

    override fun onStart(owner: LifecycleOwner) {
        connect()
    }

    override fun onStop(owner: LifecycleOwner) {
        disconnect()
    }

    fun connect() {
        if (webSocket != null) return
        val request = Request.Builder()
            .url("wss://api.waonder.com/ws")
            .addHeader("Authorization", "Bearer ${tokenProvider.getToken()}")
            .build()
        webSocket = client.newWebSocket(request, createListener())
    }

    fun disconnect() {
        webSocket?.close(1000, "App backgrounded")
        webSocket = null
    }
}
```

### Timer Management with Process Lifecycle

```kotlin
class PeriodicRefreshManager @Inject constructor(
    private val refreshUseCase: RefreshDataUseCase
) : DefaultLifecycleObserver {

    private var refreshJob: Job? = null

    override fun onStart(owner: LifecycleOwner) {
        refreshJob = ProcessLifecycleOwner.get().lifecycleScope.launch {
            while (isActive) {
                refreshUseCase()
                delay(30.seconds)
            }
        }
    }

    override fun onStop(owner: LifecycleOwner) {
        refreshJob?.cancel()
        refreshJob = null
    }
}
```

### Key Android Patterns to Recognize

- `ProcessLifecycleOwner.get().lifecycle` — app-wide lifecycle, not per-Activity
- `DefaultLifecycleObserver.onStart/onStop` — foreground/background transitions
- `ON_DESTROY` is never dispatched by ProcessLifecycleOwner
- `lifecycleScope` on ProcessLifecycleOwner — coroutine scope tied to app lifetime
- Multiple observers on same lifecycle — composable lifecycle reactions
- Debounced transitions — brief Activity switches do not trigger onStop

## iOS Best Practices (Target Patterns)

### SwiftUI ScenePhase (Preferred)

```swift
import SwiftUI

@main
struct WaonderApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let appLifecycleManager: AppLifecycleManager

    init() {
        appLifecycleManager = AppLifecycleManager(
            analytics: AnalyticsService.shared,
            webSocketManager: WebSocketManager.shared,
            syncManager: SyncManager.shared
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            appLifecycleManager.handlePhaseChange(from: oldPhase, to: newPhase)
        }
    }
}

@Observable
final class AppLifecycleManager {
    private let analytics: AnalyticsService
    private let webSocketManager: WebSocketManager
    private let syncManager: SyncManager
    private var sessionStartDate: Date?

    init(
        analytics: AnalyticsService,
        webSocketManager: WebSocketManager,
        syncManager: SyncManager
    ) {
        self.analytics = analytics
        self.webSocketManager = webSocketManager
        self.syncManager = syncManager
    }

    func handlePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // Equivalent to ProcessLifecycleOwner.onStart/onResume
            Logger.info("App became active")
            analytics.startSession()
            sessionStartDate = Date()
            webSocketManager.connect()
            syncManager.startPeriodicSync()

        case .inactive:
            // Equivalent to ProcessLifecycleOwner — transitional state
            // Brief pause (e.g., notification center pulled down)
            Logger.info("App became inactive")

        case .background:
            // Equivalent to ProcessLifecycleOwner.onStop
            Logger.info("App entered background")
            if let start = sessionStartDate {
                let duration = Date().timeIntervalSince(start)
                analytics.endSession(duration: duration)
            }
            webSocketManager.disconnect()
            syncManager.stopPeriodicSync()

        @unknown default:
            break
        }
    }
}
```

### UIKit Notification-Based Approach

```swift
import UIKit
import Combine

final class AppLifecycleTracker {
    private var cancellables = Set<AnyCancellable>()
    private let analytics: AnalyticsService
    private var sessionStartDate: Date?

    init(analytics: AnalyticsService) {
        self.analytics = analytics
        observeLifecycle()
    }

    private func observeLifecycle() {
        // Equivalent to ProcessLifecycleOwner.onStart
        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleBecameActive()
            }
            .store(in: &cancellables)

        // Equivalent to ProcessLifecycleOwner — transitional
        NotificationCenter.default
            .publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleResigningActive()
            }
            .store(in: &cancellables)

        // Equivalent to ProcessLifecycleOwner.onStop
        NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleEnteredBackground()
            }
            .store(in: &cancellables)

        // Equivalent to ProcessLifecycleOwner.onStart (from background)
        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleEnteringForeground()
            }
            .store(in: &cancellables)
    }

    private func handleBecameActive() {
        analytics.startSession()
        sessionStartDate = Date()
    }

    private func handleResigningActive() {
        // Save draft state, pause media
    }

    private func handleEnteredBackground() {
        if let start = sessionStartDate {
            analytics.endSession(duration: Date().timeIntervalSince(start))
        }
    }

    private func handleEnteringForeground() {
        // Refresh tokens, check connectivity
    }
}
```

### WebSocket Connection Manager

```swift
import Foundation

actor WebSocketManager {
    static let shared = WebSocketManager()

    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var messageStream: AsyncStream<WebSocketMessage>?
    private var messageContinuation: AsyncStream<WebSocketMessage>.Continuation?

    // Equivalent to connecting in ProcessLifecycleOwner.onStart
    func connect() {
        guard webSocketTask == nil else { return }

        let url = URL(string: "wss://api.waonder.com/ws")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(TokenProvider.shared.token)", forHTTPHeaderField: "Authorization")

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        setupMessageStream()
        receiveMessages()
    }

    // Equivalent to disconnecting in ProcessLifecycleOwner.onStop
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        messageContinuation?.finish()
    }

    var messages: AsyncStream<WebSocketMessage> {
        if messageStream == nil { setupMessageStream() }
        return messageStream!
    }

    private func setupMessageStream() {
        let (stream, continuation) = AsyncStream.makeStream(of: WebSocketMessage.self)
        messageStream = stream
        messageContinuation = continuation
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            Task {
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        await self.messageContinuation?.yield(.text(text))
                    case .data(let data):
                        await self.messageContinuation?.yield(.binary(data))
                    @unknown default:
                        break
                    }
                    await self.receiveMessages()
                case .failure(let error):
                    Logger.error("WebSocket error: \(error)")
                    await self.messageContinuation?.finish()
                }
            }
        }
    }
}
```

### Timer Management

```swift
import SwiftUI

// Equivalent to PeriodicRefreshManager with ProcessLifecycleOwner
@Observable
final class PeriodicRefreshManager {
    private let refreshUseCase: RefreshDataUseCase
    private var refreshTask: Task<Void, Never>?

    init(refreshUseCase: RefreshDataUseCase) {
        self.refreshUseCase = refreshUseCase
    }

    func startRefreshing() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshUseCase.execute()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    func stopRefreshing() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

// Usage in App-level Scene
@main
struct WaonderApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshManager = PeriodicRefreshManager(
        refreshUseCase: RefreshDataUseCase()
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                refreshManager.startRefreshing()
            case .background:
                refreshManager.stopRefreshing()
            default:
                break
            }
        }
    }
}
```

### Scene-Aware Process Lifecycle (iPad Multi-Window)

```swift
// On iPad, each scene has its own scenePhase.
// For true app-level tracking (like ProcessLifecycleOwner), observe at the App level.

@main
struct WaonderApp: App {
    // App-level scenePhase reflects the aggregate:
    // .active if ANY scene is active
    // .background only when ALL scenes are background
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                // View-level scenePhase is per-scene
                .onScenePhaseChange { oldPhase, newPhase in
                    // This fires per-scene, like per-Activity lifecycle
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // This fires at app level, like ProcessLifecycleOwner
        }
    }
}

// For UIKit scene-based apps:
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Per-scene foreground — like Activity.onResume
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Per-scene background — like Activity.onStop
    }
}
```

## Migration Mapping Reference

| Android Concept | iOS SwiftUI | iOS UIKit |
|---|---|---|
| `ProcessLifecycleOwner` | `@Environment(\.scenePhase)` at App level | `UIApplication` notifications |
| `Lifecycle.Event.ON_START` | `.background` -> `.inactive`/`.active` | `willEnterForegroundNotification` |
| `Lifecycle.Event.ON_RESUME` | `.inactive` -> `.active` | `didBecomeActiveNotification` |
| `Lifecycle.Event.ON_PAUSE` | `.active` -> `.inactive` | `willResignActiveNotification` |
| `Lifecycle.Event.ON_STOP` | `.inactive` -> `.background` | `didEnterBackgroundNotification` |
| `ProcessLifecycleOwner.lifecycleScope` | App-level `Task` | App-level `DispatchQueue` / `Task` |
| `DefaultLifecycleObserver` | `.onChange(of: scenePhase)` | `NotificationCenter` publishers |
| App foreground check | `scenePhase == .active` | `UIApplication.shared.applicationState == .active` |
| Debounced transition | Built into scenePhase | Built into notification timing |

## Common Pitfalls

### 1. Scene-Level vs App-Level ScenePhase
On iPad, `scenePhase` observed at a `View` level is per-scene. To get ProcessLifecycleOwner-equivalent behavior (app-level), observe `scenePhase` at the `App` struct level via `.onChange(of: scenePhase)` on the `Scene`.

```swift
// Per-scene (like per-Activity) — NOT equivalent to ProcessLifecycleOwner
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase // Per-scene
}

// App-level (equivalent to ProcessLifecycleOwner)
@main
struct WaonderApp: App {
    @Environment(\.scenePhase) private var scenePhase // Aggregate across all scenes
}
```

### 2. ON_DESTROY Is Never Called on ProcessLifecycleOwner
ProcessLifecycleOwner never fires `ON_DESTROY`. iOS similarly has no reliable "app will terminate" callback for SwiftUI. `applicationWillTerminate` in UIKit is called only in limited circumstances. Do not rely on termination hooks for saving critical data — save eagerly on background transition.

### 3. Treating .inactive as Background
`.inactive` is a transitional state (notification center, app switcher, incoming call). It is NOT the same as `.background`. Do not disconnect services or end sessions on `.inactive` — wait for `.background`.

```swift
// BAD — disconnects during notification pull-down
.onChange(of: scenePhase) { _, newPhase in
    if newPhase != .active {
        webSocketManager.disconnect() // Wrong!
    }
}

// GOOD — only disconnect on actual background
.onChange(of: scenePhase) { _, newPhase in
    switch newPhase {
    case .active: webSocketManager.connect()
    case .background: webSocketManager.disconnect()
    case .inactive: break // Do nothing
    @unknown default: break
    }
}
```

### 4. Background Task Completion
When the app moves to background, iOS suspends execution quickly. For critical saves, request background time.

```swift
func handleEnteredBackground() {
    let taskId = UIApplication.shared.beginBackgroundTask {
        // Expiration handler
    }
    Task {
        await syncManager.flushPendingChanges()
        UIApplication.shared.endBackgroundTask(taskId)
    }
}
```

### 5. Missing the willEnterForeground vs didBecomeActive Distinction
Android's `ON_START` (visible) and `ON_RESUME` (interactive) have distinct UIKit counterparts: `willEnterForeground` and `didBecomeActive`. Do not conflate them when migrating observers that distinguish between visibility and interactivity.

## Migration Checklist

- [ ] Replace `ProcessLifecycleOwner.get().lifecycle.addObserver()` with `.onChange(of: scenePhase)` at the `App` level
- [ ] Map `ON_START` to `.active` transition and `ON_STOP` to `.background` transition
- [ ] Move analytics session start/end to scenePhase changes
- [ ] Migrate WebSocket connect/disconnect to scenePhase-aware manager
- [ ] Replace `lifecycleScope.launch` periodic timers with `Task`-based equivalents cancelled on `.background`
- [ ] Handle `.inactive` as a transitional state — do not treat it as background
- [ ] Add `beginBackgroundTask` for critical saves when entering background
- [ ] Test on iPad with multiple windows to verify app-level vs scene-level behavior
- [ ] Verify that `scenePhase` observation is at the correct level (App vs View)
- [ ] Remove any reliance on `ON_DESTROY` — it has no iOS equivalent; save state on background
