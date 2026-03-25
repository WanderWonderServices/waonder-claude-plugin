---
name: generic-android-to-ios-firebase
description: Guides migration of Android Firebase SDK (Analytics, Crashlytics, Auth, Firestore, Remote Config, Cloud Functions, App Check) to iOS Firebase SDK via SPM/CocoaPods with GoogleService-Info.plist configuration, SwiftUI integration patterns, and async/await Firebase APIs
type: generic
---

# generic-android-to-ios-firebase

## Context

Firebase provides a unified suite of backend services for both Android and iOS. While the service APIs are conceptually similar, the SDKs differ in initialization, configuration files, platform-specific integration points, and language idioms. Android uses `google-services.json` with the Gradle plugin, while iOS uses `GoogleService-Info.plist` with SPM or CocoaPods. Modern iOS Firebase development leverages Swift async/await APIs and SwiftUI-specific patterns. This skill maps each major Firebase service from its Android implementation to the idiomatic iOS equivalent.

## Android Best Practices (Source Patterns)

### Initialization and Configuration

```kotlin
// build.gradle (project)
plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
    id("com.google.firebase.crashlytics") version "2.9.9" apply false
}

// build.gradle (app)
plugins {
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-crashlytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-config")
    implementation("com.google.firebase:firebase-functions")
    implementation("com.google.firebase:firebase-appcheck-playintegrity")
}
```

### Firebase Analytics

```kotlin
class AnalyticsService @Inject constructor(
    private val analytics: FirebaseAnalytics
) {
    fun logEvent(name: String, params: Map<String, Any>) {
        analytics.logEvent(name) {
            params.forEach { (key, value) ->
                when (value) {
                    is String -> param(key, value)
                    is Long -> param(key, value)
                    is Double -> param(key, value)
                    is Bundle -> param(key, value)
                }
            }
        }

    }

    fun setUserProperty(name: String, value: String) {
        analytics.setUserProperty(name, value)
    }

    fun setUserId(id: String) {
        analytics.setUserId(id)
    }

    fun logScreenView(screenName: String, screenClass: String) {
        analytics.logEvent(FirebaseAnalytics.Event.SCREEN_VIEW) {
            param(FirebaseAnalytics.Param.SCREEN_NAME, screenName)
            param(FirebaseAnalytics.Param.SCREEN_CLASS, screenClass)
        }
    }
}
```

### Firebase Auth

```kotlin
class AuthRepository @Inject constructor(
    private val auth: FirebaseAuth
) {
    val currentUser: Flow<FirebaseUser?> = callbackFlow {
        val listener = FirebaseAuth.AuthStateListener { trySend(it.currentUser) }
        auth.addAuthStateListener(listener)
        awaitClose { auth.removeAuthStateListener(listener) }
    }

    suspend fun signInWithEmail(email: String, password: String): Result<FirebaseUser> {
        return try {
            val result = auth.signInWithEmailAndPassword(email, password).await()
            Result.success(result.user!!)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun signInWithGoogle(idToken: String): Result<FirebaseUser> {
        val credential = GoogleAuthProvider.getCredential(idToken, null)
        return try {
            val result = auth.signInWithCredential(credential).await()
            Result.success(result.user!!)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun signUp(email: String, password: String): Result<FirebaseUser> {
        return try {
            val result = auth.createUserWithEmailAndPassword(email, password).await()
            Result.success(result.user!!)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    fun signOut() = auth.signOut()
}
```

### Firestore

```kotlin
class UserFirestoreDataSource @Inject constructor(
    private val firestore: FirebaseFirestore
) {
    suspend fun getUser(userId: String): User {
        return firestore.collection("users")
            .document(userId)
            .get()
            .await()
            .toObject<User>()!!
    }

    fun observeUser(userId: String): Flow<User> = callbackFlow {
        val registration = firestore.collection("users")
            .document(userId)
            .addSnapshotListener { snapshot, error ->
                if (error != null) { close(error); return@addSnapshotListener }
                snapshot?.toObject<User>()?.let { trySend(it) }
            }
        awaitClose { registration.remove() }
    }

    suspend fun updateUser(userId: String, updates: Map<String, Any>) {
        firestore.collection("users")
            .document(userId)
            .update(updates)
            .await()
    }

    suspend fun queryActiveUsers(): List<User> {
        return firestore.collection("users")
            .whereEqualTo("active", true)
            .orderBy("lastLogin", Query.Direction.DESCENDING)
            .limit(50)
            .get()
            .await()
            .toObjects<User>()
    }
}
```

### Remote Config

```kotlin
class RemoteConfigRepository @Inject constructor(
    private val remoteConfig: FirebaseRemoteConfig
) {
    init {
        val settings = remoteConfigSettings {
            minimumFetchIntervalInSeconds = if (BuildConfig.DEBUG) 0 else 3600
        }
        remoteConfig.setConfigSettingsAsync(settings)
        remoteConfig.setDefaultsAsync(R.xml.remote_config_defaults)
    }

    suspend fun fetchAndActivate(): Boolean {
        return remoteConfig.fetchAndActivate().await()
    }

    fun getString(key: String): String = remoteConfig.getString(key)
    fun getBoolean(key: String): Boolean = remoteConfig.getBoolean(key)
    fun getLong(key: String): Long = remoteConfig.getLong(key)
}
```

### Cloud Functions

```kotlin
class CloudFunctionsService @Inject constructor(
    private val functions: FirebaseFunctions
) {
    suspend fun processPayment(amount: Double, currency: String): PaymentResult {
        val data = hashMapOf("amount" to amount, "currency" to currency)
        val result = functions
            .getHttpsCallable("processPayment")
            .call(data)
            .await()
        val resultData = result.data as Map<*, *>
        return PaymentResult(
            transactionId = resultData["transactionId"] as String,
            status = resultData["status"] as String
        )
    }
}
```

### App Check

```kotlin
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        FirebaseApp.initializeApp(this)

        val appCheckFactory = PlayIntegrityAppCheckProviderFactory.getInstance()
        FirebaseAppCheck.getInstance().installAppCheckProviderFactory(appCheckFactory)
    }
}
```

### Crashlytics

```kotlin
class CrashlyticsService @Inject constructor(
    private val crashlytics: FirebaseCrashlytics
) {
    fun setUserId(id: String) = crashlytics.setUserId(id)
    fun log(message: String) = crashlytics.log(message)

    fun setCustomKey(key: String, value: String) =
        crashlytics.setCustomKey(key, value)

    fun recordException(throwable: Throwable) =
        crashlytics.recordException(throwable)

    fun enableCollection(enabled: Boolean) =
        crashlytics.setCrashlyticsCollectionEnabled(enabled)
}
```

## iOS Equivalent Patterns

### Initialization and Configuration via SPM

```swift
// 1. Add Firebase SDK via Swift Package Manager:
//    https://github.com/firebase/firebase-ios-sdk
//    Select: FirebaseAnalytics, FirebaseCrashlytics, FirebaseAuth,
//            FirebaseFirestore, FirebaseRemoteConfig, FirebaseFunctions,
//            FirebaseAppCheck

// 2. Add GoogleService-Info.plist to the Xcode project (download from Firebase Console)
//    Ensure it is added to the correct target

// 3. Initialize in App entry point
import SwiftUI
import FirebaseCore
import FirebaseAppCheck

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // App Check must be configured before FirebaseApp.configure()
        let providerFactory = AppAttestProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)

        FirebaseApp.configure()
        return true
    }
}
```

### Firebase Analytics

```swift
import FirebaseAnalytics

struct AnalyticsService {
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }

    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    func setUserID(_ id: String?) {
        Analytics.setUserID(id)
    }

    func logScreenView(screenName: String, screenClass: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass
        ])
    }
}

// SwiftUI screen tracking modifier
struct ScreenTrackingModifier: ViewModifier {
    let screenName: String
    let screenClass: String

    func body(content: Content) -> some View {
        content.onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: screenName,
                AnalyticsParameterScreenClass: screenClass
            ])
        }
    }
}

extension View {
    func trackScreen(name: String, className: String = "") -> some View {
        modifier(ScreenTrackingModifier(screenName: name, screenClass: className))
    }
}

// Usage
struct ProfileView: View {
    var body: some View {
        Text("Profile")
            .trackScreen(name: "Profile", className: "ProfileView")
    }
}
```

### Firebase Auth

```swift
import FirebaseAuth

@Observable
class AuthRepository {
    private(set) var currentUser: User?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signInWithEmail(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws -> User {
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )
        let result = try await Auth.auth().signIn(with: credential)
        return result.user
    }

    func signUp(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().createUser(
            withEmail: email,
            password: password
        )
        return result.user
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
```

### Firestore

```swift
import FirebaseFirestore

struct UserModel: Codable, Identifiable {
    @DocumentID var id: String?
    let name: String
    let email: String
    let active: Bool
    let lastLogin: Timestamp
}

actor UserFirestoreDataSource {
    private let db = Firestore.firestore()

    func getUser(userId: String) async throws -> UserModel {
        try await db.collection("users")
            .document(userId)
            .getDocument(as: UserModel.self)
    }

    // Real-time listener using AsyncStream
    func observeUser(userId: String) -> AsyncThrowingStream<UserModel, Error> {
        AsyncThrowingStream { continuation in
            let registration = db.collection("users")
                .document(userId)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else { return }
                    do {
                        let user = try snapshot.data(as: UserModel.self)
                        continuation.yield(user)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            continuation.onTermination = { _ in
                registration.remove()
            }
        }
    }

    func updateUser(userId: String, fields: [String: Any]) async throws {
        try await db.collection("users")
            .document(userId)
            .updateData(fields)
    }

    func queryActiveUsers() async throws -> [UserModel] {
        let snapshot = try await db.collection("users")
            .whereField("active", isEqualTo: true)
            .order(by: "lastLogin", descending: true)
            .limit(to: 50)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: UserModel.self) }
    }
}
```

### Remote Config

```swift
import FirebaseRemoteConfig

@Observable
class RemoteConfigRepository {
    private let remoteConfig = RemoteConfig.remoteConfig()

    init() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(fromPlist: "RemoteConfigDefaults")
    }

    func fetchAndActivate() async throws -> RemoteConfigFetchAndActivateStatus {
        try await remoteConfig.fetchAndActivate()
    }

    func getString(forKey key: String) -> String {
        remoteConfig.configValue(forKey: key).stringValue ?? ""
    }

    func getBool(forKey key: String) -> Bool {
        remoteConfig.configValue(forKey: key).boolValue
    }

    func getNumber(forKey key: String) -> NSNumber {
        remoteConfig.configValue(forKey: key).numberValue
    }

    // Real-time Remote Config updates (Firebase iOS SDK 10.7+)
    func listenForUpdates() async {
        do {
            for try await _ in remoteConfig.updates {
                try await remoteConfig.activate()
            }
        } catch {
            print("Remote Config update error: \(error)")
        }
    }
}
```

### Cloud Functions

```swift
import FirebaseFunctions

actor CloudFunctionsService {
    private let functions = Functions.functions()

    func processPayment(amount: Double, currency: String) async throws -> PaymentResult {
        let result = try await functions.httpsCallable("processPayment")
            .call(["amount": amount, "currency": currency])

        guard let data = result.data as? [String: Any],
              let transactionId = data["transactionId"] as? String,
              let status = data["status"] as? String else {
            throw AppError.invalidResponse
        }

        return PaymentResult(transactionId: transactionId, status: status)
    }
}
```

### App Check

```swift
import FirebaseAppCheck

// For production: App Attest
class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        } else {
            return DeviceCheckProvider(app: app)
        }
    }
}

// For debug builds
#if DEBUG
class DebugAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return AppCheckDebugProvider(app: app)
    }
}
#endif
```

### Crashlytics

```swift
import FirebaseCrashlytics

struct CrashlyticsService {
    private let crashlytics = Crashlytics.crashlytics()

    func setUserId(_ id: String) {
        crashlytics.setUserID(id)
    }

    func log(_ message: String) {
        crashlytics.log(message)
    }

    func setCustomValue(_ value: Any, forKey key: String) {
        crashlytics.setCustomValue(value, forKey: key)
    }

    func recordError(_ error: Error, userInfo: [String: Any]? = nil) {
        crashlytics.record(error: error, userInfo: userInfo)
    }

    func enableCollection(_ enabled: Bool) {
        crashlytics.setCrashlyticsCollectionEnabled(enabled)
    }
}
```

## Configuration File Mapping

| Android | iOS |
|---------|-----|
| `google-services.json` | `GoogleService-Info.plist` |
| `com.google.gms.google-services` Gradle plugin | `FirebaseApp.configure()` in AppDelegate |
| `firebase-bom` (BOM for version alignment) | SPM resolves versions from the single `firebase-ios-sdk` package |
| `R.xml.remote_config_defaults` | `RemoteConfigDefaults.plist` |
| Build variant configs (debug/release json) | Multiple `GoogleService-Info.plist` with build phase scripts or targets |

## Common Pitfalls

1. **Calling FirebaseApp.configure() too late** - Must be called in `application(_:didFinishLaunchingWithOptions:)` before any Firebase service is used. In SwiftUI, use `@UIApplicationDelegateAdaptor`.

2. **Missing GoogleService-Info.plist in target** - The plist must be added to the correct app target. Verify in Build Phases > Copy Bundle Resources.

3. **Using callback APIs instead of async/await** - Firebase iOS SDK 10+ provides native async/await APIs for all services. Avoid nesting completion handlers; use the async variants.

4. **Not handling Firestore Codable mapping** - Use `@DocumentID` for the document ID field. Firestore's `Codable` support requires explicit `Timestamp` types, not `Date`, unless you configure a custom decoder.

5. **Forgetting to add `-ObjC` linker flag** - Some Firebase pods require the `-ObjC` flag in Other Linker Flags. SPM handles this automatically but CocoaPods may not.

6. **Remote Config defaults not loading** - Ensure the plist file name matches exactly and is included in the target. Unlike Android XML defaults, iOS uses a flat key-value plist.

7. **App Check debug provider leaking to production** - Always gate `DebugAppCheckProviderFactory` behind `#if DEBUG`. The debug token in production bypasses attestation entirely.

8. **Not configuring multiple environments** - For staging/prod Firebase projects, use separate `GoogleService-Info.plist` files per build configuration. Use a Run Script build phase to copy the right one.

## Migration Checklist

- [ ] Download `GoogleService-Info.plist` from Firebase Console and add to Xcode project
- [ ] Add Firebase iOS SDK via SPM (preferred) or CocoaPods with required products
- [ ] Initialize Firebase in AppDelegate using `@UIApplicationDelegateAdaptor` for SwiftUI apps
- [ ] Migrate Analytics events, ensuring parameter names match across platforms
- [ ] Convert Auth flows to async/await, including auth state listeners using `addStateDidChangeListener`
- [ ] Migrate Firestore models to Swift `Codable` with `@DocumentID` annotation
- [ ] Convert Firestore snapshot listeners to `AsyncThrowingStream` wrappers
- [ ] Set up Remote Config with plist defaults and matching keys
- [ ] Migrate Cloud Functions callable references to async/await pattern
- [ ] Configure App Check with `AppAttestProvider` (production) and `DebugAppCheckProvider` (debug)
- [ ] Integrate Crashlytics and add `FirebaseCrashlytics` build phase for dSYM upload
- [ ] Add the Crashlytics run script: `"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"`
- [ ] Verify all Firebase services work with SwiftUI lifecycle (no UIKit AppDelegate required beyond init)
- [ ] Test with Firebase Emulator Suite for Auth, Firestore, and Functions
- [ ] Set up multiple `GoogleService-Info.plist` for debug/staging/production environments
