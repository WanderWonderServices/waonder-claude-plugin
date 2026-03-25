# Android-to-iOS Migration Skills Specification

> A comprehensive catalog of Android ecosystem features mapped to their iOS equivalents, following latest best practices (2024–2025 standards). Each feature has a dedicated skill in this plugin.

---

## Skill Naming Convention

All skills follow: `generic-android-to-ios-<feature-name>`
Invoked as: `/waonder-claude-plugin:generic-android-to-ios-<feature-name>`

---

## 1. UI FRAMEWORKS

| # | Skill Name | Android Feature | iOS Equivalent | Mapping Quality |
|---|-----------|----------------|---------------|----------------|
| 1 | `generic-android-to-ios-views` | Views (XML Layouts), ViewBinding, DataBinding | UIKit (Storyboards/XIBs/Programmatic), Auto Layout | Conceptual |
| 2 | `generic-android-to-ios-compose` | Jetpack Compose (`androidx.compose.*`) | SwiftUI | Close 1:1 |
| 3 | `generic-android-to-ios-composable` | `@Composable` functions | `View` protocol structs | Close 1:1 |
| 4 | `generic-android-to-ios-material-design` | Material Design 3 (`Material3`) | Human Interface Guidelines, native UIKit/SwiftUI components | Conceptual |
| 5 | `generic-android-to-ios-state-management` | `remember`, `mutableStateOf`, `State<T>` | `@State`, `@Binding`, `@Observable` | Close 1:1 |

## 2. ARCHITECTURE

| # | Skill Name | Android Feature | iOS Equivalent | Mapping Quality |
|---|-----------|----------------|---------------|----------------|
| 6 | `generic-android-to-ios-viewmodel` | `androidx.lifecycle.ViewModel` | `@Observable` class (iOS 17+), `ObservableObject` | Conceptual |
| 7 | `generic-android-to-ios-repository` | Repository pattern (single source of truth) | Repository pattern (same concept, Swift protocols) | 1:1 |
| 8 | `generic-android-to-ios-usecase` | Use Cases / Interactors | Use Cases / Interactors (same pattern) | 1:1 |
| 9 | `generic-android-to-ios-clean-architecture` | Clean Architecture (domain/data/presentation) | Clean Architecture + MVVM-C / TCA / VIP | Conceptual |

## 3. DATA LAYER

| # | Skill Name | Android Feature | iOS Equivalent | Mapping Quality |
|---|-----------|----------------|---------------|----------------|
| 10 | `generic-android-to-ios-room-database` | Room (`androidx.room`) | SwiftData (iOS 17+) / Core Data | Conceptual |
| 11 | `generic-android-to-ios-datastore` | DataStore (Preferences/Proto) | `UserDefaults` / `@AppStorage` | Close |
| 12 | `generic-android-to-ios-local-datasource` | Local data source pattern | Local data source pattern (Swift protocols) | 1:1 |
| 13 | `generic-android-to-ios-remote-datasource` | Remote data source pattern | Remote data source pattern (Swift protocols) | 1:1 |
| 14 | `generic-android-to-ios-retrofit` | Retrofit + OkHttp | `URLSession` / Alamofire | Conceptual |
| 15 | `generic-android-to-ios-okhttp` | OkHttp interceptors, logging, caching | `URLSessionConfiguration`, `URLProtocol` | Conceptual |
| 16 | `generic-android-to-ios-ktor` | Ktor Client (multiplatform) | Ktor Client (shared via KMP) / `URLSession` | Close |

## 4. DEPENDENCY INJECTION

| # | Skill Name | Android Feature | iOS Equivalent | Mapping Quality |
|---|-----------|----------------|---------------|----------------|
| 17 | `generic-android-to-ios-dependency-injection` | Hilt / Dagger / Koin | Protocol-based init injection / Factory / Swinject / swift-dependencies | Significant difference |

## 5. CONCURRENCY

| # | Skill Name | Android Feature | iOS Equivalent | Mapping Quality |
|---|-----------|----------------|---------------|----------------|
| 18 | `generic-android-to-ios-coroutines` | Kotlin Coroutines (`suspend`, `launch`, `async`) | Swift Concurrency (`async/await`, `Task`, `TaskGroup`) | Close 1:1 |
| 19 | `generic-android-to-ios-flows` | Kotlin Flows (`Flow`, `collect`) | `AsyncSequence`, `AsyncStream` | Close 1:1 |
| 20 | `generic-android-to-ios-stateflow` | `StateFlow` / `SharedFlow` | `@Observable` property / `CurrentValueSubject` | Close |
| 21 | `generic-android-to-ios-channels` | `Channel` | `AsyncChannel` (swift-async-algorithms) / `AsyncStream` | Close |

## 6. NAVIGATION

| # | Skill Name | Android Feature | iOS Equivalent | Mapping Quality |
|---|-----------|----------------|---------------|----------------|
| 22 | `generic-android-to-ios-navigation` | Jetpack Navigation Component / Navigation Compose | `NavigationStack` / `NavigationPath` (SwiftUI) | Close 1:1 |
| 23 | `generic-android-to-ios-deep-links` | Deep links / App Links | Universal Links / URL Schemes / `onOpenURL` | Close 1:1 |

## 7. APP COMPONENTS

| # | Skill Name | Android Feature | iOS Equivalent | Mapping Quality |
|---|-----------|----------------|---------------|----------------|
| 24 | `generic-android-to-ios-activities` | `Activity` | `UIViewController` / SwiftUI `App` + `Scene` | Conceptual |
| 25 | `generic-android-to-ios-fragments` | `Fragment` | Child `UIViewController` / SwiftUI subviews | Conceptual |
| 26 | `generic-android-to-ios-services` | `Service` (foreground/background/bound) | Background Modes / `BGTaskScheduler` / no direct equivalent | No direct mapping |
| 27 | `generic-android-to-ios-broadcast-receivers` | `BroadcastReceiver` | `NotificationCenter` / framework-specific delegates | Partial |
| 28 | `generic-android-to-ios-content-providers` | `ContentProvider` | App Groups / `FileProvider` / no direct equivalent | Partial |

## 8. LIFECYCLE

| # | Skill Name | Android Feature | iOS Equivalent | Mapping Quality |
|---|-----------|----------------|---------------|----------------|
| 29 | `generic-android-to-ios-activity-lifecycle` | Activity lifecycle (`onCreate`→`onDestroy`) | `UIViewController` lifecycle (`viewDidLoad`→`deinit`) / SwiftUI lifecycle modifiers | Conceptual |
| 30 | `generic-android-to-ios-app-lifecycle` | `Application` class, `onCreate` | `@main App` struct, `UIApplicationDelegate`, `SceneDelegate` | Conceptual |
| 31 | `generic-android-to-ios-process-lifecycle` | `ProcessLifecycleOwner` | `ScenePhase` (SwiftUI) / `UIApplication` state notifications | Close |
| 32 | `generic-android-to-ios-lifecycle-aware` | `LifecycleObserver`, lifecycle-aware components | SwiftUI `.onAppear`/`.onDisappear`/`.task` / `scenePhase` | Conceptual |

## 9. NETWORKING

| # | Skill Name | Android Feature | iOS Equivalent | Mapping Quality |
|---|-----------|----------------|---------------|----------------|
| 33 | `generic-android-to-ios-image-loading` | Coil / Glide | Kingfisher / Nuke / `AsyncImage` (SwiftUI) | Close 1:1 |
| 34 | `generic-android-to-ios-websocket` | OkHttp WebSocket / Ktor WebSocket | `URLSessionWebSocketTask` / Starscream | Close 1:1 |

## 10. BUILD & MODULARIZATION

| # | Skill Name | Android Feature | iOS Equivalent | Mapping Quality |
|---|-----------|----------------|---------------|----------------|
| 35 | `generic-android-to-ios-gradle-modules` | Gradle multi-module projects | SPM targets / Xcode frameworks / Tuist modules | Conceptual |
| 36 | `generic-android-to-ios-build-variants` | Build variants / Product flavors | Xcode Schemes / Build Configurations / xcconfig | Conceptual |
| 37 | `generic-android-to-ios-code-shrinking` | ProGuard / R8 | Swift compiler optimizations / no direct equivalent | No mapping |
| 38 | `generic-android-to-ios-version-catalogs` | Version Catalogs (`libs.versions.toml`) | `Package.swift` versions / Tuist `Dependencies.swift` | Loose |

## 11. CONFIGURATION

| # | Skill Name | Android Feature | iOS Equivalent | Mapping Quality |
|---|-----------|----------------|---------------|----------------|
| 39 | `generic-android-to-ios-manifest` | `AndroidManifest.xml` | `Info.plist` + Entitlements + `PrivacyInfo.xcprivacy` | Conceptual |
| 40 | `generic-android-to-ios-resources` | Resources (`strings.xml`, `dimens.xml`, `colors.xml`) | String Catalogs / Asset Catalogs / code constants | Partial |
| 41 | `generic-android-to-ios-local-assets` | `res/drawable`, `res/raw`, `assets/` | Asset Catalogs (`.xcassets`) / Bundle resources | Close 1:1 |
| 42 | `generic-android-to-ios-permissions` | `<uses-permission>` + runtime permissions | `Info.plist` usage descriptions + framework-specific auth | Conceptual |

## 12. GRAPHICS & MEDIA

| # | Skill Name | Android Feature | iOS Equivalent | Mapping Quality |
|---|-----------|----------------|---------------|----------------|
| 43 | `generic-android-to-ios-opengl` | OpenGL ES 3.0/3.1/3.2 | Metal (Metal 3) | Conceptual |
| 44 | `generic-android-to-ios-canvas` | `Canvas` (Compose) / `android.graphics.Canvas` | `Canvas` (SwiftUI) / Core Graphics | Close 1:1 |
| 45 | `generic-android-to-ios-media-player` | ExoPlayer / Media3 | AVFoundation / AVKit (`AVPlayer`) | Conceptual |
| 46 | `generic-android-to-ios-camera` | CameraX | AVFoundation (`AVCaptureSession`) | Conceptual |

## 13. TESTING

| # | Skill Name | Android Feature | iOS Equivalent | Mapping Quality |
|---|-----------|----------------|---------------|----------------|
| 47 | `generic-android-to-ios-unit-testing` | JUnit 4/5 | XCTest / Swift Testing (`@Test`, Xcode 16+) | Close 1:1 |
| 48 | `generic-android-to-ios-ui-testing` | Espresso | XCUITest (`XCUIApplication`) | Close 1:1 |
| 49 | `generic-android-to-ios-compose-testing` | Compose UI Test (`composeTestRule`) | ViewInspector / XCUITest / snapshot testing | Loose |
| 50 | `generic-android-to-ios-mocking` | MockK / Mockito | Protocol-based mocks / Mockolo / manual mocks | Significant difference |

## 14. PLATFORM FEATURES

| # | Skill Name | Android Feature | iOS Equivalent | Mapping Quality |
|---|-----------|----------------|---------------|----------------|
| 51 | `generic-android-to-ios-workmanager` | WorkManager | `BGTaskScheduler` / `BGProcessingTask` | Loose (iOS much more limited) |
| 52 | `generic-android-to-ios-firebase` | Firebase Android SDK | Firebase iOS SDK (SPM/CocoaPods) | 1:1 |
| 53 | `generic-android-to-ios-push-notifications` | FCM (Firebase Cloud Messaging) | APNs + `UNUserNotificationCenter` / FCM wrapper | Close 1:1 |
| 54 | `generic-android-to-ios-paging` | Paging 3 (`PagingSource`, `LazyPagingItems`) | Custom pagination / `AsyncSequence`-based | No 1:1 mapping |
| 55 | `generic-android-to-ios-accessibility` | TalkBack, `contentDescription`, `AccessibilityNodeInfo` | VoiceOver, `.accessibilityLabel()`, `.accessibilityTraits()` | Close 1:1 |
| 56 | `generic-android-to-ios-localization` | `res/values-<locale>/strings.xml`, plurals | String Catalogs (`.xcstrings`), `String(localized:)` | Close 1:1 |
| 57 | `generic-android-to-ios-security` | `AndroidKeyStore`, `EncryptedSharedPreferences`, Jetpack Security | Keychain Services, CryptoKit, Secure Enclave | Close 1:1 |
| 58 | `generic-android-to-ios-bluetooth` | `android.bluetooth`, BLE Scanner | Core Bluetooth (`CBCentralManager`) | Close 1:1 |
| 59 | `generic-android-to-ios-nfc` | `android.nfc.NfcAdapter`, HCE | Core NFC (`NFCNDEFReaderSession`) | Partial (iOS limited) |
| 60 | `generic-android-to-ios-location` | Fused Location Provider / `LocationManager` | Core Location (`CLLocationManager`) | Close 1:1 |
| 61 | `generic-android-to-ios-widgets` | `AppWidgetProvider` / Glance | WidgetKit (SwiftUI-based) | Close 1:1 |
| 62 | `generic-android-to-ios-app-shortcuts` | `ShortcutManager`, static shortcuts | Quick Actions, App Intents, Spotlight | Conceptual |
| 63 | `generic-android-to-ios-billing` | Google Play Billing Library | StoreKit 2 | Close 1:1 |

---

## Agents

Each skill is supported by specialized agents that provide deep expertise:

| Agent | Scope |
|-------|-------|
| `generic-android-to-ios-migration-expert` | Master agent covering full Android↔iOS migration strategy, architecture decisions, and cross-cutting concerns |
| `generic-android-to-ios-ui-expert` | UI frameworks: Views↔UIKit, Compose↔SwiftUI, state management, theming |
| `generic-android-to-ios-data-expert` | Data layer: databases, networking, caching, serialization |
| `generic-android-to-ios-concurrency-expert` | Concurrency: Coroutines↔Swift Concurrency, Flows↔AsyncSequence |
| `generic-android-to-ios-platform-expert` | Platform APIs: lifecycle, permissions, background work, hardware |
| `generic-android-to-ios-testing-expert` | Testing: unit, UI, mocking, CI/CD strategies |
| `generic-android-to-ios-build-expert` | Build systems: Gradle↔SPM/Xcode, modularization, CI pipelines |

---

## Waonder Android App Reference

The source Android application for migration tasks:

| Field | Value |
|-------|-------|
| **Local path** | `~/Documents/WaonderApps/waonder-android` |
| **GitHub** | [WanderWonderServices/waonder-android](https://github.com/WanderWonderServices/waonder-android) |
| **Language** | Kotlin |
| **Skill** | `generic-android-waonder-app-info` |

Use `/waonder-claude-plugin:generic-android-waonder-app-info` to load full app context before migration tasks.

---

## How to Use

1. **Locate the source code**: Start with `/waonder-claude-plugin:generic-android-waonder-app-info` to set context
2. **Single feature migration**: Invoke the specific skill, e.g., `/waonder-claude-plugin:generic-android-to-ios-compose`
3. **Architecture migration**: Start with `clean-architecture`, then drill into specific layers
4. **Full app migration**: Use the master agent `generic-android-to-ios-migration-expert` for strategy, then individual skills for implementation

## Standards

- **Android**: Kotlin-first, Jetpack Compose, Coroutines, Hilt, Room, Material 3
- **iOS**: Swift-first, SwiftUI, Swift Concurrency, SwiftData, protocol-based DI
- **Both**: Clean Architecture, MVVM, Repository pattern, unidirectional data flow
