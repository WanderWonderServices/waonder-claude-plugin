---
name: generic-android-to-ios-app-shortcuts
description: Guides migration of Android app shortcut patterns (ShortcutManager with static/dynamic/pinned shortcuts, shortcut intents, ranking) to iOS equivalents (Quick Actions via UIApplicationShortcutItem, App Intents framework, Spotlight via CSSearchableItem, Siri Shortcuts) covering home screen shortcuts, voice-triggered actions, search integration, and intent-based actions
type: generic
---

# generic-android-to-ios-app-shortcuts

## Context

Android's `ShortcutManager` provides static, dynamic, and pinned shortcuts that appear in the launcher's long-press menu and can be dragged to the home screen. iOS has a broader but different set of mechanisms: Quick Actions (3D Touch / Haptic Touch long-press on app icon), the App Intents framework (Siri, Shortcuts app, Spotlight), and `CSSearchableItem` for Spotlight indexing. There is no single 1:1 mapping — Android shortcuts map to different iOS features depending on their purpose. This skill covers all pathways.

## Android Best Practices (Source Patterns)

### Static Shortcuts (XML-defined)

```xml
<!-- res/xml/shortcuts.xml -->
<shortcuts xmlns:android="http://schemas.android.com/apk/res/android">
    <shortcut
        android:shortcutId="new_message"
        android:enabled="true"
        android:icon="@drawable/ic_message"
        android:shortcutShortLabel="@string/new_message_short"
        android:shortcutLongLabel="@string/new_message_long">
        <intent
            android:action="android.intent.action.VIEW"
            android:targetPackage="com.example.app"
            android:targetClass=".NewMessageActivity" />
        <categories android:name="android.shortcut.conversation" />
        <capability-binding android:key="actions.intent.CREATE_MESSAGE" />
    </shortcut>
</shortcuts>
```

```xml
<!-- AndroidManifest.xml -->
<activity android:name=".MainActivity">
    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>
    <meta-data
        android:name="android.app.shortcuts"
        android:resource="@xml/shortcuts" />
</activity>
```

### Dynamic Shortcuts

```kotlin
class ShortcutRepository(private val context: Context) {

    private val shortcutManager = context.getSystemService(ShortcutManager::class.java)

    fun updateDynamicShortcuts(recentContacts: List<Contact>) {
        val shortcuts = recentContacts.take(4).map { contact ->
            ShortcutInfo.Builder(context, "contact_${contact.id}")
                .setShortLabel(contact.name)
                .setLongLabel("Message ${contact.name}")
                .setIcon(Icon.createWithResource(context, R.drawable.ic_person))
                .setIntent(Intent(Intent.ACTION_VIEW).apply {
                    setClass(context, ChatActivity::class.java)
                    putExtra("contact_id", contact.id)
                })
                .setRank(contact.rank)
                .setCategories(setOf("com.example.category.CHAT"))
                .build()
        }
        shortcutManager?.dynamicShortcuts = shortcuts
    }

    fun removeShortcut(id: String) {
        shortcutManager?.removeDynamicShortcuts(listOf(id))
    }

    fun reportShortcutUsed(id: String) {
        shortcutManager?.reportShortcutUsed(id)
    }
}
```

### Pinned Shortcuts

```kotlin
fun pinShortcut(context: Context, contact: Contact) {
    val shortcutManager = context.getSystemService(ShortcutManager::class.java)
    if (shortcutManager?.isRequestPinShortcutSupported == true) {
        val shortcut = ShortcutInfo.Builder(context, "pinned_${contact.id}")
            .setShortLabel(contact.name)
            .setIntent(Intent(Intent.ACTION_VIEW).apply {
                setClass(context, ChatActivity::class.java)
                putExtra("contact_id", contact.id)
            })
            .build()

        val callbackIntent = shortcutManager.createShortcutResultIntent(shortcut)
        val pendingIntent = PendingIntent.getBroadcast(
            context, 0, callbackIntent, PendingIntent.FLAG_IMMUTABLE
        )
        shortcutManager.requestPinShortcut(shortcut, pendingIntent.intentSender)
    }
}
```

### Key Android Patterns to Recognize

- `ShortcutManager.dynamicShortcuts` — runtime-managed launcher shortcuts (max ~15)
- `ShortcutInfo.Builder` — fluent builder for shortcut metadata
- `setRank()` — ordering priority for shortcuts
- `reportShortcutUsed()` — usage tracking for prediction/ranking
- `requestPinShortcut()` — places shortcut on home screen
- Static shortcuts in `res/xml/shortcuts.xml` — defined at compile time
- `capability-binding` — ties shortcuts to Google Assistant actions

## iOS Best Practices (Target Patterns)

### Quick Actions (Home Screen Shortcuts)

```swift
// Static Quick Actions — defined in Info.plist
// <key>UIApplicationShortcutItems</key>
// <array>
//     <dict>
//         <key>UIApplicationShortcutItemType</key>
//         <string>com.myapp.newMessage</string>
//         <key>UIApplicationShortcutItemTitle</key>
//         <string>New Message</string>
//         <key>UIApplicationShortcutItemSubtitle</key>
//         <string>Start a new conversation</string>
//         <key>UIApplicationShortcutItemIconType</key>
//         <string>UIApplicationShortcutIconTypeCompose</string>
//     </dict>
// </array>

// Dynamic Quick Actions — set at runtime
import UIKit

class QuickActionManager {
    static func updateShortcuts(recentContacts: [Contact]) {
        UIApplication.shared.shortcutItems = recentContacts.prefix(4).map { contact in
            UIApplicationShortcutItem(
                type: "com.myapp.openChat",
                localizedTitle: contact.name,
                localizedSubtitle: "Message \(contact.name)",
                icon: UIApplicationShortcutIcon(systemImageName: "person.circle"),
                userInfo: ["contactID": contact.id as NSSecureCoding]
            )
        }
    }
}

// Handle Quick Action in SwiftUI App lifecycle
@main
struct MyApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onContinueUserActivity(
                    "com.myapp.openChat",
                    perform: handleQuickAction
                )
        }
    }

    private func handleQuickAction(_ userActivity: NSUserActivity) {
        if let contactID = userActivity.userInfo?["contactID"] as? String {
            // Navigate to chat with contact
        }
    }
}

// Handle Quick Action in UIKit AppDelegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        switch shortcutItem.type {
        case "com.myapp.openChat":
            if let contactID = shortcutItem.userInfo?["contactID"] as? String {
                // Navigate to chat
            }
            completionHandler(true)
        case "com.myapp.newMessage":
            // Open new message screen
            completionHandler(true)
        default:
            completionHandler(false)
        }
    }
}
```

### App Intents (iOS 16+ — Siri, Shortcuts App, Spotlight)

```swift
import AppIntents

// Define an App Intent — available in Siri, Shortcuts app, and Spotlight
struct OpenChatIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Chat"
    static var description = IntentDescription("Opens a conversation with a contact.")
    static var openAppWhenRun = true

    @Parameter(title: "Contact")
    var contact: ContactEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Navigate to chat screen with contact
        NavigationManager.shared.navigateToChat(contactID: contact.id)
        return .result(dialog: "Opening chat with \(contact.name)")
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Open chat with \(\.$contact)")
    }
}

// Entity for parameterized intents
struct ContactEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Contact")
    static var defaultQuery = ContactQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct ContactQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ContactEntity] {
        // Fetch contacts by IDs from your data store
        return try await ContactStore.shared.contacts(for: identifiers)
    }

    func suggestedEntities() async throws -> [ContactEntity] {
        // Return recently contacted users
        return try await ContactStore.shared.recentContacts()
    }
}

// App Shortcuts — predefined phrases for Siri (iOS 16+)
struct MyAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenChatIntent(),
            phrases: [
                "Open chat with \(\.$contact) in \(.applicationName)",
                "Message \(\.$contact) in \(.applicationName)"
            ],
            shortTitle: "Open Chat",
            systemImageName: "message"
        )

        AppShortcut(
            intent: NewMessageIntent(),
            phrases: [
                "Start new message in \(.applicationName)",
                "New conversation in \(.applicationName)"
            ],
            shortTitle: "New Message",
            systemImageName: "square.and.pencil"
        )
    }
}
```

### Spotlight Integration (CSSearchableItem)

```swift
import CoreSpotlight
import MobileCoreServices

class SpotlightManager {
    static func indexContacts(_ contacts: [Contact]) {
        let searchableItems = contacts.map { contact in
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = contact.name
            attributes.contentDescription = "Chat with \(contact.name)"
            attributes.thumbnailData = contact.avatarData
            attributes.phoneNumbers = [contact.phone]
            attributes.supportsPhoneCall = true

            return CSSearchableItem(
                uniqueIdentifier: "contact_\(contact.id)",
                domainIdentifier: "com.myapp.contacts",
                attributeSet: attributes
            )
        }

        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error = error {
                print("Spotlight indexing error: \(error)")
            }
        }
    }

    static func removeContact(_ contactID: String) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: ["contact_\(contactID)"]
        )
    }

    static func removeAllContacts() {
        CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: ["com.myapp.contacts"]
        )
    }
}

// Handle Spotlight result tap
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    if let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                        // Parse identifier and navigate
                        let contactID = identifier.replacingOccurrences(of: "contact_", with: "")
                        // Navigate to contact
                    }
                }
        }
    }
}
```

### NSUserActivity for Handoff and Siri Suggestions

```swift
class ActivityManager {
    static func donateActivity(for contact: Contact) {
        let activity = NSUserActivity(activityType: "com.myapp.viewChat")
        activity.title = "Chat with \(contact.name)"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.suggestedInvocationPhrase = "Message \(contact.name)"
        activity.userInfo = ["contactID": contact.id]

        // Spotlight attributes
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = contact.name
        attributes.contentDescription = "Continue chatting with \(contact.name)"
        activity.contentAttributeSet = attributes

        // Make current — this donates the activity
        activity.becomeCurrent()
    }
}
```

## Migration Mapping Table

| Android | iOS Equivalent | Notes |
|---|---|---|
| Static shortcuts (`shortcuts.xml`) | Static Quick Actions (Info.plist `UIApplicationShortcutItems`) | Both defined at compile time |
| Dynamic shortcuts (`ShortcutManager`) | Dynamic Quick Actions (`UIApplication.shared.shortcutItems`) | Max 4 on iOS |
| Pinned shortcuts (`requestPinShortcut`) | No direct equivalent | iOS does not support programmatic home screen shortcuts |
| `ShortcutInfo.Builder` | `UIApplicationShortcutItem` init | Similar API surface |
| `setRank()` | Array order in `shortcutItems` | First item = highest priority |
| `reportShortcutUsed()` | `NSUserActivity.becomeCurrent()` | Improves Siri suggestions ranking |
| `capability-binding` (Google Assistant) | `AppShortcut` phrases (Siri) | Voice assistant integration |
| Shortcut intents | `AppIntent` (iOS 16+) | More powerful on iOS |
| Shortcut categories | `AppShortcutsProvider` | Different categorization model |
| `ShortcutManager.maxShortcutCountPerActivity` | Max 4 Quick Actions | iOS limit is lower |
| Deep link via shortcut Intent | `userInfo` dictionary + `onContinueUserActivity` | Different navigation pattern |

## Feature Mapping by Use Case

| Use Case | Android Approach | iOS Approach |
|---|---|---|
| Long-press app icon menu | Static/dynamic shortcuts | Quick Actions |
| Home screen dedicated shortcut | Pinned shortcuts | Not available (use widgets instead) |
| Voice-triggered actions | Google Assistant + `capability-binding` | Siri + `AppShortcut` phrases |
| Search integration | No built-in (use Google App Indexing) | Spotlight (`CSSearchableItem`) |
| Shortcuts/automation app | Google Assistant Routines | Shortcuts app (`AppIntent`) |
| Predictive suggestions | `reportShortcutUsed()` | `NSUserActivity` donation |
| In-app action execution | Shortcut Intents | `AppIntent.perform()` |

## Common Pitfalls

1. **Quick Action limit of 4** — Android supports up to ~15 dynamic shortcuts. iOS allows a maximum of 4 Quick Actions (combining static + dynamic). Prioritize the most-used actions and use Spotlight or Siri Shortcuts for additional discoverability.

2. **No pinned shortcuts on iOS** — Android's `requestPinShortcut()` places a dedicated icon on the home screen. iOS does not support this. The closest alternative is a WidgetKit widget configured to deep link to a specific screen, or adding a Shortcut to the home screen via the Shortcuts app.

3. **Quick Actions vs App Intents confusion** — Quick Actions (long-press menu) and App Intents (Siri, Shortcuts app) are separate systems on iOS. Android unifies these under `ShortcutManager`. On iOS, implement both if you need launcher shortcuts AND voice/automation support.

4. **App Intents require iOS 16+** — The modern `AppIntent` framework requires iOS 16 minimum. For iOS 15 and earlier, use the older `SiriKit` Intents framework (`.intentdefinition` files), which has more limited capabilities.

5. **Spotlight indexing lifecycle** — Spotlight items persist across app launches but should be updated when data changes. Unlike Android shortcuts that are managed by the system, you must explicitly delete stale Spotlight items. Use domain identifiers to batch-delete by category.

6. **NSUserActivity donation timing** — Donate `NSUserActivity` when the user actually performs an action (viewing a contact, opening a chat), not proactively. Over-donating reduces prediction quality. This is the iOS equivalent of `reportShortcutUsed()`.

7. **Quick Action handling at cold launch** — When the app is not running and a Quick Action is tapped, the action arrives differently. In UIKit, check `launchOptions[.shortcutItem]` in `application(_:didFinishLaunchingWithOptions:)`. In SwiftUI, use `.onContinueUserActivity` or the scene-level handler.

8. **SF Symbols for icons** — iOS Quick Actions support system icon names via `UIApplicationShortcutIcon(systemImageName:)`. Android uses drawable resources. Use SF Symbols on iOS for consistent, resolution-independent icons.

## Migration Checklist

- [ ] Identify all static shortcuts from `res/xml/shortcuts.xml` and add equivalent entries to Info.plist `UIApplicationShortcutItems`
- [ ] Convert dynamic shortcuts from `ShortcutManager` to `UIApplication.shared.shortcutItems` (max 4)
- [ ] Implement Quick Action handling in AppDelegate or SwiftUI `.onContinueUserActivity`
- [ ] Handle Quick Actions at both cold launch and warm launch
- [ ] Replace pinned shortcuts with WidgetKit widgets if home screen presence is needed
- [ ] Create `AppIntent` definitions for actions that should work with Siri and the Shortcuts app (iOS 16+)
- [ ] Define `AppShortcut` phrases in `AppShortcutsProvider` for voice activation
- [ ] Index searchable content with `CSSearchableItem` for Spotlight integration
- [ ] Handle Spotlight result taps via `onContinueUserActivity(CSSearchableItemActionType)`
- [ ] Donate `NSUserActivity` for user actions to improve Siri prediction
- [ ] Replace `reportShortcutUsed()` with `NSUserActivity.becomeCurrent()` for usage tracking
- [ ] Manage Spotlight index lifecycle — update and delete stale items
- [ ] Replace Android shortcut icons with SF Symbols or custom assets
- [ ] Test Quick Actions on device (long-press app icon)
- [ ] Test Siri integration with defined phrases
