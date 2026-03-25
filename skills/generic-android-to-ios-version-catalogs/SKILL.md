---
name: generic-android-to-ios-version-catalogs
description: Guides migration of Android Version Catalogs (libs.versions.toml), BOMs, and dependency constraints to iOS equivalents (Package.swift version requirements, CocoaPods Podfile, Tuist Dependencies.swift) with centralized version management, dependency locking, resolution strategies, and update workflows
type: generic
---

# generic-android-to-ios-version-catalogs

## Context

Android's Version Catalogs (`libs.versions.toml`) centralize dependency declarations and version management across a multi-module Gradle project. Combined with BOMs (Bill of Materials) that align versions across a library suite, this system provides type-safe dependency accessors and consistent version resolution. On iOS, dependency version management is split across SPM (`Package.swift`), CocoaPods (`Podfile`), and optionally Tuist (`Dependencies.swift`). Each tool has different version resolution semantics, locking mechanisms, and update workflows. This skill maps Android version management patterns to idiomatic iOS equivalents.

## Android Best Practices (Source Patterns)

### Version Catalog (libs.versions.toml)

```toml
# gradle/libs.versions.toml

[versions]
kotlin = "2.0.21"
agp = "8.7.3"
compose-bom = "2024.12.01"
coroutines = "1.9.0"
ktor = "3.0.2"
hilt = "2.53.1"
room = "2.6.1"
navigation = "2.8.5"
lifecycle = "2.8.7"
coil = "2.7.0"
okhttp = "4.12.0"
retrofit = "2.11.0"
moshi = "1.15.1"
timber = "5.0.1"
junit = "4.13.2"
truth = "1.4.4"
mockk = "1.13.13"

[libraries]
# Compose BOM — aligns all Compose library versions
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
compose-ui = { group = "androidx.compose.ui", name = "ui" }
compose-material3 = { group = "androidx.compose.material3", name = "material3" }
compose-ui-tooling = { group = "androidx.compose.ui", name = "ui-tooling" }

# Coroutines
coroutines-core = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-core", version.ref = "coroutines" }
coroutines-android = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-android", version.ref = "coroutines" }

# Networking
ktor-client-core = { group = "io.ktor", name = "ktor-client-core", version.ref = "ktor" }
ktor-client-okhttp = { group = "io.ktor", name = "ktor-client-okhttp", version.ref = "ktor" }
ktor-client-content-negotiation = { group = "io.ktor", name = "ktor-client-content-negotiation", version.ref = "ktor" }
okhttp = { group = "com.squareup.okhttp3", name = "okhttp", version.ref = "okhttp" }
retrofit = { group = "com.squareup.retrofit2", name = "retrofit", version.ref = "retrofit" }

# DI
hilt-android = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
hilt-compiler = { group = "com.google.dagger", name = "hilt-android-compiler", version.ref = "hilt" }

# Database
room-runtime = { group = "androidx.room", name = "room-runtime", version.ref = "room" }
room-compiler = { group = "androidx.room", name = "room-compiler", version.ref = "room" }
room-ktx = { group = "androidx.room", name = "room-ktx", version.ref = "room" }

# Lifecycle
lifecycle-viewmodel = { group = "androidx.lifecycle", name = "lifecycle-viewmodel-ktx", version.ref = "lifecycle" }
lifecycle-runtime-compose = { group = "androidx.lifecycle", name = "lifecycle-runtime-compose", version.ref = "lifecycle" }

# Testing
junit = { group = "junit", name = "junit", version.ref = "junit" }
truth = { group = "com.google.truth", name = "truth", version.ref = "truth" }
mockk = { group = "io.mockk", name = "mockk", version.ref = "mockk" }
coroutines-test = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-test", version.ref = "coroutines" }

[bundles]
compose = ["compose-ui", "compose-material3"]
ktor = ["ktor-client-core", "ktor-client-okhttp", "ktor-client-content-negotiation"]
room = ["room-runtime", "room-ktx"]
testing = ["junit", "truth", "mockk", "coroutines-test"]

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
android-library = { id = "com.android.library", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
room = { id = "androidx.room", version.ref = "room" }
```

### Usage in build.gradle.kts

```kotlin
// Type-safe accessors generated from the catalog
dependencies {
    // BOM usage — no version needed for individual libraries
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)

    // Version from catalog
    implementation(libs.coroutines.core)
    implementation(libs.ktor.client.core)

    // Bundles — groups of related dependencies
    implementation(libs.bundles.ktor)
    implementation(libs.bundles.room)

    // Test bundles
    testImplementation(libs.bundles.testing)

    // KSP/KAPT processors
    ksp(libs.room.compiler)
    ksp(libs.hilt.compiler)
}
```

### BOM (Bill of Materials)

```kotlin
// BOM aligns all libraries from a suite to compatible versions
// Only need to specify the BOM version; individual libraries inherit it

dependencies {
    // Compose BOM
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)          // version from BOM
    implementation(libs.compose.material3)   // version from BOM

    // OkHttp BOM
    implementation(platform("com.squareup.okhttp3:okhttp-bom:4.12.0"))
    implementation("com.squareup.okhttp3:okhttp")         // version from BOM
    implementation("com.squareup.okhttp3:logging-interceptor") // version from BOM

    // Firebase BOM
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-analytics")  // version from BOM
    implementation("com.google.firebase:firebase-auth")       // version from BOM
}
```

### Dependency Constraints and Resolution

```kotlin
// Force a specific version across all modules
configurations.all {
    resolutionStrategy {
        force("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")
    }
}

// Dependency constraints (softer than force)
dependencies {
    constraints {
        implementation("com.squareup.okhttp3:okhttp") {
            version { strictly("4.12.0") }
            because("Security fix in 4.12.0")
        }
    }
}

// Dependency locking
dependencyLocking {
    lockAllConfigurations()
}
// Run: ./gradlew dependencies --write-locks
// Generates: gradle/dependency-locks/*.lockfile
```

### Key Android Patterns to Recognize

- `libs.versions.toml` — centralized version catalog file
- `libs.library.name` — type-safe accessor in `build.gradle.kts`
- `libs.bundles.name` — group of related dependencies
- `platform(libs.xxx.bom)` — BOM for version alignment
- `version.ref = "name"` — version reference in catalog
- `[bundles]` section — dependency groups
- `[plugins]` section — Gradle plugin version management
- `resolutionStrategy.force()` — force a dependency version
- `dependencyLocking` — lock dependency versions to specific resolved versions

## iOS Best Practices (Target Patterns)

### SPM Package.swift Version Requirements

```swift
// Package.swift — version requirements for external dependencies
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.iOS(.v17)],
    dependencies: [
        // Exact equivalent of version catalog entries:

        // "Up to next major" — most common, like Gradle's default behavior
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0"),

        // Exact version (like `strictly` in Gradle)
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "6.29.3"),

        // Version range
        .package(url: "https://github.com/apple/swift-async-algorithms.git", "1.0.0"..<"2.0.0"),

        // Up to next minor (stricter than `from:`)
        .package(url: "https://github.com/onevcat/Kingfisher.git", .upToNextMinor(from: "8.1.0")),

        // Branch-based (development only)
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", branch: "main"),

        // Revision-based (pinned to exact commit)
        .package(url: "https://github.com/some/package.git", revision: "abc123"),
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
    ]
)
```

### Centralized Version Management with SPM (Version Catalog Equivalent)

```swift
// Package.swift — centralize versions using Swift variables
// This is the closest SPM pattern to libs.versions.toml

// swift-tools-version: 5.10
import PackageDescription

// MARK: - Version Catalog (equivalent to [versions] in libs.versions.toml)
enum Versions {
    static let alamofire = Version("5.9.1")
    static let grdb = Version("6.29.3")
    static let kingfisher = Version("8.1.3")
    static let asyncAlgorithms = Version("1.0.2")
    static let swiftDependencies = Version("1.6.2")
    static let snapshotTesting = Version("1.17.6")
    static let nuke = Version("12.8.0")
}

let package = Package(
    name: "Core",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CoreNetwork", targets: ["CoreNetwork"]),
        .library(name: "CoreDatabase", targets: ["CoreDatabase"]),
        .library(name: "CoreUI", targets: ["CoreUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: Versions.alamofire),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: Versions.grdb),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: Versions.kingfisher),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: Versions.asyncAlgorithms),
        .package(url: "https://github.com/kean/Nuke.git", from: Versions.nuke),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: Versions.snapshotTesting),
    ],
    targets: [
        .target(
            name: "CoreNetwork",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
            ]
        ),
        .target(
            name: "CoreDatabase",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .target(
            name: "CoreUI",
            dependencies: [
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "NukeUI", package: "Nuke"),
            ]
        ),
    ]
)
```

### SPM Dependency Locking (Package.resolved)

```json
// Package.resolved — auto-generated, equivalent to Gradle lock files
// Located at: MyApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
// Or for SPM packages: Package.resolved at the root
//
// This file records exact resolved versions:
{
  "pins" : [
    {
      "identity" : "alamofire",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/Alamofire/Alamofire.git",
      "state" : {
        "revision" : "f455c2975872ccd2d9c81594c658af65716e9b9a",
        "version" : "5.9.1"
      }
    }
  ],
  "version" : 3
}

// IMPORTANT: Commit Package.resolved to version control for reproducible builds
// Equivalent to committing Gradle lock files

// To update all dependencies:
// Xcode: File > Packages > Update to Latest Package Versions
// Command line: swift package update

// To update a specific dependency:
// swift package update Alamofire

// To resolve without updating (use locked versions):
// swift package resolve
```

### CocoaPods Podfile (Legacy but Still Common)

```ruby
# Podfile — version management for CocoaPods

platform :ios, '17.0'
use_frameworks!

# Equivalent to [versions] in libs.versions.toml
$alamofireVersion = '5.9.1'
$kingfisherVersion = '8.1.3'
$snapkitVersion = '5.7.1'
$realmVersion = '10.54.0'

target 'MyApp' do
  # Networking
  pod 'Alamofire', "~> #{$alamofireVersion}"  # Up to next major
  pod 'Kingfisher', "~> #{$kingfisherVersion}"

  # UI
  pod 'SnapKit', "~> #{$snapkitVersion}"

  # Database
  pod 'RealmSwift', "~> #{$realmVersion}"

  # Feature modules
  target 'FeatureHome' do
    inherit! :search_paths
    pod 'Kingfisher', "~> #{$kingfisherVersion}"
  end

  # Test target
  target 'MyAppTests' do
    inherit! :search_paths
    pod 'Quick', '~> 7.0'
    pod 'Nimble', '~> 13.0'
  end
end

# Version operators:
# pod 'X', '5.0'       — exact version (like `strictly`)
# pod 'X', '~> 5.0'    — >= 5.0, < 6.0 (up to next major)
# pod 'X', '~> 5.1.0'  — >= 5.1.0, < 5.2.0 (up to next minor)
# pod 'X', '>= 5.0'    — any version >= 5.0
# pod 'X', '> 5.0, < 6.0'  — range

# Lock file: Podfile.lock (auto-generated, commit to version control)
# Update: pod update [PodName]
# Install with locked versions: pod install
```

### Tuist Dependencies.swift

```swift
// Tuist/Dependencies.swift — centralized dependency management for Tuist

import ProjectDescription

let dependencies = Dependencies(
    swiftPackageManager: SwiftPackageManagerDependencies(
        [
            .remote(url: "https://github.com/Alamofire/Alamofire.git", requirement: .upToNextMajor(from: "5.9.0")),
            .remote(url: "https://github.com/onevcat/Kingfisher.git", requirement: .upToNextMajor(from: "8.1.0")),
            .remote(url: "https://github.com/groue/GRDB.swift.git", requirement: .exact("6.29.3")),
            .remote(url: "https://github.com/apple/swift-async-algorithms.git", requirement: .upToNextMajor(from: "1.0.0")),
        ],
        productTypes: [
            "Alamofire": .framework,
            "Kingfisher": .framework,
        ]
    ),
    platforms: [.iOS]
)

// Usage in Project.swift targets:
// .target(
//     name: "CoreNetwork",
//     dependencies: [
//         .external(name: "Alamofire"),
//     ]
// )
```

### Firebase / Suite-Based Dependencies (BOM Equivalent)

```swift
// SPM does not have a formal BOM concept.
// Firebase manages version alignment through a single package with multiple products:

// Package.swift
.package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.6.0"),

// In targets:
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
        .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
        .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
        // All products come from the same package version — implicit BOM behavior
    ]
)

// For Alamofire (single product) — no BOM needed, version is the package version
// For libraries with multiple products (Firebase, AWS, Google), the package itself acts as a BOM
```

### Dependency Update Workflows

```bash
# SPM: Update all packages
swift package update
# Or in Xcode: File > Packages > Update to Latest Package Versions

# SPM: Show resolved versions
swift package show-dependencies

# SPM: Reset package caches (troubleshooting)
swift package reset
# Or in Xcode: File > Packages > Reset Package Caches

# CocoaPods: Update all pods
pod update

# CocoaPods: Update specific pod
pod update Alamofire

# CocoaPods: Show outdated pods (equivalent to Gradle dependencyUpdates)
pod outdated

# Tuist: Fetch and resolve dependencies
tuist fetch
tuist generate
```

## Migration Mapping Table

| Android (Version Catalog) | iOS (SPM) | iOS (CocoaPods) | iOS (Tuist) |
|---|---|---|---|
| `libs.versions.toml` | `Package.swift` (or `Versions` enum) | `Podfile` (with variables) | `Dependencies.swift` |
| `[versions]` section | Swift `enum Versions { }` | Ruby variables `$version` | `requirement:` parameter |
| `version.ref = "name"` | `Versions.name` | `$nameVersion` | `requirement:` parameter |
| `[libraries]` section | `.package(url:from:)` | `pod 'Name', '~> X'` | `.remote(url:requirement:)` |
| `[bundles]` section | No direct equivalent | Target-level grouping | Target `dependencies: []` |
| `[plugins]` section | N/A (no SPM plugin versioning) | N/A | N/A |
| `platform(libs.xxx.bom)` | Single package with multiple products | N/A (implicit per-pod) | `.external(name:)` |
| `libs.library.name` (type-safe) | `.product(name:package:)` | `pod 'Name'` | `.external(name:)` |
| `implementation(libs.x)` | `.product(name:package:)` in target | `pod 'Name'` in target | `.external(name:)` |
| `from: "X.Y.Z"` (default) | `.upToNextMajor(from:)` / `from:` | `~> X.Y` | `.upToNextMajor(from:)` |
| `strictly("X.Y.Z")` | `exact: "X.Y.Z"` | `'X.Y.Z'` (no operator) | `.exact("X.Y.Z")` |
| `dependency-locks/*.lockfile` | `Package.resolved` | `Podfile.lock` | `Package.resolved` |
| `./gradlew dependencies --write-locks` | `swift package resolve` | `pod install` | `tuist fetch` |
| `./gradlew dependencyUpdates` | `swift package update` + manual check | `pod outdated` | `tuist fetch` + manual check |
| `resolutionStrategy.force()` | `exact:` version requirement | `pod 'X', 'exact'` | `.exact()` requirement |
| `configurations.all { }` version override | Override in root `Package.swift` | `Podfile` post_install hook | `Dependencies.swift` |

## Common Pitfalls

1. **SPM has no type-safe accessors** — Android's version catalog generates `libs.xxx` accessors with IDE autocompletion. SPM requires string-based `.product(name:package:)` references. Typos in product or package names cause build failures, not compile-time errors. Double-check these strings carefully.

2. **Package.resolved must be committed** — Unlike Android where lock files are optional, `Package.resolved` is essential for reproducible CI/CD builds. Without it, `swift package resolve` may resolve different versions on different machines. Always commit this file.

3. **No BOM concept in SPM** — Android BOMs align versions across a library suite (e.g., Compose BOM, Firebase BOM). In SPM, the closest equivalent is a single package with multiple products (like `firebase-ios-sdk`). For unrelated libraries, you must manage version compatibility manually.

4. **Version requirement semantics differ** — Gradle's default is "prefer this version, resolve conflicts upward." SPM's `from:` means "up to next major" and strictly enforces the range. If two packages require incompatible ranges of the same dependency, SPM fails to resolve. Android's Gradle is more lenient with version conflict resolution.

5. **CocoaPods and SPM version operators are different** — CocoaPods `~> 5.1.0` means `>= 5.1.0, < 5.2.0` (up to next minor). SPM `from: "5.1.0"` means `>= 5.1.0, < 6.0.0` (up to next major). These are not equivalent. When migrating from CocoaPods to SPM, verify the intended version range.

6. **No centralized versions file in SPM** — Android's `libs.versions.toml` is a dedicated file. SPM versions are scattered across `Package.swift` files. Use a `Versions` enum pattern (shown above) to centralize versions within a package, but across packages you must keep them in sync manually.

7. **Mixing dependency managers** — Some iOS projects use both SPM and CocoaPods. This can cause duplicate symbols, version conflicts, and build order issues. Prefer migrating fully to SPM. If you must mix, ensure no library is imported by both managers.

8. **SPM package resolution is slow** — For large dependency graphs, SPM resolution can take significant time (especially on CI). The `Package.resolved` file speeds this up by providing pre-resolved versions. If resolution is very slow, consider vendoring critical dependencies.

## Migration Checklist

- [ ] Export the full Android dependency list from `libs.versions.toml`
- [ ] Map each Android library to its iOS equivalent (e.g., Retrofit to Alamofire/URLSession, Room to GRDB)
- [ ] Choose the iOS dependency manager: SPM (recommended), CocoaPods, or Tuist
- [ ] Create the `Package.swift` with all external dependencies and their version requirements
- [ ] Use a `Versions` enum or similar pattern to centralize version numbers
- [ ] Identify Android BOM usages and map to single-package multi-product patterns in SPM
- [ ] Set version requirements appropriate to each dependency (use `from:` for most, `exact:` for critical)
- [ ] Run `swift package resolve` and verify all dependencies resolve correctly
- [ ] Commit `Package.resolved` to version control for reproducible builds
- [ ] Set up a dependency update workflow (regular `swift package update` or Dependabot/Renovate)
- [ ] Remove any duplicate dependencies if migrating from CocoaPods to SPM
- [ ] Verify no version conflicts exist between packages requiring the same transitive dependency
- [ ] Document the dependency mapping (Android library to iOS equivalent) for the team
- [ ] Set up CI/CD to use `swift package resolve` (locked versions) rather than `swift package update`
