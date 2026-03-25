---
name: generic-android-to-ios-code-shrinking
description: Guides migration of Android code shrinking and optimization (R8/ProGuard rules, obfuscation, mapping files) to iOS equivalents (Swift compiler optimizations, WMO, dead code stripping, symbol stripping, app thinning) with binary size optimization strategies, optimization flags, and build pipeline configuration
type: generic
---

# generic-android-to-ios-code-shrinking

## Context

Android relies heavily on R8 (successor to ProGuard) for code shrinking, obfuscation, and optimization. R8 removes unused classes, methods, and fields; obfuscates remaining symbols; and applies compiler optimizations — all controlled by keep rules. On iOS, the landscape is fundamentally different: Swift's compiler handles optimizations (Whole Module Optimization), the linker strips dead code, and there is no standard obfuscation tool. Instead, iOS focuses on app thinning (on-demand resources, app slicing, bitcode — now deprecated), symbol stripping, and compiler optimization levels. This skill maps Android shrinking patterns to iOS optimization strategies.

## Android Best Practices (Source Patterns)

### R8 / ProGuard Configuration

```kotlin
// app/build.gradle.kts
android {
    buildTypes {
        release {
            isMinifyEnabled = true       // Enable R8 code shrinking
            isShrinkResources = true     // Remove unused resources
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

### ProGuard Rules (proguard-rules.pro)

```proguard
# Keep rules — prevent R8 from removing/obfuscating specific code

# Keep data classes used with serialization (Gson, Moshi, kotlinx.serialization)
-keep class com.app.data.model.** { *; }

# Keep classes used via reflection
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep Retrofit service interfaces
-keepattributes Signature
-keepattributes *Annotation*
-keep,allowobfuscation interface * {
    @retrofit2.http.* <methods>;
}

# Keep Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# Keep enum values (used via valueOf)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
    public static int i(...);
}

# R8 full mode (more aggressive)
# In gradle.properties:
# android.enableR8.fullMode=true
```

### Mapping Files and Crash Reporting

```kotlin
// R8 generates mapping.txt for de-obfuscation
// Located at: app/build/outputs/mapping/release/mapping.txt
// Upload to Firebase Crashlytics, Bugsnag, Sentry for readable stack traces

// In build.gradle.kts — auto-upload mapping file
android {
    buildTypes {
        release {
            // Firebase Crashlytics reads mapping file automatically
            // For custom upload:
            // mappingFileUploadEnabled = true
        }
    }
}
```

### Resource Shrinking

```kotlin
// Strict mode — fail on unused resources
android {
    buildTypes {
        release {
            isShrinkResources = true
        }
    }
}

// Keep specific resources via res/raw/keep.xml
// <?xml version="1.0" encoding="utf-8"?>
// <resources xmlns:tools="http://schemas.android.com/tools"
//     tools:keep="@layout/l_used*,@drawable/ic_keep*"
//     tools:discard="@layout/l_unused*" />
```

### Key Android Patterns to Recognize

- `isMinifyEnabled = true` — enables R8 code shrinking
- `isShrinkResources = true` — removes unused resources
- `proguardFiles(...)` — rule files controlling what R8 preserves
- `-keep class ...` — prevent removal and obfuscation
- `-keepclassmembers` — keep specific members but allow class renaming
- `-dontwarn` — suppress warnings for missing classes
- `-assumenosideeffects` — remove calls (e.g., logging)
- `mapping.txt` — symbol mapping for crash de-obfuscation
- R8 full mode — more aggressive optimizations with stricter keep rules needed

## iOS Best Practices (Target Patterns)

### Swift Compiler Optimization Levels

```
// Build Settings > Swift Compiler - Code Generation > Optimization Level
//
// -Onone     (Debug default) — No optimization, fastest compile, best debuggability
// -O         (Release default) — Full optimization, good balance
// -Osize     — Optimize for binary size (may reduce performance slightly)
// -Ounchecked — Remove runtime safety checks (dangerous, rarely used)
//
// In xcconfig:
// Debug.xcconfig
SWIFT_OPTIMIZATION_LEVEL = -Onone

// Release.xcconfig
SWIFT_OPTIMIZATION_LEVEL = -O
// Or for size-constrained apps:
// SWIFT_OPTIMIZATION_LEVEL = -Osize
```

### Whole Module Optimization (WMO)

```
// Build Settings > Swift Compiler - Code Generation > Compilation Mode
//
// Incremental  (Debug default) — Compiles files individually, faster rebuilds
// Whole Module  (Release default) — Compiles all files together, enables cross-file optimizations
//
// WMO enables:
// - Cross-file function inlining
// - Dead code elimination across files (functions never called from any file)
// - Generic specialization across file boundaries
// - More aggressive devirtualization
//
// In xcconfig:
// Release.xcconfig
SWIFT_COMPILATION_MODE = wholemodule
```

### Dead Code Stripping (Linker)

```
// Build Settings > Linking > Dead Code Stripping
// DEAD_CODE_STRIPPING = YES (default for Release)
//
// The linker removes functions and data that are never referenced.
// This is iOS's closest equivalent to R8's code shrinking.
//
// Additional linker flags for aggressive stripping:
// OTHER_LDFLAGS = -Wl,-dead_strip
//
// Note: Dead code stripping works at the object-file level.
// If any symbol in an object file is used, the entire object file is included.
// For finer granularity, enable:
// GCC_GENERATE_DEBUGGING_SYMBOLS = NO  (Release only)
```

### Symbol Stripping

```
// Build Settings > Deployment > Strip Style
//
// STRIP_STYLE = all          — Strip all symbols (smallest binary)
// STRIP_STYLE = non-global   — Strip non-global symbols
// STRIP_STYLE = debugging    — Strip debugging symbols only
//
// Build Settings > Deployment > Strip Linked Product
// STRIP_INSTALLED_PRODUCT = YES (Release builds)
//
// Build Settings > Deployment > Strip Swift Symbols
// STRIP_SWIFT_SYMBOLS = YES
//
// In xcconfig (Release.xcconfig):
STRIP_INSTALLED_PRODUCT = YES
STRIP_STYLE = all
STRIP_SWIFT_SYMBOLS = YES
COPY_PHASE_STRIP = YES

// Debug symbols for crash reporting (equivalent to mapping.txt)
// Build Settings > Build Options > Debug Information Format
// DEBUG_INFORMATION_FORMAT = dwarf-with-dsym  (generates .dSYM for crash symbolication)
```

### App Thinning (iOS-Specific Size Optimization)

```swift
// App Thinning is handled by the App Store and has three components:
//
// 1. App Slicing — delivers only the assets needed for the target device
//    - @1x, @2x, @3x images — only the correct scale is delivered
//    - Device-specific assets in Asset Catalogs
//    - No code changes needed; use Asset Catalogs correctly
//
// 2. On-Demand Resources (ODR) — download assets lazily
//    Tag resources in Xcode with an ODR tag, then request at runtime:

let request = NSBundleResourceRequest(tags: ["level-5-assets"])
request.beginAccessingResources { error in
    if let error {
        print("Failed to download: \(error)")
        return
    }
    // Use the resources
    let image = UIImage(named: "level5_background")
}
// When done:
request.endAccessingResources()

// 3. Bitcode (DEPRECATED in Xcode 14+)
//    Previously allowed Apple to re-optimize binaries server-side.
//    No longer supported. Remove ENABLE_BITCODE = YES if still present.
```

### Removing Logging in Release (R8 -assumenosideeffects Equivalent)

```swift
// Option 1: Compile-time removal with #if DEBUG
#if DEBUG
func debugLog(_ message: @autoclosure () -> String) {
    print(message())
}
#else
@inline(__always)
func debugLog(_ message: @autoclosure () -> String) {
    // No-op in release — compiler removes this entirely
}
#endif

// Option 2: os.Logger with appropriate levels
import OSLog

extension Logger {
    static let app = Logger(subsystem: "com.app", category: "general")
    static let network = Logger(subsystem: "com.app", category: "network")
}

// os.Logger automatically suppresses debug/info logs in release builds
// when the log level is below the system's configured level.
Logger.app.debug("This won't appear in release console")
Logger.app.error("This will appear in release console")

// Option 3: SwiftLog with configurable log level
import Logging

var logger = Logger(label: "com.app")
#if DEBUG
logger.logLevel = .debug
#else
logger.logLevel = .error
#endif
```

### Binary Size Analysis

```bash
# Analyze binary size (equivalent to Android APK Analyzer)

# 1. Generate app size report via xcodebuild
xcodebuild -exportArchive \
  -archivePath MyApp.xcarchive \
  -exportPath output \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates

# 2. Use App Thinning Size Report
# In Xcode: Window > Organizer > Archives > Distribute App > "App Thinning Size Report"

# 3. Analyze Mach-O binary
size -m MyApp.app/MyApp
# Shows __TEXT, __DATA, __LINKEDIT segment sizes

# 4. Find large symbols
nm -S --size-sort MyApp.app/MyApp | tail -20

# 5. Bloaty (third-party tool for detailed size analysis)
bloaty MyApp.app/MyApp -d compileunits
```

### Obfuscation on iOS

```swift
// Swift has NO standard obfuscation tool equivalent to R8/ProGuard.
// Swift symbols are already somewhat mangled by the compiler.
//
// If obfuscation is required:
// - String encryption: Use tools like SwiftShield or iXGuard (commercial)
// - Control flow obfuscation: iXGuard, Arxan (commercial)
// - Strip symbols: STRIP_STYLE = all (removes symbol names from binary)
//
// For most apps, symbol stripping + Swift name mangling provides
// sufficient protection. Full obfuscation is typically only needed
// for DRM, financial, or security-critical applications.
//
// Important: Unlike Android where obfuscation is free (R8),
// iOS obfuscation tools are typically commercial products.
```

## Migration Mapping Table

| Android (R8/ProGuard) | iOS Equivalent | Notes |
|---|---|---|
| `isMinifyEnabled = true` | `SWIFT_OPTIMIZATION_LEVEL = -O` + `DEAD_CODE_STRIPPING = YES` | Combined effect of compiler optimization and linker stripping |
| `isShrinkResources = true` | App Slicing (automatic) + Asset Catalog cleanup | iOS has no automatic unused resource removal tool |
| R8 code shrinking | Dead Code Stripping (`DEAD_CODE_STRIPPING = YES`) | Linker-level, less granular than R8 |
| R8 obfuscation | Symbol stripping (`STRIP_STYLE = all`) | No renaming; only removes symbols from binary |
| R8 optimization | WMO (`SWIFT_COMPILATION_MODE = wholemodule`) | Cross-file inlining, devirtualization |
| `-keep class ...` | Not needed — no obfuscation/shrinking removes named classes | Only relevant if using third-party obfuscation tools |
| `-assumenosideeffects` (remove logging) | `#if DEBUG` guards or `os.Logger` levels | Compile-time conditional removal |
| `mapping.txt` | `.dSYM` bundle | Upload to Crashlytics/Sentry for crash symbolication |
| `proguard-rules.pro` | No equivalent | No rule files needed in standard iOS builds |
| `-Osize` in R8 | `SWIFT_OPTIMIZATION_LEVEL = -Osize` | Both optimize for binary size over speed |
| APK Analyzer | Xcode Organizer App Thinning Report / `size` command | Binary size breakdown tools |
| Resource shrinking | On-Demand Resources + manual asset cleanup | No automatic unused resource detection |
| `isDebuggable = false` | `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym` + `STRIP_INSTALLED_PRODUCT = YES` | Release stripping with dSYM for crash reporting |
| R8 full mode | `-Osize` + WMO + dead stripping | Most aggressive safe optimization combination |
| Multidex (historical) | N/A | iOS has no method count limit |

## Common Pitfalls

1. **Expecting R8-level code removal** — R8 performs class-level and method-level dead code elimination. iOS dead code stripping operates at the object-file/symbol level and is less granular. You cannot "remove" unused types the same way. Focus on keeping module boundaries clean so unused frameworks are not linked at all.

2. **Forgetting dSYM files** — When you strip symbols for release, you lose the ability to symbolicate crash reports. Always generate dSYMs (`DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`) and upload them to your crash reporting service. This is the equivalent of uploading `mapping.txt`.

3. **Overusing -Ounchecked** — This flag removes bounds checks, overflow checks, and force-unwrap checks. Unlike R8's safe optimizations, `-Ounchecked` can cause undefined behavior and security vulnerabilities. Only use it for performance-critical paths that have been thoroughly tested.

4. **No automatic resource shrinking** — Android's `isShrinkResources = true` automatically removes unreferenced resources. iOS has no built-in equivalent. Unused images, fonts, and data files remain in the bundle. Use tools like FengNiao or manual audits to find unused assets.

5. **Bitcode is deprecated** — If migrating an older iOS project, remove `ENABLE_BITCODE = YES`. Bitcode was deprecated in Xcode 14 and is no longer accepted by the App Store. This was historically the closest thing to R8's server-side optimization.

6. **Dynamic framework overhead** — Each dynamic framework embedded in the app has a launch-time cost (dyld loading). If you have many small frameworks from modularization, consider merging them into static libraries or using `MACH_O_TYPE = staticlib` to avoid launch time regression.

7. **Swift metadata bloat** — Swift generics, protocol witness tables, and type metadata contribute to binary size in ways that have no Android equivalent. Use `-Osize` and avoid excessive generic type parameters to minimize this overhead.

8. **Obfuscation is not free on iOS** — Unlike Android where R8 provides obfuscation at no cost, iOS obfuscation requires commercial tools (SwiftShield, iXGuard). For most apps, symbol stripping provides sufficient protection.

## Migration Checklist

- [ ] Identify all R8/ProGuard configurations in the Android project
- [ ] Set Release build configuration to use `-O` or `-Osize` optimization level
- [ ] Enable Whole Module Optimization (`SWIFT_COMPILATION_MODE = wholemodule`) for Release
- [ ] Enable Dead Code Stripping (`DEAD_CODE_STRIPPING = YES`) for Release
- [ ] Configure symbol stripping: `STRIP_INSTALLED_PRODUCT = YES`, `STRIP_STYLE = all`
- [ ] Enable dSYM generation: `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`
- [ ] Set up dSYM upload to crash reporting service (Crashlytics, Sentry, Bugsnag)
- [ ] Replace `-assumenosideeffects` logging removal with `#if DEBUG` guards or `os.Logger`
- [ ] Audit and remove unused assets manually (use FengNiao or similar tool)
- [ ] Configure Asset Catalogs properly for app slicing (use @1x/@2x/@3x, device-specific variants)
- [ ] Consider On-Demand Resources for large assets not needed at launch
- [ ] Remove `ENABLE_BITCODE = YES` if present (deprecated)
- [ ] Measure binary size using Xcode Organizer App Thinning Report
- [ ] If obfuscation is required, evaluate commercial tools (SwiftShield, iXGuard)
- [ ] Profile launch time to ensure dynamic framework count is not excessive
- [ ] Compare final IPA size against Android APK/AAB size as a sanity check
