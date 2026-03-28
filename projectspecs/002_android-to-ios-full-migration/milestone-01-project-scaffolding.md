# Milestone 01: Project Scaffolding & SPM Setup

**Status:** Not Started
**Dependencies:** None (first milestone)
**Estimated Files:** ~10 configuration files

---

## Objective

Create the iOS Xcode project from scratch with the full multi-module SPM package structure that mirrors the Android project's `settings.gradle.kts`. After this milestone, every module target exists (empty) and the project compiles.

---

## Deliverables

### 1. Xcode Project
- [ ] Create `waonder-ios.xcodeproj` with deployment target iOS 17.0
- [ ] Configure app target `WaonderApp`
- [ ] Set bundle identifier: `com.app.waonder`
- [ ] Add app icons and launch screen

### 2. Build Configurations
- [ ] Create 3 build configurations: Debug, Staging, Release
- [ ] Create 3 xcconfig files with base URLs:
  - `Debug.xcconfig` → `http://192.168.50.44:3001/`
  - `Staging.xcconfig` → `https://waonder-api.onrender.com/`
  - `Release.xcconfig` → `https://api.waonder.app/`
- [ ] Create 3 Xcode schemes: Waonder-Debug, Waonder-Staging, Waonder-Release

### 3. SPM Package (WaonderModules)
- [ ] Create `WaonderModules/Package.swift` with all 18 targets:
  - Core: `CoreCommon`, `CoreDomain`, `CoreDataLayer`, `CoreDesign`, `CoreMapUI`
  - Features: `FeatureOnboarding`, `FeaturePermissions`, `FeaturePlaceDetails`, `FeatureRemoteVisit`, `FeatureSettings`, `FeatureDeveloper`, `FeatureErrors`, `FeatureTheme`, `FeatureSession`
  - Rendering: `SharedRendering`, `MapEngineV2`, `FogScene`
- [ ] Create empty `Sources/<TargetName>/` directory for each target with a placeholder `.swift` file
- [ ] Create empty `Tests/<TargetName>Tests/` directory for each testable target
- [ ] Define dependency graph matching Android:
  ```
  CoreDomain depends on: CoreCommon
  CoreDataLayer depends on: CoreDomain, CoreCommon
  CoreDesign depends on: CoreCommon
  CoreMapUI depends on: CoreCommon, CoreDomain
  SharedRendering depends on: CoreCommon
  MapEngineV2 depends on: CoreCommon, CoreDomain, SharedRendering
  FogScene depends on: CoreCommon, SharedRendering
  FeatureOnboarding depends on: CoreDomain, CoreDesign, CoreMapUI
  FeaturePermissions depends on: CoreDomain, CoreDesign
  FeaturePlaceDetails depends on: CoreDomain, CoreDesign
  FeatureRemoteVisit depends on: CoreDomain, CoreDesign
  FeatureSettings depends on: CoreDomain, CoreDesign
  FeatureDeveloper depends on: CoreDomain, CoreDesign
  FeatureErrors depends on: CoreDesign
  FeatureTheme depends on: CoreDomain, CoreDesign
  FeatureSession depends on: CoreDomain
  ```

### 4. Firebase Setup
- [ ] Add Firebase iOS SDK via SPM (Analytics, Crashlytics, Auth)
- [ ] Add `GoogleService-Info.plist` for each build configuration
- [ ] Configure Firebase initialization in app entry point

### 5. External Dependencies
- [ ] MapLibre iOS SDK (via SPM)
- [ ] PhoneNumberKit (libphonenumber equivalent)
- [ ] H3-Swift (Uber H3 bindings, if available, otherwise wrap C library)

### 6. Git & CI
- [ ] Initialize git repository
- [ ] Add `.gitignore` for Xcode/SPM
- [ ] Basic CI pipeline that builds all schemes (Ignore for now)

---

## Verification

- [ ] `xcodebuild build` succeeds for all 3 schemes
- [ ] All 18 SPM targets compile (even if empty)
- [ ] All test targets compile
- [ ] Firebase initializes on app launch (console log confirms)
- [ ] Package.swift dependency graph matches Android settings.gradle.kts

---

## Android References

| Android File | iOS Equivalent |
|-------------|---------------|
| `settings.gradle.kts` | `Package.swift` |
| `build-logic/convention/` | xcconfig files |
| `waonder/build.gradle.kts` | App target build settings |
| `google-services.json` | `GoogleService-Info.plist` |
