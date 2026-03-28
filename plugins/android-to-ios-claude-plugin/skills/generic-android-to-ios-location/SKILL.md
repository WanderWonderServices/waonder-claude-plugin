---
name: generic-android-to-ios-location
description: Use when migrating Android location patterns (FusedLocationProviderClient, Geofencing API, location permissions) to iOS Core Location equivalents (CLLocationManager, CLLocation, CLCircularRegion, authorization levels) covering permission tiers, background location, geofencing, accuracy levels, and battery optimization
type: generic
---

# generic-android-to-ios-location

## Context

Android's location stack centers on `FusedLocationProviderClient` from Google Play Services, which intelligently fuses GPS, Wi-Fi, and cell data. iOS uses `CLLocationManager` from the Core Location framework, which provides a delegate-based API with fine-grained authorization levels. The key architectural differences are: Android separates permission grants (`ACCESS_FINE_LOCATION` vs `ACCESS_COARSE_LOCATION`) at the manifest/runtime level, while iOS has a tiered authorization model (`whenInUse` -> `always`) with the option for reduced accuracy. This skill maps Android location patterns to idiomatic iOS equivalents.

## Android Best Practices (Source Patterns)

### Location Permissions

```kotlin
// AndroidManifest.xml
// <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
// <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
// <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

class LocationPermissionHelper(private val activity: ComponentActivity) {

    private val locationPermissionLauncher = activity.registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val fineGranted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true
        val coarseGranted = permissions[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        // Handle results
    }

    fun requestLocationPermission() {
        locationPermissionLauncher.launch(
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        )
    }

    // Background location must be requested separately (Android 11+)
    fun requestBackgroundLocation() {
        locationPermissionLauncher.launch(
            arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        )
    }
}
```

### Getting Current Location

```kotlin
class LocationRepository(private val context: Context) {

    private val fusedLocationClient = LocationServices.getFusedLocationProviderClient(context)

    suspend fun getCurrentLocation(): Location? {
        return suspendCancellableCoroutine { continuation ->
            val cancellationToken = CancellationTokenSource()
            fusedLocationClient.getCurrentLocation(
                Priority.PRIORITY_HIGH_ACCURACY,
                cancellationToken.token
            ).addOnSuccessListener { location ->
                continuation.resume(location)
            }.addOnFailureListener { exception ->
                continuation.resumeWithException(exception)
            }
            continuation.invokeOnCancellation {
                cancellationToken.cancel()
            }
        }
    }
}
```

### Continuous Location Updates

```kotlin
class LocationTracker(private val context: Context) {

    private val fusedLocationClient = LocationServices.getFusedLocationProviderClient(context)
    private var locationCallback: LocationCallback? = null

    fun startTracking(): Flow<Location> = callbackFlow {
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 10_000L)
            .setMinUpdateIntervalMillis(5_000L)
            .setMinUpdateDistanceMeters(10f)
            .setWaitForAccurateLocation(true)
            .build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let { trySend(it) }
            }

            override fun onLocationAvailability(availability: LocationAvailability) {
                if (!availability.isLocationAvailable) {
                    // Location services unavailable
                }
            }
        }

        fusedLocationClient.requestLocationUpdates(request, locationCallback!!, Looper.getMainLooper())

        awaitClose {
            fusedLocationClient.removeLocationUpdates(locationCallback!!)
        }
    }
}
```

### Geofencing

```kotlin
class GeofenceManager(private val context: Context) {

    private val geofencingClient = LocationServices.getGeofencingClient(context)

    fun addGeofence(id: String, latitude: Double, longitude: Double, radius: Float) {
        val geofence = Geofence.Builder()
            .setRequestId(id)
            .setCircularRegion(latitude, longitude, radius)
            .setTransitionTypes(
                Geofence.GEOFENCE_TRANSITION_ENTER or
                Geofence.GEOFENCE_TRANSITION_EXIT or
                Geofence.GEOFENCE_TRANSITION_DWELL
            )
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setLoiteringDelay(30_000) // 30 seconds for DWELL
            .build()

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofence(geofence)
            .build()

        val pendingIntent = PendingIntent.getBroadcast(
            context, 0,
            Intent(context, GeofenceBroadcastReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        geofencingClient.addGeofences(request, pendingIntent)
    }

    fun removeGeofence(id: String) {
        geofencingClient.removeGeofences(listOf(id))
    }
}
```

### Key Android Patterns to Recognize

- `FusedLocationProviderClient` — primary location API from Google Play Services
- `Priority.PRIORITY_HIGH_ACCURACY` / `PRIORITY_BALANCED_POWER_ACCURACY` — accuracy/power tradeoff
- `LocationRequest.Builder` — configures update interval, distance, and accuracy
- `LocationCallback` — receives location updates
- `GeofencingClient` — manages geofence regions
- `Geofence.GEOFENCE_TRANSITION_ENTER/EXIT/DWELL` — geofence transition types
- `ACCESS_BACKGROUND_LOCATION` — separate permission for background access (Android 10+)

## iOS Best Practices (Target Patterns)

### Location Manager Setup and Authorization

```swift
import CoreLocation

// Info.plist required keys:
// NSLocationWhenInUseUsageDescription — required for foreground location
// NSLocationAlwaysAndWhenInUseUsageDescription — required for background location
// UIBackgroundModes: location — for continuous background updates

final class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var locationError: Error?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        // Must request whenInUse first on iOS 13+
        // Then request always — iOS shows a secondary prompt
        manager.requestAlwaysAuthorization()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            // Can use location in foreground
            break
        case .authorizedAlways:
            // Can use location in background
            break
        case .denied, .restricted:
            // Direct user to Settings
            break
        case .notDetermined:
            break
        @unknown default:
            break
        }

        // Check accuracy authorization (iOS 14+)
        switch manager.accuracyAuthorization {
        case .fullAccuracy:
            break
        case .reducedAccuracy:
            // User chose approximate location
            // Request temporary full accuracy if needed:
            // manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "DirectionsKey")
            break
        @unknown default:
            break
        }
    }
}
```

### Getting Current Location

```swift
extension LocationManager {
    func requestCurrentLocation() {
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error
    }
}

// iOS 15+ async/await approach using CLLocationUpdate
@available(iOS 15.0, *)
extension LocationManager {
    func getCurrentLocationAsync() async throws -> CLLocation {
        let updates = CLLocationUpdate.liveUpdates()
        for try await update in updates {
            if let location = update.location {
                return location
            }
        }
        throw CLError(.locationUnknown)
    }
}
```

### Continuous Location Updates

```swift
extension LocationManager {
    func startContinuousUpdates() {
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10 // meters — equivalent to setMinUpdateDistanceMeters
        manager.allowsBackgroundLocationUpdates = true // requires UIBackgroundModes: location
        manager.showsBackgroundLocationIndicator = true // blue status bar indicator
        manager.startUpdatingLocation()
    }

    func stopContinuousUpdates() {
        manager.stopUpdatingLocation()
    }
}

// iOS 15+ AsyncSequence-based approach
@available(iOS 15.0, *)
extension LocationManager {
    func locationStream() -> AsyncStream<CLLocation> {
        AsyncStream { continuation in
            let updates = CLLocationUpdate.liveUpdates(.fitness)
            let task = Task {
                for try await update in updates {
                    if let location = update.location {
                        continuation.yield(location)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

### Significant Location Changes (Battery Efficient)

```swift
extension LocationManager {
    // Equivalent to Android's PRIORITY_BALANCED_POWER_ACCURACY with large intervals
    // Wakes app from background on significant location changes (~500m)
    func startSignificantLocationMonitoring() {
        manager.startMonitoringSignificantLocationChanges()
    }

    func stopSignificantLocationMonitoring() {
        manager.stopMonitoringSignificantLocationChanges()
    }
}
```

### Geofencing (Region Monitoring)

```swift
extension LocationManager {
    func addGeofence(
        identifier: String,
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        notifyOnEntry: Bool = true,
        notifyOnExit: Bool = true
    ) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        guard manager.authorizationStatus == .authorizedAlways else {
            // Geofencing requires Always authorization
            requestAlwaysAuthorization()
            return
        }

        let region = CLCircularRegion(
            center: center,
            radius: min(radius, manager.maximumRegionMonitoringDistance),
            identifier: identifier
        )
        region.notifyOnEntry = notifyOnEntry
        region.notifyOnExit = notifyOnExit

        manager.startMonitoring(for: region)
    }

    func removeGeofence(identifier: String) {
        for region in manager.monitoredRegions {
            if region.identifier == identifier {
                manager.stopMonitoring(for: region)
                break
            }
        }
    }

    func removeAllGeofences() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
    }

    // Delegate methods for geofencing
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        // Handle enter event
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        // Handle exit event
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        // Handle monitoring failure
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        switch state {
        case .inside:
            // Currently inside region
            break
        case .outside:
            // Currently outside region
            break
        case .unknown:
            break
        }
    }
}
```

## Migration Mapping Table

| Android | iOS (Core Location) |
|---|---|
| `FusedLocationProviderClient` | `CLLocationManager` |
| `getCurrentLocation()` | `requestLocation()` or `CLLocationUpdate.liveUpdates()` (iOS 15+) |
| `requestLocationUpdates()` | `startUpdatingLocation()` |
| `removeLocationUpdates()` | `stopUpdatingLocation()` |
| `LocationCallback` | `CLLocationManagerDelegate` |
| `LocationRequest.Builder` | Properties on `CLLocationManager` (`desiredAccuracy`, `distanceFilter`) |
| `Priority.PRIORITY_HIGH_ACCURACY` | `kCLLocationAccuracyBest` |
| `Priority.PRIORITY_BALANCED_POWER_ACCURACY` | `kCLLocationAccuracyHundredMeters` |
| `Priority.PRIORITY_LOW_POWER` | `kCLLocationAccuracyKilometer` |
| `Priority.PRIORITY_PASSIVE` | `startMonitoringSignificantLocationChanges()` |
| `setMinUpdateIntervalMillis()` | No direct equivalent — iOS controls update rate internally |
| `setMinUpdateDistanceMeters()` | `distanceFilter` property |
| `ACCESS_FINE_LOCATION` | `requestWhenInUseAuthorization()` with full accuracy |
| `ACCESS_COARSE_LOCATION` | Reduced accuracy authorization (iOS 14+) |
| `ACCESS_BACKGROUND_LOCATION` | `requestAlwaysAuthorization()` + `UIBackgroundModes: location` |
| `GeofencingClient` | `CLLocationManager.startMonitoring(for: CLCircularRegion)` |
| `Geofence.Builder` | `CLCircularRegion` init |
| `GEOFENCE_TRANSITION_ENTER` | `notifyOnEntry = true` on `CLCircularRegion` |
| `GEOFENCE_TRANSITION_EXIT` | `notifyOnExit = true` on `CLCircularRegion` |
| `GEOFENCE_TRANSITION_DWELL` | No direct equivalent — must implement manually with timers |
| `setExpirationDuration()` | No equivalent — regions monitor until explicitly stopped |
| Geofence limit: 100 | Geofence limit: 20 per app |

## Common Pitfalls

1. **Permission escalation model** — On iOS, you should request `whenInUse` first, then later upgrade to `always` if needed. If you request `always` directly without prior `whenInUse`, the user only sees the "When In Use" option. The "Always" option appears as a follow-up system prompt later.

2. **Geofence limit of 20** — Android supports up to 100 geofences per app. iOS limits this to 20 monitored regions total. If your Android app uses many geofences, implement a strategy to dynamically monitor the nearest 20 and rotate them as the user moves.

3. **No dwell transition** — Android supports `GEOFENCE_TRANSITION_DWELL` with a configurable loitering delay. iOS has no equivalent. You must track enter time and implement dwell detection manually in your app logic.

4. **`requestLocation()` is a one-shot** — Unlike Android's `getCurrentLocation()`, iOS's `requestLocation()` delivers the best available location and then stops. It may take several seconds. For faster response, use `startUpdatingLocation()` and stop after receiving the first acceptable fix.

5. **Background location indicator** — When using continuous background location on iOS, set `showsBackgroundLocationIndicator = true` to show the blue status bar pill. This is both a best practice and may be required by App Store review. Not setting this can lead to app rejection.

6. **Reduced accuracy on iOS 14+** — Users can grant location permission with reduced (approximate) accuracy. Check `manager.accuracyAuthorization` and handle `.reducedAccuracy` gracefully. Use `requestTemporaryFullAccuracyAuthorization` with a purpose key defined in Info.plist when precise location is needed for a specific task.

7. **No update interval control** — Android's `LocationRequest` allows setting exact update intervals. iOS's `CLLocationManager` does not expose update timing — it uses `desiredAccuracy` and `distanceFilter` to control when updates are delivered. You cannot guarantee a specific update frequency.

8. **`startUpdatingLocation` in background** — Continuous location updates in the background require `UIBackgroundModes: location` in Info.plist and `allowsBackgroundLocationUpdates = true`. Without both, updates stop when the app is backgrounded. This is a common cause of "location works in foreground but not background" bugs.

9. **Geofencing requires Always authorization** — On iOS, region monitoring (geofencing) requires `.authorizedAlways`. It does not work with `.authorizedWhenInUse`. Android requires `ACCESS_BACKGROUND_LOCATION` for geofencing only on Android 10+.

## Migration Checklist

- [ ] Add `NSLocationWhenInUseUsageDescription` to Info.plist
- [ ] Add `NSLocationAlwaysAndWhenInUseUsageDescription` if background location or geofencing is needed
- [ ] Add `UIBackgroundModes: location` if continuous background updates are needed
- [ ] Replace `FusedLocationProviderClient` with `CLLocationManager`
- [ ] Implement `CLLocationManagerDelegate` for all location callbacks
- [ ] Map Android priority levels to iOS `desiredAccuracy` values
- [ ] Replace `LocationRequest.setMinUpdateDistanceMeters` with `distanceFilter`
- [ ] Convert `getCurrentLocation()` to `requestLocation()` or `CLLocationUpdate.liveUpdates()`
- [ ] Convert `requestLocationUpdates` / `removeLocationUpdates` to `startUpdatingLocation` / `stopUpdatingLocation`
- [ ] Replace `GeofencingClient` with `CLCircularRegion` and `startMonitoring(for:)`
- [ ] Handle the 20-geofence limit if the Android app uses more than 20
- [ ] Implement manual dwell detection if `GEOFENCE_TRANSITION_DWELL` was used
- [ ] Handle reduced accuracy authorization (iOS 14+) gracefully
- [ ] Request `whenInUse` before `always` to follow Apple's recommended flow
- [ ] Set `allowsBackgroundLocationUpdates = true` and `showsBackgroundLocationIndicator = true` for background tracking
- [ ] Test permission flows on real devices (Simulator location simulation has limitations)
- [ ] Handle the case where user downgrades permission in Settings
