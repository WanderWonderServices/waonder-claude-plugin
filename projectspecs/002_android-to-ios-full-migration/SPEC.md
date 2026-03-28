# Android-to-iOS Full Migration Specification

> Complete 1:1 migration of the Waonder Android app to iOS, preserving module structure, folder hierarchy, file organization, and architectural patterns while respecting native iOS platform conventions.

**Created:** 2026-03-26
**Status:** In Progress
**Source:** `~/Documents/WaonderApps/waonder-android`
**Target:** New iOS project (Waonder iOS)

---

## 1. Project Overview

### Source App Profile

| Metric | Value |
|--------|-------|
| Total Modules | 19 (real, on disk) |
| Kotlin Files | ~450+ |
| Estimated LOC | 40,000+ |
| Core Modules | 5 (common, domain, data, design, map-ui) |
| Feature Modules | 9 (onboarding, permissions, placedetails, remote-visit, settings, developer, errors, theme, session) |
| Rendering Modules | 3 (map_engine_v2, fog-scene, shared-rendering) |
| Architecture | Clean Architecture (3 layers) + MVVM + Unidirectional Data Flow |
| UI Framework | Jetpack Compose + Material 3 |
| DI | Hilt (Dagger) |
| Database | Room + DataStore |
| Networking | Retrofit + OkHttp |
| Map | MapLibre 11.13.5 + Custom C++17 NDK |
| Auth | Firebase Phone Auth |
| Native Code | C++17 (fog rendering, annotation engine) via JNI |

### Migration Goal

Reproduce every Android module, subfolder, and file on iOS using Swift and native iOS frameworks. The iOS project must be a structural mirror of Android — same number of modules, same folder hierarchy, same file names (with iOS naming conventions applied), same architectural patterns.

---

## 2. Architectural Decisions (Binding)

These decisions are final and apply to every milestone.

| Decision | Choice | Rationale |
|----------|--------|-----------|
| iOS Minimum | **iOS 17+** | Unlocks @Observable, SwiftData, modern NavigationStack |
| UI Framework | **SwiftUI** | 1:1 match for Jetpack Compose |
| State Management | **@Observable (Observation framework)** | Direct equivalent to ViewModel + StateFlow |
| Module System | **Single local SPM package (monorepo)** | Mirrors settings.gradle.kts — all modules declared in one Package.swift |
| DI Strategy | **Manual protocol-based injection + DependencyContainer** | Mirrors Hilt modules; no third-party DI framework |
| Networking | **URLSession + custom APIClient** | Mirrors Retrofit service interface pattern |
| Database | **SwiftData (@Model)** | Mirrors Room @Entity pattern |
| Preferences | **UserDefaults / @AppStorage** | Mirrors DataStore |
| Navigation | **NavigationStack + NavigationPath + Coordinator** | Mirrors Navigation Compose |
| Async | **Swift Concurrency (async/await, Task, AsyncSequence)** | Mirrors Kotlin Coroutines + Flow |
| Testing | **Swift Testing (@Test) + protocol-based mocks** | Mirrors JUnit + MockK |
| Map | **MapLibre iOS (maplibre-native)** | Same engine as Android, different SDK |
| Auth | **Firebase iOS SDK** | Same Firebase project, iOS app config |

---

## 3. Technology Mapping

### Framework-Level

| Android | iOS | Notes |
|---------|-----|-------|
| Jetpack Compose | SwiftUI | @Composable → View struct |
| ViewModel + StateFlow | @Observable class | MutableStateFlow → @Observable property |
| Kotlin Coroutines | Swift Concurrency | suspend fun → async func |
| Flow<T> | AsyncSequence / AsyncStream<T> | Cold streams |
| StateFlow<T> | @Observable property | Hot state |
| Hilt @Module | DependencyContainer sections | One container replaces all modules |
| Room @Entity | SwiftData @Model | Entity → Model |
| Room @Dao | *Store class | DAO → Store |
| Retrofit interface | APIService protocol | Annotation-based → protocol-based |
| OkHttp Interceptor | URLProtocol / middleware | Request/response pipeline |
| Navigation Compose | NavigationStack | NavHost → NavigationStack |
| Material 3 | Native SwiftUI + custom theme | Custom WaonderTheme |
| Timber | os.Logger | Logging abstraction |
| Coil | AsyncImage / native | Image loading |
| WorkManager | BGTaskScheduler | Limited iOS background execution |
| DataStore | UserDefaults / @AppStorage | Preferences |
| MapLibre Android | MapLibre iOS | Same map engine |
| Firebase (Android SDK) | Firebase (iOS SDK via SPM) | Same project, different SDK |

### Pattern-Level

| Android | iOS |
|---------|-----|
| `@HiltViewModel class FooViewModel` | `@Observable final class FooViewModel` |
| `@Composable fun FooScreen(vm)` | `struct FooView: View { let vm: FooViewModel }` |
| `data class FooUiState(...)` | `struct FooUiState: Equatable { ... }` |
| `sealed class FooEvent` | `enum FooEvent { ... }` |
| `sealed interface FooError` | `enum FooError: Error { ... }` |
| `interface FooRepository` | `protocol FooRepositoryProtocol` |
| `class FooRepositoryImpl @Inject` | `final class FooRepositoryImpl: FooRepositoryProtocol` |
| `class FooUseCase @Inject` | `struct FooUseCase { ... }` |
| `suspend fun foo(): T` | `func foo() async throws -> T` |
| `fun observe(): Flow<T>` | `func observe() -> AsyncStream<T>` |
| `by lazy { dependency }` (in ViewModel) | `let dependency` in `init`, or `@ObservationIgnored lazy var` |
| `viewModelScope.launch { }` | `Task { @MainActor in ... }` |
| `collectAsStateWithLifecycle()` | SwiftUI automatic observation |

### Naming Convention Mapping

| Android | iOS | Rule |
|---------|-----|------|
| `FooScreen.kt` | `FooView.swift` | Screen → View |
| `FooViewModel.kt` | `FooViewModel.swift` | Identical |
| `FooUiState.kt` | `FooUiState.swift` | Identical |
| `FooRepository.kt` (interface) | `FooRepositoryProtocol.swift` | Add Protocol suffix |
| `FooRepositoryImpl.kt` | `FooRepositoryImpl.swift` | Identical |
| `FooDto.kt` | `FooDTO.swift` | Uppercase acronym |
| `FooEntity.kt` | `FooModel.swift` | Entity → Model (SwiftData) |
| `FooDao.kt` | `FooStore.swift` | Dao → Store |
| `FooApiService.kt` | `FooAPI.swift` | Uppercase acronym |
| `FooMapper.kt` | `FooMapper.swift` | Identical |
| `model/` | `Models/` | Capitalize + pluralize |
| `repository/` | `Repositories/` | Capitalize + pluralize |
| `usecase/` | `UseCases/` | Capitalize + PascalCase |
| `components/` | `Components/` | Capitalize |
| `di/` | `DI/` | Uppercase acronym |

---

## 4. Module Mapping (Complete)

### Android → iOS Module Table

| # | Android Module | iOS SPM Target | Purpose |
|---|---------------|---------------|---------|
| 1 | `:waonder` (app) | `WaonderApp` (Xcode app target) | Entry point, DI, navigation |
| 2 | `:core:common` | `CoreCommon` | Shared utilities, constants |
| 3 | `:core:domain` | `CoreDomain` | Domain models, protocols, use cases |
| 4 | `:core:data` | `CoreDataLayer` | Repository impls, networking, DB (renamed to avoid Apple CoreData clash) |
| 5 | `:core:design` | `CoreDesign` | Design system, components, theme |
| 6 | `:core:map-ui` | `CoreMapUI` | Map Compose/SwiftUI wrappers |
| 7 | `:feature:onboarding` | `FeatureOnboarding` | Onboarding flow |
| 8 | `:feature:permissions` | `FeaturePermissions` | Location permission handling |
| 9 | `:feature:placedetails` | `FeaturePlaceDetails` | Place detail cards + chat |
| 10 | `:feature:remote-visit` | `FeatureRemoteVisit` | Remote visit card |
| 11 | `:feature:settings` | `FeatureSettings` | Settings screens |
| 12 | `:feature:developer` | `FeatureDeveloper` | Developer options |
| 13 | `:feature:errors` | `FeatureErrors` | Error UI components |
| 14 | `:feature:theme` | `FeatureTheme` | Theme provider |
| 15 | `:feature:session` | `FeatureSession` | Session management |
| 16 | `:map_engine_v2` | `MapEngineV2` | Map annotation engine (C++ bridging) |
| 17 | `:fog-scene` | `FogScene` | Fog effect rendering (C++ bridging) |
| 18 | `:shared-rendering` | `SharedRendering` | Shared rendering utilities |
| 19 | `:map-playground` | `MapPlayground` (separate app target) | Experimental map testing |

### Excluded from Migration

| Item | Reason |
|------|--------|
| `:app` (ghost module) | No directory on disk |
| `:feature:home` (ghost module) | No directory on disk |
| `:waonder-android-map-playgroud` (ghost) | No directory, typo |
| `main-scene/` (orphan) | Not in settings.gradle.kts |
| `build-logic/convention/` | Gradle-specific, use xcconfig |
| `categories-generation/` | Build tooling, not app code |

---

## 5. Folder Structure Mapping (Per Module)

### Core Domain (`:core:domain` → `CoreDomain`)

```
Android: core/domain/src/main/java/com/app/waonder/domain/
iOS:     Sources/CoreDomain/

├── Annotation/
│   └── AnnotationBuilder.swift
├── Cache/
│   ├── ChatCache.swift
│   ├── MessageCache.swift
│   ├── RelatedTopicsCache.swift
│   └── ThreadCache.swift
├── Constants/
│   └── AnnotationVisibilityGroup.swift
├── Coordinator/
│   ├── CoordinatorEvent.swift
│   ├── CoordinatorState.swift
│   ├── HomeScreenCoordinatorProtocol.swift
│   ├── HomeScreenCoordinatorExtensions.swift
│   ├── HomeScreenCoordinatorImpl.swift
│   └── TransitionBridge.swift
├── Enrichment/
│   └── ContextEnrichmentService.swift
├── Error/
│   ├── ChatError.swift
│   └── ContextsError.swift
├── Lifecycle/
│   ├── OnActivityDestroyCleanable.swift
│   └── OnActivityDestroyOrchestrator.swift
├── Location/
│   ├── LocationConfiguration.swift
│   ├── LocationManagerProtocol.swift
│   ├── LocationUtils.swift
│   └── RadialSegmentUtils.swift
├── Logging/
│   └── Logger.swift
├── Manager/
│   ├── ChatCacheManager.swift
│   ├── MapContextsManager.swift
│   ├── ThreadManagerProtocol.swift
│   └── ThreadManagerImpl.swift
├── Map/
│   ├── CategoryStyleProvider.swift
│   ├── FogConfigProvider.swift
│   ├── MapCameraConstants.swift
│   └── MapStyleProvider.swift
├── Models/
│   ├── Annotation/
│   │   └── AnnotationRequest.swift
│   ├── Auth/
│   │   ├── AuthResult.swift
│   │   ├── AuthState.swift
│   │   ├── OtpMethod.swift
│   │   └── OtpResult.swift
│   ├── Chat/
│   │   ├── ChatAnswer.swift
│   │   ├── ChatExecuteResult.swift
│   │   ├── ChatMessage.swift
│   │   ├── ChatMessageRole.swift
│   │   ├── ChatRelatedTopic.swift
│   │   ├── ChatSource.swift
│   │   ├── ChatThread.swift
│   │   ├── ConversationData.swift
│   │   └── MessageStatus.swift
│   ├── Context/
│   │   ├── ContextAnnotation.swift
│   │   ├── ContextInput.swift
│   │   ├── ProgressiveLoadPhase.swift
│   │   └── ProgressiveLoadRings.swift
│   ├── Developer/
│   │   ├── DeveloperSettings.swift
│   │   └── LocationProjection.swift
│   ├── Location/
│   │   ├── DeviceLocation.swift
│   │   ├── LocationPermissionStatus.swift
│   │   ├── LocationServicesState.swift
│   │   ├── LocationState.swift
│   │   └── UserLocationPreferences.swift
│   ├── Map/
│   │   ├── CameraPosition.swift
│   │   ├── CameraPositioningState.swift
│   │   ├── LatLng.swift
│   │   ├── MapState.swift
│   │   └── ScreenPoint.swift
│   ├── Theme/
│   │   ├── FontCombinationId.swift
│   │   ├── PaletteId.swift
│   │   ├── PaletteSettings.swift
│   │   └── TypographySettings.swift
│   ├── User/
│   │   └── UserSettings.swift
│   ├── TeleportState.swift
│   └── User.swift
├── Network/
│   └── NetworkMonitorProtocol.swift
├── Onboarding/
│   ├── DeviceLocaleProviderProtocol.swift
│   ├── DriftCalculator.swift
│   ├── OnboardingCoordinatorProtocol.swift
│   ├── OnboardingCoordinatorImpl.swift
│   ├── OnboardingEvent.swift
│   ├── OnboardingExtensions.swift
│   ├── OnboardingPreferencesRepositoryProtocol.swift
│   ├── OnboardingState.swift
│   └── TeaserPlaceRepositoryProtocol.swift
├── Overlay/
│   ├── HomeAlertsOrchestrator.swift
│   ├── HomeAlertsOrchestratorState.swift
│   ├── HomeAlertsType.swift
│   └── MapAlertsOrchestratorImpl.swift
├── Phone/
│   ├── Country.swift
│   ├── PhoneNumberFormatterProtocol.swift
│   └── PhoneNumberRepositoryProtocol.swift
├── Repositories/
│   ├── AuthRepositoryProtocol.swift
│   ├── ContextsRepositoryProtocol.swift
│   ├── DeveloperSettingsRepositoryProtocol.swift
│   ├── LocationDataSourceProtocol.swift
│   ├── LocationPermissionLocalSourceProtocol.swift
│   ├── LocationPermissionsRepositoryProtocol.swift
│   ├── LocationPermissionSystemSourceProtocol.swift
│   ├── LocationServicesRepositoryProtocol.swift
│   ├── LocationServicesSystemSourceProtocol.swift
│   ├── PaletteRepositoryProtocol.swift
│   ├── SessionRepositoryProtocol.swift
│   ├── TeleportLocalSourceProtocol.swift
│   ├── TeleportLocationRepositoryProtocol.swift
│   ├── ThreadMessagesRepositoryProtocol.swift
│   ├── ThreadRelatedTopicsRepositoryProtocol.swift
│   ├── ThreadsRepositoryProtocol.swift
│   ├── TypographyRepositoryProtocol.swift
│   └── UserSettingsRepositoryProtocol.swift
├── Session/
│   ├── SessionCleanable.swift
│   ├── SessionCleanupOrchestrator.swift
│   ├── SessionManagerProtocol.swift
│   ├── SessionManagerImpl.swift
│   └── SessionState.swift
├── Spatial/
│   └── H3SpatialCalculator.swift
├── Theme/
│   └── ThemeColorProvider.swift
└── UseCases/
    ├── CameraPositioningUseCase.swift
    └── GetContextsNearUserUseCase.swift
```

### Core Data Layer (`:core:data` → `CoreDataLayer`)

```
Android: core/data/src/main/java/com/app/waonder/core/data/
iOS:     Sources/CoreDataLayer/

├── Auth/
│   ├── ActivityHolder.swift
│   ├── AuthActivityHolder.swift
│   ├── AuthAPI.swift
│   ├── FirebaseAuthRepositoryImpl.swift
│   ├── SessionRepositoryImpl.swift
│   └── UserLocalDataSource.swift
├── Cache/
│   └── MemoryCacheSizeConfig.swift
├── Chat/
│   ├── DTOs/
│   │   ├── ChatAnswerDTO.swift
│   │   ├── ChatApiErrorDTO.swift
│   │   ├── ChatExecuteResponseDTO.swift
│   │   ├── ChatQuestionDTO.swift
│   │   ├── ChatRelatedTopicDTO.swift
│   │   ├── ChatSourceDTO.swift
│   │   ├── ChatThreadDTO.swift
│   │   ├── ChatThreadsListResponseDTO.swift
│   │   ├── ConversationHistoryDTO.swift
│   │   ├── CreateThreadRequestDTO.swift
│   │   ├── DeleteResponseDTO.swift
│   │   ├── ExecuteQuestionRequestDTO.swift
│   │   ├── ChatRelatedTopicsResponseDTO.swift
│   │   └── UpdateThreadRequestDTO.swift
│   ├── Models/
│   │   ├── ChatMessageModel.swift
│   │   ├── ChatThreadModel.swift
│   │   └── ChatRelatedTopicModel.swift
│   ├── ChatAPI.swift
│   ├── ChatCacheConfig.swift
│   ├── ChatCacheEvictionScheduler.swift
│   ├── ChatStore.swift
│   ├── ChatErrorMapper.swift
│   ├── ChatL1Cache.swift
│   ├── ChatMappers.swift
│   ├── Messages/
│   │   ├── MessageLocalDataSource.swift
│   │   ├── MessageLocalDataSourceImpl.swift
│   │   ├── MessageRemoteDataSource.swift
│   │   ├── MessageRemoteDataSourceImpl.swift
│   │   └── ThreadMessagesRepositoryImpl.swift
│   ├── Threads/
│   │   ├── ThreadsLocalDataSource.swift
│   │   ├── ThreadsLocalDataSourceImpl.swift
│   │   ├── ThreadsRemoteDataSource.swift
│   │   ├── ThreadsRemoteDataSourceImpl.swift
│   │   └── ThreadsRepositoryImpl.swift
│   └── Topics/
│       ├── RelatedTopicsLocalDataSource.swift
│       ├── RelatedTopicsLocalDataSourceImpl.swift
│       ├── RelatedTopicsRemoteDataSource.swift
│       ├── RelatedTopicsRemoteDataSourceImpl.swift
│       └── ThreadRelatedTopicsRepositoryImpl.swift
├── Contexts/
│   ├── Models/
│   │   ├── ArchetypeContextDataModel.swift
│   │   └── ContextModel.swift
│   ├── DTOs/
│   │   ├── ContextDataDTO.swift
│   │   └── ContextDTO.swift
│   ├── ArchetypeContextsDataAPI.swift
│   ├── ArchetypeContextsDataStore.swift
│   ├── ArchetypeContextsDataLocalDataSource.swift
│   ├── ArchetypeContextsDataRemoteDataSource.swift
│   ├── ContextEntityMappers.swift
│   ├── ContextMappers.swift
│   ├── ContextsAPI.swift
│   ├── ContextsStore.swift
│   ├── ContextsLocalDataSource.swift
│   ├── ContextsRemoteDataSource.swift
│   ├── ContextsRepositoryImpl.swift
│   └── MockContextsRepository.swift
├── Database/
│   ├── AppDatabase.swift
│   └── DatabaseSizeConfig.swift
├── Device/
│   └── DeviceLocaleProviderImpl.swift
├── DI/
│   └── Qualifiers.swift
├── Location/
│   ├── LocationClientLocalDataSourceImpl.swift
│   ├── LocationPermissionLocalSourceImpl.swift
│   ├── LocationPermissionsRepositoryImpl.swift
│   ├── LocationPermissionSystemSourceImpl.swift
│   ├── LocationServicesRepositoryImpl.swift
│   ├── LocationServicesSystemSourceImpl.swift
│   ├── TeleportLocalSourceImpl.swift
│   └── TeleportLocationRepositoryImpl.swift
├── Logging/
│   └── OSLogger.swift
├── Network/
│   ├── AuthTokenInterceptor.swift
│   ├── NetworkChaosInterceptor.swift
│   ├── RequestHeadersInterceptor.swift
│   ├── RetryConfig.swift
│   ├── RetryExecutor.swift
│   └── TokenAuthenticator.swift
├── Onboarding/
│   ├── OnboardingPreferences.swift
│   └── OnboardingPreferencesRepositoryImpl.swift
├── Phone/
│   ├── PhoneNumberFormatterImpl.swift
│   ├── PhoneNumberLocalDataSource.swift
│   └── PhoneNumberRepositoryImpl.swift
├── Settings/
│   ├── DeveloperSettingsRepositoryImpl.swift
│   ├── PaletteRepositoryImpl.swift
│   ├── TypographyRepositoryImpl.swift
│   └── UserSettingsRepositoryImpl.swift
└── Util/
    └── PermissionChecker.swift
```

### Core Design (`:core:design` → `CoreDesign`)

```
Sources/CoreDesign/
├── Components/
│   ├── AnimatedSelectableWordText.swift
│   ├── BlurContainer.swift
│   ├── EmptyState.swift
│   ├── ErrorView.swift
│   ├── HtmlSelectableWordText.swift
│   ├── LetterByLetterText.swift
│   ├── LoadingIndicator.swift
│   ├── MapLoadingView.swift
│   ├── RapidReadCard.swift
│   ├── RecentPlacesPathIcon.swift
│   ├── SelectableWordText.swift
│   ├── ShadowedIcon.swift
│   ├── StatusBarEffect.swift
│   ├── TimeShadowOffset.swift
│   ├── VignetteOverlay.swift
│   ├── WaonderButtons.swift
│   ├── WaonderDialog.swift
│   ├── WaonderText.swift
│   └── WordByWordText.swift
└── Theme/
    ├── Color.swift
    ├── ColorExtensions.swift
    ├── ColorPalettes.swift
    ├── Fonts.swift
    ├── Shadows.swift
    ├── Shapes.swift
    ├── TypographyExtensions.swift
    ├── WaonderAuthColors.swift
    └── WaonderAuthTypography.swift
```

---

## 6. Migration Order (Bottom-Up)

Migration follows dependency order. No module starts until its dependencies are complete.

```
Phase 1 — Core Foundation (no internal dependencies)
  CoreCommon → CoreDomain

Phase 2 — Core Infrastructure (depends on Phase 1)
  CoreDataLayer → CoreDesign → CoreMapUI → SharedRendering

Phase 3 — Map & Rendering Engine (depends on Phase 2)
  MapEngineV2 → FogScene

Phase 4 — Feature Modules (depends on Phase 1-2)
  FeatureTheme → FeatureSession → FeatureErrors → FeaturePermissions
  FeatureDeveloper → FeatureRemoteVisit → FeaturePlaceDetails
  FeatureSettings → FeatureOnboarding

Phase 5 — App Shell (depends on everything)
  WaonderApp (DI container, navigation, entry point)
```

---

## 7. iOS Project Structure (Target)

```
waonder-ios/
├── WaonderApp/                              # Xcode app target
│   ├── WaonderApp.swift                     # @main entry point
│   ├── RootView.swift                       # MainActivity equivalent
│   ├── DI/                                  # DependencyContainer (all Hilt modules)
│   │   ├── DependencyContainer.swift
│   │   ├── AuthDependencies.swift
│   │   ├── ChatDependencies.swift
│   │   ├── LocationDependencies.swift
│   │   ├── MapDependencies.swift
│   │   ├── NetworkDependencies.swift
│   │   └── RepositoryDependencies.swift
│   ├── Navigation/
│   │   ├── AppCoordinator.swift
│   │   ├── NavigationGraph.swift
│   │   └── Routes.swift
│   ├── Initializer/
│   │   └── CacheEvictionInitializer.swift
│   ├── UI/
│   │   ├── Home/
│   │   │   ├── Components/
│   │   │   ├── Developer/
│   │   │   ├── Map/
│   │   │   │   ├── Annotations/
│   │   │   │   │   └── Definitions/
│   │   │   │   ├── Components/
│   │   │   │   ├── Effects/
│   │   │   │   └── State/
│   │   │   ├── HomeView.swift
│   │   │   └── HomeControlsView.swift
│   │   └── Overlay/
│   ├── Utils/
│   │   ├── Extensions/
│   │   ├── Location/
│   │   ├── Logging/
│   │   ├── Map/
│   │   └── Network/
│   ├── Assets.xcassets
│   ├── Info.plist
│   └── GoogleService-Info.plist
│
├── WaonderModules/                          # Local SPM package
│   ├── Package.swift
│   ├── Sources/
│   │   ├── CoreCommon/
│   │   ├── CoreDomain/
│   │   ├── CoreDataLayer/
│   │   ├── CoreDesign/
│   │   ├── CoreMapUI/
│   │   ├── SharedRendering/
│   │   ├── MapEngineV2/
│   │   ├── FogScene/
│   │   ├── FeatureOnboarding/
│   │   ├── FeaturePermissions/
│   │   ├── FeaturePlaceDetails/
│   │   ├── FeatureRemoteVisit/
│   │   ├── FeatureSettings/
│   │   ├── FeatureDeveloper/
│   │   ├── FeatureErrors/
│   │   ├── FeatureTheme/
│   │   └── FeatureSession/
│   └── Tests/
│       ├── CoreDomainTests/
│       ├── CoreDataLayerTests/
│       ├── FeatureOnboardingTests/
│       └── ... (one per module)
│
└── waonder-ios.xcodeproj
```

---

## 8. Build Variants

| Android | iOS Scheme | Base URL |
|---------|-----------|----------|
| Debug | Waonder-Debug | `http://192.168.50.44:3001/` |
| Staging | Waonder-Staging | `https://waonder-api.onrender.com/` |
| Release | Waonder-Release | `https://api.waonder.app/` |

Implemented via xcconfig files and Xcode build configurations, not code-level #if blocks.

---

## 9. Allowed Exceptions

These are the ONLY structural divergences permitted between Android and iOS:

| Divergence | Reason |
|------------|--------|
| No `build-logic/` | Gradle convention plugins → xcconfig files |
| No `res/` folder | Android resources → .xcassets + .xcstrings |
| No AndroidManifest.xml | → Info.plist + Entitlements |
| Multiple `*Module.kt` → single DependencyContainer | Hilt is annotation-driven; Swift DI is manual |
| `*Entity.kt` → `*Model.swift` | SwiftData uses @Model, not @Entity |
| `*Dao.kt` → `*Store.swift` | No DAO pattern in Swift |
| `WaonderApplication.kt` → `WaonderApp.swift` | Different app lifecycle |
| `ChatCacheEvictionWorker` → BGTaskScheduler task | iOS has limited background execution |
| C++17 JNI bridge → Swift/C++ interop or Metal | Different native bridging mechanism |
| `R.string.*` → `String(localized:)` | Different resource system |
| `lazy var` in `@Observable` needs `@ObservationIgnored` | `@Observable` macro conflicts with `lazy var` storage |
| Module-qualified type names (e.g., `CoreDomain.LatLng`) | Swift has no package-path disambiguation like Kotlin |

---

## 10. Milestones

This migration is organized into 15 milestones, each targeting a specific subdomain. See individual milestone files in this folder:

| # | Milestone | Modules Covered |
|---|-----------|----------------|
| 01 | Project Scaffolding & SPM Setup | Xcode project, Package.swift, build configs |
| 02 | Core Common & Extensions | CoreCommon |
| 03 | Domain Models & Protocols | CoreDomain (models, repository protocols) |
| 04 | Domain Business Logic | CoreDomain (use cases, coordinators, managers) |
| 05 | Networking Foundation | CoreDataLayer/Network |
| 06 | Database & Local Storage | CoreDataLayer/Database, SwiftData models |
| 07 | Data Layer Repositories | CoreDataLayer (all repository implementations) |
| 08 | Design System | CoreDesign (theme, components) |
| 09 | Map Infrastructure | CoreMapUI, SharedRendering, MapEngineV2, FogScene |
| 10 | Authentication Flow | FeatureSession, Auth data sources, Firebase Auth |
| 11 | Onboarding Feature | FeatureOnboarding, FeaturePermissions |
| 12 | Home Screen & Map UI | WaonderApp/UI/Home, map effects, annotations |
| 13 | Place Details & Chat | FeaturePlaceDetails, chat data flow |
| 14 | Settings & Remaining Features | FeatureSettings, FeatureDeveloper, FeatureErrors, FeatureTheme, FeatureRemoteVisit |
| 15 | App Shell, Navigation & Integration | WaonderApp (DI, navigation, entry point), end-to-end testing |

---

## 11. Parity Verification Checklist

After completing each milestone:

1. Module exists as SPM target in Package.swift
2. Dependencies match Android build.gradle.kts
3. Folder structure mirrors Android (with naming conventions applied)
4. File count matches (excluding allowed exceptions)
5. All protocols mirror Android interfaces
6. All implementations mirror Android classes
7. Test target exists with mirrored test files
8. Code compiles without errors
