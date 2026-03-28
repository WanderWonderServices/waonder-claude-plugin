---
name: generic-android-to-ios-activities
description: Use when migrating Android Activity patterns (single-activity architecture, startActivity, Intent, result APIs, task/back stack) to iOS UIViewController, SwiftUI App+Scene, and presentation patterns
type: generic
---

# generic-android-to-ios-activities

## Context

Android's `Activity` is the fundamental entry point for user interaction, managing its own lifecycle, window, and UI. Modern Android apps use single-activity architecture where one `Activity` hosts all navigation via fragments or Compose screens. iOS has no direct `Activity` equivalent -- `UIViewController` serves a similar role in UIKit, while SwiftUI uses `App` and `Scene` as the top-level entry points with views composing the UI. This skill covers migrating Activity patterns, intent-based navigation, result handling, and task/back stack management to their iOS equivalents.

## Concept Mapping

| Android | iOS (SwiftUI) | iOS (UIKit) |
|---|---|---|
| `Activity` | `App` + `Scene` (top-level) / `View` (screen) | `UIViewController` |
| `Application` class | `@main App` struct | `AppDelegate` |
| `Intent` (explicit) | Navigation via `NavigationPath` / `.sheet` | `UINavigationController.pushViewController` |
| `Intent` (implicit) | `UIApplication.shared.open(url)` | `UIApplication.shared.open(url)` |
| `startActivity(intent)` | `path.append(destination)` | `navigationController?.pushViewController` |
| `startActivityForResult` / Activity Result API | Callback closure / `@Binding` / async return | Delegate / completion handler |
| `finish()` | `@Environment(\.dismiss)` | `dismiss(animated:)` / `popViewController` |
| `onActivityResult` | Closure callback / `onChange` | Delegate pattern |
| `Intent` extras / Bundle | Hashable struct properties | Property injection |
| `launchMode` (singleTop, singleTask) | Custom router logic | Custom navigation logic |
| `taskAffinity` / task back stack | `NavigationPath` per flow | `UINavigationController` per flow |
| `onCreate` | `onAppear` / `init` | `viewDidLoad` |
| `onResume` | `scenePhase == .active` / `onAppear` | `viewDidAppear` |
| `onPause` | `scenePhase == .inactive` | `viewWillDisappear` |
| `onDestroy` | View removed from hierarchy | `deinit` |
| `onSaveInstanceState` | `@SceneStorage` | `encodeRestorableState` |
| `configurationChanged` | `@Environment(\.horizontalSizeClass)` | `viewWillTransition(to:)` |

## Code Patterns

### App Entry Point

**Android:**
```kotlin
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // App-wide initialization
        Timber.plant(Timber.DebugTree())
        FirebaseApp.initializeApp(this)
    }
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MyAppTheme {
                AppNavigation()
            }
        }
    }
}
```

**iOS (SwiftUI):**
```swift
@main
struct MyApp: App {
    init() {
        // App-wide initialization
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Single-Activity Architecture Migration

**Android (single-activity with Compose):**
```kotlin
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val navController = rememberNavController()
            NavHost(navController, startDestination = "home") {
                composable("home") { HomeScreen(navController) }
                composable("detail/{id}") { DetailScreen(navController) }
                composable("settings") { SettingsScreen(navController) }
            }
        }
    }
}
```

**iOS (SwiftUI -- direct equivalent):**
```swift
@main
struct MyApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                HomeScreen()
                    .navigationDestination(for: AppDestination.self) { dest in
                        switch dest {
                        case .detail(let id): DetailScreen(id: id)
                        case .settings: SettingsScreen()
                        }
                    }
            }
            .environment(router)
        }
    }
}
```

### Intent-Based Navigation (Explicit)

**Android:**
```kotlin
// Navigate to another Activity with extras
val intent = Intent(this, DetailActivity::class.java).apply {
    putExtra("ITEM_ID", "123")
    putExtra("CATEGORY", "electronics")
}
startActivity(intent)
```

**iOS (SwiftUI):**
```swift
// Navigate by appending a typed destination
struct DetailDestination: Hashable {
    let itemId: String
    let category: String
}

// In the source view
path.append(DetailDestination(itemId: "123", category: "electronics"))

// In the NavigationStack
.navigationDestination(for: DetailDestination.self) { dest in
    DetailScreen(itemId: dest.itemId, category: dest.category)
}
```

### Implicit Intents (Opening External Apps)

**Android:**
```kotlin
// Open a URL in browser
val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))
startActivity(intent)

// Share text
val shareIntent = Intent(Intent.ACTION_SEND).apply {
    type = "text/plain"
    putExtra(Intent.EXTRA_TEXT, "Check this out!")
}
startActivity(Intent.createChooser(shareIntent, "Share via"))

// Open maps
val mapIntent = Intent(Intent.ACTION_VIEW,
    Uri.parse("geo:37.7749,-122.4194?q=restaurants"))
startActivity(mapIntent)

// Send email
val emailIntent = Intent(Intent.ACTION_SENDTO).apply {
    data = Uri.parse("mailto:")
    putExtra(Intent.EXTRA_EMAIL, arrayOf("user@example.com"))
    putExtra(Intent.EXTRA_SUBJECT, "Subject")
}
startActivity(emailIntent)
```

**iOS:**
```swift
// Open a URL in browser
if let url = URL(string: "https://example.com") {
    UIApplication.shared.open(url)
}

// Share text
struct ContentView: View {
    @State private var showShareSheet = false

    var body: some View {
        Button("Share") { showShareSheet = true }
            .sheet(isPresented: $showShareSheet) {
                ShareLink(item: "Check this out!")
            }
    }
}

// Or using ShareLink directly (iOS 16+)
ShareLink(item: URL(string: "https://example.com")!) {
    Label("Share", systemImage: "square.and.arrow.up")
}

// Open maps
if let url = URL(string: "maps://?q=restaurants&ll=37.7749,-122.4194") {
    UIApplication.shared.open(url)
}

// Send email
if let url = URL(string: "mailto:user@example.com?subject=Subject") {
    UIApplication.shared.open(url)
}
```

### Activity Result API Migration

**Android:**
```kotlin
class HomeActivity : ComponentActivity() {
    private val pickImageLauncher = registerForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let { handleSelectedImage(it) }
    }

    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) { enableFeature() }
    }

    // Custom result
    private val editLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == RESULT_OK) {
            val editedData = result.data?.getStringExtra("edited_text")
            handleEdit(editedData)
        }
    }

    fun launchImagePicker() {
        pickImageLauncher.launch("image/*")
    }

    fun launchEditor() {
        val intent = Intent(this, EditorActivity::class.java).apply {
            putExtra("text", "initial content")
        }
        editLauncher.launch(intent)
    }
}
```

**iOS (SwiftUI):**
```swift
struct HomeView: View {
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showEditor = false
    @State private var editedText: String = ""

    var body: some View {
        VStack {
            Button("Pick Image") { showImagePicker = true }
            Button("Edit Text") { showEditor = true }
        }
        // Image picker result via sheet
        .sheet(isPresented: $showImagePicker) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Text("Select Photo")
            }
        }
        // Custom result via sheet with binding
        .sheet(isPresented: $showEditor) {
            EditorView(text: $editedText)
        }
        .onChange(of: editedText) { _, newValue in
            handleEdit(newValue)
        }
    }

    @State private var selectedItem: PhotosPickerItem?
}

// PhotosPicker (iOS 16+) -- replaces image picker intent
import PhotosUI

struct ImagePickerExample: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Text("Select Photo")
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
    }
}

// Permission request
import AVFoundation

func requestCameraPermission() async -> Bool {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .authorized: return true
    case .notDetermined:
        return await AVCaptureDevice.requestAccess(for: .video)
    default: return false
    }
}
```

### Activity Lifecycle to SwiftUI Lifecycle

**Android:**
```kotlin
class DetailActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize, restore state
        val restored = savedInstanceState?.getString("key")
    }

    override fun onStart() { super.onStart(); /* Become visible */ }
    override fun onResume() { super.onResume(); /* Interactive */ }
    override fun onPause() { super.onPause(); /* Losing focus */ }
    override fun onStop() { super.onStop(); /* Not visible */ }
    override fun onDestroy() { super.onDestroy(); /* Cleanup */ }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putString("key", currentValue)
    }
}
```

**iOS (SwiftUI):**
```swift
struct DetailView: View {
    @Environment(\.scenePhase) private var scenePhase
    @SceneStorage("detailKey") private var savedValue: String = ""

    var body: some View {
        Text("Detail")
            .onAppear {
                // Equivalent to onStart/onResume (view becomes visible)
                loadData()
            }
            .onDisappear {
                // Equivalent to onStop (view is no longer visible)
                cleanup()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    // App is in foreground (similar to onResume)
                    break
                case .inactive:
                    // App is transitioning (similar to onPause)
                    break
                case .background:
                    // App is in background (similar to onStop)
                    saveState()
                @unknown default:
                    break
                }
            }
            .task {
                // Async work tied to view lifecycle
                // Automatically cancelled when view disappears
                await fetchData()
            }
    }
}
```

### Launch Modes

**Android:**
```xml
<!-- singleTop: reuse if already on top -->
<activity android:launchMode="singleTop" />

<!-- singleTask: reuse existing instance, clear above -->
<activity android:launchMode="singleTask" />

<!-- singleInstance: sole activity in its task -->
<activity android:launchMode="singleInstance" />
```

**iOS (SwiftUI -- handled via router logic):**
```swift
@Observable
final class AppRouter {
    var path = NavigationPath()

    // singleTop equivalent: only navigate if not already showing this destination
    func navigateSingleTop(_ destination: AppDestination) {
        // NavigationPath doesn't expose its contents for inspection,
        // so track the last destination separately
        guard lastDestination != destination else { return }
        path.append(destination)
        lastDestination = destination
    }

    // singleTask equivalent: pop everything above the destination,
    // or navigate to it if not in the stack
    func navigateSingleTask(_ destination: AppDestination) {
        // Reset to root and push destination
        path = NavigationPath()
        path.append(destination)
    }

    private var lastDestination: AppDestination?
}
```

### finish() and Result Return

**Android:**
```kotlin
// In EditorActivity
val resultIntent = Intent().apply {
    putExtra("edited_text", editedText)
}
setResult(RESULT_OK, resultIntent)
finish()
```

**iOS (SwiftUI):**
```swift
struct EditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            TextEditor(text: $draft)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            text = draft  // "Return" the result via binding
                            dismiss()     // Equivalent to finish()
                        }
                    }
                }
        }
        .onAppear { draft = text }
    }
}
```

### Configuration Changes

**Android:**
```kotlin
// Handled automatically by ViewModel + Compose
// Or manually:
class MainActivity : ComponentActivity() {
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        when (newConfig.orientation) {
            Configuration.ORIENTATION_LANDSCAPE -> { /* handle */ }
            Configuration.ORIENTATION_PORTRAIT -> { /* handle */ }
        }
    }
}
```

**iOS (SwiftUI -- handled declaratively):**
```swift
struct AdaptiveView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            // Landscape / iPad layout
            HStack {
                SidebarView()
                ContentView()
            }
        } else {
            // Portrait / compact layout
            ContentView()
        }
    }
}
```

## Best Practices

1. **There is no Activity on iOS** -- Do not try to replicate `Activity` as a class. SwiftUI views are lightweight value types. The `App` struct is the single entry point; individual screens are just views composed within a `NavigationStack`.
2. **Use `@Environment(\.dismiss)`** -- This is the universal replacement for `finish()`. It works for both navigation push and modal presentation.
3. **Use bindings or closures for results** -- Instead of the request/result pattern, pass `@Binding` or closure callbacks to child views. This is more direct and type-safe.
4. **Prefer `NavigationStack` over multiple `UIViewController`** -- In SwiftUI, avoid creating `UIHostingController` wrappers for each screen. Use a single `NavigationStack` with value-based destinations.
5. **Leverage `@SceneStorage` for state restoration** -- It persists simple values across app restarts, equivalent to `onSaveInstanceState`.
6. **Use `.task {}` for lifecycle-bound async work** -- It automatically cancels when the view disappears, providing structured concurrency without manual lifecycle management.
7. **Handle implicit intents via `UIApplication.shared.open`** -- For opening external apps, URLs, maps, email, etc., use URL schemes. For sharing, use `ShareLink` (iOS 16+).

## Common Pitfalls

- **Creating ViewModel per Activity** -- On iOS, ViewModels (as `@Observable` classes) are scoped to the view hierarchy via `@State` or `.environment()`. There is no `ViewModelStore` tied to a lifecycle owner. Use `@State` at the appropriate ancestor view.
- **Expecting `onDisappear` to mean destruction** -- `onDisappear` fires when a view leaves the visible hierarchy (e.g., navigating forward). The view may reappear if the user navigates back. It is closer to `onStop` than `onDestroy`.
- **Multi-window confusion** -- On iPad, `Scene` can have multiple windows. Each `WindowGroup` instance has independent state. Be aware of this when migrating single-Activity patterns.
- **Missing UIKit interop for some intents** -- Some Android implicit intents (file picker, camera, contacts) require UIKit components wrapped with `UIViewControllerRepresentable` or dedicated SwiftUI APIs like `PhotosPicker`.
- **Not using `@MainActor`** -- UI updates from background tasks must happen on the main thread. SwiftUI views are `@MainActor` by default, but view model classes need explicit annotation.

## Migration Checklist

- [ ] Replace `Application` class initialization with `@main App` struct `init()`
- [ ] Replace single `Activity` + `setContent` with `App` + `WindowGroup` + `NavigationStack`
- [ ] Replace `Intent` extras with `Hashable` destination structs
- [ ] Replace `startActivity` with `path.append(destination)`
- [ ] Replace `finish()` with `@Environment(\.dismiss)`
- [ ] Replace `startActivityForResult` / Activity Result API with `@Binding` or closure callbacks
- [ ] Replace implicit intents with `UIApplication.shared.open(url)` or SwiftUI equivalents
- [ ] Replace `onSaveInstanceState` with `@SceneStorage` for simple state
- [ ] Replace `onConfigurationChanged` with `@Environment(\.horizontalSizeClass)` checks
- [ ] Replace lifecycle callbacks with `onAppear` / `onDisappear` / `scenePhase` / `.task`
- [ ] Replace launch modes with custom router logic
- [ ] Verify all permission requests use iOS-native APIs (AVCaptureDevice, PHPhotoLibrary, etc.)
- [ ] Test state restoration across app termination and relaunch
