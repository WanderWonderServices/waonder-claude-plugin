---
name: generic-android-to-ios-deep-links
description: Migrate Android deep links (intent filters, App Links, Navigation deep links, Firebase Dynamic Links) to iOS Universal Links, URL Schemes, SwiftUI .onOpenURL, and Firebase Dynamic Links
type: generic
---

# generic-android-to-ios-deep-links

## Context

Android supports deep linking through intent filters, verified App Links (Digital Asset Links), Navigation Component deep links, and Firebase Dynamic Links. iOS provides equivalent functionality through Universal Links (apple-app-site-association), custom URL Schemes, SwiftUI's `.onOpenURL` modifier, and Firebase Dynamic Links. This skill covers the full migration of deep linking infrastructure, verification setup, link handling, routing, and testing strategies.

## Concept Mapping

| Android | iOS |
|---|---|
| Intent filter `<data>` with scheme/host/path | URL Scheme (custom) or Universal Link |
| App Links (verified, `autoVerify="true"`) | Universal Links (AASA file) |
| `assetlinks.json` on server | `apple-app-site-association` on server |
| `NavDeepLink` in Navigation Component | `.onOpenURL` + router |
| `Intent.getData()` / `intent.data` | `URL` from `onOpenURL` or `NSUserActivity` |
| Firebase Dynamic Links | Firebase Dynamic Links (iOS SDK) |
| `PendingDynamicLinkData` | `DynamicLink` |
| Deferred deep links (Play Install Referrer) | Deferred deep links (Firebase / clipboard) |
| `TaskStackBuilder` for synthetic back stack | Build `NavigationPath` manually |

## Code Patterns

### URL Scheme Setup

**Android (AndroidManifest.xml):**
```xml
<activity android:name=".MainActivity">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="myapp" android:host="open" />
    </intent-filter>
</activity>
```

**iOS (Info.plist):**
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.myapp.scheme</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>myapp</string>
        </array>
    </dict>
</array>
```

**iOS (handling in SwiftUI App):**
```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // url == myapp://open/path?query=value
                    DeepLinkRouter.shared.handle(url)
                }
        }
    }
}
```

### Verified Links (App Links / Universal Links)

**Android (App Links - AndroidManifest.xml):**
```xml
<activity android:name=".MainActivity">
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https"
              android:host="www.example.com"
              android:pathPrefix="/items" />
    </intent-filter>
</activity>
```

**Android (Server - `/.well-known/assetlinks.json`):**
```json
[{
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
        "namespace": "android_app",
        "package_name": "com.example.myapp",
        "sha256_cert_fingerprints": ["AA:BB:CC:..."]
    }
}]
```

**iOS (Associated Domains entitlement):**
```
# In Signing & Capabilities, add Associated Domains:
applinks:www.example.com
```

**iOS (Server - `/.well-known/apple-app-site-association`):**
```json
{
    "applinks": {
        "details": [
            {
                "appIDs": ["TEAMID.com.example.myapp"],
                "components": [
                    {
                        "/": "/items/*",
                        "comment": "Match all item deep links"
                    },
                    {
                        "/": "/profile/*",
                        "comment": "Match profile links"
                    }
                ]
            }
        ]
    }
}
```

**Important AASA requirements:**
- Must be served over HTTPS with a valid certificate
- Content-Type must be `application/json`
- No redirects allowed
- File must be at `https://domain.com/.well-known/apple-app-site-association`
- Use the modern `components` array format (not the legacy `paths` format)

### Handling Incoming Universal Links

**Android:**
```kotlin
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val uri = intent.data ?: return
        val pathSegments = uri.pathSegments
        // Route based on path
    }
}
```

**iOS (SwiftUI):**
```swift
@main
struct MyApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
                .onOpenURL { url in
                    router.handleDeepLink(url)
                }
        }
    }
}
```

**iOS (UIKit fallback via SceneDelegate):**
```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene,
               continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        DeepLinkRouter.shared.handle(url)
    }
}
```

### Deep Link Router

**Android:**
```kotlin
class DeepLinkRouter(private val navController: NavController) {
    fun handle(uri: Uri) {
        when {
            uri.pathSegments.firstOrNull() == "items" -> {
                val itemId = uri.pathSegments.getOrNull(1) ?: return
                navController.navigate("detail/$itemId")
            }
            uri.pathSegments.firstOrNull() == "profile" -> {
                val userId = uri.getQueryParameter("id") ?: return
                navController.navigate("profile/$userId")
            }
            else -> navController.navigate("home")
        }
    }
}
```

**iOS:**
```swift
@Observable
final class AppRouter {
    var path = NavigationPath()
    var selectedTab: Tab = .home

    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch pathComponents.first {
        case "items":
            guard let itemId = pathComponents[safe: 1] else { return }
            selectedTab = .home
            // Reset stack then navigate to the item
            path = NavigationPath()
            path.append(AppDestination.detail(itemId: itemId))

        case "profile":
            guard let userId = components.queryItems?
                .first(where: { $0.name == "id" })?.value else { return }
            selectedTab = .profile
            path = NavigationPath()
            path.append(ProfileDestination.user(id: userId))

        default:
            selectedTab = .home
            path = NavigationPath()
        }
    }
}

// Safe subscript helper
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

### Building a Synthetic Back Stack (Deep Link Entry)

**Android:**
```kotlin
// TaskStackBuilder for notifications / deep links
val pendingIntent = TaskStackBuilder.create(context).run {
    addNextIntentWithParentStack(
        Intent(context, MainActivity::class.java).apply {
            data = Uri.parse("https://example.com/items/123")
        }
    )
    getPendingIntent(0, PendingIntent.FLAG_IMMUTABLE)
}
```

**iOS:**
```swift
func handleDeepLink(_ url: URL) {
    // Build the back stack manually so the user can navigate back
    path = NavigationPath()

    let pathComponents = url.pathComponents.filter { $0 != "/" }
    if pathComponents.first == "items", let itemId = pathComponents[safe: 1] {
        // User lands on detail but can go back to the item list
        path.append(AppDestination.itemList)
        path.append(AppDestination.detail(itemId: itemId))
    }
}
```

### Firebase Dynamic Links

**Android:**
```kotlin
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Firebase.dynamicLinks
            .getDynamicLink(intent)
            .addOnSuccessListener { pendingDynamicLinkData ->
                val deepLink = pendingDynamicLinkData?.link ?: return@addOnSuccessListener
                handleDeepLink(deepLink)
            }
            .addOnFailureListener { e ->
                Log.e("DynamicLinks", "Error getting dynamic link", e)
            }
    }
}
```

**iOS:**
```swift
// Note: Firebase Dynamic Links is deprecated. Consider migrating to
// Universal Links or a third-party solution. If still using FDL:

import FirebaseDynamicLinks

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Check if this is a Firebase Dynamic Link
                    if let dynamicLink = DynamicLinks.dynamicLinks()
                        .dynamicLink(fromCustomSchemeURL: url) {
                        handleDynamicLink(dynamicLink)
                    } else {
                        // Handle as regular deep link
                        AppRouter.shared.handleDeepLink(url)
                    }
                }
        }
    }

    private func handleDynamicLink(_ dynamicLink: DynamicLink) {
        guard let url = dynamicLink.url else { return }
        AppRouter.shared.handleDeepLink(url)
    }
}

// AppDelegate for handling Universal Link-based Dynamic Links
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let incomingURL = userActivity.webpageURL {
            let handled = DynamicLinks.dynamicLinks()
                .handleUniversalLink(incomingURL) { dynamicLink, error in
                    guard error == nil, let link = dynamicLink?.url else { return }
                    AppRouter.shared.handleDeepLink(link)
                }
            return handled
        }
        return false
    }
}
```

### Navigation Component Deep Links

**Android:**
```kotlin
// In NavHost
composable(
    route = "detail/{itemId}",
    deepLinks = listOf(
        navDeepLink {
            uriPattern = "https://example.com/items/{itemId}"
            action = "android.intent.action.VIEW"
        }
    ),
    arguments = listOf(navArgument("itemId") { type = NavType.StringType })
) { backStackEntry ->
    DetailScreen(backStackEntry.arguments?.getString("itemId") ?: "")
}
```

**iOS (equivalent via centralized onOpenURL):**
```swift
// iOS does not have declarative deep link registration per destination.
// Instead, handle all deep links centrally and route to the appropriate path.

struct ContentView: View {
    @State private var router = AppRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeScreen()
                .navigationDestination(for: AppDestination.self) { dest in
                    switch dest {
                    case .detail(let itemId):
                        DetailScreen(itemId: itemId)
                    // ...
                    }
                }
        }
        .onOpenURL { url in
            router.handleDeepLink(url)
        }
    }
}
```

## Verification Setup

### Android App Links Verification
1. Generate SHA-256 fingerprint: `keytool -list -v -keystore release.keystore`
2. Host `assetlinks.json` at `https://domain/.well-known/assetlinks.json`
3. Add `android:autoVerify="true"` to intent filters
4. Test: `adb shell am start -a android.intent.action.VIEW -d "https://domain/path"`

### iOS Universal Links Verification
1. Add `applinks:domain.com` to Associated Domains entitlement
2. Host `apple-app-site-association` at `https://domain/.well-known/apple-app-site-association`
3. Ensure AASA is served without redirects, with `Content-Type: application/json`
4. For development, use `applinks:domain.com?mode=developer` to bypass CDN cache
5. Test: paste the link in Notes app and long-press, or use `swcutil` command-line tool

## Testing Deep Links

**Android:**
```bash
# Test deep link via adb
adb shell am start -a android.intent.action.VIEW \
    -d "https://www.example.com/items/123" com.example.myapp

# Verify App Links
adb shell pm get-app-links com.example.myapp
```

**iOS:**
```bash
# Test URL scheme via simulator
xcrun simctl openurl booted "myapp://open/items/123"

# Test Universal Link via simulator
xcrun simctl openurl booted "https://www.example.com/items/123"

# Validate AASA file
curl -v "https://www.example.com/.well-known/apple-app-site-association"

# Check AASA via Apple CDN (production)
curl "https://app-site-association.cdn-apple.com/a/v1/www.example.com"
```

**iOS (Unit test):**
```swift
func testDeepLinkRouting() {
    let router = AppRouter()
    let url = URL(string: "https://www.example.com/items/abc123")!

    router.handleDeepLink(url)

    XCTAssertEqual(router.path.count, 1)
    // Verify the correct destination was pushed
}
```

## Best Practices

1. **Prefer Universal Links over URL Schemes** -- Universal Links provide a verified, secure association between your website and app. URL Schemes are unverified and can be hijacked by other apps.
2. **Always provide a web fallback** -- Universal Links open in the browser if the app is not installed. Ensure your website handles all deep link paths gracefully.
3. **Build synthetic back stacks** -- When a deep link opens a detail screen, pre-populate the `NavigationPath` so the user can navigate back logically rather than being stranded.
4. **Centralize routing logic** -- Use a single `AppRouter` class that handles all deep link parsing and navigation. This keeps URL-to-screen mapping in one place and simplifies testing.
5. **Use deferred deep links for install flows** -- When users click a link and need to install the app first, use Firebase Dynamic Links or a custom clipboard/pasteboard approach to restore context after install.
6. **Validate AASA on every deploy** -- Use Apple's AASA validator or curl the CDN endpoint to ensure the file is correctly served. Invalid AASA silently breaks Universal Links.
7. **Test on real devices** -- Universal Links have caching behavior that differs between simulator and device. Always verify on physical hardware before release.

## Common Pitfalls

- **AASA caching** -- Apple caches the AASA file aggressively (up to 24 hours via CDN). During development, use `?mode=developer` in the Associated Domains entitlement to bypass the CDN.
- **Universal Links not firing in Safari** -- If the user is already on your domain in Safari, tapping a link will not open the app. This is by design. Links must come from a different domain or from another app.
- **URL Scheme conflicts** -- Multiple apps can register the same URL scheme. There is no verification. Use Universal Links for production deep linking.
- **Missing `NSUserActivity` handling** -- Universal Links arrive as `NSUserActivity` with type `NSUserActivityTypeBrowsingWeb`. In SwiftUI, `.onOpenURL` handles both URL schemes and Universal Links, but in UIKit you must handle them separately.
- **Forgetting `webcredentials`** -- For password autofill to work across app and website, add `webcredentials:domain.com` to Associated Domains alongside `applinks`.
- **Firebase Dynamic Links deprecation** -- Firebase Dynamic Links is deprecated. Plan migration to native Universal Links with server-side redirect logic.

## Migration Checklist

- [ ] Map all Android intent filter `<data>` entries to iOS URL Schemes or Universal Links
- [ ] Create and host `apple-app-site-association` file equivalent to `assetlinks.json`
- [ ] Add `applinks:` entries to Associated Domains entitlement
- [ ] Implement `.onOpenURL` handler in SwiftUI `App` struct
- [ ] Create centralized `DeepLinkRouter` to parse URLs and route to `NavigationPath`
- [ ] Build synthetic back stacks for deep link entry points
- [ ] Migrate Firebase Dynamic Links handling to iOS SDK (or replace with Universal Links)
- [ ] Set up deferred deep link handling for install-then-open flows
- [ ] Implement unit tests for all deep link URL patterns
- [ ] Test Universal Links on physical device (not just simulator)
- [ ] Validate AASA file via Apple CDN endpoint
- [ ] Verify web fallback works when app is not installed
- [ ] Test deep links from various entry points (Safari, Messages, Mail, other apps)
