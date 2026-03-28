---
name: waonder-help
description: Use when the user asks what skills are available or needs to discover Waonder plugin capabilities — lists all skills grouped by domain
type: generic
---

# waonder-help

## Context
Quick reference for all skills available in the waonder-claude-plugin.

## Instructions
When invoked, list every skill in the `skills/` directory grouped by domain (generic, mobile, backend). For each skill show its name, one-line description, and whether it is user-invoked or auto-invoked.

## Steps
1. Read all `skills/*/SKILL.md` files in this plugin
2. Parse the frontmatter of each skill
3. Group skills by their `type` field (generic, mobile, backend)
4. Within generic skills, sub-group the `generic-android-to-ios-*` skills by category (UI, Architecture, Data, DI, Concurrency, Navigation, Lifecycle, Networking, Build, Config, Graphics, Testing, Platform)
5. Display a formatted table for each group with columns: Skill Name | Description | Invocation

## Skill Catalog

### Core Skills
| Skill | Description |
|-------|-------------|
| `waonder-help` | Lists all available Waonder plugin skills |
| `generic-waonder-projects` | Quick reference of all Waonder repositories |
| `generic-agent-updater` | Scans all agents and verifies data accuracy |
| `generic-mobile-landmark-generation` | Removes white backgrounds from landmark images |
| `generic-android-waonder-app-info` | Waonder Android app reference (local path + GitHub repo) |

### Android-to-iOS Migration Skills (63 skills)

**UI Frameworks:**
- `generic-android-to-ios-views` — XML Views/ViewBinding → UIKit/Auto Layout
- `generic-android-to-ios-compose` — Jetpack Compose → SwiftUI
- `generic-android-to-ios-composable` — @Composable functions → View structs
- `generic-android-to-ios-material-design` — Material Design 3 → HIG/native components
- `generic-android-to-ios-state-management` — remember/mutableStateOf → @State/@Observable

**Architecture:**
- `generic-android-to-ios-viewmodel` — ViewModel → @Observable class
- `generic-android-to-ios-repository` — Repository pattern (Kotlin → Swift)
- `generic-android-to-ios-usecase` — Use Cases/Interactors
- `generic-android-to-ios-clean-architecture` — Clean Architecture layers

**Data Layer:**
- `generic-android-to-ios-room-database` — Room → SwiftData/Core Data
- `generic-android-to-ios-datastore` — DataStore → UserDefaults/@AppStorage
- `generic-android-to-ios-local-datasource` — Local data source pattern
- `generic-android-to-ios-remote-datasource` — Remote data source pattern
- `generic-android-to-ios-retrofit` — Retrofit → URLSession/Alamofire
- `generic-android-to-ios-okhttp` — OkHttp → URLSessionConfiguration
- `generic-android-to-ios-ktor` — Ktor Client (KMP/native)

**Dependency Injection:**
- `generic-android-to-ios-dependency-injection` — Hilt/Dagger → Protocol injection

**Concurrency:**
- `generic-android-to-ios-coroutines` — Coroutines → Swift Concurrency
- `generic-android-to-ios-flows` — Flows → AsyncSequence
- `generic-android-to-ios-stateflow` — StateFlow → @Observable/@Published
- `generic-android-to-ios-channels` — Channel → AsyncStream

**Navigation:**
- `generic-android-to-ios-navigation` — Navigation Compose → NavigationStack
- `generic-android-to-ios-deep-links` — Deep/App Links → Universal Links

**App Components:**
- `generic-android-to-ios-activities` — Activity → UIViewController/SwiftUI App
- `generic-android-to-ios-fragments` — Fragment → Child VC/SwiftUI subviews
- `generic-android-to-ios-services` — Service → Background Modes/BGTask
- `generic-android-to-ios-broadcast-receivers` — BroadcastReceiver → NotificationCenter
- `generic-android-to-ios-content-providers` — ContentProvider → App Groups

**Lifecycle:**
- `generic-android-to-ios-activity-lifecycle` — Activity lifecycle → VC/SwiftUI lifecycle
- `generic-android-to-ios-app-lifecycle` — Application class → App struct/AppDelegate
- `generic-android-to-ios-process-lifecycle` — ProcessLifecycleOwner → ScenePhase
- `generic-android-to-ios-lifecycle-aware` — LifecycleObserver → SwiftUI modifiers

**Networking:**
- `generic-android-to-ios-image-loading` — Coil/Glide → Kingfisher/AsyncImage
- `generic-android-to-ios-websocket` — OkHttp WebSocket → URLSessionWebSocketTask

**Build & Modularization:**
- `generic-android-to-ios-gradle-modules` — Gradle modules → SPM/Frameworks
- `generic-android-to-ios-build-variants` — Build variants → Schemes/xcconfig
- `generic-android-to-ios-code-shrinking` — R8/ProGuard → compiler optimizations
- `generic-android-to-ios-version-catalogs` — Version Catalogs → Package.swift

**Configuration:**
- `generic-android-to-ios-manifest` — AndroidManifest → Info.plist/Entitlements
- `generic-android-to-ios-resources` — Resources → Asset/String Catalogs
- `generic-android-to-ios-local-assets` — Drawable/raw → xcassets/Bundle
- `generic-android-to-ios-permissions` — Runtime permissions → Info.plist/auth APIs

**Graphics & Media:**
- `generic-android-to-ios-opengl` — OpenGL ES 3 → Metal
- `generic-android-to-ios-canvas` — Canvas/DrawScope → Canvas/Core Graphics
- `generic-android-to-ios-media-player` — ExoPlayer/Media3 → AVFoundation/AVKit
- `generic-android-to-ios-camera` — CameraX → AVCaptureSession

**Testing:**
- `generic-android-to-ios-unit-testing` — JUnit → Swift Testing/XCTest
- `generic-android-to-ios-ui-testing` — Espresso → XCUITest
- `generic-android-to-ios-compose-testing` — Compose Testing → ViewInspector/XCUITest
- `generic-android-to-ios-mocking` — MockK/Mockito → Protocol mocks

**Platform Features:**
- `generic-android-to-ios-workmanager` — WorkManager → BGTaskScheduler
- `generic-android-to-ios-firebase` — Firebase Android → Firebase iOS
- `generic-android-to-ios-push-notifications` — FCM → APNs/UNNotificationCenter
- `generic-android-to-ios-paging` — Paging 3 → Custom pagination
- `generic-android-to-ios-accessibility` — TalkBack → VoiceOver
- `generic-android-to-ios-localization` — strings.xml → String Catalogs
- `generic-android-to-ios-security` — KeyStore → Keychain/CryptoKit
- `generic-android-to-ios-bluetooth` — android.bluetooth → Core Bluetooth
- `generic-android-to-ios-nfc` — NfcAdapter → Core NFC
- `generic-android-to-ios-location` — FusedLocation → Core Location
- `generic-android-to-ios-widgets` — AppWidget/Glance → WidgetKit
- `generic-android-to-ios-app-shortcuts` — ShortcutManager → Quick Actions/App Intents
- `generic-android-to-ios-billing` — Play Billing → StoreKit 2

## Constraints
- Only list skills that exist in this plugin (waonder-claude-plugin)
- Do not list skills from other plugins
- All android-to-ios skills are invoked as `/waonder-claude-plugin:generic-android-to-ios-<feature>`
