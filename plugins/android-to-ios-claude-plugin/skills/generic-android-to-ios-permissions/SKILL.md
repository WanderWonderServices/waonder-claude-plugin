---
name: generic-android-to-ios-permissions
description: Use when migrating Android permission system (uses-permission, runtime permissions via ActivityResultContracts, permission groups, shouldShowRequestPermissionRationale) to iOS equivalents (Info.plist usage descriptions, framework-specific authorization APIs like PHPhotoLibrary, CLLocationManager, ATTrackingManager, permission flow design, rationale handling, settings redirect)
type: generic
---

# generic-android-to-ios-permissions

## Context

Android uses a unified permission system: declare permissions in `AndroidManifest.xml` with `<uses-permission>`, then request dangerous permissions at runtime using `ActivityResultContracts.RequestPermission`. The system provides `shouldShowRequestPermissionRationale` to detect when a user has previously denied a permission. iOS takes a fundamentally different approach: each framework owns its authorization API. Camera access goes through `AVCaptureDevice`, location through `CLLocationManager`, photos through `PHPhotoLibrary`, and so on. There is no central permission-requesting API. This skill maps Android's permission model to the per-framework iOS authorization pattern.

## Concept Mapping

| Android | iOS |
|---------|-----|
| `<uses-permission>` in manifest | `NS*UsageDescription` in Info.plist |
| `ActivityResultContracts.RequestPermission` | Framework-specific authorization API |
| `ContextCompat.checkSelfPermission()` | Framework-specific status check (e.g., `AVCaptureDevice.authorizationStatus(for:)`) |
| `shouldShowRequestPermissionRationale()` | No direct equivalent; show rationale before first request |
| Permission denied permanently | `.denied` status (must redirect to Settings) |
| `CAMERA` | `AVCaptureDevice.requestAccess(for: .video)` |
| `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE` | `PHPhotoLibrary.requestAuthorization(for:)` |
| `ACCESS_FINE_LOCATION` | `CLLocationManager.requestWhenInUseAuthorization()` |
| `ACCESS_BACKGROUND_LOCATION` | `CLLocationManager.requestAlwaysAuthorization()` |
| `RECORD_AUDIO` | `AVAudioSession.sharedInstance().requestRecordPermission()` |
| `POST_NOTIFICATIONS` | `UNUserNotificationCenter.requestAuthorization(options:)` |
| `BLUETOOTH_CONNECT` / `BLUETOOTH_SCAN` | `CBCentralManager` (triggers prompt on init) |
| `READ_CONTACTS` | `CNContactStore.requestAccess(for: .contacts)` |
| `READ_CALENDAR` | `EKEventStore.requestAccess(to: .event)` (iOS 17: `requestFullAccessToEvents()`) |
| `BODY_SENSORS` | `HKHealthStore.requestAuthorization(toShare:read:)` |
| `AD_ID` (Google Play) | `ATTrackingManager.requestTrackingAuthorization()` |
| Permission groups | No grouping; each permission is independent |
| `Settings.ACTION_APPLICATION_DETAILS_SETTINGS` | `UIApplication.openSettingsURLString` |

## Android Best Practices (Source Patterns)

### Declaring Permissions

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />

<!-- Optional hardware feature (prevents filtering on Play Store) -->
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

### Runtime Permission Request with ActivityResultContracts

```kotlin
class LandmarkScanFragment : Fragment() {

    private val cameraPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            openCamera()
        } else {
            showPermissionDeniedMessage()
        }
    }

    private fun requestCameraPermission() {
        when {
            ContextCompat.checkSelfPermission(
                requireContext(),
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_GRANTED -> {
                openCamera()
            }

            shouldShowRequestPermissionRationale(Manifest.permission.CAMERA) -> {
                // User previously denied; show explanation before re-asking
                showCameraRationale {
                    cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                }
            }

            else -> {
                // First time or "Don't ask again" checked
                cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
            }
        }
    }
}
```

### Multiple Permissions

```kotlin
private val locationPermissionsLauncher = registerForActivityResult(
    ActivityResultContracts.RequestMultiplePermissions()
) { permissions ->
    val fineGranted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true
    val coarseGranted = permissions[Manifest.permission.ACCESS_COARSE_LOCATION] == true

    when {
        fineGranted -> startPreciseLocationTracking()
        coarseGranted -> startApproximateLocationTracking()
        else -> showLocationDeniedMessage()
    }
}

private fun requestLocationPermissions() {
    locationPermissionsLauncher.launch(
        arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
    )
}
```

### Background Location (Two-Step Request)

```kotlin
// Step 1: Request foreground location first
private val foregroundLocationLauncher = registerForActivityResult(
    ActivityResultContracts.RequestMultiplePermissions()
) { permissions ->
    if (permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true) {
        // Step 2: Only then request background location
        requestBackgroundLocation()
    }
}

private val backgroundLocationLauncher = registerForActivityResult(
    ActivityResultContracts.RequestPermission()
) { isGranted ->
    if (isGranted) {
        startBackgroundLocationTracking()
    }
}

private fun requestBackgroundLocation() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        backgroundLocationLauncher.launch(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
    } else {
        // Pre-Q: foreground location permission covers background too
        startBackgroundLocationTracking()
    }
}
```

### Permission State Tracking in ViewModel

```kotlin
class PermissionViewModel : ViewModel() {

    data class PermissionState(
        val camera: Status = Status.NOT_DETERMINED,
        val location: Status = Status.NOT_DETERMINED,
        val notifications: Status = Status.NOT_DETERMINED
    )

    enum class Status {
        NOT_DETERMINED,
        GRANTED,
        DENIED,
        PERMANENTLY_DENIED
    }

    private val _permissionState = MutableStateFlow(PermissionState())
    val permissionState: StateFlow<PermissionState> = _permissionState.asStateFlow()

    fun updateCameraPermission(isGranted: Boolean, shouldShowRationale: Boolean) {
        _permissionState.update {
            it.copy(
                camera = when {
                    isGranted -> Status.GRANTED
                    shouldShowRationale -> Status.DENIED
                    else -> Status.PERMANENTLY_DENIED
                }
            )
        }
    }
}
```

## iOS Equivalent Patterns

### Info.plist Usage Descriptions (Required)

Every permission request on iOS requires a corresponding usage description in Info.plist. The string is displayed in the system permission dialog. Missing it causes a crash at runtime.

```xml
<!-- Info.plist -->
<key>NSCameraUsageDescription</key>
<string>Waonder uses the camera to scan landmarks and capture photos for your travel journal.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Waonder accesses your photos to let you add images to landmarks.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Waonder saves landmark photos to your library.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Waonder uses your location to show landmarks near you.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Waonder uses your location in the background to notify you when you are near a landmark.</string>

<key>NSMicrophoneUsageDescription</key>
<string>Waonder uses the microphone to record audio guides for landmarks.</string>

<key>NSContactsUsageDescription</key>
<string>Waonder accesses contacts to share landmarks with friends.</string>

<key>NSCalendarsFullAccessUsageDescription</key>
<string>Waonder adds landmark visit events to your calendar.</string>

<key>NSUserTrackingUsageDescription</key>
<string>Waonder uses this identifier to provide personalized landmark recommendations.</string>

<key>NSHealthShareUsageDescription</key>
<string>Waonder reads your step count to show walking stats for landmark routes.</string>

<key>NSBluetoothAlwaysUsageDescription</key>
<string>Waonder connects to nearby landmark beacons for enhanced AR experiences.</string>

<key>NSMotionUsageDescription</key>
<string>Waonder uses motion data for pedometer-based landmark navigation.</string>
```

### Camera Permission

```swift
import AVFoundation

final class CameraPermissionHandler {

    enum PermissionStatus {
        case notDetermined
        case granted
        case denied
    }

    var status: PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: return .notDetermined
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    func request() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}

// SwiftUI usage
struct LandmarkScanView: View {
    @State private var cameraStatus: CameraPermissionHandler.PermissionStatus = .notDetermined
    @State private var showSettingsAlert = false
    private let cameraHandler = CameraPermissionHandler()

    var body: some View {
        VStack {
            switch cameraStatus {
            case .notDetermined:
                Button("Enable Camera") {
                    Task {
                        let granted = await cameraHandler.request()
                        cameraStatus = granted ? .granted : .denied
                    }
                }
            case .granted:
                CameraPreviewView()
            case .denied:
                PermissionDeniedView(
                    title: "Camera Access Required",
                    message: "Enable camera access in Settings to scan landmarks.",
                    onOpenSettings: { openAppSettings() }
                )
            }
        }
        .onAppear {
            cameraStatus = cameraHandler.status
        }
    }
}
```

### Location Permission (Equivalent to ACCESS_FINE_LOCATION + ACCESS_BACKGROUND_LOCATION)

```swift
import CoreLocation

@Observable
final class LocationPermissionManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    enum Status {
        case notDetermined
        case whenInUse
        case always
        case denied
    }

    private(set) var status: Status = .notDetermined
    private var continuation: CheckedContinuation<Status, Never>?

    override init() {
        super.init()
        manager.delegate = self
        updateStatus()
    }

    /// Request when-in-use authorization (equivalent to ACCESS_FINE_LOCATION)
    func requestWhenInUse() async -> Status {
        guard status == .notDetermined else { return status }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    /// Request always authorization (equivalent to ACCESS_BACKGROUND_LOCATION)
    /// Must call requestWhenInUse first -- iOS requires the two-step flow
    func requestAlways() async -> Status {
        guard status == .whenInUse else { return status }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestAlwaysAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateStatus()
        continuation?.resume(returning: status)
        continuation = nil
    }

    private func updateStatus() {
        switch manager.authorizationStatus {
        case .notDetermined:
            status = .notDetermined
        case .authorizedWhenInUse:
            status = .whenInUse
        case .authorizedAlways:
            status = .always
        case .denied, .restricted:
            status = .denied
        @unknown default:
            status = .denied
        }
    }
}

// SwiftUI view with two-step location flow
struct LocationSetupView: View {
    @State private var locationManager = LocationPermissionManager()

    var body: some View {
        VStack(spacing: 16) {
            switch locationManager.status {
            case .notDetermined:
                Button("Enable Location") {
                    Task { await locationManager.requestWhenInUse() }
                }
            case .whenInUse:
                Text("Foreground location enabled")
                Button("Enable Background Location") {
                    Task { await locationManager.requestAlways() }
                }
            case .always:
                Text("Full location access granted")
            case .denied:
                PermissionDeniedView(
                    title: "Location Access Required",
                    message: "Enable location in Settings to discover nearby landmarks.",
                    onOpenSettings: { openAppSettings() }
                )
            }
        }
    }
}
```

### Photo Library Permission

```swift
import Photos

final class PhotoLibraryPermissionHandler {

    enum Status {
        case notDetermined
        case full
        case limited  // iOS 14+: user selected specific photos
        case denied
    }

    var status: Status {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined: return .notDetermined
        case .authorized: return .full
        case .limited: return .limited
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    func request() async -> Status {
        let phStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch phStatus {
        case .authorized: return .full
        case .limited: return .limited
        default: return .denied
        }
    }
}

// Handle limited photo access (no Android equivalent)
// iOS 14+ lets users grant access to specific photos only
struct PhotoPickerView: View {
    @State private var photoHandler = PhotoLibraryPermissionHandler()

    var body: some View {
        Group {
            switch photoHandler.status {
            case .limited:
                VStack {
                    Text("You have granted limited photo access.")
                    Button("Manage Selected Photos") {
                        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: rootViewController)
                    }
                }
            case .full:
                PhotoGridView()
            case .denied:
                PermissionDeniedView(
                    title: "Photo Access Required",
                    message: "Grant photo access in Settings to add images to landmarks.",
                    onOpenSettings: { openAppSettings() }
                )
            case .notDetermined:
                Button("Grant Photo Access") {
                    Task { await photoHandler.request() }
                }
            }
        }
    }
}
```

### Notification Permission (Equivalent to POST_NOTIFICATIONS)

```swift
import UserNotifications

final class NotificationPermissionHandler {

    enum Status {
        case notDetermined
        case authorized
        case provisional
        case denied
    }

    func currentStatus() async -> Status {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .provisional: return .provisional
        case .denied: return .denied
        case .ephemeral: return .authorized
        @unknown default: return .denied
        }
    }

    /// Standard request (equivalent to POST_NOTIFICATIONS runtime request)
    func request() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
    }

    /// Provisional request -- delivers notifications silently without prompting
    /// No Android equivalent; useful for onboarding
    func requestProvisional() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound, .provisional])
    }
}
```

### App Tracking Transparency (Equivalent to AD_ID)

```swift
import AppTrackingTransparency

final class TrackingPermissionHandler {

    var status: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    /// Must be called after the app becomes active (not in applicationDidFinishLaunching)
    func request() async -> ATTrackingManager.AuthorizationStatus {
        await ATTrackingManager.requestTrackingAuthorization()
    }
}

// Request on first meaningful screen, not at launch
struct OnboardingCompleteView: View {
    var body: some View {
        ContentView()
            .task {
                // Delay slightly to ensure the app is fully active
                try? await Task.sleep(for: .seconds(1))
                if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                    await ATTrackingManager.requestTrackingAuthorization()
                }
            }
    }
}
```

### Settings Redirect (Equivalent to ACTION_APPLICATION_DETAILS_SETTINGS)

```swift
// Open app settings -- this is the ONLY way to recover from a denied permission on iOS.
// Unlike Android, there is no way to re-trigger the system permission dialog once denied.
func openAppSettings() {
    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(settingsURL)
}

// Reusable denied-permission view with Settings redirect
struct PermissionDeniedView: View {
    let title: String
    let message: String
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                onOpenSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

### Unified Permission State Tracking (Equivalent to PermissionViewModel)

```swift
import AVFoundation
import CoreLocation
import Photos
import UserNotifications

@Observable
final class PermissionStateManager: NSObject, CLLocationManagerDelegate {

    enum Status: String {
        case notDetermined
        case granted
        case limited      // iOS-specific: partial photo access
        case denied
    }

    private(set) var camera: Status = .notDetermined
    private(set) var location: Status = .notDetermined
    private(set) var photos: Status = .notDetermined
    private(set) var notifications: Status = .notDetermined

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    /// Refresh all permission states from system
    /// Call this in .onAppear and when returning from Settings
    func refreshAll() async {
        refreshCamera()
        refreshLocation()
        refreshPhotos()
        await refreshNotifications()
    }

    func refreshCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: camera = .notDetermined
        case .authorized: camera = .granted
        case .denied, .restricted: camera = .denied
        @unknown default: camera = .denied
        }
    }

    func refreshLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined: location = .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: location = .granted
        case .denied, .restricted: location = .denied
        @unknown default: location = .denied
        }
    }

    func refreshPhotos() {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined: photos = .notDetermined
        case .authorized: photos = .granted
        case .limited: photos = .limited
        case .denied, .restricted: photos = .denied
        @unknown default: photos = .denied
        }
    }

    func refreshNotifications() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: notifications = .notDetermined
        case .authorized, .provisional, .ephemeral: notifications = .granted
        case .denied: notifications = .denied
        @unknown default: notifications = .denied
        }
    }

    // CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refreshLocation()
    }
}

// SwiftUI integration: refresh permissions when returning from Settings
struct PermissionAwareView: View {
    @State private var permissionManager = PermissionStateManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        LandmarkListView()
            .task { await permissionManager.refreshAll() }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Re-check permissions when user returns from Settings
                if newPhase == .active {
                    Task { await permissionManager.refreshAll() }
                }
            }
    }
}
```

## Key Differences and Pitfalls

### 1. iOS Cannot Re-Prompt After Denial
On Android, `shouldShowRequestPermissionRationale` returns `true` after the first denial, and you can show a dialog then re-trigger the system prompt. On iOS, once the user taps "Don't Allow", the system dialog **never appears again**. The only recovery path is redirecting to Settings. This makes pre-request rationale screens critical on iOS.

### 2. Show Rationale Before the First Request, Not After
On Android, the common pattern is to check `shouldShowRequestPermissionRationale` after denial. On iOS, you must show your custom rationale screen **before** calling the framework's authorization method, because you only get one chance at the system dialog. Best practice: present a pre-permission screen explaining why the permission is needed, with a "Continue" button that triggers the actual system request.

### 3. Each Framework Has Its Own Authorization API
Android's `ActivityResultContracts.RequestPermission` works for all permissions uniformly. iOS has no unified API. Camera uses `AVCaptureDevice`, location uses `CLLocationManager`, photos use `PHPhotoLibrary`, notifications use `UNUserNotificationCenter`, and tracking uses `ATTrackingManager`. Each has different method signatures and callback patterns.

### 4. Permission Dialogs Require Active App State
On iOS, permission prompts (especially `ATTrackingManager`) must be requested when the app is in the active state. Requesting during `application(_:didFinishLaunchingWithOptions:)` or before the first frame renders causes the dialog to be suppressed. Always request after the UI is visible.

### 5. Limited Photo Access is iOS-Only
iOS 14 introduced "Select Photos" -- the user can grant access to specific photos rather than the entire library. Android has no equivalent. Your app must handle `.limited` status gracefully, potentially showing a "Manage Selected Photos" option.

### 6. Background Location Requires Two-Step Flow on Both Platforms
Both Android (API 30+) and iOS require requesting foreground location before background location. On iOS, calling `requestAlwaysAuthorization()` before the user has granted `whenInUse` does nothing. Always request `whenInUse` first, confirm it is granted, then request `always`.

### 7. Missing Usage Description Causes a Crash
On Android, a missing `<uses-permission>` causes a `SecurityException` at the point of use. On iOS, a missing `NS*UsageDescription` in Info.plist causes an **immediate crash** when the permission is requested -- not a catchable error. Always verify Info.plist entries before calling authorization APIs.

### 8. Bluetooth Permission is Implicit
On Android, `BLUETOOTH_CONNECT` and `BLUETOOTH_SCAN` are explicit runtime permissions. On iOS, creating a `CBCentralManager` instance automatically triggers the Bluetooth permission dialog. There is no separate "request" step.

### 9. No Permission Groups on iOS
Android groups related permissions (e.g., `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`). On iOS, each permission is fully independent. Location does have `whenInUse` vs. `always` tiers, but these are authorization levels, not groups.

### 10. Health Data Requires Specific Entitlement
Android's `BODY_SENSORS` is a standard runtime permission. iOS HealthKit requires both Info.plist usage descriptions and the HealthKit entitlement in the `.entitlements` file. Additionally, HealthKit authorization status for reading is always `.notDetermined` from the app's perspective for privacy reasons -- you cannot determine if the user denied read access.

## Migration Checklist

- [ ] Add `NS*UsageDescription` keys to Info.plist for every permission the app requests
- [ ] Write clear, specific usage description strings that explain exactly why the permission is needed
- [ ] Create framework-specific permission handlers for each permission type (camera, location, photos, etc.)
- [ ] Implement pre-request rationale screens shown before the first system dialog
- [ ] Build a unified `PermissionStateManager` to track all permission statuses in one place
- [ ] Replace `shouldShowRequestPermissionRationale` logic with pre-request rationale (show rationale first on iOS)
- [ ] Implement Settings redirect for denied permissions using `UIApplication.openSettingsURLString`
- [ ] Refresh permission states when the app returns to foreground (`scenePhase == .active`)
- [ ] Handle `.limited` photo library access with `presentLimitedLibraryPicker`
- [ ] Implement two-step location flow: `requestWhenInUse` then `requestAlways`
- [ ] Request `ATTrackingManager` authorization only after the app UI is visible and active
- [ ] Add HealthKit entitlement if migrating `BODY_SENSORS` permission
- [ ] Add `NSBluetoothAlwaysUsageDescription` if using `CBCentralManager`
- [ ] Test permission flows on a fresh install (all `.notDetermined`) and after denial (redirect to Settings)
- [ ] Test with "Reset Location & Privacy" in iOS Settings to re-test first-time permission dialogs
- [ ] Verify the app does not crash when any `NS*UsageDescription` is accessed before being set
