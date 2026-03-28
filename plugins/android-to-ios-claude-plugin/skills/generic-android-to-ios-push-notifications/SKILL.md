---
name: generic-android-to-ios-push-notifications
description: Use when migrating Android FCM push notifications (FirebaseMessagingService, token management, data/notification messages, channels, notification importance) to iOS APNs + UNUserNotificationCenter (UNNotificationServiceExtension, rich notifications, categories, provisional authorization) with payload differences, silent push, and token registration
type: generic
---

# generic-android-to-ios-push-notifications

## Context

Android push notifications rely on Firebase Cloud Messaging (FCM) with a service-based architecture: `FirebaseMessagingService` handles incoming messages and token refresh, notification channels control presentation, and data messages enable background processing. iOS uses Apple Push Notification service (APNs) as the transport layer, with `UNUserNotificationCenter` for presentation and `UNNotificationServiceExtension` for rich notification modification. While FCM can be used as a cross-platform abstraction, iOS still requires APNs configuration, explicit user permission, and category-based actions instead of channels. This skill maps Android FCM patterns to their iOS equivalents, covering token management, payload structure, rich notifications, and silent push.

## Android Best Practices (Source Patterns)

### FirebaseMessagingService

```kotlin
class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        // Send token to your backend
        CoroutineScope(Dispatchers.IO).launch {
            tokenRepository.registerToken(token)
        }
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        // Data message - always received (foreground and background)
        remoteMessage.data.let { data ->
            when (data["type"]) {
                "chat" -> handleChatMessage(data)
                "sync" -> triggerBackgroundSync(data)
                "update" -> handleAppUpdate(data)
            }
        }

        // Notification message - only received here if app is in foreground
        remoteMessage.notification?.let { notification ->
            showCustomNotification(
                title = notification.title ?: "",
                body = notification.body ?: "",
                data = remoteMessage.data
            )
        }
    }

    private fun showCustomNotification(
        title: String,
        body: String,
        data: Map<String, String>
    ) {
        val channelId = data["channel"] ?: "default"
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("notification_data", Bundle().apply {
                data.forEach { (k, v) -> putString(k, v) }
            })
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(this).notify(
            System.currentTimeMillis().toInt(),
            notification
        )
    }
}
```

### Notification Channels (Android 8+)

```kotlin
class NotificationChannelManager(private val context: Context) {

    fun createChannels() {
        val channels = listOf(
            NotificationChannel(
                "messages",
                "Messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Chat message notifications"
                enableVibration(true)
                enableLights(true)
                lightColor = Color.BLUE
            },
            NotificationChannel(
                "updates",
                "App Updates",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Application update notifications"
            },
            NotificationChannel(
                "promotions",
                "Promotions",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Promotional offers"
            }
        )

        val manager = context.getSystemService(NotificationManager::class.java)
        channels.forEach { manager.createNotificationChannel(it) }
    }
}
```

### Token Management

```kotlin
class TokenRepository @Inject constructor(
    private val api: PushTokenApi,
    private val dataStore: DataStore<Preferences>
) {
    suspend fun registerToken(token: String) {
        val previousToken = dataStore.data.first()[PUSH_TOKEN_KEY]
        if (token != previousToken) {
            api.registerToken(token)
            dataStore.edit { it[PUSH_TOKEN_KEY] = token }
        }
    }

    suspend fun getCurrentToken(): String {
        return FirebaseMessaging.getInstance().token.await()
    }

    suspend fun unregisterToken() {
        FirebaseMessaging.getInstance().deleteToken().await()
        dataStore.edit { it.remove(PUSH_TOKEN_KEY) }
    }

    companion object {
        private val PUSH_TOKEN_KEY = stringPreferencesKey("push_token")
    }
}
```

### Topic Subscription

```kotlin
FirebaseMessaging.getInstance().subscribeToTopic("news").await()
FirebaseMessaging.getInstance().unsubscribeFromTopic("news").await()
```

### Data vs Notification Messages

```json
// Data message (handled by app in all states)
{
  "to": "device_token",
  "data": {
    "type": "chat",
    "senderId": "123",
    "message": "Hello!"
  }
}

// Notification message (system handles when app in background)
{
  "to": "device_token",
  "notification": {
    "title": "New Message",
    "body": "You have a new message",
    "channel_id": "messages"
  },
  "data": {
    "type": "chat",
    "senderId": "123"
  }
}
```

## iOS Equivalent Patterns

### Permission Request and Registration

```swift
import UserNotifications
import FirebaseMessaging

@Observable
class PushNotificationManager: NSObject {
    var isAuthorized = false
    var deviceToken: String?

    func requestPermission() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(
            options: [.alert, .badge, .sound, .provisional] // .provisional = no prompt
        )
        isAuthorized = granted

        if granted {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        return granted
    }

    func checkCurrentStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
}
```

### AppDelegate Setup for APNs + FCM

```swift
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate,
                   MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        return true
    }

    // APNs token received from system
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Pass APNs token to FCM - it maps to an FCM token
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }

    // MARK: - MessagingDelegate (FCM token)

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let token = fcmToken else { return }
        // Send to your backend - equivalent to onNewToken()
        Task {
            await TokenRepository.shared.registerToken(token)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Called when notification arrives while app is in FOREGROUND
    // Equivalent to onMessageReceived() for notification messages
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo

        // Process the data payload
        handleIncomingNotification(userInfo: userInfo)

        // Return how to present (banner, sound, badge, list)
        return [.banner, .sound, .badge, .list]
    }

    // Called when user TAPS on notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            handleNotificationTap(userInfo: userInfo)
        case "REPLY_ACTION":
            if let textResponse = response as? UNTextInputNotificationResponse {
                handleReply(text: textResponse.userText, userInfo: userInfo)
            }
        case UNNotificationDismissActionIdentifier:
            break
        default:
            handleCustomAction(actionIdentifier, userInfo: userInfo)
        }
    }

    private func handleIncomingNotification(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }
        switch type {
        case "chat": NotificationRouter.shared.handleChat(userInfo)
        case "sync": SyncService.shared.triggerSync()
        case "update": NotificationRouter.shared.handleUpdate(userInfo)
        default: break
        }
    }

    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        NotificationRouter.shared.navigateTo(userInfo: userInfo)
    }

    private func handleReply(text: String, userInfo: [AnyHashable: Any]) {
        Task { await ChatService.shared.sendReply(text, context: userInfo) }
    }

    private func handleCustomAction(_ action: String, userInfo: [AnyHashable: Any]) {
        NotificationRouter.shared.handleAction(action, userInfo: userInfo)
    }
}
```

### Notification Categories (Channel Equivalent)

```swift
// Categories define actions and behavior - closest equivalent to Android channels
// but they do NOT control importance/sound like channels do

class NotificationCategoryManager {
    static func registerCategories() {
        // Messages category with inline reply
        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_ACTION",
            title: "Reply",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type a message..."
        )
        let markReadAction = UNNotificationAction(
            identifier: "MARK_READ_ACTION",
            title: "Mark as Read",
            options: []
        )
        let messagesCategory = UNNotificationCategory(
            identifier: "MESSAGES",
            actions: [replyAction, markReadAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "New message",
            categorySummaryFormat: "%u new messages",
            options: [.customDismissAction]
        )

        // Updates category
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "View",
            options: [.foreground]
        )
        let updatesCategory = UNNotificationCategory(
            identifier: "UPDATES",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        // Promotions category (minimal actions)
        let promotionsCategory = UNNotificationCategory(
            identifier: "PROMOTIONS",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            messagesCategory,
            updatesCategory,
            promotionsCategory
        ])
    }
}
```

### Token Management

```swift
actor TokenRepository {
    static let shared = TokenRepository()

    private let tokenKey = "push_token"

    func registerToken(_ token: String) async {
        let previousToken = UserDefaults.standard.string(forKey: tokenKey)
        if token != previousToken {
            do {
                try await PushTokenAPI.shared.register(token: token)
                UserDefaults.standard.set(token, forKey: tokenKey)
            } catch {
                print("Failed to register token: \(error)")
            }
        }
    }

    func getCurrentToken() async throws -> String {
        try await Messaging.messaging().token()
    }

    func deleteToken() async throws {
        try await Messaging.messaging().deleteToken()
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}
```

### Topic Subscription

```swift
try await Messaging.messaging().subscribe(toTopic: "news")
try await Messaging.messaging().unsubscribe(fromTopic: "news")
```

### Rich Notifications (Notification Service Extension)

```swift
// 1. Add a new target: File > New > Target > Notification Service Extension

// NotificationService.swift (in the extension target)
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // Download and attach image
        if let imageURLString = content.userInfo["image_url"] as? String,
           let imageURL = URL(string: imageURLString) {
            downloadImage(from: imageURL) { attachment in
                if let attachment {
                    content.attachments = [attachment]
                }
                contentHandler(content)
            }
        } else {
            contentHandler(content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension is terminated
        if let content = bestAttemptContent, let handler = contentHandler {
            handler(content)
        }
    }

    private func downloadImage(
        from url: URL,
        completion: @escaping (UNNotificationAttachment?) -> Void
    ) {
        URLSession.shared.downloadTask(with: url) { localURL, _, error in
            guard let localURL, error == nil else {
                completion(nil)
                return
            }
            let tmpDir = FileManager.default.temporaryDirectory
            let tmpFile = tmpDir.appendingPathComponent(UUID().uuidString + ".jpg")
            try? FileManager.default.moveItem(at: localURL, to: tmpFile)
            let attachment = try? UNNotificationAttachment(
                identifier: "image",
                url: tmpFile,
                options: nil
            )
            completion(attachment)
        }.resume()
    }
}
```

### Silent Push (Background Data Fetch)

```swift
// APNs payload for silent push:
// { "aps": { "content-available": 1 }, "type": "sync", "data": {...} }

// In AppDelegate:
func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any]
) async -> UIBackgroundFetchResult {
    guard let type = userInfo["type"] as? String else {
        return .noData
    }

    switch type {
    case "sync":
        do {
            let hasNewData = try await SyncService.shared.performBackgroundSync()
            return hasNewData ? .newData : .noData
        } catch {
            return .failed
        }
    default:
        return .noData
    }
}

// Enable in Capabilities: Background Modes > Remote notifications
```

### APNs Payload Structure (vs FCM)

```json
// iOS APNs payload (sent from server)
{
  "aps": {
    "alert": {
      "title": "New Message",
      "subtitle": "From John",
      "body": "Hey, are you free tonight?"
    },
    "badge": 5,
    "sound": "default",
    "category": "MESSAGES",
    "mutable-content": 1,
    "thread-id": "chat-123",
    "interruption-level": "time-sensitive"
  },
  "type": "chat",
  "senderId": "123",
  "image_url": "https://example.com/photo.jpg"
}

// Silent push payload
{
  "aps": {
    "content-available": 1
  },
  "type": "sync",
  "syncId": "abc123"
}
```

## Payload and Concept Mapping

| Android FCM | iOS APNs |
|------------|----------|
| `notification.title` | `aps.alert.title` |
| `notification.body` | `aps.alert.body` |
| `notification.channel_id` | `aps.category` (for actions, not presentation) |
| `data` payload | Custom keys at root level of payload |
| `IMPORTANCE_HIGH` | `aps.interruption-level: "time-sensitive"` |
| `IMPORTANCE_DEFAULT` | `aps.interruption-level: "active"` (default) |
| `IMPORTANCE_LOW` | `aps.interruption-level: "passive"` |
| Notification channel sound | `aps.sound` (per notification, not per channel) |
| `notification.tag` (grouping) | `aps.thread-id` |
| Data-only message | Payload with only `aps.content-available: 1` |
| `FirebaseMessaging.getInstance().token` | `Messaging.messaging().token()` |
| Topic subscription | Same API: `Messaging.messaging().subscribe(toTopic:)` |

## Common Pitfalls

1. **Not requesting permission before registering** - iOS requires explicit user permission (`UNUserNotificationCenter.requestAuthorization`). Unlike Android (pre-13), notifications are opt-in from the start.

2. **Forgetting to set APNs token on Messaging** - FCM on iOS needs the raw APNs device token. If you handle `didRegisterForRemoteNotificationsWithDeviceToken`, you must pass it to `Messaging.messaging().apnsToken`.

3. **Expecting data-only messages to always wake the app** - iOS throttles silent push notifications. If the system determines the app uses too much background time, silent pushes are depressed. Always include visible notification as fallback for critical updates.

4. **Not setting mutable-content for rich notifications** - The Notification Service Extension only fires when `mutable-content: 1` is in the APNs payload. Without it, images and modifications are not applied.

5. **Confusing categories with channels** - Android channels control importance, sound, and vibration at the OS level. iOS categories only define actions. Sound, badge, and interruption level are per-notification in the payload.

6. **Not handling provisional authorization** - iOS 12+ supports `.provisional` authorization that delivers notifications quietly to the notification center without prompting the user. This is useful for onboarding but must be handled in the UX.

7. **Forgetting Background Modes capability** - Silent push requires "Remote notifications" checked in Background Modes. Without it, `didReceiveRemoteNotification` is not called in the background.

8. **Not adding Notification Service Extension to the same App Group** - If the extension needs to share data with the main app (e.g., for encryption keys or user preferences), both targets must be in the same App Group.

## Migration Checklist

- [ ] Enable Push Notifications capability in Xcode project settings
- [ ] Enable Background Modes > Remote Notifications for silent push
- [ ] Configure APNs key or certificate in Firebase Console (Settings > Cloud Messaging)
- [ ] Set up `UNUserNotificationCenter.delegate` and `Messaging.delegate` in AppDelegate
- [ ] Implement permission request flow with fallback for denied state
- [ ] Pass APNs device token to `Messaging.messaging().apnsToken`
- [ ] Implement `messaging(_:didReceiveRegistrationToken:)` for FCM token management
- [ ] Implement `willPresent` delegate for foreground notification display
- [ ] Implement `didReceive` response delegate for notification tap handling
- [ ] Register notification categories with actions (replacing Android channels for interaction)
- [ ] Create Notification Service Extension target for rich notifications (images, modifications)
- [ ] Update server payloads to include APNs-specific fields (`aps`, `mutable-content`, `category`, `thread-id`)
- [ ] Implement silent push handler for background data sync
- [ ] Map Android notification importance levels to iOS `interruption-level` in payloads
- [ ] Replace Android notification channel grouping with `thread-id` for notification threading
- [ ] Test with both FCM-routed and direct APNs payloads
- [ ] Handle notification tap deep linking via `userInfo` parsing in `didReceive` response
- [ ] Test notification delivery in all app states: foreground, background, terminated
