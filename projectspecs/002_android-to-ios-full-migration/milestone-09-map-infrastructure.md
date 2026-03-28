# Milestone 09: Map Infrastructure

**Status:** Not Started
**Dependencies:** Milestones 04, 08
**Android Modules:** `:core:map-ui`, `:shared-rendering`, `:map_engine_v2`, `:fog-scene`
**iOS Targets:** `CoreMapUI`, `SharedRendering`, `MapEngineV2`, `FogScene`

---

## Objective

Migrate the entire map rendering stack — MapLibre integration, annotation engine, fog effects, and shared rendering utilities. This is the most technically complex milestone due to the C++/native code bridging.

---

## Deliverables

### 1. SharedRendering (`SharedRendering/`)
- [ ] `BitmapRegistry.swift` — Image/bitmap cache management
- [ ] `ImageRenderer.swift` — Image rendering utilities
- [ ] `ImageSource.swift` — Image source definitions
- [ ] `TexturePreloader.swift` — Texture loading
- [ ] `TextureRegistry.swift` — Texture cache management
- [ ] `TexturesLocalCache.swift` — Persistent texture cache

### 2. CoreMapUI (`CoreMapUI/`)
Mirror `core/map-ui/`:
- [ ] Map container view (SwiftUI wrapper for MapLibre)
- [ ] Annotation configuration
- [ ] Z-index management
- [ ] Map state (camera state, selection state)

### 3. MapEngineV2 (`MapEngineV2/`)

#### Kotlin API Layer (direct translation)
- [ ] `MapEngineV2.swift` — Public API interface
- [ ] `TapDetector.swift` — Touch handling
- [ ] `MapEngineV2Container.swift` — Container managing lifecycle

#### Annotations (Kotlin layer)
- [ ] `AnchorExtensions.swift`
- [ ] `AnimationBuilders.swift`
- [ ] `AnimationPayload.swift`
- [ ] `AnimationRepaintScheduler.swift`
- [ ] `AnnotationAnimationsBuilder.swift`
- [ ] `AnnotationMetrics.swift`
- [ ] `BitmapRegistry.swift`
- [ ] `CameraMotionGuard.swift`
- [ ] `ClusterModels.swift`
- [ ] `MapEngineAnnotations.swift`
- [ ] `Models.swift`
- [ ] `StateAnimationBuilder.swift`
- [ ] `StateTransitionAnimator.swift`

#### MapLibre Integration
- [ ] `CameraState.swift`
- [ ] `LatLngExtensions.swift`
- [ ] `MapEngineV2ContainerView.swift` — UIViewRepresentable for MapLibre
- [ ] `MapLibreMapView.swift` — MapLibre view wrapper

#### Fog API (Kotlin layer)
- [ ] `FogBuilders.swift`
- [ ] `MapEngineFog.swift`
- [ ] `FogModels.swift`

#### C++ Native Bridge Strategy

The Android app uses JNI to bridge Kotlin ↔ C++17 for:
- `mapengine-annotations` (annotation rendering, clustering, collision detection)
- `fog-scene` (OpenGL fog rendering)
- `shared_native/fog/` (shared fog C++ code)

**iOS bridging options (choose one per component):**

Option A: **Swift/C++ Interop** (Swift 5.9+)
- Directly call C++ from Swift using `@_cdecl` and bridging headers
- Best for: annotation engine, clustering logic

Option B: **Metal replacement** (recommended for fog)
- Replace OpenGL ES fog rendering with Metal shaders
- iOS does not support OpenGL ES since iOS 12 deprecation
- Best for: fog-scene rendering

Option C: **Objective-C++ bridge**
- Wrap C++ in Objective-C++ (.mm files)
- Access from Swift via bridging header
- Most compatible, slightly more boilerplate

**Recommended approach:**
- Annotation engine: Port C++ clustering/collision logic to Swift (simpler maintenance)
- Fog rendering: Rewrite in Metal (OpenGL ES is deprecated on iOS)
- Shared native fog: Metal shader equivalents

### 4. FogScene (`FogScene/`)
- [ ] `ComposeFogScene.swift` → SwiftUI wrapper for fog view
- [ ] `FogSceneController.swift` — Fog control interface
- [ ] `FogSceneView.swift` — Metal-based fog rendering view
- [ ] `FogModels.swift` — Data models

### 5. C++ Source Migration

#### Clustering Pipeline (Port to Swift or keep as C++)
- [ ] `ClusteringPipeline` — Pipeline orchestrator
- [ ] `ClusterFormationStage`
- [ ] `AbsorptionStage`
- [ ] `DissolutionStage`
- [ ] `ZoneAssignmentStage`
- [ ] `EventEmissionStage`
- [ ] `SaveStateStage`

#### Utilities
- [ ] `GeoUtils` — Haversine, projections
- [ ] `HitboxUtils` — Tap detection geometry
- [ ] `UnionFind` — Cluster merging data structure

---

## Risk: This is the Highest-Complexity Milestone

| Risk | Impact | Mitigation |
|------|--------|------------|
| OpenGL ES not available on iOS | Fog rendering won't work | Use Metal for all GPU rendering |
| JNI bridge has no iOS equivalent | Native code won't compile as-is | Port to Swift or use Obj-C++ bridge |
| MapLibre iOS SDK API differences | Map integration code differs | Budget extra time, reference MapLibre iOS docs |
| C++17 clustering is complex | Porting is error-prone | Consider keeping C++ and using bridging header |
| Custom annotation rendering | Different rendering pipeline | May need Metal compute shaders |

---

## Verification

- [ ] MapLibre map renders in SwiftUI view
- [ ] Map responds to camera movements (pan, zoom, rotate)
- [ ] Annotations display at correct coordinates
- [ ] Annotation clustering works at zoom levels
- [ ] Fog effect renders over map
- [ ] Tap detection identifies tapped annotations
- [ ] Animation system produces smooth transitions
- [ ] Performance: 60fps with 100+ annotations visible
