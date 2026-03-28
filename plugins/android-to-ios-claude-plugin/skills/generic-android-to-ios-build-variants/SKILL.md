---
name: generic-android-to-ios-build-variants
description: Use when migrating Android build types (debug/release), product flavors, build variants, dimension, and BuildConfig to iOS equivalents (Xcode Schemes, Build Configurations, xcconfig files, compiler flags, and #if DEBUG) with environment switching, per-variant API endpoints, signing configurations, and CI/CD integration
type: generic
---

# generic-android-to-ios-build-variants

## Context

Android's Gradle build system provides build types (debug, release), product flavors (free, paid; staging, production), and build variants (combinations of the two) for managing different app configurations. `BuildConfig` fields, resource overlays, and source sets allow per-variant customization. On iOS, Xcode uses Schemes, Build Configurations (Debug/Release, plus custom ones), xcconfig files, and compiler flags to achieve similar results. This skill maps Android build variant patterns to idiomatic iOS configuration management.

## Android Best Practices (Source Patterns)

### Build Types

```kotlin
// app/build.gradle.kts
android {
    buildTypes {
        debug {
            isDebuggable = true
            isMinifyEnabled = false
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            buildConfigField("String", "API_BASE_URL", "\"https://api.staging.example.com\"")
            buildConfigField("Boolean", "ENABLE_LOGGING", "true")
            resValue("string", "app_name", "MyApp Debug")
        }

        release {
            isDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            buildConfigField("String", "API_BASE_URL", "\"https://api.example.com\"")
            buildConfigField("Boolean", "ENABLE_LOGGING", "false")
            resValue("string", "app_name", "MyApp")

            signingConfig = signingConfigs.getByName("release")
        }
    }

    buildFeatures {
        buildConfig = true
    }
}
```

### Product Flavors and Dimensions

```kotlin
android {
    flavorDimensions += listOf("environment", "monetization")

    productFlavors {
        // Environment dimension
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            buildConfigField("String", "API_BASE_URL", "\"https://api.staging.example.com\"")
            buildConfigField("String", "ENVIRONMENT", "\"staging\"")
        }
        create("production") {
            dimension = "environment"
            buildConfigField("String", "API_BASE_URL", "\"https://api.example.com\"")
            buildConfigField("String", "ENVIRONMENT", "\"production\"")
        }

        // Monetization dimension
        create("free") {
            dimension = "monetization"
            applicationIdSuffix = ".free"
            buildConfigField("Boolean", "IS_PREMIUM", "false")
        }
        create("paid") {
            dimension = "monetization"
            buildConfigField("Boolean", "IS_PREMIUM", "true")
        }
    }

    // Resulting variants: stagingFreeDebug, stagingPaidDebug,
    // productionFreeDebug, productionPaidDebug,
    // stagingFreeRelease, stagingPaidRelease,
    // productionFreeRelease, productionPaidRelease
}
```

### BuildConfig Usage in Code

```kotlin
// Auto-generated BuildConfig fields
if (BuildConfig.DEBUG) {
    Timber.plant(Timber.DebugTree())
}

val apiUrl = BuildConfig.API_BASE_URL

if (BuildConfig.ENABLE_LOGGING) {
    setupNetworkLogging()
}

// Flavor-specific source sets
// src/staging/java/com/app/config/FlavorConfig.kt
// src/production/java/com/app/config/FlavorConfig.kt
// src/free/java/com/app/feature/AdsManager.kt
// src/paid/java/com/app/feature/PremiumFeatures.kt
```

### Signing Configurations

```kotlin
android {
    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("KEYSTORE_PATH") ?: "release.keystore")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
            keyAlias = System.getenv("KEY_ALIAS") ?: ""
            keyPassword = System.getenv("KEY_PASSWORD") ?: ""
        }
    }
}
```

### Key Android Patterns to Recognize

- `buildTypes { debug { } release { } }` — build type configuration
- `productFlavors { }` with `flavorDimensions` — multi-axis variant configuration
- `buildConfigField("Type", "NAME", "value")` — compile-time constants
- `BuildConfig.DEBUG`, `BuildConfig.FIELD_NAME` — accessing variant-specific values
- `applicationIdSuffix` — unique app ID per variant for side-by-side installs
- `signingConfig` — per-variant signing configuration
- `resValue("string", "name", "value")` — per-variant resource values
- Source sets: `src/debug/`, `src/staging/`, `src/productionRelease/`

## iOS Best Practices (Target Patterns)

### Build Configurations (Debug/Release + Custom)

```
// Xcode Build Configurations (equivalent to build types + flavors)
// Project > Info > Configurations:
//
// Debug               (default — local development)
// Debug-Staging       (custom — staging environment, debug build)
// Release-Staging     (custom — staging environment, release optimizations)
// Release-Production  (custom — production release)
//
// Each configuration can have different settings for:
// - Optimization level, code signing, preprocessor macros, etc.
```

### xcconfig Files (Recommended for CI/CD)

```
// Configuration/Base.xcconfig
// Shared settings across all configurations
PRODUCT_BUNDLE_IDENTIFIER = com.app.myapp
MARKETING_VERSION = 1.0.0
CURRENT_PROJECT_VERSION = 1
SWIFT_VERSION = 5.10
IPHONEOS_DEPLOYMENT_TARGET = 17.0

// Configuration/Debug.xcconfig
#include "Base.xcconfig"
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG
PRODUCT_BUNDLE_IDENTIFIER = $(inherited).debug
PRODUCT_NAME = MyApp Debug
API_BASE_URL = https:/$()/api.staging.example.com
ENABLE_LOGGING = YES
CODE_SIGN_IDENTITY = Apple Development
PROVISIONING_PROFILE_SPECIFIER =

// Configuration/Debug-Staging.xcconfig
#include "Base.xcconfig"
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG STAGING
PRODUCT_BUNDLE_IDENTIFIER = $(inherited).staging
PRODUCT_NAME = MyApp Staging
API_BASE_URL = https:/$()/api.staging.example.com
ENABLE_LOGGING = YES
CODE_SIGN_IDENTITY = Apple Development
PROVISIONING_PROFILE_SPECIFIER =

// Configuration/Release-Staging.xcconfig
#include "Base.xcconfig"
SWIFT_ACTIVE_COMPILATION_CONDITIONS = STAGING
PRODUCT_BUNDLE_IDENTIFIER = $(inherited).staging
PRODUCT_NAME = MyApp Staging
API_BASE_URL = https:/$()/api.staging.example.com
ENABLE_LOGGING = NO
SWIFT_OPTIMIZATION_LEVEL = -O
CODE_SIGN_IDENTITY = Apple Distribution
PROVISIONING_PROFILE_SPECIFIER = MyApp Staging Distribution

// Configuration/Release-Production.xcconfig
#include "Base.xcconfig"
SWIFT_ACTIVE_COMPILATION_CONDITIONS = PRODUCTION
PRODUCT_NAME = MyApp
API_BASE_URL = https:/$()/api.example.com
ENABLE_LOGGING = NO
SWIFT_OPTIMIZATION_LEVEL = -O
CODE_SIGN_IDENTITY = Apple Distribution
PROVISIONING_PROFILE_SPECIFIER = MyApp Production Distribution
```

### Accessing Configuration Values in Swift

```swift
// Option 1: Compiler flags (#if DEBUG equivalent to BuildConfig.DEBUG)
#if DEBUG
import OSLog
let logger = Logger(subsystem: "com.app", category: "debug")
#endif

#if STAGING
let environment = "staging"
#elseif PRODUCTION
let environment = "production"
#else
let environment = "development"
#endif

// Option 2: Info.plist values (equivalent to buildConfigField)
// In Info.plist: API_BASE_URL = $(API_BASE_URL)
// Then in xcconfig: API_BASE_URL = https:/$()/api.example.com

enum AppConfiguration {
    static let apiBaseURL: URL = {
        guard let urlString = Bundle.main.infoDictionary?["API_BASE_URL"] as? String,
              let url = URL(string: urlString) else {
            fatalError("API_BASE_URL not configured")
        }
        return url
    }()

    static let isLoggingEnabled: Bool = {
        Bundle.main.infoDictionary?["ENABLE_LOGGING"] as? String == "YES"
    }()

    static let environment: String = {
        #if STAGING
        return "staging"
        #elseif PRODUCTION
        return "production"
        #else
        return "debug"
        #endif
    }()
}

// Option 3: Build Configuration enum (centralized, type-safe)
enum BuildConfiguration {
    case debug
    case staging
    case production

    static var current: BuildConfiguration {
        #if DEBUG
        return .debug
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }

    var apiBaseURL: URL {
        switch self {
        case .debug, .staging:
            URL(string: "https://api.staging.example.com")!
        case .production:
            URL(string: "https://api.example.com")!
        }
    }

    var isLoggingEnabled: Bool {
        switch self {
        case .debug, .staging: true
        case .production: false
        }
    }
}
```

### Xcode Schemes (Equivalent to Selecting a Build Variant)

```
// Schemes tie together a Build Configuration with run/test/profile/archive actions
//
// Scheme: MyApp-Debug
//   Build → Configuration: Debug
//   Run → Configuration: Debug
//   Test → Configuration: Debug
//
// Scheme: MyApp-Staging
//   Build → Configuration: Debug-Staging
//   Run → Configuration: Debug-Staging
//   Test → Configuration: Debug-Staging
//   Archive → Configuration: Release-Staging
//
// Scheme: MyApp-Production
//   Build → Configuration: Release-Production
//   Run → Configuration: Release-Production
//   Archive → Configuration: Release-Production
//
// Environment variables can be set per-scheme in Run > Arguments > Environment Variables
```

### Signing Configuration

```
// In xcconfig files:
// Debug.xcconfig
CODE_SIGN_STYLE = Automatic
DEVELOPMENT_TEAM = XXXXXXXXXX
CODE_SIGN_IDENTITY = Apple Development

// Release-Production.xcconfig
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM = XXXXXXXXXX
CODE_SIGN_IDENTITY = Apple Distribution
PROVISIONING_PROFILE_SPECIFIER = MyApp Production

// For CI/CD, use environment variables:
// Release-CI.xcconfig
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM = $(DEVELOPMENT_TEAM)
PROVISIONING_PROFILE_SPECIFIER = $(PROVISIONING_PROFILE)
```

### Side-by-Side Installation (applicationIdSuffix Equivalent)

```
// Use different bundle identifiers per configuration
// Debug.xcconfig:
PRODUCT_BUNDLE_IDENTIFIER = com.app.myapp.debug

// Staging.xcconfig:
PRODUCT_BUNDLE_IDENTIFIER = com.app.myapp.staging

// Production.xcconfig:
PRODUCT_BUNDLE_IDENTIFIER = com.app.myapp

// Also customize the display name:
// Debug.xcconfig:
PRODUCT_NAME = MyApp Debug
// Or use INFOPLIST_KEY_CFBundleDisplayName = MyApp Debug

// Custom app icon per configuration:
// Add alternate AppIcon sets (AppIcon-Debug, AppIcon-Staging)
// In xcconfig:
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-Debug  // or AppIcon-Staging
```

### CI/CD Integration (Fastlane / xcodebuild)

```ruby
# Fastlane example
lane :build_staging do
  build_app(
    scheme: "MyApp-Staging",
    configuration: "Release-Staging",
    export_method: "ad-hoc"
  )
end

lane :build_production do
  build_app(
    scheme: "MyApp-Production",
    configuration: "Release-Production",
    export_method: "app-store"
  )
end
```

```bash
# xcodebuild command line
xcodebuild archive \
  -project MyApp.xcodeproj \
  -scheme "MyApp-Production" \
  -configuration "Release-Production" \
  -archivePath build/MyApp.xcarchive

xcodebuild -exportArchive \
  -archivePath build/MyApp.xcarchive \
  -exportPath build/output \
  -exportOptionsPlist ExportOptions.plist
```

## Migration Mapping Table

| Android | iOS |
|---|---|
| `buildTypes { debug { } }` | Build Configuration: "Debug" |
| `buildTypes { release { } }` | Build Configuration: "Release" |
| `productFlavors { staging { } }` | Custom Build Configuration: "Debug-Staging", "Release-Staging" |
| `flavorDimensions` | Multiple xcconfig layers with `#include` |
| `buildConfigField("String", "X", "\"val\"")` | xcconfig `X = val` + Info.plist `$(X)` |
| `BuildConfig.DEBUG` | `#if DEBUG` |
| `BuildConfig.CUSTOM_FIELD` | `Bundle.main.infoDictionary?["KEY"]` or `#if FLAG` |
| `applicationIdSuffix ".debug"` | `PRODUCT_BUNDLE_IDENTIFIER = $(inherited).debug` in xcconfig |
| `versionNameSuffix "-debug"` | `MARKETING_VERSION` suffix in xcconfig |
| `resValue("string", "app_name", ...)` | `PRODUCT_NAME` or `INFOPLIST_KEY_CFBundleDisplayName` in xcconfig |
| `signingConfig = signingConfigs["release"]` | `CODE_SIGN_IDENTITY`, `PROVISIONING_PROFILE_SPECIFIER` in xcconfig |
| Source sets `src/debug/`, `src/staging/` | Compiler flags `#if DEBUG`, `#if STAGING` for conditional compilation |
| `isMinifyEnabled = true` | `SWIFT_OPTIMIZATION_LEVEL = -O` |
| `isDebuggable = true` | Build Configuration derived from "Debug" template |
| Gradle variant selection in IDE | Xcode Scheme selection |
| `./gradlew assembleStagingDebug` | `xcodebuild -scheme MyApp-Staging -configuration Debug-Staging` |

## Common Pitfalls

1. **No direct productFlavors equivalent** — iOS does not have a first-class "flavor" concept. You must create custom Build Configurations manually. For a 2x2 matrix (staging/production x debug/release), you need 4 configurations (Debug-Staging, Release-Staging, Debug-Production, Release-Production). This gets unwieldy with many dimensions.

2. **xcconfig syntax gotchas** — xcconfig files use `=` without quotes for string values. URLs require escaping `//` as `/$()/` (e.g., `https:/$()/api.example.com`). Forgetting this causes silent parsing failures.

3. **SWIFT_ACTIVE_COMPILATION_CONDITIONS vs GCC_PREPROCESSOR_DEFINITIONS** — Use `SWIFT_ACTIVE_COMPILATION_CONDITIONS` for Swift code (`#if DEBUG`). Use `GCC_PREPROCESSOR_DEFINITIONS` only for Objective-C code. These are separate settings.

4. **Info.plist variable substitution timing** — Variables in Info.plist (like `$(API_BASE_URL)`) are resolved at build time, not runtime. If you change xcconfig values, you must rebuild. This is similar to Android's `buildConfigField` but some developers expect runtime flexibility.

5. **Scheme sharing** — By default, Xcode schemes are user-specific (stored in `xcuserdata/`). For CI/CD and team sharing, mark schemes as "Shared" (checkbox in Scheme editor) so they are stored in `xcshareddata/` and committed to version control.

6. **Missing configurations for dependencies** — When you add custom Build Configurations, CocoaPods and SPM packages may not have matching configurations. CocoaPods maps unknown configurations to either Debug or Release. SPM always uses Debug/Release. Make sure your custom configs are based on (duplicated from) Debug or Release.

7. **Source sets vs compiler flags** — Android's source sets allow entirely different source files per flavor. iOS uses `#if` compiler flags for conditional code within the same file. For large divergences, consider separate targets rather than flags.

8. **Signing complexity** — Android has one keystore per signing config. iOS has separate certificates (development, distribution) and provisioning profiles (per app ID, per device set). Automatic signing simplifies development but CI/CD usually requires manual signing with explicit profiles.

## Migration Checklist

- [ ] List all Android build types and product flavors with their dimensions
- [ ] Map each build variant to an iOS Build Configuration (create custom ones as needed)
- [ ] Create xcconfig files for each Build Configuration with appropriate settings
- [ ] Set xcconfig files in Xcode project settings (Project > Info > Configurations)
- [ ] Convert `buildConfigField` values to xcconfig variables + Info.plist entries
- [ ] Set `SWIFT_ACTIVE_COMPILATION_CONDITIONS` for conditional compilation flags (DEBUG, STAGING, PRODUCTION)
- [ ] Replace `BuildConfig.DEBUG` usages with `#if DEBUG`
- [ ] Replace `BuildConfig.CUSTOM_FIELD` usages with `Bundle.main.infoDictionary` lookups or `#if` flags
- [ ] Configure `PRODUCT_BUNDLE_IDENTIFIER` per configuration for side-by-side installs
- [ ] Set up signing: `CODE_SIGN_IDENTITY` and `PROVISIONING_PROFILE_SPECIFIER` per configuration
- [ ] Create Xcode Schemes for each major variant (Debug, Staging, Production)
- [ ] Mark all schemes as "Shared" for version control
- [ ] Set up `ASSETCATALOG_COMPILER_APPICON_NAME` per configuration for variant-specific icons
- [ ] Update CI/CD pipeline to use appropriate scheme and configuration
- [ ] Test that each scheme builds, runs, and archives correctly
- [ ] Verify Info.plist variable substitution produces correct values in each configuration
