# Milestone 04: Domain Business Logic

**Status:** Not Started
**Dependencies:** Milestone 03
**Android Module:** `:core:domain` (use cases, coordinators, managers, services)
**iOS Target:** `CoreDomain`

---

## Objective

Migrate all business logic from the domain layer — use cases, coordinators, managers, and domain services. These are pure logic classes with no platform dependencies.

---

## Deliverables

### 1. Use Cases (`usecase/` → `UseCases/`)
- [ ] `CameraPositioningUseCase.swift`
- [ ] `GetContextsNearUserUseCase.swift`

### 2. Coordinators (`coordinator/` → `Coordinator/`)
- [ ] `CoordinatorEvent.swift` — sealed class → enum
- [ ] `CoordinatorState.swift`
- [ ] `HomeScreenCoordinatorProtocol.swift` — interface → protocol
- [ ] `HomeScreenCoordinatorExtensions.swift`
- [ ] `HomeScreenCoordinatorImpl.swift`
- [ ] `TransitionBridge.swift`

### 3. Onboarding Coordinator (`onboarding/`)
- [ ] `OnboardingCoordinatorProtocol.swift`
- [ ] `OnboardingCoordinatorImpl.swift`
- [ ] `OnboardingEvent.swift`
- [ ] `OnboardingExtensions.swift`
- [ ] `OnboardingState.swift`
- [ ] `DriftCalculator.swift` — pure math, direct translation
- [ ] `DeviceLocaleProviderProtocol.swift`
- [ ] `OnboardingPreferencesRepositoryProtocol.swift`
- [ ] `TeaserPlaceRepositoryProtocol.swift`

### 4. Session Management (`session/`)
- [ ] `SessionCleanable.swift` — protocol
- [ ] `SessionCleanupOrchestrator.swift`
- [ ] `SessionManagerProtocol.swift`
- [ ] `SessionManagerImpl.swift`
- [ ] `SessionState.swift`

### 5. Managers (`manager/`)
- [ ] `ChatCacheManager.swift`
- [ ] `MapContextsManager.swift`
- [ ] `ThreadManagerProtocol.swift`
- [ ] `ThreadManagerImpl.swift`

### 6. Overlay/Alerts (`overlay/`)
- [ ] `HomeAlertsOrchestrator.swift`
- [ ] `HomeAlertsOrchestratorState.swift`
- [ ] `HomeAlertsType.swift` — enum
- [ ] `MapAlertsOrchestratorImpl.swift`

### 7. Map Domain Logic (`map/`)
- [ ] `CategoryStyleProvider.swift`
- [ ] `FogConfigProvider.swift`
- [ ] `MapCameraConstants.swift`
- [ ] `MapStyleProvider.swift`

### 8. Location Logic (`location/`)
- [ ] `LocationConfiguration.swift`
- [ ] `LocationManagerProtocol.swift`
- [ ] `LocationUtils.swift` — distance/bounds calculations
- [ ] `RadialSegmentUtils.swift` — radial segment math

### 9. Spatial (`spatial/`)
- [ ] `H3SpatialCalculator.swift` — H3 hexagonal grid integration

### 10. Other Domain Services
- [ ] `AnnotationBuilder.swift` — `annotation/`
- [ ] `ContextEnrichmentService.swift` — `enrichment/`
- [ ] `AnnotationVisibilityGroup.swift` — `constants/`
- [ ] `OnActivityDestroyCleanable.swift` — `lifecycle/` (adapt to iOS scene lifecycle)
- [ ] `OnActivityDestroyOrchestrator.swift`
- [ ] `Logger.swift` — `logging/`
- [ ] `ThemeColorProvider.swift` — `theme/`

---

## Key Translation: Coroutines → Swift Concurrency

```kotlin
// Android - Coordinator with Flow
class HomeScreenCoordinatorImpl @Inject constructor(
    private val contextsManager: MapContextsManager
) : HomeScreenCoordinator {
    private val _events = MutableSharedFlow<CoordinatorEvent>()
    override val events: SharedFlow<CoordinatorEvent> = _events.asSharedFlow()
}
```

```swift
// iOS - Coordinator with AsyncStream
@Observable
final class HomeScreenCoordinatorImpl: HomeScreenCoordinatorProtocol {
    private let contextsManager: MapContextsManager
    private let eventsContinuation: AsyncStream<CoordinatorEvent>.Continuation
    let events: AsyncStream<CoordinatorEvent>

    init(contextsManager: MapContextsManager) {
        self.contextsManager = contextsManager
        var continuation: AsyncStream<CoordinatorEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventsContinuation = continuation
    }
}
```

---

## Verification

- [ ] `CoreDomain` target compiles with all business logic
- [ ] All use cases have proper async/throws signatures
- [ ] All coordinators emit events via AsyncStream
- [ ] DriftCalculator unit tests pass (pure math)
- [ ] H3SpatialCalculator integrates with H3 library
- [ ] No UIKit/SwiftUI imports in this target (pure domain)
