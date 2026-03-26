---
name: generic-android-to-ios-datastore
description: Migrate Android DataStore (Preferences and Proto) to iOS UserDefaults, @AppStorage, and NSUbiquitousKeyValueStore for key-value and typed preference storage
type: generic
---

# generic-android-to-ios-datastore

## Context
Android Jetpack DataStore is the modern replacement for SharedPreferences, offering asynchronous, type-safe key-value storage (Preferences DataStore) and schema-backed storage via Protocol Buffers (Proto DataStore). On iOS the native equivalents are `UserDefaults` for simple key-value storage, `@AppStorage` for SwiftUI-reactive preferences, and `NSUbiquitousKeyValueStore` for iCloud-synced key-value pairs.

This skill covers migrating both Preferences DataStore and Proto DataStore patterns, including async read/write flows, type safety strategies, and migration paths from legacy storage.

## Android Best Practices (DataStore)

### Preferences DataStore
- Create a single `DataStore<Preferences>` instance per file using the `preferencesDataStore` delegate.
- Define keys as `Preferences.Key<T>` constants grouped in a companion object or dedicated keys object.
- Read values via `dataStore.data.map { prefs -> prefs[KEY] }` returning a `Flow<T?>`.
- Write values inside `dataStore.edit { prefs -> prefs[KEY] = value }` which is a suspend function.
- Handle `IOException` during reads (corrupted file) by emitting default values.

### Proto DataStore
- Define the schema in a `.proto` file and generate Kotlin classes.
- Implement a `Serializer<T>` for the proto message.
- Access data as a typed `Flow<T>` and update via `dataStore.updateData { current -> current.toBuilder()... }`.

### Kotlin Patterns

```kotlin
// --- Preferences DataStore ---
private val Context.settingsDataStore by preferencesDataStore(name = "settings")

object SettingsKeys {
    val DARK_MODE = booleanPreferencesKey("dark_mode")
    val LANGUAGE = stringPreferencesKey("language")
    val MAP_ZOOM = floatPreferencesKey("map_zoom")
    val ONBOARDING_COMPLETE = booleanPreferencesKey("onboarding_complete")
}

class SettingsRepository(private val context: Context) {

    val darkMode: Flow<Boolean> = context.settingsDataStore.data
        .catch { e ->
            if (e is IOException) emit(emptyPreferences())
            else throw e
        }
        .map { prefs -> prefs[SettingsKeys.DARK_MODE] ?: false }

    val language: Flow<String> = context.settingsDataStore.data
        .map { prefs -> prefs[SettingsKeys.LANGUAGE] ?: "en" }

    suspend fun setDarkMode(enabled: Boolean) {
        context.settingsDataStore.edit { prefs ->
            prefs[SettingsKeys.DARK_MODE] = enabled
        }
    }

    suspend fun setLanguage(code: String) {
        context.settingsDataStore.edit { prefs ->
            prefs[SettingsKeys.LANGUAGE] = code
        }
    }

    suspend fun clearAll() {
        context.settingsDataStore.edit { it.clear() }
    }
}

// --- Proto DataStore ---
// user_preferences.proto
// message UserPreferences {
//   bool dark_mode = 1;
//   string language = 2;
//   float map_zoom = 3;
//   bool onboarding_complete = 4;
// }

object UserPreferencesSerializer : Serializer<UserPreferences> {
    override val defaultValue: UserPreferences = UserPreferences.getDefaultInstance()

    override suspend fun readFrom(input: InputStream): UserPreferences =
        try { UserPreferences.parseFrom(input) }
        catch (e: InvalidProtocolBufferException) { throw CorruptionException("Cannot read proto", e) }

    override suspend fun writeTo(t: UserPreferences, output: OutputStream) = t.writeTo(output)
}

private val Context.userPrefsDataStore by dataStore(
    fileName = "user_preferences.pb",
    serializer = UserPreferencesSerializer
)

class UserPreferencesRepository(private val context: Context) {
    val preferences: Flow<UserPreferences> = context.userPrefsDataStore.data

    suspend fun updateDarkMode(enabled: Boolean) {
        context.userPrefsDataStore.updateData { prefs ->
            prefs.toBuilder().setDarkMode(enabled).build()
        }
    }
}

// --- Migration from SharedPreferences ---
private val Context.settingsDataStore by preferencesDataStore(
    name = "settings",
    produceMigrations = { context ->
        listOf(SharedPreferencesMigration(context, "old_shared_prefs"))
    }
)
```

## iOS Best Practices

### UserDefaults
- Use `UserDefaults.standard` for app-scoped preferences or a custom suite for app groups.
- Define keys as static string constants in a dedicated enum or struct to avoid typos.
- Use `register(defaults:)` at app launch to set initial values.
- UserDefaults is synchronous but writes are coalesced and persisted asynchronously.
- For complex types, store them as `Data` via `Codable` encoding.

### @AppStorage (SwiftUI)
- Binds directly to `UserDefaults` and triggers SwiftUI view updates on change.
- Supports `Bool`, `Int`, `Double`, `String`, `URL`, `Data`, and `RawRepresentable` types.
- Specify a custom `UserDefaults` suite via the `store` parameter for app groups.

### NSUbiquitousKeyValueStore (iCloud Sync)
- Mirrors the `UserDefaults` API but syncs across devices via iCloud.
- Limited to 1 MB total and 1024 keys.
- Observe `NSUbiquitousKeyValueStore.didChangeExternallyNotification` for remote changes.

### Swift Patterns

```swift
// --- Key definitions ---
enum SettingsKey {
    static let darkMode = "dark_mode"
    static let language = "language"
    static let mapZoom = "map_zoom"
    static let onboardingComplete = "onboarding_complete"
}

// --- UserDefaults wrapper (equivalent to Preferences DataStore) ---
final class SettingsRepository: ObservableObject {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            SettingsKey.darkMode: false,
            SettingsKey.language: "en",
            SettingsKey.mapZoom: 14.0,
            SettingsKey.onboardingComplete: false
        ])
    }

    @Published var darkMode: Bool {
        get { defaults.bool(forKey: SettingsKey.darkMode) }
        set { defaults.set(newValue, forKey: SettingsKey.darkMode) }
    }

    @Published var language: String {
        get { defaults.string(forKey: SettingsKey.language) ?? "en" }
        set { defaults.set(newValue, forKey: SettingsKey.language) }
    }

    var mapZoom: Float {
        get { defaults.float(forKey: SettingsKey.mapZoom) }
        set { defaults.set(newValue, forKey: SettingsKey.mapZoom) }
    }

    func clearAll() {
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
    }
}

// --- @AppStorage in SwiftUI (reactive equivalent of DataStore Flow reads) ---
struct SettingsView: View {
    @AppStorage(SettingsKey.darkMode) private var darkMode = false
    @AppStorage(SettingsKey.language) private var language = "en"
    @AppStorage(SettingsKey.mapZoom) private var mapZoom: Double = 14.0

    var body: some View {
        Form {
            Toggle("Dark Mode", isOn: $darkMode)
            Picker("Language", selection: $language) {
                Text("English").tag("en")
                Text("Spanish").tag("es")
                Text("French").tag("fr")
            }
            Slider(value: $mapZoom, in: 1...20, step: 1) {
                Text("Map Zoom: \(Int(mapZoom))")
            }
        }
    }
}

// --- Typed preferences object (equivalent to Proto DataStore) ---
struct UserPreferences: Codable, Equatable {
    var darkMode: Bool = false
    var language: String = "en"
    var mapZoom: Float = 14.0
    var onboardingComplete: Bool = false
}

final class UserPreferencesRepository: ObservableObject {
    private static let storageKey = "user_preferences"
    private let defaults: UserDefaults

    @Published private(set) var preferences: UserPreferences

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            self.preferences = decoded
        } else {
            self.preferences = UserPreferences()
        }
    }

    func update(_ transform: (inout UserPreferences) -> Void) {
        var updated = preferences
        transform(&updated)
        preferences = updated
        if let data = try? JSONEncoder().encode(updated) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}

// Usage:
// repository.update { $0.darkMode = true }

// --- iCloud sync (equivalent to cross-device DataStore) ---
final class CloudSettingsRepository {
    private let store = NSUbiquitousKeyValueStore.default

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        store.synchronize()
    }

    var darkMode: Bool {
        get { store.bool(forKey: SettingsKey.darkMode) }
        set { store.set(newValue, forKey: SettingsKey.darkMode) }
    }

    @objc private func storeDidChange(_ notification: Notification) {
        // Handle external changes, update local state
    }
}

// --- Migration from legacy NSUserDefaults keys ---
final class PreferencesMigrator {
    static func migrateIfNeeded(from old: UserDefaults = .standard, to new: UserPreferencesRepository) {
        let migrationKey = "preferences_migrated_v1"
        guard !old.bool(forKey: migrationKey) else { return }

        // Read legacy keys
        let darkMode = old.bool(forKey: "old_dark_mode_key")
        let language = old.string(forKey: "old_language_key") ?? "en"

        // Write to new storage
        new.update {
            $0.darkMode = darkMode
            $0.language = language
        }

        // Clean up legacy keys
        old.removeObject(forKey: "old_dark_mode_key")
        old.removeObject(forKey: "old_language_key")
        old.set(true, forKey: migrationKey)
    }
}
```

## Concept Mapping

| Android (DataStore) | iOS Equivalent | Notes |
|---|---|---|
| `preferencesDataStore` | `UserDefaults.standard` | Both are key-value stores |
| `Preferences.Key<T>` | Static string constants | iOS has no typed key objects; use wrapper methods |
| `dataStore.data` (Flow) | `@AppStorage` / `@Published` | `@AppStorage` is SwiftUI-only; use `@Published` in ObservableObject elsewhere |
| `dataStore.edit { }` | `defaults.set(value, forKey:)` | iOS writes are synchronous API, async persistence |
| Proto DataStore | `Codable` struct in UserDefaults | Store as JSON `Data` blob |
| `SharedPreferencesMigration` | Manual migration helper | No built-in equivalent; write a one-time migration |
| `produceMigrations` | `register(defaults:)` + migration flag | Use a boolean flag to track migration completion |
| DataStore file scope | `UserDefaults` suite / App Group | Use `UserDefaults(suiteName:)` for shared containers |
| iCloud via custom DataStore | `NSUbiquitousKeyValueStore` | 1 MB limit, 1024 keys max |

## Common Pitfalls
1. **Type safety gap**: DataStore keys are typed (`booleanPreferencesKey`, `stringPreferencesKey`). UserDefaults returns `Any?` from `object(forKey:)`. Always use the typed accessors (`bool(forKey:)`, `string(forKey:)`) or build a typed wrapper.
2. **Default values**: DataStore emits `null` for missing keys; you apply defaults in the `map` operator. UserDefaults returns `0`/`false`/`nil` for missing keys. Use `register(defaults:)` to set baseline values at launch.
3. **Observation model**: DataStore emits via `Flow` (cold stream, multiple collectors supported). `@AppStorage` only works in SwiftUI views. For non-SwiftUI observation, use `UserDefaults.publisher(for:)` (Combine) or KVO.
4. **Thread safety**: DataStore is fully async and thread-safe. UserDefaults is thread-safe for reads/writes but `register(defaults:)` should be called on the main thread before any access.
5. **Data size**: DataStore and UserDefaults are both designed for small data. Do not store large blobs (images, large JSON arrays). Use the file system or a database instead.
6. **Proto DataStore migration**: When migrating Proto DataStore, the schema is the `.proto` file. On iOS, the schema is the `Codable` struct. Add new fields with default values to maintain backward compatibility.
7. **App Group sharing**: DataStore files are app-private. To share preferences across app extensions on iOS, use `UserDefaults(suiteName: "group.com.waonder.app")`.

## Migration Checklist
- [ ] Inventory all `preferencesDataStore` and `dataStore` instances in the Android codebase
- [ ] Map each `Preferences.Key<T>` to a typed UserDefaults accessor or `@AppStorage` property
- [ ] Convert Proto DataStore schemas to equivalent `Codable` structs
- [ ] Replace `Flow<T>` reads with `@AppStorage` (SwiftUI) or `@Published` properties (non-SwiftUI)
- [ ] Replace `dataStore.edit { }` calls with UserDefaults `set(_:forKey:)` calls
- [ ] Implement `register(defaults:)` at app launch for all default values
- [ ] Write a one-time migration helper if migrating from legacy NSUserDefaults keys
- [ ] Add App Group suite if preferences must be shared with extensions or widgets
- [ ] Set up `NSUbiquitousKeyValueStore` if cross-device sync is required
- [ ] Unit test the preferences repository with a custom `UserDefaults(suiteName:)` instance
- [ ] Verify that `@AppStorage` views update correctly when values change from non-UI code
