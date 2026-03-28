# Milestone 12: Home Screen & Map UI

**Status:** Not Started
**Dependencies:** Milestones 09, 10
**Android Module:** `:waonder` (ui/home/ package)
**iOS Target:** `WaonderApp/UI/Home/`

---

## Objective

Migrate the main home screen — the map view with annotations, controls overlay, developer options, and all map effects. This is the primary screen users interact with after onboarding.

---

## Deliverables

### 1. Home Screen Container
- [ ] `HomeView.swift` — mirrors `HomeScreen.kt`
- [ ] `HomeControlsView.swift` — mirrors `HomeScreenControls.kt`
- [ ] `HomeControlsViewModel.swift` — mirrors `HomeScreenControlsViewModel.kt`

### 2. Map Screen (`Map/`)
- [ ] `MapEngineV2View.swift` — mirrors `MapEngineV2Screen.kt` (main map UI)
- [ ] `MapCameraViewModel.swift`
- [ ] `MapContextsViewModel.swift` — Places/contexts on map
- [ ] `MapCoreViewModel.swift`

### 3. Map Annotations (`Map/Annotations/`)
- [ ] `CategoryStyleProvider.swift`
- [ ] `ContextAnnotationBuilder.swift`

#### Annotation Definitions (`Map/Annotations/Definitions/`)
- [ ] `AnnotationConfig.swift`
- [ ] `AnnotationLayoutBuilder.swift`
- [ ] `NearVisibleAnnotationDefinition.swift`
- [ ] `OuterHiddenAnnotationDefinition.swift`
- [ ] `OuterVisibleAnnotationDefinition.swift`
- [ ] `PriorityAnnotationDefinition.swift`

### 4. Map Effects (`Map/Effects/`)
- [ ] `CameraInitializationEffect.swift` — Initial camera positioning
- [ ] `MapAutoFocusEffect.swift` — Auto-focus on nearby places
- [ ] `MapCameraCommandEffect.swift` — Programmatic camera movements
- [ ] `MapCameraObserverEffect.swift` — Camera change observation
- [ ] `MapClickHandlerEffect.swift` — Tap/click handling on map
- [ ] `MapClusteringEffect.swift` — Annotation clustering management
- [ ] `MapContextAnnotationsEffect.swift` — Context annotation placement
- [ ] `MapDebugSettingsEffect.swift` — Debug overlay
- [ ] `MapFogEffect.swift` — Fog rendering on map
- [ ] `MapNativeMetricsEffect.swift` — Performance metrics display
- [ ] `MapUserLocationEffect.swift` — User location dot
- [ ] `PostAuthCameraConfig.swift` — Camera config after authentication

### 5. Map State (`Map/State/`)
- [ ] `AutoFocusCardState.swift`
- [ ] `MapAnnotationsState.swift`
- [ ] `MapCameraCommand.swift` — Camera movement commands
- [ ] `MapDebugState.swift`

### 6. Map Components (`Map/Components/`)
- [ ] `AutoFocusCard.swift` — Place focus card
- [ ] `AnnotationIds.swift` — Annotation ID constants

### 7. Home Components (`Components/`)
- [ ] `LoadingHaloConfig.swift`
- [ ] `MapLoadingView.swift`
- [ ] `MapLoadingViewModel.swift`

### 8. Developer Overlay (`Developer/`)
- [ ] `HomeScreenDeveloperOptionsOverlay.swift`
- [ ] `HomeScreenDeveloperOptionsOverlayViewModel.swift`
- [ ] `NativeMetricsSection.swift` — Performance metrics display

### 9. Overlay Host
- [ ] `MapOverlayHost.swift` — Overlay container
- [ ] `MapOverlayHostViewModel.swift`

---

## SwiftUI Compose Effect Translation

Android uses `LaunchedEffect` and `SideEffect` extensively in the map screen. iOS equivalents:

| Android | iOS |
|---------|-----|
| `LaunchedEffect(key) { }` | `.task(id: key) { }` or `.onAppear { }` |
| `SideEffect { }` | `.onChange(of: value) { }` |
| `DisposableEffect(key) { onDispose { } }` | `.onDisappear { }` |
| `rememberCoroutineScope()` | `Task { }` inside event handler |
| `collectAsStateWithLifecycle()` | Automatic with @Observable |

---

## Verification

- [ ] Home screen displays MapLibre map
- [ ] User location dot appears at correct position
- [ ] Place annotations render at correct coordinates
- [ ] Annotation clustering works at different zoom levels
- [ ] Tap on annotation shows place details
- [ ] Map controls (zoom, location) work
- [ ] Fog effect renders over map
- [ ] Camera animations are smooth (60fps)
- [ ] Developer overlay accessible via 3-finger gesture
- [ ] All map effects from Android are present
