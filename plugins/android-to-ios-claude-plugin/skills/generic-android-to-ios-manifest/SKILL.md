---
name: generic-android-to-ios-manifest
description: Guides migration of Android AndroidManifest.xml (activities, services, receivers, permissions, intent-filters, meta-data, application attributes) to iOS Info.plist (app metadata, URL schemes, background modes, usage descriptions), Entitlements (capabilities), and PrivacyInfo.xcprivacy (API usage declarations required since 2024)
type: generic
---

# generic-android-to-ios-manifest

## Context

Android uses `AndroidManifest.xml` as the single source of truth for declaring app components, permissions, intent filters, and metadata. Every Activity, Service, BroadcastReceiver, and ContentProvider must be registered there. iOS distributes this responsibility across three separate configuration files: `Info.plist` for app metadata and URL schemes, an `.entitlements` file for system capabilities, and `PrivacyInfo.xcprivacy` for privacy-related API usage declarations. This skill provides a systematic mapping from AndroidManifest.xml declarations to their idiomatic iOS equivalents, covering component registration, permission setup, capability configuration, and privacy manifest compliance.

## Concept Mapping

| Android (AndroidManifest.xml) | iOS Equivalent |
|-------------------------------|----------------|
| `<activity>` declaration | No registration needed; UIViewController is instantiated in code or storyboard |
| `<service>` declaration | Background Modes in Info.plist + Entitlements |
| `<receiver>` declaration | No registration needed; NotificationCenter observers registered in code |
| `<provider>` declaration | App Groups entitlement + shared UserDefaults/FileManager |
| `<uses-permission>` | Info.plist usage description keys (NSCameraUsageDescription, etc.) |
| `<intent-filter>` with `ACTION_VIEW` | `CFBundleURLTypes` in Info.plist (URL schemes) or Universal Links in Entitlements |
| `<intent-filter>` with `ACTION_MAIN` + `LAUNCHER` | `UILaunchStoryboardName` / `UIApplicationSceneManifest` in Info.plist |
| `android:theme` | `UIAppearance` configuration in code or `UIUserInterfaceStyle` in Info.plist |
| `android:screenOrientation` | `UISupportedInterfaceOrientations` in Info.plist |
| `android:launchMode` | Scene configuration in `UIApplicationSceneManifest` |
| `android:exported` | No direct equivalent; all URL scheme handlers are implicitly exported |
| `<meta-data>` (e.g., API keys) | Info.plist custom keys or build configuration |
| `android:networkSecurityConfig` | `NSAppTransportSecurity` in Info.plist |
| `android:allowBackup` | No direct equivalent; iCloud backup is controlled via entitlements and file attributes |
| `queries` (package visibility) | `LSApplicationQueriesSchemes` in Info.plist |

## Android Best Practices (Source Patterns)

### Complete AndroidManifest.xml Structure

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

    <!-- Feature declarations -->
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.location.gps" android:required="false" />

    <!-- Package visibility -->
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <package android:name="com.google.android.apps.maps" />
    </queries>

    <application
        android:name=".WaonderApplication"
        android:label="@string/app_name"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:theme="@style/Theme.Waonder"
        android:supportsRtl="true"
        android:allowBackup="true"
        android:networkSecurityConfig="@xml/network_security_config"
        android:localeConfig="@xml/locales_config"
        tools:targetApi="34">

        <!-- Main Activity -->
        <activity
            android:name=".ui.MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:screenOrientation="portrait"
            android:windowSoftInputMode="adjustResize">

            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>

            <!-- Deep link -->
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https"
                    android:host="waonder.com"
                    android:pathPrefix="/landmark" />
            </intent-filter>

            <!-- Custom URL scheme -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="waonder" android:host="open" />
            </intent-filter>
        </activity>

        <!-- Foreground Service -->
        <service
            android:name=".service.LocationTrackingService"
            android:exported="false"
            android:foregroundServiceType="location" />

        <!-- Firebase Messaging -->
        <service
            android:name=".service.WaonderMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>

        <!-- Meta-data -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="${MAPS_API_KEY}" />
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="waonder_default" />
    </application>
</manifest>
```

### Network Security Config

```xml
<!-- res/xml/network_security_config.xml -->
<network-security-config>
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">api.waonder.com</domain>
    </domain-config>
    <!-- Debug only -->
    <debug-overrides>
        <trust-anchors>
            <certificates src="user" />
        </trust-anchors>
    </debug-overrides>
</network-security-config>
```

## iOS Equivalent Patterns

### Info.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Identity -->
    <key>CFBundleDisplayName</key>
    <string>Waonder</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>

    <!-- Orientation (equivalent to android:screenOrientation) -->
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>

    <!-- Scene Configuration (equivalent to launchMode / activity declaration) -->
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <false/>
        <key>UISceneConfigurations</key>
        <dict>
            <key>UIWindowSceneSessionRoleApplication</key>
            <array>
                <dict>
                    <key>UISceneConfigurationName</key>
                    <string>Default Configuration</string>
                    <key>UISceneDelegateClassName</key>
                    <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
                </dict>
            </array>
        </dict>
    </dict>

    <!-- Custom URL Scheme (equivalent to intent-filter with custom scheme) -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.waonder.app</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>waonder</string>
            </array>
        </dict>
    </array>

    <!-- Queried URL Schemes (equivalent to <queries>) -->
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <string>comgooglemaps</string>
        <string>maps</string>
    </array>

    <!-- Permission Usage Descriptions (equivalent to <uses-permission>) -->
    <key>NSCameraUsageDescription</key>
    <string>Waonder needs camera access to scan landmarks and capture photos.</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Waonder uses your location to show nearby landmarks.</string>
    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>Waonder uses your location in the background to notify you about nearby landmarks.</string>
    <key>NSUserTrackingUsageDescription</key>
    <string>Waonder uses this to provide personalized landmark recommendations.</string>

    <!-- Background Modes (equivalent to <service> with foregroundServiceType) -->
    <key>UIBackgroundModes</key>
    <array>
        <string>location</string>
        <string>remote-notification</string>
        <string>fetch</string>
    </array>

    <!-- App Transport Security (equivalent to network_security_config) -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
        <key>NSExceptionDomains</key>
        <dict>
            <key>api.waonder.com</key>
            <dict>
                <key>NSExceptionRequiresForwardSecrecy</key>
                <true/>
                <key>NSRequiresCertificateTransparency</key>
                <true/>
            </dict>
        </dict>
    </dict>

    <!-- Localization -->
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>es</string>
        <string>fr</string>
        <string>de</string>
    </array>
</dict>
</plist>
```

### Entitlements File

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Universal Links (equivalent to intent-filter with autoVerify) -->
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:waonder.com</string>
        <string>webcredentials:waonder.com</string>
    </array>

    <!-- Push Notifications (equivalent to FirebaseMessagingService) -->
    <key>aps-environment</key>
    <string>development</string>

    <!-- App Groups (equivalent to ContentProvider for inter-app data) -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.waonder.shared</string>
    </array>

    <!-- Keychain Sharing -->
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.waonder.app</string>
    </array>

    <!-- Maps -->
    <key>com.apple.developer.maps</key>
    <true/>

    <!-- Sign In with Apple -->
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>

    <!-- Background Modes capability (mirrors UIBackgroundModes in Info.plist) -->
    <key>com.apple.developer.location.push</key>
    <true/>
</dict>
</plist>
```

### PrivacyInfo.xcprivacy (Required Since Spring 2024)

Apple requires a privacy manifest declaring which "required reason APIs" your app and its dependencies use. This has no direct Android equivalent -- it maps loosely to Android's `<uses-permission>` declarations but focuses on API-level data access rather than system permissions.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Privacy tracking declaration -->
    <key>NSPrivacyTracking</key>
    <false/>

    <!-- Tracking domains (empty if NSPrivacyTracking is false) -->
    <key>NSPrivacyTrackingDomains</key>
    <array/>

    <!-- Collected data types -->
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypePreciseLocation</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeDeviceID</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
            </array>
        </dict>
    </array>

    <!-- Required Reason APIs -->
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <!-- UserDefaults (file timestamp API) -->
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
        <!-- File timestamp APIs -->
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
        <!-- System boot time APIs -->
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategorySystemBootTime</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>35F9.1</string>
            </array>
        </dict>
        <!-- Disk space APIs -->
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>E174.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

### Handling URL Schemes and Universal Links in Code

```swift
// SwiftUI App with URL handling (equivalent to intent-filter handling)
@main
struct WaonderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handles both custom scheme (waonder://) and universal links
                    DeepLinkRouter.shared.handle(url)
                }
        }
    }
}

// AppDelegate for push notification registration
// (equivalent to FirebaseMessagingService declaration in manifest)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        // Send token to backend
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
        let userInfo = response.notification.request.content.userInfo
        DeepLinkRouter.shared.handleNotification(userInfo)
    }
}
```

### Universal Links Setup (Equivalent to autoVerify intent-filter)

```swift
// apple-app-site-association (hosted at https://waonder.com/.well-known/apple-app-site-association)
// This is the iOS equivalent of Android's Digital Asset Links (assetlinks.json)
/*
{
    "applinks": {
        "apps": [],
        "details": [
            {
                "appID": "TEAMID.com.waonder.app",
                "paths": ["/landmark/*", "/explore/*"]
            }
        ]
    }
}
*/
```

## Key Differences and Pitfalls

### 1. Component Registration is Not Required on iOS
On Android, every Activity, Service, and Receiver must be declared in the manifest or the system cannot instantiate them. On iOS, view controllers are instantiated directly in code or via storyboards -- there is no central registry.

### 2. iOS Splits Configuration Across Multiple Files
Android consolidates everything in `AndroidManifest.xml`. iOS requires you to configure Info.plist for metadata, `.entitlements` for capabilities, and `PrivacyInfo.xcprivacy` for privacy declarations. Missing any one of these causes silent failures or App Store rejection.

### 3. Privacy Manifest is Mandatory
Since Spring 2024, Apple requires `PrivacyInfo.xcprivacy` for any app submitted to the App Store. This must declare all "required reason APIs" used by both your code and your third-party dependencies. Android has no equivalent requirement -- permissions alone suffice.

### 4. Background Execution Model Differs Fundamentally
Android's `<service>` declaration with `foregroundServiceType` gives apps persistent background execution. iOS grants limited background time through specific background modes (location, audio, fetch, processing). Each mode has strict behavioral requirements enforced by App Review.

### 5. Deep Links Require Server-Side Configuration on iOS
Android's `android:autoVerify` for App Links requires hosting `assetlinks.json`. iOS Universal Links require hosting `apple-app-site-association` at `/.well-known/`. The format and signing requirements differ. Custom URL schemes work without server config on both platforms.

### 6. Network Security Defaults Differ
Android requires explicit `networkSecurityConfig` to allow cleartext traffic (blocked by default since API 28). iOS blocks cleartext by default via App Transport Security. Both require explicit exceptions, but the configuration format and granularity differ.

### 7. Permission Strings Must Be User-Facing on iOS
Android's `<uses-permission>` declares technical permission names. iOS's Info.plist usage descriptions (`NS*UsageDescription`) must contain human-readable strings that are shown to the user in the permission dialog. Missing or vague descriptions cause App Review rejection.

## Migration Checklist

- [ ] Map all `<uses-permission>` entries to corresponding `NS*UsageDescription` keys in Info.plist
- [ ] Convert `<intent-filter>` declarations to `CFBundleURLTypes` (custom schemes) or Associated Domains entitlement (universal links)
- [ ] Set up `UIBackgroundModes` in Info.plist for any `<service>` with `foregroundServiceType`
- [ ] Configure `NSAppTransportSecurity` in Info.plist to match `network_security_config.xml`
- [ ] Move API keys from `<meta-data>` to Info.plist custom keys or build configuration (xcconfig)
- [ ] Set `UISupportedInterfaceOrientations` to match `android:screenOrientation` declarations
- [ ] Create `.entitlements` file with push notification, associated domains, and app group capabilities
- [ ] Create `PrivacyInfo.xcprivacy` declaring all required reason API usage and collected data types
- [ ] Configure `LSApplicationQueriesSchemes` to match `<queries>` package visibility declarations
- [ ] Host `apple-app-site-association` file if migrating Android App Links with `autoVerify`
- [ ] Set `UISceneConfigurations` in Info.plist if the app uses multiple windows or custom scene handling
- [ ] Verify all third-party SDKs include their own `PrivacyInfo.xcprivacy` or merge their declarations into yours
