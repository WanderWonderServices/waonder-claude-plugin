---
name: generic-android-to-ios-gradle-modules
description: Use when migrating Android Gradle multi-module architecture (feature modules, core modules, convention plugins, composite builds) to iOS equivalents (SPM packages/targets, Xcode frameworks, Tuist project generation) with modular dependency graphs, build performance, and shared code strategies
type: generic
---

# generic-android-to-ios-gradle-modules

## Context

Modern Android projects use Gradle multi-module architecture to enforce separation of concerns, improve build times through incremental compilation, and enable parallel builds. A typical project has an `app` module, multiple `feature` modules, and `core` modules (networking, database, design system). Convention plugins centralize build configuration. On iOS, modularity is achieved through SPM (Swift Package Manager) packages with multiple targets, Xcode framework targets, or Tuist for project generation. This skill maps Android's module architecture to idiomatic iOS modular patterns.

## Android Best Practices (Source Patterns)

### Typical Multi-Module Structure

```
project/
├── app/                          # Application module (entry point)
│   └── build.gradle.kts
├── feature/
│   ├── feature-home/             # Feature module
│   │   └── build.gradle.kts
│   ├── feature-profile/
│   │   └── build.gradle.kts
│   └── feature-settings/
│       └── build.gradle.kts
├── core/
│   ├── core-network/             # Core networking
│   │   └── build.gradle.kts
│   ├── core-database/            # Core persistence
│   │   └── build.gradle.kts
│   ├── core-domain/              # Domain models & use cases
│   │   └── build.gradle.kts
│   ├── core-data/                # Repository implementations
│   │   └── build.gradle.kts
│   ├── core-ui/                  # Shared UI components
│   │   └── build.gradle.kts
│   └── core-common/              # Utilities, extensions
│       └── build.gradle.kts
├── build-logic/                  # Convention plugins
│   └── convention/
│       └── build.gradle.kts
├── settings.gradle.kts
└── gradle/
    └── libs.versions.toml        # Version catalog
```

### Module build.gradle.kts Examples

```kotlin
// feature-home/build.gradle.kts
plugins {
    id("app.android.feature")    // Convention plugin
    id("app.android.hilt")       // Convention plugin for DI
}

android {
    namespace = "com.app.feature.home"
}

dependencies {
    implementation(project(":core:core-domain"))
    implementation(project(":core:core-ui"))
    implementation(project(":core:core-data"))

    testImplementation(project(":core:core-testing"))
}

// core-domain/build.gradle.kts
plugins {
    id("app.android.library")   // Pure Kotlin/Android library
}

dependencies {
    // Domain has no Android framework dependencies
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.javax.inject)
}

// app/build.gradle.kts
plugins {
    id("app.android.application")
    id("app.android.hilt")
}

dependencies {
    implementation(project(":feature:feature-home"))
    implementation(project(":feature:feature-profile"))
    implementation(project(":feature:feature-settings"))
    implementation(project(":core:core-network"))
    implementation(project(":core:core-database"))
}
```

### Convention Plugins

```kotlin
// build-logic/convention/src/main/kotlin/AndroidFeatureConventionPlugin.kt
class AndroidFeatureConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            pluginManager.apply {
                apply("com.android.library")
                apply("org.jetbrains.kotlin.android")
                apply("org.jetbrains.kotlin.plugin.compose")
            }

            extensions.configure<LibraryExtension> {
                compileSdk = 35
                defaultConfig.minSdk = 26
                buildFeatures.compose = true
            }

            dependencies {
                add("implementation", project(":core:core-ui"))
                add("implementation", libs.findLibrary("androidx.compose.material3").get())
                add("testImplementation", libs.findLibrary("junit").get())
            }
        }
    }
}
```

### settings.gradle.kts (Module Registration)

```kotlin
// settings.gradle.kts
pluginManagement {
    includeBuild("build-logic")
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "MyApp"

include(":app")
include(":feature:feature-home")
include(":feature:feature-profile")
include(":feature:feature-settings")
include(":core:core-network")
include(":core:core-database")
include(":core:core-domain")
include(":core:core-data")
include(":core:core-ui")
include(":core:core-common")
include(":core:core-testing")
```

### Key Android Patterns to Recognize

- `include(":feature:feature-xxx")` — module registration in settings
- `implementation(project(":core:core-xxx"))` — inter-module dependency
- `api(project(...))` vs `implementation(project(...))` — transitive vs non-transitive dependency
- Convention plugins in `build-logic/` — shared build configuration
- `com.android.library` — library module plugin
- `com.android.application` — app module plugin
- Feature modules depend on core modules; core modules never depend on feature modules
- `testImplementation(project(":core:core-testing"))` — shared test utilities module

## iOS Best Practices (Target Patterns)

### SPM Local Packages (Recommended for Modular iOS)

```
MyApp/
├── MyApp.xcodeproj/              # Main Xcode project (app target only)
├── MyApp/                        # App source (thin, just wiring)
│   ├── MyAppApp.swift
│   └── DependencyContainer.swift
├── Packages/
│   ├── Features/                 # Local SPM package for features
│   │   ├── Package.swift
│   │   └── Sources/
│   │       ├── FeatureHome/
│   │       ├── FeatureProfile/
│   │       └── FeatureSettings/
│   ├── Core/                     # Local SPM package for core
│   │   ├── Package.swift
│   │   └── Sources/
│   │       ├── CoreNetwork/
│   │       ├── CoreDatabase/
│   │       ├── CoreDomain/
│   │       ├── CoreData/
│   │       ├── CoreUI/
│   │       └── CoreCommon/
│   └── Testing/                  # Shared test utilities
│       ├── Package.swift
│       └── Sources/
│           └── CoreTesting/
```

### SPM Package.swift (Core Package)

```swift
// Packages/Core/Package.swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CoreNetwork", targets: ["CoreNetwork"]),
        .library(name: "CoreDatabase", targets: ["CoreDatabase"]),
        .library(name: "CoreDomain", targets: ["CoreDomain"]),
        .library(name: "CoreData", targets: ["CoreData"]),
        .library(name: "CoreUI", targets: ["CoreUI"]),
        .library(name: "CoreCommon", targets: ["CoreCommon"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.0.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
    ],
    targets: [
        // CoreCommon — no dependencies on other Core targets
        .target(
            name: "CoreCommon",
            dependencies: []
        ),

        // CoreDomain — pure Swift, no framework dependencies
        .target(
            name: "CoreDomain",
            dependencies: ["CoreCommon"]
        ),

        // CoreNetwork — networking layer
        .target(
            name: "CoreNetwork",
            dependencies: [
                "CoreDomain",
                "CoreCommon",
            ]
        ),

        // CoreDatabase — persistence layer
        .target(
            name: "CoreDatabase",
            dependencies: [
                "CoreDomain",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),

        // CoreData — repository implementations
        .target(
            name: "CoreData",
            dependencies: [
                "CoreDomain",
                "CoreNetwork",
                "CoreDatabase",
            ]
        ),

        // CoreUI — shared SwiftUI components
        .target(
            name: "CoreUI",
            dependencies: ["CoreCommon"],
            resources: [.process("Resources")]
        ),

        // Test targets
        .testTarget(
            name: "CoreNetworkTests",
            dependencies: [
                "CoreNetwork",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "CoreDomainTests",
            dependencies: ["CoreDomain"]
        ),
    ]
)
```

### SPM Package.swift (Features Package)

```swift
// Packages/Features/Package.swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Features",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureHome", targets: ["FeatureHome"]),
        .library(name: "FeatureProfile", targets: ["FeatureProfile"]),
        .library(name: "FeatureSettings", targets: ["FeatureSettings"]),
    ],
    dependencies: [
        .package(path: "../Core"),    // Local path dependency
        .package(path: "../Testing"),
    ],
    targets: [
        .target(
            name: "FeatureHome",
            dependencies: [
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
                .product(name: "CoreData", package: "Core"),
            ]
        ),
        .target(
            name: "FeatureProfile",
            dependencies: [
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
            ]
        ),
        .target(
            name: "FeatureSettings",
            dependencies: [
                .product(name: "CoreDomain", package: "Core"),
                .product(name: "CoreUI", package: "Core"),
            ]
        ),
        .testTarget(
            name: "FeatureHomeTests",
            dependencies: [
                "FeatureHome",
                .product(name: "CoreTesting", package: "Testing"),
            ]
        ),
    ]
)
```

### Xcode Framework Targets (Alternative to SPM)

```
MyApp.xcodeproj
├── MyApp (Application target)
├── CoreNetwork.framework
├── CoreDomain.framework
├── CoreUI.framework
├── FeatureHome.framework
└── FeatureProfile.framework
```

```swift
// In Xcode project settings:
// - Each framework is a separate target in the same project (or workspace)
// - Dependencies configured via "Frameworks and Libraries" in Build Phases
// - Access control via `public`/`internal` (internal is module-scoped)
// - App target embeds feature frameworks; feature frameworks link core frameworks
```

### Tuist Project Generation

```swift
// Project.swift (Tuist manifest)
import ProjectDescription

let project = Project(
    name: "MyApp",
    targets: [
        .target(
            name: "MyApp",
            destinations: .iOS,
            product: .app,
            bundleId: "com.app.myapp",
            deploymentTargets: .iOS("17.0"),
            sources: ["MyApp/Sources/**"],
            resources: ["MyApp/Resources/**"],
            dependencies: [
                .target(name: "FeatureHome"),
                .target(name: "FeatureProfile"),
                .target(name: "CoreNetwork"),
                .target(name: "CoreDatabase"),
            ]
        ),
        .target(
            name: "FeatureHome",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.app.feature.home",
            sources: ["Features/Home/Sources/**"],
            dependencies: [
                .target(name: "CoreDomain"),
                .target(name: "CoreUI"),
            ]
        ),
        .target(
            name: "CoreDomain",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.app.core.domain",
            sources: ["Core/Domain/Sources/**"],
            dependencies: []
        ),
        .target(
            name: "CoreUI",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.app.core.ui",
            sources: ["Core/UI/Sources/**"],
            resources: ["Core/UI/Resources/**"],
            dependencies: [
                .target(name: "CoreCommon"),
            ]
        ),
        .target(
            name: "CoreNetwork",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.app.core.network",
            sources: ["Core/Network/Sources/**"],
            dependencies: [
                .target(name: "CoreDomain"),
            ]
        ),
    ]
)
```

### Access Control for Module Boundaries

```swift
// In CoreDomain target — public API
public struct User: Sendable, Codable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public protocol UserRepository: Sendable {
    func getUser(id: String) async throws -> User
}

// In CoreData target — internal implementation, public conformance
public final class UserRepositoryImpl: UserRepository {
    private let networkClient: NetworkClient  // internal to CoreData
    private let database: UserDatabase        // internal to CoreData

    public init(networkClient: NetworkClient, database: UserDatabase) {
        self.networkClient = networkClient
        self.database = database
    }

    public func getUser(id: String) async throws -> User {
        // Implementation details are internal
        if let cached = try await database.getUser(id: id) {
            return cached
        }
        let user = try await networkClient.fetchUser(id: id)
        try await database.save(user)
        return user
    }
}

// In FeatureHome — depends on CoreDomain protocol, not CoreData implementation
@Observable
final class HomeViewModel {
    private let userRepository: UserRepository  // Protocol from CoreDomain

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }
}
```

## Migration Mapping Table

| Android (Gradle) | iOS (SPM) | iOS (Xcode Frameworks) | iOS (Tuist) |
|---|---|---|---|
| `settings.gradle.kts` `include()` | `Package.swift` targets/products | Xcode project targets | `Project.swift` targets |
| `com.android.application` plugin | App target in `.xcodeproj` | App target | `.app` product |
| `com.android.library` plugin | `.target()` in Package.swift | Framework target | `.framework` product |
| `implementation(project(":x"))` | `.product(name:package:)` dependency | "Link Binary" build phase | `.target(name:)` dependency |
| `api(project(":x"))` | Transitive by default in SPM | Set to "Do Not Embed" + link | `.target(name:)` — always transitive |
| `build-logic/` convention plugins | Shared `Package.swift` settings | Xcode build config files (`.xcconfig`) | `ProjectDescription.Helpers` |
| `testImplementation(project(":testing"))` | `.testTarget(dependencies:)` | Test target dependency | `.target(product: .unitTests)` |
| `gradle/libs.versions.toml` | `Package.swift` dependency versions | Podfile or SPM versions | `Dependencies.swift` |
| `namespace` in `build.gradle.kts` | Target name (module name) | Framework bundle ID | `bundleId` |
| Gradle module = separate `build.gradle.kts` | SPM target = folder under `Sources/` | Xcode framework = separate target | Tuist target = manifest entry |
| `internal` (module-scoped in Kotlin) | `internal` (module-scoped in Swift) | `internal` (target-scoped) | `internal` (target-scoped) |
| Composite builds (`includeBuild`) | Local path packages (`.package(path:)`) | Xcode workspace with subprojects | Tuist workspace |

## Common Pitfalls

1. **SPM targets are not the same as packages** — A single SPM package can contain multiple targets (like multiple Gradle modules in one `build.gradle.kts`). Each target compiles to its own module with its own `internal` visibility scope. Do not create one package per module; group related targets in a single package.

2. **Access control differences** — In Kotlin, `internal` is module-scoped. In Swift, `internal` is also module-scoped (where module = SPM target or framework). However, Swift requires explicit `public` on all types, functions, and initializers that must be visible outside the module. Forgetting `public init()` on a public struct is a common mistake.

3. **Circular dependencies** — Gradle prevents circular module dependencies at configuration time. SPM also prevents them but with less helpful error messages. Plan the dependency graph carefully: core modules should never depend on feature modules, and domain should have zero framework dependencies.

4. **Build performance expectations** — Gradle's incremental compilation and configuration caching provide fast rebuilds. SPM recompiles an entire target when any file in it changes (no file-level incremental compilation as of Xcode 16). Keep targets small and focused to maintain build speed.

5. **Resources in SPM** — Android modules can include resources freely. SPM targets require explicit resource declarations (`.process("Resources")` or `.copy("Resources")`). Forgetting this causes runtime crashes when accessing missing resources.

6. **Test target isolation** — In Android, `testImplementation` dependencies are not visible to production code. In SPM, `testTarget` dependencies are similarly isolated. However, to test internal types in Swift you need `@testable import ModuleName`, which only works if the module is compiled with testing enabled (default in debug).

7. **No convention plugin equivalent in SPM** — Android convention plugins centralize `compileSdk`, `minSdk`, and common dependencies. SPM has no built-in equivalent. Use a shared `Package.swift` helper or Tuist's `ProjectDescription.Helpers` for this pattern.

8. **Type name collisions across SPM targets** — In Kotlin, types are disambiguated by full package path. In Swift, SPM modules have flat namespaces — if two modules export the same type name, the compiler raises an ambiguity error. Fix with module-qualified names: `CoreDomain.LatLng`. When migrating, audit type names across modules and either rename to be unique or use `typealias`.

9. **Public default argument values** — If a `public` function has a default argument referencing a type or static member, that type/member must also be `public`. Not required in Kotlin.

## Migration Checklist

- [ ] Map the Android module dependency graph — identify all modules and their dependencies
- [ ] Classify modules: `app` (entry point), `feature` (UI + logic), `core` (shared infra)
- [ ] Choose iOS modularization approach: SPM local packages (recommended), Xcode frameworks, or Tuist
- [ ] Create the package/folder structure mirroring the Android module layout
- [ ] Define `Package.swift` with targets matching Android modules
- [ ] Set up inter-target dependencies preserving the same dependency direction
- [ ] Mark all public API surface with `public` access control
- [ ] Define `public` protocols in domain targets for dependency inversion
- [ ] Move shared test utilities to a dedicated testing target/package
- [ ] Configure resource processing for targets that contain assets, strings, or other resources
- [ ] Verify no circular dependencies exist in the target graph
- [ ] Set up the app target to import all feature modules and wire up dependency injection
- [ ] Validate build times — split large targets if compilation is slow
- [ ] Ensure convention-plugin-equivalent settings (deployment target, Swift version) are consistent across all targets
