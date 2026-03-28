---
name: generic-android-to-ios-services
description: Use when migrating Android Service patterns (started, bound, foreground services, WorkManager) to iOS Background Modes, BGTaskScheduler, Background URLSession, and platform-specific alternatives
type: generic
---

# generic-android-to-ios-services

## Context

Android's `Service` is a component that runs operations in the background without a UI. Android supports started services, bound services, and foreground services (with persistent notifications). `WorkManager` handles deferrable, guaranteed background work. iOS has no direct `Service` equivalent. iOS is fundamentally more restrictive about background execution, offering specific background modes (audio, location, VOIP, etc.), `BGTaskScheduler` for deferred tasks, and background `URLSession` for downloads/uploads. This skill covers the complete mapping from Android background execution patterns to their iOS equivalents, including the critical limitations imposed by iOS.

## Concept Mapping

| Android | iOS |
|---|---|
| `Service` (started) | No direct equivalent; use background modes or `BGTaskScheduler` |
| `Service` (bound) | No equivalent; use in-process `@Observable` objects or actors |
| Foreground Service | Background mode (audio, location, VOIP, etc.) with active session |
| `IntentService` / coroutine in Service | `.task {}` with `URLSession` / background `URLSession` |
| `WorkManager` (one-time) | `BGProcessingTask` via `BGTaskScheduler` |
| `WorkManager` (periodic) | `BGAppRefreshTask` via `BGTaskScheduler` |
| `WorkManager` constraints (network, charging) | `BGProcessingTaskRequest` with `requiresNetworkConnectivity` / `requiresExternalPower` |
| `JobScheduler` | `BGTaskScheduler` |
| `AlarmManager` | `UNNotificationRequest` (for user-facing) / `BGTaskScheduler` |
| `startForeground()` + notification | Background mode + active session (e.g., `AVAudioSession`) |
| `Notification` (ongoing) | Live Activity / Dynamic Island (iOS 16.1+) |
| `stopSelf()` / `stopService()` | End background session / task completion |
| `ServiceConnection` (bound) | Direct object reference (in-process only) |

## Code Patterns

### Started Service to iOS Background Task

**Android:**
```kotlin
class DataSyncService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        CoroutineScope(Dispatchers.IO).launch {
            performSync()
            stopSelf(startId)
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private suspend fun performSync() {
        // Sync data with server
    }
}

// Start it
context.startService(Intent(context, DataSyncService::class.java))
```

**iOS (BGTaskScheduler):**
```swift
import BackgroundTasks

// 1. Register in App init or AppDelegate
@main
struct MyApp: App {
    init() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.myapp.datasync",
            using: nil
        ) { task in
            handleDataSync(task: task as! BGProcessingTask)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        scheduleDataSync()
                    }
                }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
}

// 2. Schedule the task
func scheduleDataSync() {
    let request = BGProcessingTaskRequest(identifier: "com.myapp.datasync")
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        print("Failed to schedule background task: \(error)")
    }
}

// 3. Handle the task
func handleDataSync(task: BGProcessingTask) {
    // Schedule the next sync
    scheduleDataSync()

    let syncTask = Task {
        do {
            try await DataSyncManager.shared.performSync()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    // Handle expiration
    task.expirationHandler = {
        syncTask.cancel()
    }
}

// 4. Add to Info.plist:
// <key>BGTaskSchedulerPermittedIdentifiers</key>
// <array>
//     <string>com.myapp.datasync</string>
// </array>
```

### Foreground Service: Music Playback

**Android:**
```kotlin
class MusicService : Service() {
    private var mediaPlayer: MediaPlayer? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Now Playing")
            .setContentText("Song Title")
            .setSmallIcon(R.drawable.ic_music)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        mediaPlayer = MediaPlayer().apply {
            setDataSource(intent?.getStringExtra("url"))
            prepare()
            start()
        }

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        mediaPlayer?.release()
        super.onDestroy()
    }
}
```

**iOS:**
```swift
import AVFoundation
import MediaPlayer

@Observable
final class MusicPlayerService {
    static let shared = MusicPlayerService()

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?

    func startPlayback(url: URL) {
        // Configure audio session for background playback
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
            return
        }

        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.play()

        // Set up Now Playing info (equivalent to notification)
        updateNowPlayingInfo(title: "Song Title", artist: "Artist Name")

        // Set up remote command center (lock screen controls)
        setupRemoteCommands()
    }

    func stopPlayback() {
        player?.pause()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func updateNowPlayingInfo(title: String, artist: String) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            return .success
        }
    }
}

// Enable "Audio, AirPlay, and Picture in Picture" in Background Modes capability
// Info.plist:
// <key>UIBackgroundModes</key>
// <array>
//     <string>audio</string>
// </array>
```

### Foreground Service: Location Tracking

**Android:**
```kotlin
class LocationService : Service() {
    private lateinit var fusedLocationClient: FusedLocationProviderClient

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Tracking Location")
            .setSmallIcon(R.drawable.ic_location)
            .setForegroundServiceType(ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            .build()
        startForeground(NOTIFICATION_ID, notification)

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY, 5000L
        ).build()

        fusedLocationClient.requestLocationUpdates(
            locationRequest,
            locationCallback,
            Looper.getMainLooper()
        )

        return START_STICKY
    }

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            result.lastLocation?.let { location ->
                // Process location update
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
```

**iOS:**
```swift
import CoreLocation

@Observable
final class LocationTrackingService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationTrackingService()

    private let locationManager = CLLocationManager()
    var currentLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // meters
        // Required for background location
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
    }

    func startTracking() {
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
    }

    // CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        // Process location update
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}

// Enable "Location updates" in Background Modes capability
// Info.plist:
// <key>UIBackgroundModes</key>
// <array>
//     <string>location</string>
// </array>
// <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
// <string>We need your location to track your route.</string>
// <key>NSLocationWhenInUseUsageDescription</key>
// <string>We need your location to show nearby places.</string>
```

### WorkManager Periodic Work

**Android:**
```kotlin
class PeriodicSyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        return try {
            SyncRepository().performSync()
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}

// Schedule periodic work
val syncRequest = PeriodicWorkRequestBuilder<PeriodicSyncWorker>(
    repeatInterval = 1, repeatIntervalTimeUnit = TimeUnit.HOURS
)
    .setConstraints(
        Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
    )
    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 10, TimeUnit.MINUTES)
    .build()

WorkManager.getInstance(context).enqueueUniquePeriodicWork(
    "periodic_sync",
    ExistingPeriodicWorkPolicy.KEEP,
    syncRequest
)
```

**iOS (BGAppRefreshTask):**
```swift
// 1. Register in App init
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.myapp.refresh",
    using: nil
) { task in
    handleAppRefresh(task: task as! BGAppRefreshTask)
}

// 2. Schedule (call when entering background)
func scheduleAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.myapp.refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour

    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        print("Failed to schedule refresh: \(error)")
    }
}

// 3. Handle
func handleAppRefresh(task: BGAppRefreshTask) {
    // Schedule the next refresh immediately
    scheduleAppRefresh()

    let refreshTask = Task {
        do {
            try await SyncRepository.shared.performSync()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    task.expirationHandler = {
        refreshTask.cancel()
    }
}

// Info.plist:
// <key>BGTaskSchedulerPermittedIdentifiers</key>
// <array>
//     <string>com.myapp.refresh</string>
// </array>
```

### Bound Service to In-Process Observable

**Android:**
```kotlin
class DownloadService : Service() {
    private val binder = DownloadBinder()
    var progress: Float = 0f
        private set

    inner class DownloadBinder : Binder() {
        fun getService(): DownloadService = this@DownloadService
    }

    override fun onBind(intent: Intent): IBinder = binder

    fun startDownload(url: String) {
        CoroutineScope(Dispatchers.IO).launch {
            // Download with progress updates
            progress = 0.5f
            // ...
            progress = 1.0f
        }
    }
}

// Bind in Activity
val connection = object : ServiceConnection {
    override fun onServiceConnected(name: ComponentName, service: IBinder) {
        val downloadService = (service as DownloadService.DownloadBinder).getService()
        downloadService.startDownload("https://...")
    }
    override fun onServiceDisconnected(name: ComponentName) { }
}
bindService(intent, connection, Context.BIND_AUTO_CREATE)
```

**iOS (in-process @Observable -- no IPC needed):**
```swift
@Observable
final class DownloadService {
    static let shared = DownloadService()

    var progress: Double = 0
    var isDownloading = false

    func startDownload(url: URL) async throws {
        isDownloading = true
        progress = 0

        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
        let totalBytes = Double(response.expectedContentLength)
        var receivedBytes: Double = 0
        var data = Data()

        for try await byte in asyncBytes {
            data.append(byte)
            receivedBytes += 1
            await MainActor.run {
                progress = receivedBytes / totalBytes
            }
        }

        await MainActor.run {
            isDownloading = false
            progress = 1.0
        }
    }
}

// Use in SwiftUI
struct DownloadView: View {
    @State private var downloadService = DownloadService.shared

    var body: some View {
        VStack {
            ProgressView(value: downloadService.progress)
            Button("Download") {
                Task {
                    try? await downloadService.startDownload(
                        url: URL(string: "https://example.com/file.zip")!
                    )
                }
            }
        }
    }
}
```

### Background URLSession (Large Downloads/Uploads)

**iOS (equivalent to Android DownloadManager / foreground service for downloads):**
```swift
final class BackgroundDownloadManager: NSObject, URLSessionDownloadDelegate {
    static let shared = BackgroundDownloadManager()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.myapp.background-download"
        )
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func startDownload(url: URL) {
        let task = session.downloadTask(with: url)
        task.resume()
    }

    // Called when download completes (even if app was terminated)
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Move file from temp location to permanent storage
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first!
        let destinationURL = documentsURL.appendingPathComponent("downloaded_file")

        try? FileManager.default.moveItem(at: location, to: destinationURL)
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        // Update UI via notification or delegate
    }
}

// In AppDelegate, handle background session completion
func application(_ application: UIApplication,
                 handleEventsForBackgroundURLSession identifier: String,
                 completionHandler: @escaping () -> Void) {
    BackgroundDownloadManager.shared.backgroundCompletionHandler = completionHandler
}
```

## iOS Background Execution Modes Reference

| Background Mode | Purpose | Time Limit |
|---|---|---|
| `audio` | Music/podcast playback | Unlimited while playing |
| `location` | GPS tracking | Unlimited while tracking |
| `voip` | VoIP calls (PushKit) | Unlimited during call |
| `fetch` | Periodic data refresh | ~30 seconds |
| `processing` | Long tasks (ML, sync) | Minutes (system-determined) |
| `remote-notification` | Silent push processing | ~30 seconds |
| `bluetooth-central` | BLE communication | Unlimited while connected |
| `bluetooth-peripheral` | BLE advertising | Unlimited while active |
| `external-accessory` | Hardware accessories | Unlimited while connected |

## Best Practices

1. **Accept that iOS is more restrictive** -- There is no way to run arbitrary long-running background services on iOS. Design your architecture around the available background modes and accept the platform constraints.
2. **Use background URLSession for network transfers** -- This is the only reliable way to perform large uploads/downloads in the background on iOS. The system manages the transfer even if the app is terminated.
3. **Use BGTaskScheduler for deferred work** -- Replace `WorkManager` with `BGProcessingTask` (long tasks) or `BGAppRefreshTask` (periodic refresh). Note that the system determines actual execution time.
4. **Use push notifications to trigger background work** -- Silent push notifications (`content-available: 1`) can wake the app briefly to fetch new data. This is more reliable than BGAppRefreshTask for time-sensitive updates.
5. **Replace bound services with in-process objects** -- iOS apps are single-process. Use `@Observable` objects, actors, or singletons instead of IPC-based bound services.
6. **Request only the background modes you need** -- Apple reviews apps that use background modes. Requesting `location` or `audio` without a legitimate use case will result in App Store rejection.
7. **Use `beginBackgroundTask` for short extensions** -- When your app enters the background and needs a few extra seconds to complete work, use `UIApplication.shared.beginBackgroundTask` (up to ~30 seconds).

## Common Pitfalls

- **Expecting services to run indefinitely** -- iOS aggressively suspends apps. Only specific background modes (audio, location, VOIP, BLE) allow continuous execution, and only while actively performing that function.
- **BGTaskScheduler timing is not precise** -- The system decides when to run background tasks based on usage patterns, battery, network conditions, etc. A task scheduled for 1 hour may not run for several hours.
- **Background URLSession requires delegate, not completion handlers** -- You must use `URLSessionDownloadDelegate` methods, not async/await or completion handler APIs, for background transfers.
- **App termination during background work** -- iOS can terminate your app at any time. Background URLSession survives this; BGTaskScheduler does not. Design for crash recovery.
- **Foreground service notification has no direct equivalent** -- iOS uses the blue bar (location), status bar indicators, or Live Activities instead of persistent notifications. You cannot show a permanent notification while running background work.
- **`beginBackgroundTask` is not a background service** -- It only extends your app's execution by ~30 seconds when transitioning to the background. It is not a mechanism for long-running work.

## Migration Checklist

- [ ] Audit all Android Services and categorize: network transfer, computation, sensor tracking, media playback, IPC
- [ ] Replace long-running foreground services with appropriate iOS background modes (audio, location, VOIP, BLE)
- [ ] Replace `WorkManager` one-time tasks with `BGProcessingTask`
- [ ] Replace `WorkManager` periodic tasks with `BGAppRefreshTask`
- [ ] Replace download/upload services with background `URLSession`
- [ ] Replace bound services with in-process `@Observable` objects or actors
- [ ] Replace `IntentService` / coroutine services with `.task {}` or structured concurrency
- [ ] Add required background mode capabilities in Xcode project settings
- [ ] Add `BGTaskSchedulerPermittedIdentifiers` to Info.plist
- [ ] Add required usage description strings (location, microphone, etc.) to Info.plist
- [ ] Implement `beginBackgroundTask` for short cleanup work on app backgrounding
- [ ] Replace `AlarmManager` exact alarms with `UNNotificationRequest` for user-facing reminders
- [ ] Test background execution on real devices (simulator does not accurately simulate background behavior)
- [ ] Verify App Store compliance for all claimed background modes
