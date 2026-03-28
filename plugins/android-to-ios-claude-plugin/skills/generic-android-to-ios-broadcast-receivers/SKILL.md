---
name: generic-android-to-ios-broadcast-receivers
description: Use when migrating Android BroadcastReceiver patterns (manifest-registered, context-registered, LocalBroadcastManager, system broadcasts) to iOS NotificationCenter, Darwin notifications, and framework-specific delegates/callbacks
type: generic
---

# generic-android-to-ios-broadcast-receivers

## Context

Android's `BroadcastReceiver` is a component that listens for system-wide or app-internal broadcast messages (intents). Receivers can be registered in the manifest (for system events even when the app is not running) or dynamically in code (context-registered, active while the component is alive). `LocalBroadcastManager` (deprecated) handled in-process broadcasts. iOS has no direct equivalent. Instead, iOS uses `NotificationCenter` for in-process pub/sub, Darwin notifications for cross-process communication, delegate patterns for framework callbacks, and specific APIs for system events like connectivity, battery, and app lifecycle.

## Concept Mapping

| Android | iOS |
|---|---|
| `BroadcastReceiver` (context-registered) | `NotificationCenter` observer |
| `BroadcastReceiver` (manifest-registered) | No direct equivalent; use background modes, push notifications, or app extensions |
| `LocalBroadcastManager` (deprecated) | `NotificationCenter.default` (in-process) |
| `sendBroadcast(intent)` | `NotificationCenter.default.post(name:object:userInfo:)` |
| `IntentFilter` | `Notification.Name` |
| `Intent` extras in broadcast | `userInfo` dictionary or typed `Notification` payload |
| System broadcast: `BOOT_COMPLETED` | No equivalent (apps cannot run at boot) |
| System broadcast: `CONNECTIVITY_CHANGE` | `NWPathMonitor` |
| System broadcast: `BATTERY_CHANGED` | `UIDevice.batteryLevelDidChangeNotification` |
| System broadcast: `AIRPLANE_MODE_CHANGED` | `NWPathMonitor` (detect no connectivity) |
| System broadcast: `LOCALE_CHANGED` | `NSLocale.currentLocaleDidChangeNotification` |
| System broadcast: `TIME_SET` / `TIMEZONE_CHANGED` | `NSNotification.Name.NSSystemTimeZoneDidChange` |
| System broadcast: `SCREEN_ON` / `SCREEN_OFF` | No equivalent (apps are suspended) |
| System broadcast: `PACKAGE_ADDED` | No equivalent |
| `registerReceiver(receiver, filter)` | `NotificationCenter.default.addObserver` |
| `unregisterReceiver(receiver)` | `NotificationCenter.default.removeObserver` / store `AnyCancellable` |
| Ordered broadcasts | No equivalent; use sequential async processing |
| Sticky broadcasts (deprecated) | No equivalent; query current state directly |

## Code Patterns

### In-App Event Broadcasting

**Android (LocalBroadcastManager / context-registered):**
```kotlin
// Define action
const val ACTION_DATA_UPDATED = "com.myapp.DATA_UPDATED"

// Send broadcast
val intent = Intent(ACTION_DATA_UPDATED).apply {
    putExtra("item_id", "123")
    putExtra("update_type", "modified")
}
LocalBroadcastManager.getInstance(context).sendBroadcast(intent)

// Receive broadcast
class DataUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val itemId = intent.getStringExtra("item_id")
        val updateType = intent.getStringExtra("update_type")
        // Handle update
    }
}

// Register
val receiver = DataUpdateReceiver()
val filter = IntentFilter(ACTION_DATA_UPDATED)
LocalBroadcastManager.getInstance(context)
    .registerReceiver(receiver, filter)

// Unregister
LocalBroadcastManager.getInstance(context)
    .unregisterReceiver(receiver)
```

**iOS (NotificationCenter):**
```swift
// Define notification name
extension Notification.Name {
    static let dataUpdated = Notification.Name("dataUpdated")
}

// Send notification
NotificationCenter.default.post(
    name: .dataUpdated,
    object: nil,
    userInfo: [
        "itemId": "123",
        "updateType": "modified"
    ]
)

// Receive -- Option 1: Closure-based (preferred)
let observer = NotificationCenter.default.addObserver(
    forName: .dataUpdated,
    object: nil,
    queue: .main
) { notification in
    let itemId = notification.userInfo?["itemId"] as? String
    let updateType = notification.userInfo?["updateType"] as? String
    // Handle update
}

// Unregister
NotificationCenter.default.removeObserver(observer)

// Receive -- Option 2: Combine publisher (modern approach)
import Combine

class DataObserver {
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: .dataUpdated)
            .receive(on: DispatchQueue.main)
            .sink { notification in
                let itemId = notification.userInfo?["itemId"] as? String
                // Handle update
            }
            .store(in: &cancellables)
    }
}
```

### Type-Safe Notification Pattern (Recommended)

**iOS:**
```swift
// Define a typed notification payload
struct DataUpdateEvent {
    let itemId: String
    let updateType: UpdateType

    enum UpdateType: String {
        case created, modified, deleted
    }
}

// Type-safe posting and receiving
extension Notification.Name {
    static let dataUpdated = Notification.Name("dataUpdated")
}

enum AppNotification {
    static func postDataUpdate(_ event: DataUpdateEvent) {
        NotificationCenter.default.post(
            name: .dataUpdated,
            object: event
        )
    }

    static func observeDataUpdate(
        handler: @escaping (DataUpdateEvent) -> Void
    ) -> any NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: .dataUpdated,
            object: nil,
            queue: .main
        ) { notification in
            guard let event = notification.object as? DataUpdateEvent else { return }
            handler(event)
        }
    }
}

// Usage
AppNotification.postDataUpdate(
    DataUpdateEvent(itemId: "123", updateType: .modified)
)

let observer = AppNotification.observeDataUpdate { event in
    print("Item \(event.itemId) was \(event.updateType)")
}
```

### SwiftUI View Integration

**iOS:**
```swift
struct ItemListView: View {
    @State private var items: [Item] = []

    var body: some View {
        List(items) { item in
            Text(item.name)
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataUpdated)) { notification in
            guard let event = notification.object as? DataUpdateEvent else { return }
            refreshItems(for: event)
        }
    }
}
```

### Network Connectivity Changes

**Android:**
```kotlin
// Manifest-registered (limited in modern Android)
// <receiver android:name=".ConnectivityReceiver">
//     <intent-filter>
//         <action android:name="android.net.conn.CONNECTIVITY_CHANGE" />
//     </intent-filter>
// </receiver>

// Modern approach: NetworkCallback
class NetworkMonitor(context: Context) {
    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            // Connected
        }
        override fun onLost(network: Network) {
            // Disconnected
        }
        override fun onCapabilitiesChanged(
            network: Network,
            capabilities: NetworkCapabilities
        ) {
            val hasWifi = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
            val hasCellular = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
        }
    }

    fun startMonitoring() {
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        connectivityManager.registerNetworkCallback(request, networkCallback)
    }

    fun stopMonitoring() {
        connectivityManager.unregisterNetworkCallback(networkCallback)
    }
}
```

**iOS:**
```swift
import Network

@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    var isConnected = false
    var isWifi = false
    var isCellular = false

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isWifi = path.usesInterfaceType(.wifi)
                self?.isCellular = path.usesInterfaceType(.cellular)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

// Use in SwiftUI
struct ContentView: View {
    @State private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        VStack {
            if networkMonitor.isConnected {
                Text("Connected")
                if networkMonitor.isWifi {
                    Text("via Wi-Fi")
                }
            } else {
                Text("No Connection")
            }
        }
    }
}
```

### Battery State Changes

**Android:**
```kotlin
class BatteryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        val batteryPct = level * 100 / scale
        val isCharging = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ==
            BatteryManager.BATTERY_STATUS_CHARGING
    }
}

// Register
val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
registerReceiver(BatteryReceiver(), filter)
```

**iOS:**
```swift
@Observable
final class BatteryMonitor {
    var batteryLevel: Float = 0
    var isCharging = false

    private var observers: [NSObjectProtocol] = []

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel
        isCharging = UIDevice.current.batteryState == .charging
            || UIDevice.current.batteryState == .full

        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIDevice.batteryLevelDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.batteryLevel = UIDevice.current.batteryLevel
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIDevice.batteryStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                let state = UIDevice.current.batteryState
                self?.isCharging = state == .charging || state == .full
            }
        )
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        UIDevice.current.isBatteryMonitoringEnabled = false
    }
}
```

### App Lifecycle Events

**Android:**
```kotlin
// Broadcast for app lifecycle
class AppLifecycleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SCREEN_ON -> { /* screen turned on */ }
            Intent.ACTION_SCREEN_OFF -> { /* screen turned off */ }
            Intent.ACTION_USER_PRESENT -> { /* device unlocked */ }
        }
    }
}

// ProcessLifecycleOwner (modern approach)
ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
    override fun onStart(owner: LifecycleOwner) { /* app in foreground */ }
    override fun onStop(owner: LifecycleOwner) { /* app in background */ }
})
```

**iOS (SwiftUI):**
```swift
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        MainContent()
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    // App is in foreground and interactive
                    // Equivalent to onStart / ACTION_USER_PRESENT
                    handleBecameActive()
                case .inactive:
                    // App is visible but not interactive (transitioning)
                    handleBecameInactive()
                case .background:
                    // App is in background
                    // Equivalent to onStop
                    handleEnteredBackground()
                @unknown default:
                    break
                }
            }
    }
}

// UIKit notifications for more granular lifecycle events
NotificationCenter.default.addObserver(
    forName: UIApplication.willEnterForegroundNotification, ...)
NotificationCenter.default.addObserver(
    forName: UIApplication.didEnterBackgroundNotification, ...)
NotificationCenter.default.addObserver(
    forName: UIApplication.willTerminateNotification, ...)
NotificationCenter.default.addObserver(
    forName: UIApplication.significantTimeChangeNotification, ...)
```

### Keyboard Visibility

**Android:**
```kotlin
// Common broadcast-like pattern for keyboard visibility
ViewCompat.setOnApplyWindowInsetsListener(view) { v, insets ->
    val imeVisible = insets.isVisible(WindowInsetsCompat.Type.ime())
    val imeHeight = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
    // React to keyboard
    insets
}
```

**iOS (SwiftUI -- handled automatically, but observable):**
```swift
// SwiftUI handles keyboard avoidance automatically.
// To observe keyboard events explicitly:

import Combine

@Observable
final class KeyboardObserver {
    var isVisible = false
    var height: CGFloat = 0

    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                    as? CGRect {
                    self?.height = frame.height
                    self?.isVisible = true
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.height = 0
                self?.isVisible = false
            }
            .store(in: &cancellables)
    }
}
```

### Cross-Process Notifications (Darwin Notifications)

**Android:**
```kotlin
// System-wide broadcasts between apps
val intent = Intent("com.myapp.CUSTOM_EVENT")
sendBroadcast(intent)
```

**iOS (Darwin Notifications -- rare, limited):**
```swift
import Darwin

// Darwin notifications are cross-process but carry no payload
let name = "com.myapp.customEvent" as CFString

// Post
let center = CFNotificationCenterGetDarwinNotifyCenter()
CFNotificationCenterPostNotification(center, CFNotificationName(name), nil, nil, true)

// Observe
CFNotificationCenterAddObserver(
    center,
    nil,
    { center, observer, name, object, userInfo in
        // Handle notification (no payload available)
        DispatchQueue.main.async {
            // Update UI
        }
    },
    name,
    nil,
    .deliverImmediately
)

// Note: Darwin notifications are rarely needed. Prefer App Groups
// and shared UserDefaults for cross-app communication within your app suite.
```

## Replacing @Observable with Event Bus (Alternative Pattern)

For apps that heavily use broadcast-style event buses, consider an `@Observable`-based event bus:

```swift
@Observable
final class EventBus {
    static let shared = EventBus()

    // Use AsyncStream for event-driven patterns
    private var continuations: [String: [AsyncStream<Any>.Continuation]] = [:]

    func stream<T>(for type: T.Type) -> AsyncStream<T> {
        let key = String(describing: type)
        return AsyncStream { continuation in
            if continuations[key] == nil {
                continuations[key] = []
            }
            continuations[key]?.append(continuation as! AsyncStream<Any>.Continuation)
        }
    }

    func emit<T>(_ event: T) {
        let key = String(describing: T.self)
        continuations[key]?.forEach { continuation in
            continuation.yield(event as Any)
        }
    }
}

// Usage in SwiftUI
struct ItemListView: View {
    var body: some View {
        List { /* ... */ }
            .task {
                for await event in EventBus.shared.stream(for: DataUpdateEvent.self) {
                    handleEvent(event)
                }
            }
    }
}
```

## Best Practices

1. **Use `NotificationCenter` for in-process pub/sub** -- This is the direct replacement for `LocalBroadcastManager` and context-registered broadcast receivers within your app.
2. **Use typed notification payloads** -- Instead of stringly-typed `userInfo` dictionaries, pass typed objects via the `object` parameter or create wrapper functions for type safety.
3. **Use framework-specific APIs instead of system broadcasts** -- iOS provides dedicated APIs for most system events: `NWPathMonitor` for connectivity, `UIDevice` notifications for battery, `CLLocationManager` for location, etc.
4. **Use Combine publishers for reactive patterns** -- `NotificationCenter.default.publisher(for:)` integrates cleanly with Combine and SwiftUI's `.onReceive` modifier.
5. **Prefer `@Observable` over NotificationCenter for view model communication** -- If the sender and receiver are in the same view hierarchy, use `@Observable` objects with `@Environment` or `@Binding` instead of notifications.
6. **Always remove observers** -- Use the `AnyCancellable` pattern with Combine, or store the observer token and call `removeObserver` in `deinit`. Failure to do so causes crashes or memory leaks.
7. **There is no manifest-registered receiver on iOS** -- Apps cannot register to receive system events when not running (with very few exceptions like push notifications and background fetch). Accept this limitation.

## Common Pitfalls

- **Expecting broadcasts to work when app is not running** -- iOS does not deliver notifications to suspended apps. Use push notifications or background fetch for wake-up scenarios.
- **Using `NotificationCenter` for cross-app communication** -- `NotificationCenter.default` is in-process only. For cross-app communication, use App Groups with shared `UserDefaults`, Darwin notifications (no payload), or URL schemes.
- **Forgetting `@MainActor` for UI updates** -- `NotificationCenter` callbacks and `NWPathMonitor` handlers may fire on background queues. Always dispatch to main for UI updates.
- **Memory leaks from unremoved observers** -- Closure-based `addObserver` returns a token that must be retained and used to remove the observer. If you lose the token, the observer leaks.
- **Overusing NotificationCenter** -- If you find yourself creating many custom notifications for in-app communication, consider using `@Observable` objects, delegate protocols, or async streams instead. Notifications should be used for truly decoupled, broadcast-style events.
- **`BOOT_COMPLETED` has no iOS equivalent** -- iOS apps cannot run at device boot. If you need to perform setup, do it on first app launch.

## Migration Checklist

- [ ] Audit all `BroadcastReceiver` subclasses and categorize: in-app events, system events, cross-app events
- [ ] Replace `LocalBroadcastManager` / context-registered receivers with `NotificationCenter` observers
- [ ] Replace `CONNECTIVITY_CHANGE` receiver with `NWPathMonitor`
- [ ] Replace `BATTERY_CHANGED` receiver with `UIDevice` battery notifications
- [ ] Replace `ACTION_LOCALE_CHANGED` with `NSLocale.currentLocaleDidChangeNotification`
- [ ] Replace `ACTION_TIMEZONE_CHANGED` with `NSSystemTimeZoneDidChange`
- [ ] Replace app lifecycle broadcasts with `scenePhase` or `UIApplication` notifications
- [ ] Replace keyboard visibility broadcasts with `UIResponder` keyboard notifications
- [ ] Replace manifest-registered receivers with push notifications or background fetch where applicable
- [ ] Create typed notification payloads instead of stringly-typed `userInfo` dictionaries
- [ ] Ensure all `NotificationCenter` observers are properly removed on deinit
- [ ] Replace cross-app broadcasts with App Groups, Darwin notifications, or URL schemes
- [ ] Verify all notification handlers dispatch UI updates to the main thread
- [ ] Test connectivity and battery observers on real devices
