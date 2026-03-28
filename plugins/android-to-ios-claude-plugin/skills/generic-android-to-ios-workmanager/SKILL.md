---
name: generic-android-to-ios-workmanager
description: Use when migrating Android WorkManager (OneTimeWorkRequest, PeriodicWorkRequest, constraints, chaining, expedited work, CoroutineWorker) to iOS equivalents (BGTaskScheduler, BGAppRefreshTask, BGProcessingTask, Background URLSession) with scheduling strategies, constraint equivalents, and background work limitations
type: generic
---

# generic-android-to-ios-workmanager

## Context

Android's WorkManager provides a unified, reliable API for deferrable background work that survives process death and respects system constraints. It supports one-time and periodic tasks, work chaining, constraints (network, battery, storage), and expedited execution. iOS has no single equivalent; instead, background work is split across BGTaskScheduler (BGAppRefreshTask for short ~30s tasks, BGProcessingTask for longer operations), Background URLSession for network transfers, and limited silent-push-triggered processing. This skill maps WorkManager patterns to the correct combination of iOS APIs, including workarounds for iOS's stricter background execution limits.

## Android Best Practices (Source Patterns)

### OneTimeWorkRequest with Constraints

```kotlin
class SyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val userId = inputData.getString("user_id") ?: return Result.failure()
        return try {
            val syncResult = syncRepository.syncUserData(userId)
            val outputData = workDataOf("synced_count" to syncResult.count)
            Result.success(outputData)
        } catch (e: Exception) {
            if (runAttemptCount < 3) Result.retry() else Result.failure()
        }
    }
}

// Enqueuing with constraints
val constraints = Constraints.Builder()
    .setRequiredNetworkType(NetworkType.CONNECTED)
    .setRequiresBatteryNotLow(true)
    .setRequiresStorageNotLow(true)
    .build()

val syncRequest = OneTimeWorkRequestBuilder<SyncWorker>()
    .setConstraints(constraints)
    .setInputData(workDataOf("user_id" to userId))
    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
    .addTag("sync")
    .build()

WorkManager.getInstance(context).enqueueUniqueWork(
    "user_sync_$userId",
    ExistingWorkPolicy.REPLACE,
    syncRequest
)
```

### PeriodicWorkRequest

```kotlin
val periodicSync = PeriodicWorkRequestBuilder<PeriodicSyncWorker>(
    repeatInterval = 6, TimeUnit.HOURS,
    flexInterval = 30, TimeUnit.MINUTES
)
    .setConstraints(constraints)
    .addTag("periodic_sync")
    .build()

WorkManager.getInstance(context).enqueueUniquePeriodicWork(
    "periodic_sync",
    ExistingPeriodicWorkPolicy.KEEP,
    periodicSync
)
```

### Work Chaining

```kotlin
val downloadWork = OneTimeWorkRequestBuilder<DownloadWorker>().build()
val processWork = OneTimeWorkRequestBuilder<ProcessWorker>().build()
val uploadWork = OneTimeWorkRequestBuilder<UploadWorker>().build()

WorkManager.getInstance(context)
    .beginWith(downloadWork)
    .then(processWork)
    .then(uploadWork)
    .enqueue()

// Parallel then sequential
val download1 = OneTimeWorkRequestBuilder<DownloadWorker>()
    .setInputData(workDataOf("file" to "file1.json"))
    .build()
val download2 = OneTimeWorkRequestBuilder<DownloadWorker>()
    .setInputData(workDataOf("file" to "file2.json"))
    .build()

WorkManager.getInstance(context)
    .beginWith(listOf(download1, download2))
    .then(mergeWork)
    .enqueue()
```

### Expedited Work (Android 12+)

```kotlin
val urgentWork = OneTimeWorkRequestBuilder<UrgentSyncWorker>()
    .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
    .build()

class UrgentSyncWorker(context: Context, params: WorkerParameters)
    : CoroutineWorker(context, params) {

    override suspend fun getForegroundInfo(): ForegroundInfo {
        return ForegroundInfo(
            NOTIFICATION_ID,
            createNotification("Syncing...")
        )
    }

    override suspend fun doWork(): Result {
        // Critical sync work
        return Result.success()
    }
}
```

### Observing Work Status

```kotlin
WorkManager.getInstance(context)
    .getWorkInfoByIdLiveData(syncRequest.id)
    .observe(lifecycleOwner) { workInfo ->
        when (workInfo.state) {
            WorkInfo.State.ENQUEUED -> showPending()
            WorkInfo.State.RUNNING -> showProgress()
            WorkInfo.State.SUCCEEDED -> {
                val count = workInfo.outputData.getInt("synced_count", 0)
                showSuccess(count)
            }
            WorkInfo.State.FAILED -> showError()
            WorkInfo.State.CANCELLED -> showCancelled()
            else -> {}
        }
    }
```

## iOS Equivalent Patterns

### BGTaskScheduler: App Refresh Task (~30 seconds)

```swift
import BackgroundTasks

// 1. Register in AppDelegate or App init
// Info.plist: Add "BGTaskSchedulerPermittedIdentifiers" array with task identifiers

@main
struct MyApp: App {
    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.waonder.app.refresh",
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task {
                await self.handleAppRefresh(task: refreshTask)
            }
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.waonder.app.processing",
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            Task {
                await self.handleProcessing(task: processingTask)
            }
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) async {
        // Schedule the next refresh
        scheduleAppRefresh()

        let syncTask = Task {
            do {
                let result = try await SyncService.shared.syncUserData()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        // Handle expiration - iOS can cancel at any time
        task.expirationHandler = {
            syncTask.cancel()
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(
            identifier: "com.waonder.app.refresh"
        )
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600) // ~6 hours
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
}
```

### BGProcessingTask for Longer Work

```swift
func handleProcessing(task: BGProcessingTask) async {
    scheduleProcessingTask() // Re-schedule for next time

    let operation = Task {
        do {
            try await DatabaseMaintenance.shared.cleanupOldRecords()
            try await MediaCache.shared.optimizeStorage()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    task.expirationHandler = {
        operation.cancel()
    }
}

func scheduleProcessingTask() {
    let request = BGProcessingTaskRequest(
        identifier: "com.waonder.app.processing"
    )
    request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 3600)
    request.requiresNetworkConnectivity = true  // Constraint equivalent
    request.requiresExternalPower = false
    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        print("Could not schedule processing: \(error)")
    }
}
```

### Background URLSession (Network Transfer Equivalent)

```swift
// For reliable uploads/downloads that continue after app suspension
class BackgroundTransferManager: NSObject, URLSessionDownloadDelegate {
    static let shared = BackgroundTransferManager()

    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.waonder.app.background-transfer"
        )
        config.isDiscretionary = true // System chooses optimal time
        config.sessionSendsLaunchEvents = true // Re-launch app on completion
        config.allowsCellularAccess = true
        config.timeoutIntervalForResource = 24 * 3600
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func scheduleDownload(url: URL) -> URLSessionDownloadTask {
        let task = backgroundSession.downloadTask(with: url)
        task.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        task.countOfBytesClientExpectsToSend = 200
        task.countOfBytesClientExpectsToReceive = 5_000_000
        task.resume()
        return task
    }

    func scheduleUpload(request: URLRequest, fileURL: URL) -> URLSessionUploadTask {
        let task = backgroundSession.uploadTask(with: request, fromFile: fileURL)
        task.resume()
        return task
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Move file from tmp location to permanent storage
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first!
        let destinationURL = documentsURL.appendingPathComponent(
            downloadTask.originalRequest?.url?.lastPathComponent ?? "download"
        )
        try? FileManager.default.moveItem(at: location, to: destinationURL)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            print("Background transfer failed: \(error)")
        }
    }

    // Handle app re-launch for completed transfers
    func urlSessionDidFinishEvents(
        forBackgroundURLSession session: URLSession
    ) {
        DispatchQueue.main.async {
            // Call the stored completion handler from AppDelegate
            if let handler = AppDelegate.backgroundCompletionHandler {
                handler()
                AppDelegate.backgroundCompletionHandler = nil
            }
        }
    }
}

// In AppDelegate (UIKit) or via scene phase handling
class AppDelegate: NSObject, UIApplicationDelegate {
    static var backgroundCompletionHandler: (() -> Void)?

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        Self.backgroundCompletionHandler = completionHandler
        _ = BackgroundTransferManager.shared // Trigger lazy init to reconnect
    }
}
```

### Simulating Work Chaining on iOS

```swift
// iOS has no built-in work chaining; use structured concurrency
actor BackgroundWorkChain {
    enum WorkResult {
        case success(Data?)
        case failure(Error)
    }

    func executeChain(userId: String) async throws {
        // Sequential chain (like WorkManager .then())
        let downloadedData = try await downloadStep(userId: userId)
        let processedData = try await processStep(data: downloadedData)
        try await uploadStep(data: processedData)
    }

    func executeParallelThenMerge() async throws {
        // Parallel start then merge (like beginWith(listOf(...)).then())
        async let result1 = downloadStep(userId: "file1")
        async let result2 = downloadStep(userId: "file2")

        let (data1, data2) = try await (result1, result2)
        try await mergeStep(data1: data1, data2: data2)
    }

    private func downloadStep(userId: String) async throws -> Data {
        try await NetworkService.shared.download(path: "/users/\(userId)")
    }

    private func processStep(data: Data) async throws -> Data {
        try await DataProcessor.shared.process(data)
    }

    private func uploadStep(data: Data) async throws {
        try await NetworkService.shared.upload(data: data, path: "/sync")
    }

    private func mergeStep(data1: Data, data2: Data) async throws {
        try await DataProcessor.shared.merge(data1, data2)
    }
}
```

### Observing Background Task Status

```swift
import Combine

@Observable
class BackgroundTaskMonitor {
    var status: TaskStatus = .idle
    var lastSyncDate: Date?
    var syncedCount: Int = 0

    enum TaskStatus: Equatable {
        case idle
        case pending
        case running
        case succeeded
        case failed(String)
    }

    func performSync(userId: String) async {
        status = .running
        do {
            let result = try await SyncService.shared.syncUserData(userId: userId)
            syncedCount = result.count
            lastSyncDate = Date()
            status = .succeeded
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}

// In SwiftUI
struct SyncStatusView: View {
    @State private var monitor = BackgroundTaskMonitor()

    var body: some View {
        VStack {
            switch monitor.status {
            case .idle: Text("Ready to sync")
            case .pending: Text("Sync scheduled")
            case .running: ProgressView("Syncing...")
            case .succeeded: Text("Synced \(monitor.syncedCount) items")
            case .failed(let msg): Text("Error: \(msg)").foregroundStyle(.red)
            }
        }
    }
}
```

### Retry Logic (BackoffPolicy Equivalent)

```swift
struct RetryableTask {
    let maxAttempts: Int
    let initialDelay: TimeInterval
    let backoffMultiplier: Double

    func execute<T>(
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts - 1 {
                    let delay = initialDelay * pow(backoffMultiplier, Double(attempt))
                    try await Task.sleep(for: .seconds(delay))
                }
            }
        }

        throw lastError ?? CancellationError()
    }
}

// Usage - equivalent to EXPONENTIAL backoff starting at 30s
let retryable = RetryableTask(
    maxAttempts: 3,
    initialDelay: 30,
    backoffMultiplier: 2.0
)

try await retryable.execute {
    try await SyncService.shared.syncUserData(userId: userId)
}
```

## Constraint Mapping

| Android WorkManager Constraint | iOS Equivalent |
|-------------------------------|----------------|
| `NetworkType.CONNECTED` | `BGProcessingTaskRequest.requiresNetworkConnectivity = true` |
| `NetworkType.UNMETERED` | `URLSessionConfiguration.allowsCellularAccess = false` |
| `requiresBatteryNotLow()` | No direct equivalent; use `requiresExternalPower` for charging |
| `requiresCharging()` | `BGProcessingTaskRequest.requiresExternalPower = true` |
| `requiresStorageNotLow()` | No equivalent; check manually via `FileManager` |
| `requiresDeviceIdle()` | `URLSessionConfiguration.isDiscretionary = true` (system decides) |

## Common Pitfalls

1. **Assuming iOS background tasks always run** - BGTaskScheduler does not guarantee execution. The system decides when and if tasks run based on usage patterns, battery, and other factors. Always design for the task not running.

2. **Exceeding BGAppRefreshTask time** - Refresh tasks get roughly 30 seconds. Exceeding this causes the system to terminate your task and penalize future scheduling. For long operations, use BGProcessingTask.

3. **Not re-scheduling periodic tasks** - Unlike WorkManager's PeriodicWorkRequest, iOS BGTasks are one-shot. You must re-schedule the next occurrence inside the task handler itself.

4. **Forgetting Info.plist registration** - Every BGTask identifier must be listed in `BGTaskSchedulerPermittedIdentifiers` in Info.plist or the submission will silently fail.

5. **Not handling the expiration handler** - iOS calls `expirationHandler` when time is up. If you do not cancel work promptly, the system terminates your process and may reduce future background time.

6. **Using background URLSession for small requests** - Background URLSession has significant overhead. Only use it for large transfers that must survive app suspension. For small API calls, do them in foreground or during a BGTask window.

7. **Expecting work chaining to persist across launches** - Swift structured concurrency chains exist only in memory. If the app is terminated, the chain is lost. For critical multi-step workflows, persist progress to disk and resume.

## Migration Checklist

- [ ] Identify all WorkManager workers and classify them: short refresh (<30s) vs. long processing vs. network transfer
- [ ] Register all BGTask identifiers in Info.plist under `BGTaskSchedulerPermittedIdentifiers`
- [ ] Register task handlers in `AppDelegate.init()` or `App.init()` before app finishes launching
- [ ] Convert `CoroutineWorker.doWork()` to async functions with proper cancellation handling
- [ ] Implement `expirationHandler` for every BGTask to cancel in-flight work gracefully
- [ ] Replace `PeriodicWorkRequest` with self-re-scheduling BGTask calls inside each handler
- [ ] Replace work chaining with Swift structured concurrency (`async let`, sequential `await`)
- [ ] Persist intermediate chain results to disk for crash resilience
- [ ] Map constraints to `BGProcessingTaskRequest` properties and `URLSessionConfiguration`
- [ ] Replace `Result.retry()` with custom retry logic using exponential backoff
- [ ] Move large network transfers to Background URLSession instead of BGTask
- [ ] Handle `application(_:handleEventsForBackgroundURLSession:completionHandler:)` in AppDelegate
- [ ] Test background tasks using Xcode debug commands: `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"IDENTIFIER"]`
- [ ] Implement work status observation using `@Observable` or Combine publishers
- [ ] Add UserDefaults or database persistence for last-sync timestamps (replacing WorkInfo state)
- [ ] Verify task scheduling in `sceneDidEnterBackground` or `.background` scene phase
