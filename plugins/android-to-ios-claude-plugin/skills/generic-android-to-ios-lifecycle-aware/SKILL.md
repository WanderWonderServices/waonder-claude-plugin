---
name: generic-android-to-ios-lifecycle-aware
description: Use when migrating Android lifecycle-aware components (LifecycleObserver, DefaultLifecycleObserver, repeatOnLifecycle, flowWithLifecycle) to iOS equivalents (SwiftUI .onAppear, .onDisappear, .task, .onChange modifiers, Combine + view lifecycle, UIKit observation patterns), covering automatic cleanup, subscription management, and safe collection patterns
type: generic
---

# generic-android-to-ios-lifecycle-aware

## Context

Android's lifecycle-aware components allow objects to automatically respond to lifecycle changes without manual registration/unregistration in each callback. `LifecycleObserver`, `DefaultLifecycleObserver`, and especially `repeatOnLifecycle` / `flowWithLifecycle` provide safe patterns for collecting Flows only when the UI is in the correct state, automatically pausing and restarting collection. On iOS, SwiftUI's declarative lifecycle modifiers (`.task`, `.onAppear`, `.onDisappear`, `.onChange`) and structured concurrency provide equivalent safety, while UIKit requires Combine or manual NotificationCenter patterns.

## Pattern Mapping Overview

```
Android                                iOS SwiftUI                    iOS UIKit
=======                                ===========                    =========
LifecycleObserver                      View lifecycle modifiers       NotificationCenter observers
DefaultLifecycleObserver               .onAppear / .onDisappear       viewDidAppear / viewDidDisappear

repeatOnLifecycle(STARTED) {           .task {                        viewWillAppear + Combine
    flow.collect { }                       for await value in ... }       .sink { } + cancel in
}                                      }                                  viewWillDisappear

flowWithLifecycle(STARTED)             .task { stream.collect }        Combine + lifecycle
lifecycle.coroutineScope               View's Task scope              DispatchQueue / Task
Lifecycle.State.STARTED                View is on screen              isViewLoaded && view.window != nil
Lifecycle.State.RESUMED                scenePhase == .active          applicationState == .active
```

## Android Best Practices (Source Patterns)

### DefaultLifecycleObserver

```kotlin
class LocationTracker(
    private val locationClient: FusedLocationProviderClient
) : DefaultLifecycleObserver {

    private val _location = MutableStateFlow<Location?>(null)
    val location: StateFlow<Location?> = _location.asStateFlow()

    override fun onStart(owner: LifecycleOwner) {
        startLocationUpdates()
    }

    override fun onStop(owner: LifecycleOwner) {
        stopLocationUpdates()
    }

    private fun startLocationUpdates() {
        val request = LocationRequest.Builder(10_000L).build()
        locationClient.requestLocationUpdates(request, locationCallback, Looper.getMainLooper())
    }

    private fun stopLocationUpdates() {
        locationClient.removeLocationUpdates(locationCallback)
    }

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            _location.value = result.lastLocation
        }
    }
}

// Registration — lifecycle-aware, no manual cleanup needed
class MapFragment : Fragment() {
    private val locationTracker by lazy { LocationTracker(locationClient) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lifecycle.addObserver(locationTracker)
    }
}
```

### repeatOnLifecycle (Safe Flow Collection)

```kotlin
class ChatFragment : Fragment(R.layout.fragment_chat) {

    private val viewModel: ChatViewModel by viewModels()

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Safe collection: starts when STARTED, cancels when STOPPED, restarts when STARTED again
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                // Multiple parallel collections in the same repeatOnLifecycle block
                launch {
                    viewModel.messages.collect { messages ->
                        adapter.submitList(messages)
                    }
                }
                launch {
                    viewModel.onlineUsers.collect { users ->
                        updateOnlineIndicator(users)
                    }
                }
                launch {
                    viewModel.typingStatus.collect { status ->
                        updateTypingIndicator(status)
                    }
                }
            }
        }
    }
}
```

### flowWithLifecycle (Single Flow)

```kotlin
class NotificationFragment : Fragment(R.layout.fragment_notifications) {

    private val viewModel: NotificationViewModel by viewModels()

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        viewLifecycleOwner.lifecycleScope.launch {
            // Shorthand for single flow — cancels/restarts with lifecycle
            viewModel.notifications
                .flowWithLifecycle(viewLifecycleOwner.lifecycle, Lifecycle.State.STARTED)
                .collect { notifications ->
                    updateBadge(notifications.count { it.isUnread })
                }
        }
    }
}
```

### Lifecycle-Aware Coroutine Scope

```kotlin
class SensorManager(
    private val sensorRepository: SensorRepository
) : DefaultLifecycleObserver {

    private var collectionJob: Job? = null

    override fun onResume(owner: LifecycleOwner) {
        collectionJob = owner.lifecycleScope.launch {
            sensorRepository.sensorData.collect { data ->
                processSensorData(data)
            }
        }
    }

    override fun onPause(owner: LifecycleOwner) {
        collectionJob?.cancel()
        collectionJob = null
    }
}
```

### Key Android Patterns to Recognize

- `DefaultLifecycleObserver` — interface with default methods for each lifecycle event
- `lifecycle.addObserver()` — register once, automatic callbacks on lifecycle changes
- `repeatOnLifecycle(State.STARTED)` — safe block that runs/cancels with lifecycle transitions
- `flowWithLifecycle` — operator version for single flow collection
- `viewLifecycleOwner.lifecycleScope` — coroutine scope tied to Fragment's view lifecycle
- `Lifecycle.State.STARTED` vs `RESUMED` — visible vs interactive
- Multiple `launch` blocks inside `repeatOnLifecycle` — parallel safe collections

## iOS Best Practices (Target Patterns)

### SwiftUI .task Modifier (Primary Replacement for repeatOnLifecycle)

```swift
import SwiftUI

struct ChatView: View {
    @State private var viewModel: ChatViewModel

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(viewModel.messages) { message in
                    MessageRow(message: message)
                }
            }
        }
        // Equivalent to repeatOnLifecycle(STARTED) { flow.collect {} }
        // .task starts when view appears, cancels when view disappears
        .task {
            await viewModel.observeMessages()
        }
        // Multiple .task modifiers for parallel collections
        .task {
            await viewModel.observeOnlineUsers()
        }
        .task {
            await viewModel.observeTypingStatus()
        }
    }
}

// ViewModel using AsyncSequence (equivalent to Flow)
@Observable
final class ChatViewModel {
    private(set) var messages: [Message] = []
    private(set) var onlineUsers: [User] = []
    private(set) var typingStatus: TypingStatus = .idle

    private let messageRepository: MessageRepository
    private let presenceRepository: PresenceRepository

    init(messageRepository: MessageRepository, presenceRepository: PresenceRepository) {
        self.messageRepository = messageRepository
        self.presenceRepository = presenceRepository
    }

    func observeMessages() async {
        for await newMessages in messageRepository.messagesStream {
            messages = newMessages
        }
    }

    func observeOnlineUsers() async {
        for await users in presenceRepository.onlineUsersStream {
            onlineUsers = users
        }
    }

    func observeTypingStatus() async {
        for await status in presenceRepository.typingStream {
            typingStatus = status
        }
    }
}
```

### .task(id:) for Reactive Restarting

```swift
struct UserDetailView: View {
    @State private var viewModel: UserDetailViewModel
    let userId: String

    var body: some View {
        userContent
            // Equivalent to:
            // repeatOnLifecycle(STARTED) { viewModel.loadUser(id).collect {} }
            // where the flow restarts when userId changes
            .task(id: userId) {
                await viewModel.loadUser(id: userId)
            }
    }
}
```

### .onAppear / .onDisappear (Lifecycle Observer Equivalent)

```swift
struct MapView: View {
    @State private var locationTracker: LocationTracker

    var body: some View {
        Map(coordinateRegion: $locationTracker.region)
            // Equivalent to DefaultLifecycleObserver.onStart/onStop
            .onAppear {
                locationTracker.startUpdates()
            }
            .onDisappear {
                locationTracker.stopUpdates()
            }
    }
}

// Equivalent to LocationTracker : DefaultLifecycleObserver
@Observable
final class LocationTracker {
    var region = MKCoordinateRegion()
    private let locationManager = CLLocationManager()

    func startUpdates() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdates() {
        locationManager.stopUpdatingLocation()
    }
}
```

### SwiftUI .onChange Modifier (State-Reactive Lifecycle)

```swift
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Form {
            settingsContent
        }
        // Equivalent to lifecycle observer reacting to RESUMED/PAUSED
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                viewModel.refreshSettings()
            }
        }
        // React to state changes — equivalent to Flow.distinctUntilChanged
        .onChange(of: viewModel.selectedTheme) { oldTheme, newTheme in
            viewModel.applyTheme(newTheme)
        }
    }
}
```

### Combine + UIKit Lifecycle (UIViewController Pattern)

```swift
import UIKit
import Combine

final class ChatViewController: UIViewController {
    private let viewModel: ChatViewModel
    private var cancellables = Set<AnyCancellable>()
    private var lifecycleCancellables = Set<AnyCancellable>()

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()

        // Permanent subscriptions — equivalent to lifecycle.addObserver in onCreate
        viewModel.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateConnectionBanner(status)
            }
            .store(in: &cancellables)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Equivalent to repeatOnLifecycle(STARTED) — start collecting
        viewModel.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.updateMessages(messages)
            }
            .store(in: &lifecycleCancellables)

        viewModel.$onlineUsers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] users in
                self?.updateOnlineIndicator(users)
            }
            .store(in: &lifecycleCancellables)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Equivalent to repeatOnLifecycle cancelling on STOPPED
        lifecycleCancellables.removeAll()
    }

    deinit {
        // cancellables automatically cleaned up
    }
}
```

### UIKit with Async/Await (Modern UIKit)

```swift
final class NotificationsViewController: UIViewController {
    private let viewModel: NotificationViewModel
    private var observationTask: Task<Void, Never>?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Equivalent to repeatOnLifecycle(STARTED)
        observationTask = Task { [weak self] in
            guard let stream = self?.viewModel.notificationStream else { return }
            for await notifications in stream {
                guard !Task.isCancelled else { break }
                self?.updateBadge(notifications.filter(\.isUnread).count)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Equivalent to lifecycle-driven cancellation
        observationTask?.cancel()
        observationTask = nil
    }
}
```

### Custom Lifecycle-Aware Component (Observer Pattern Equivalent)

```swift
// Equivalent to Android's DefaultLifecycleObserver for reusable components
protocol ViewLifecycleObserver: AnyObject {
    func onAppear()
    func onDisappear()
}

// SwiftUI ViewModifier that bridges to observer pattern
struct LifecycleObserverModifier: ViewModifier {
    let observer: ViewLifecycleObserver

    func body(content: Content) -> some View {
        content
            .onAppear { observer.onAppear() }
            .onDisappear { observer.onDisappear() }
    }
}

extension View {
    func observeLifecycle(_ observer: ViewLifecycleObserver) -> some View {
        modifier(LifecycleObserverModifier(observer: observer))
    }
}

// Usage — equivalent to lifecycle.addObserver(locationTracker)
struct MapView: View {
    @State private var locationTracker = LocationTracker()

    var body: some View {
        Map(coordinateRegion: $locationTracker.region)
            .observeLifecycle(locationTracker)
    }
}

final class LocationTracker: ViewLifecycleObserver {
    // ...
    func onAppear() { startUpdates() }
    func onDisappear() { stopUpdates() }
}
```

### Safe Collection with TaskGroup (Multiple Parallel Streams)

```swift
// Equivalent to multiple launch blocks inside repeatOnLifecycle
struct DashboardView: View {
    @State private var viewModel: DashboardViewModel

    var body: some View {
        dashboardContent
            .task {
                // All streams collected in parallel, all cancelled on disappear
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await viewModel.observeMetrics() }
                    group.addTask { await viewModel.observeAlerts() }
                    group.addTask { await viewModel.observeUserActivity() }
                }
            }
    }
}
```

## Migration Mapping Reference

| Android Concept | iOS SwiftUI | iOS UIKit |
|---|---|---|
| `DefaultLifecycleObserver` | `.onAppear` / `.onDisappear` modifiers | `viewWillAppear` / `viewWillDisappear` |
| `lifecycle.addObserver()` | `.observeLifecycle()` custom modifier | Manual registration in `viewDidLoad` |
| `repeatOnLifecycle(STARTED)` | `.task { }` | `Task` in `viewWillAppear`, cancel in `viewWillDisappear` |
| `flowWithLifecycle(STARTED)` | `.task { for await ... }` | Combine `.sink` in appear, cancel in disappear |
| Multiple `launch` in `repeatOnLifecycle` | Multiple `.task` or `withTaskGroup` | Multiple Combine pipelines |
| `lifecycleScope.launch` | `Task { }` (unstructured) or `.task` | `Task { }` |
| `viewLifecycleOwner.lifecycleScope` | View's `.task` scope | `Task` scoped to VC appear/disappear |
| `Lifecycle.State.STARTED` | View is on screen | `viewWillAppear` called |
| `Lifecycle.State.RESUMED` | `scenePhase == .active` | `applicationState == .active` |
| Automatic observer removal | `.task` auto-cancellation | Manual cancellation required |
| `lifecycle.currentState.isAtLeast(STARTED)` | No direct check needed | `isViewLoaded && view.window != nil` |

## Common Pitfalls

### 1. Not Cancelling Tasks in UIKit
SwiftUI's `.task` automatically cancels on disappear. In UIKit, you must manually cancel. Forgetting this causes the same bug as forgetting to remove a lifecycle observer on Android.

```swift
// BAD — task outlives the view controller
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    Task {
        for await msg in stream { handle(msg) } // Never cancelled
    }
}

// GOOD — store and cancel
private var streamTask: Task<Void, Never>?

override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    streamTask = Task { [weak self] in
        guard let stream = self?.viewModel.stream else { return }
        for await msg in stream {
            guard !Task.isCancelled else { break }
            self?.handle(msg)
        }
    }
}

override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    streamTask?.cancel()
}
```

### 2. Assuming .task Runs Only Once
`.task` runs each time the view appears (when attached to a view that appears/disappears). This matches `repeatOnLifecycle` semantics (restart on STARTED). If you need truly one-time work, gate it with a flag.

```swift
.task {
    // This runs every time the view appears — like repeatOnLifecycle
    // The previous task is cancelled on disappear, new one starts on reappear
    await viewModel.observe()
}
```

### 3. Using Combine Without Lifecycle Scoping in UIKit
Storing all subscriptions in a single `cancellables` set (cleared only in `deinit`) means subscriptions run even when the view is not visible. This is equivalent to collecting a Flow without `repeatOnLifecycle`.

```swift
// BAD — equivalent to lifecycleScope.launch without repeatOnLifecycle
override func viewDidLoad() {
    viewModel.$data
        .sink { [weak self] in self?.update($0) }
        .store(in: &cancellables) // Active even when view not visible
}

// GOOD — equivalent to repeatOnLifecycle(STARTED)
private var lifecycleCancellables = Set<AnyCancellable>()

override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    viewModel.$data
        .sink { [weak self] in self?.update($0) }
        .store(in: &lifecycleCancellables)
}

override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    lifecycleCancellables.removeAll() // Cancel all
}
```

### 4. Strong Reference Cycles in Closures
Android's `lifecycleScope` and `viewModelScope` use structured concurrency that avoids leaks. In iOS Combine pipelines and closures, always use `[weak self]` to avoid retain cycles.

### 5. Forgetting Task.isCancelled Checks
Swift's `Task` cancellation is cooperative. Long-running loops must check `Task.isCancelled` or use `try Task.checkCancellation()`. `for await` naturally handles this for `AsyncSequence`, but manual loops need explicit checks.

```swift
// AsyncSequence — cancellation handled automatically
.task {
    for await value in stream { /* cancelled when task is cancelled */ }
}

// Manual loop — must check cancellation
.task {
    while !Task.isCancelled {
        let data = await fetchData()
        updateUI(data)
        try? await Task.sleep(for: .seconds(5))
    }
}
```

## Migration Checklist

- [ ] Replace `DefaultLifecycleObserver` implementations with SwiftUI `.onAppear`/`.onDisappear` or custom `ViewLifecycleObserver` protocol
- [ ] Replace `repeatOnLifecycle(STARTED) { flow.collect {} }` with `.task { for await ... }`
- [ ] Replace `flowWithLifecycle` with `.task { for await value in stream {} }`
- [ ] Convert multiple `launch` blocks inside `repeatOnLifecycle` to multiple `.task` modifiers or `withTaskGroup`
- [ ] Replace `lifecycle.addObserver()` registration with SwiftUI modifiers
- [ ] In UIKit: store `Task` references and cancel in `viewWillDisappear`
- [ ] In UIKit: use separate `lifecycleCancellables` set for appear/disappear scoped subscriptions
- [ ] Ensure all Combine `.sink` closures use `[weak self]`
- [ ] Verify `Task.isCancelled` checks in manual loops
- [ ] Test view appear/disappear cycles to confirm subscriptions start and stop correctly
- [ ] Verify no work runs while the view is off-screen (background tab, popped from navigation)
