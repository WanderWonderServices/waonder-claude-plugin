# Milestone 15: App Shell, Navigation & Integration

**Status:** Not Started
**Dependencies:** All previous milestones (01-14)
**Android Module:** `:waonder` (app module — DI, navigation, entry point)
**iOS Target:** `WaonderApp` (main app target)

---

## Objective

Wire everything together — DI container, navigation graph, app entry point, and end-to-end integration. After this milestone, the app is functionally complete.

---

## Deliverables

### 1. App Entry Point
- [ ] `WaonderApp.swift` — `@main` App struct (mirrors `WaonderApplication.kt`)
  - Firebase initialization
  - DI container setup
  - Theme provider injection
  - ModelContainer configuration (SwiftData)
- [ ] `RootView.swift` — mirrors `MainActivity.kt`
  - Auth state observation
  - Route to onboarding or home based on session

### 2. DI Container (`DI/`)
Collapse all Android Hilt modules into organized DI:

- [ ] `DependencyContainer.swift` — Main container (mirrors `AppModule.kt`)
- [ ] `AuthDependencies.swift` — mirrors `AuthModule.kt`
- [ ] `ChatDependencies.swift` — mirrors `ChatModule.kt`
- [ ] `CoordinatorDependencies.swift` — mirrors `CoordinatorModule.kt`
- [ ] `CoreDependencies.swift` — mirrors `CoreModule.kt`
- [ ] `LocationDependencies.swift` — mirrors `LocationModule.kt`
- [ ] `MapDependencies.swift` — mirrors `MapModule.kt`
- [ ] `NetworkDependencies.swift` — mirrors `NetworkModule.kt`
- [ ] `OnboardingDependencies.swift` — mirrors `OnboardingModule.kt`
- [ ] `OverlayDependencies.swift` — mirrors `OverlayModule.kt`
- [ ] `PhoneDependencies.swift` — mirrors `PhoneModule.kt`
- [ ] `RepositoryDependencies.swift` — mirrors `RepositoryModule.kt`
- [ ] `SessionDependencies.swift` — mirrors `SessionModule.kt`
- [ ] `StorageDependencies.swift` — mirrors `StorageModule.kt`
- [ ] `ThreadManagerDependencies.swift` — mirrors `ThreadManagerModule.kt`

### 3. Navigation (`Navigation/`)
- [ ] `Routes.swift` — Route definitions (mirrors `Routes.kt`)
  ```swift
  enum Route: Hashable {
      case onboarding
      case home
      case settings
      case placeDetails(placeId: String)
      case developer
  }
  ```
- [ ] `NavigationGraph.swift` — NavigationStack setup (mirrors `NavigationGraph.kt`)
- [ ] `NavigationExtensions.swift` — Navigation utility extensions

### 4. Initializers (`Initializer/`)
- [ ] `CacheEvictionInitializer.swift` — Schedule background cache cleanup

### 5. Utilities (`Utils/`)
- [ ] `ContextExtensions.swift` — mirrors `ContextExtensions.kt`
- [ ] `LocationManagerLifecycleAdapter.swift` — Location lifecycle management
- [ ] `CrashlyticsLogger.swift` — Firebase Crashlytics integration
- [ ] `MapConfiguration.swift` — Map global configuration
- [ ] `NetworkMonitor.swift` — NWPathMonitor implementation

### 6. Resources
- [ ] `Assets.xcassets` — App icons, images, colors
- [ ] `Localizable.xcstrings` — All strings (English + Spanish)
- [ ] `Info.plist` — App configuration
  - Location usage descriptions
  - Camera usage description (if needed)
  - URL schemes
  - Firebase configuration
- [ ] `GoogleService-Info.plist` — Firebase config (per build configuration)

---

## DI Wiring Pattern

```swift
// DependencyContainer.swift
@Observable
final class DependencyContainer {
    // Core
    lazy var apiClient = APIClient(baseURL: Environment.baseURL)
    lazy var modelContainer = try! ModelContainer(for: /* all models */)
    lazy var logger = OSLogger()

    // Auth
    lazy var authRepository: AuthRepositoryProtocol = FirebaseAuthRepositoryImpl(...)
    lazy var sessionManager: SessionManagerProtocol = SessionManagerImpl(...)

    // Chat
    lazy var chatAPI: ChatAPI = ChatAPIImpl(client: apiClient)
    lazy var threadsRepository: ThreadsRepositoryProtocol = ThreadsRepositoryImpl(...)

    // ... all dependencies
}

// Injection via SwiftUI Environment
@main
struct WaonderApp: App {
    @State private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
        }
    }
}
```

---

## Navigation Architecture

```swift
struct RootView: View {
    @Environment(DependencyContainer.self) var container
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            // Check auth state to determine start destination
            Group {
                if container.sessionManager.isAuthenticated {
                    HomeView()
                } else {
                    OnboardingView()
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .settings: SettingsView()
                case .developer: DeveloperOptionsView()
                case .placeDetails(let id): PlaceDetailsView(placeId: id)
                default: EmptyView()
                }
            }
        }
    }
}
```

---

## End-to-End Integration Tests

- [ ] **Auth flow:** App launch → Onboarding → Phone input → OTP → Home
- [ ] **Map flow:** Home → Map loads → Annotations appear → Tap → Place details
- [ ] **Chat flow:** Place details → Chat → Send message → AI response
- [ ] **Settings flow:** Home → Settings → Change theme → Theme applies
- [ ] **Session flow:** Settings → Logout → Returns to onboarding
- [ ] **Offline flow:** Disable network → Vignette appears → Re-enable → Recovers

---

## Verification

- [ ] App launches and shows correct screen (onboarding or home)
- [ ] All DI dependencies resolve without crashes
- [ ] Navigation between all screens works
- [ ] Deep links (if any) resolve correctly
- [ ] Firebase Analytics events fire
- [ ] Firebase Crashlytics captures errors
- [ ] All 3 build schemes build successfully
- [ ] No memory leaks (check with Instruments)
- [ ] End-to-end flows complete without errors

---

## Final Parity Check

After this milestone, run the complete parity verification:

| Check | Status |
|-------|--------|
| Module count matches (18 SPM targets) | [ ] |
| Every Android folder has iOS counterpart | [ ] |
| Every Android file has iOS counterpart | [ ] |
| Every ViewModel exists on both platforms | [ ] |
| Every repository exists on both platforms | [ ] |
| Every screen exists on both platforms | [ ] |
| Dependency graph matches | [ ] |
| Build configurations match (3 variants) | [ ] |
| API endpoints match | [ ] |
| All features functional | [ ] |
