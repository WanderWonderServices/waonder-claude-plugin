---
name: generic-mobile-automation-test-sync
description: Use when synchronizing a feature between Android and iOS via automation tests — takes a scenario description, creates a passing Android test, captures screenshots, then syncs to iOS with visual and functional parity
type: generic
---

# Automation Test Android-to-iOS Synchronizer

## Context

This skill is the main orchestrator for test-driven feature synchronization between Android and iOS. It takes a scenario description (not an existing test), creates a passing Android automation test, captures screenshots as the reference, then ensures iOS has a matching test and feature implementation.

The Android app is the single source of truth. The automation test is both the specification and the verification mechanism.

**Core Principle — Perfect Parity**: When both tests pass, it means both platforms render the same UI with the same styling. The only acceptable differences are unavoidable platform differences (SF Pro vs Roboto font, status bar chrome, system dialogs). Everything else — colors, backgrounds, button shapes, spacing, accent colors, text treatment, animations — MUST match. Visual parity is not a "nice to have"; it is a hard requirement enforced automatically in every sync.

**iOS Best Practices — Never Violate**: When writing or fixing iOS code, always follow idiomatic Swift and SwiftUI patterns. Never port Android patterns that violate iOS conventions. Examples:
- ViewModels use `@Observable` with `@MainActor`, NOT manual `init()` with dependency injection like Android's Hilt `@Inject constructor`
- Use `@Environment` for dependency access, not constructor injection
- Use SwiftUI view modifiers, not imperative layout
- Use `async/await` and `Task`, not callback patterns
- Use protocol-based abstractions, not abstract classes

## Input

A scenario description. Examples:
- `"test the login flow — sign in with phone and OTP"`
- `"test onboarding with location permission granted"`
- `"test cold start screen loads correctly"`

## Instructions

When this skill is invoked with a scenario description, execute the following phases. Each phase uses sub-agents spawned in parallel where possible.

### Phase 1: Android Test Creation & Validation

**Goal**: A passing Android automation test with screenshot capture at each step.

1. **Spawn `mobile-android-test-creator-expert` agent** with this prompt:

   > You are creating an Android automation test for this scenario: `{scenario}`.
   >
   > Android repo: `~/Documents/WaonderApps/waonder-android`
   > Test location: `waonder/src/androidTest/java/com/app/waonder/`
   >
   > BEFORE writing anything:
   > 1. Read 2-3 existing tests to learn the project's patterns (start with `auth/LoginFlowTest.kt` and `onboarding/OnboardingGrantLocationTest.kt`)
   > 2. Read the screenshot utility at `screenshot/ScreenshotCapture.kt`
   > 3. Explore the feature code related to the scenario
   >
   > Create the test following the project's exact infrastructure:
   > - `@HiltAndroidTest` + `@RunWith(AndroidJUnit4::class)`
   > - `HiltAndroidRule` (order=0) + `createAndroidComposeRule<MainActivity>` (order=1)
   > - Compose UI Testing for app screens, UiAutomator for system dialogs
   > - Include `ScreenshotCapture` — call `screenshots.capture("step_name")` after every waitUntil/assertion
   > - Test credentials: phone `7865550001`, OTP `123456`
   >
   > After creating the test, run it:
   > ```
   > cd ~/Documents/WaonderApps/waonder-android
   > ./gradlew :waonder:connectedAndroidTest \
   >   -Pandroid.testInstrumentationRunnerArguments.class=com.app.waonder.<package>.<TestClass> \
   >   --info 2>&1 | tail -100
   > ```
   >
   > If it fails, fix the TEST CODE ONLY (never feature code), and re-run. Max 10 iterations.
   > NEVER modify Android feature code — only the test file.
   >
   > When the test passes, report: test class name, file path, number of steps, screenshot names.

2. **Wait for the agent to finish**. If it reports success, proceed. If it reports failure after 10 iterations, stop and report to the user with the failure details.

### Phase 2: Screenshot Capture & Artifact Organization

**Goal**: Pull screenshots from the Android device, organize into the artifact structure.

Once the Android test passes, **spawn `mobile-screenshot-artifact-expert` agent**:

> The Android test `{TestClassName}` just passed on the emulator.
> Screenshots were saved to the device at `/sdcard/Pictures/waonder-test-screenshots/{TestClassName}/`.
>
> 1. Pull screenshots from the device:
>    ```
>    mkdir -p ~/Documents/WaonderApps/sync-artifacts/{TestClassName}/android/
>    adb pull /sdcard/Pictures/waonder-test-screenshots/{TestClassName}/ ~/Documents/WaonderApps/sync-artifacts/{TestClassName}/android/
>    ```
>
> 2. List all pulled screenshots and verify they are valid PNG files.
>
> 3. Read each screenshot image file — describe what you see on each screen (layout, text, buttons, visual state). This becomes the visual reference for iOS.
>
> 4. Read the Android test source file at `{test_file_path}` and produce a Feature Behavior Specification:
>    - List every screen with its UI elements
>    - List every step with the action and expected state
>    - Map each step to its screenshot file
>    - Include test setup (permissions, test data, launch arguments)
>
> 5. Save the specification to `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/spec.md`
>
> Report: path to spec file, number of screenshots, summary of what each screen shows.

**In parallel**, also spawn a second instance to read the Android feature source code and map it to iOS file paths:

> Read the Android test file at `{test_file_path}`.
> Follow the imports and identify all feature source files involved (ViewModels, Screens, Repositories, UseCases).
> For each Android file, determine the iOS counterpart path following structural parity:
>   - `com/app/waonder/feature/auth/` → `Feature/Auth/`
>   - `ViewModel.kt` → `ViewModel.swift`
>   - Capitalize folder names for iOS
>
> Check the iOS repo at `~/Documents/WaonderApps/waonder-ios` to determine which iOS files exist, which are missing, and which may need fixes.
>
> Report: a mapping table of Android path → iOS path → status (exists/missing).

### Phase 3: iOS Test Creation & Feature Sync

**Goal**: A passing iOS automation test with matching behavior and visual output.

1. **Spawn `mobile-ios-test-sync-expert` agent** with:

   > You are syncing the iOS feature to match Android for this scenario.
   >
   > Context:
   > - Feature Behavior Specification: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/spec.md`
   > - Android screenshots: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/android/`
   > - Android test source: `{android_test_file_path}`
   > - Android feature files: `{list of android feature files}`
   > - iOS repo: `~/Documents/WaonderApps/waonder-ios`
   > - File mapping: `{android_to_ios_mapping}`
   >
   > Your job is to make iOS match Android — both functionally AND visually. This involves THREE areas of work:
   >
   > **A. Create/fix the iOS XCUITest** — translate the Android test to XCUITest:
   >   - Use `XCTestCase`, `XCUIApplication`, `waitForExistence(timeout:)`
   >   - Include screenshot capture at matching steps (XCTAttachment)
   >   - Handle iOS-specific differences (permission model, system dialogs via `addUIInterruptionMonitor`)
   >   - Place in the matching iOS test folder structure
   >
   > **B. Fix iOS feature code** — when the test reveals broken iOS behavior:
   >   - Read the Android feature source as reference
   >   - Use idiomatic iOS patterns ONLY: SwiftUI views, @Observable ViewModels with @MainActor, @Environment for DI, async/await
   >   - NEVER violate iOS best practices — no Android-style init() injection in ViewModels, no callback patterns, no imperative layout
   >   - Maintain structural parity (same modules, folders, file names with iOS conventions)
   >
   > **C. Enforce visual styling parity** — BEFORE the test is considered passing:
   >   - Read the Android screenshots and source code for exact styling: colors (hex values), backgrounds (gradients, textures), button shapes, accent colors, text treatment (uppercase, letter spacing), font weights
   >   - Read the iOS source code for the same screens and compare styling
   >   - Fix ANY visual divergence: wrong colors, flat backgrounds where Android has gradients/textures, different button shapes, different accent colors, different text treatment
   >   - The ONLY acceptable differences are truly unavoidable platform differences: SF Pro vs Roboto font rendering, iOS status bar style, system chrome
   >   - Everything else MUST match: background style, color palette, button shapes, accent colors, title treatment, highlight colors, icon styles
   >
   > **Iteration loop** (max 10 iterations):
   >   1. Build iOS project: `xcodebuild build-for-testing -scheme WaonderUITests -destination 'platform=iOS Simulator,name=iPhone 16'`
   >   2. Run the test: `xcodebuild test -scheme WaonderUITests -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WaonderUITests/{TestClass}/{testMethod}`
   >   3. If build fails → fix compilation errors
   >   4. If test fails → read failure log, determine if it's a test issue or feature issue, fix accordingly
   >   5. Re-run until green
   >
   > When the test passes, capture iOS screenshots and save to:
   > `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/ios/`
   >
   > Report: test file path, files created, files modified, number of iterations, any remaining concerns.

2. **Wait for the iOS sync agent to finish**.

### Phase 4: Visual Parity Verification & Automatic Fix Loop

**Goal**: Confirm Android and iOS look the same. If they don't, fix automatically — do NOT just report.

**Spawn `mobile-screenshot-artifact-expert` agent**:

> Compare the Android and iOS screenshots for visual parity.
>
> Android screenshots: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/android/`
> iOS screenshots: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/ios/`
>
> For each matching pair (same step name):
> 1. Read both screenshot images
> 2. Compare: layout, text content, button labels, colors, spacing, element positions
> 3. Classify differences — be STRICT:
>    - **Acceptable** (ONLY these): SF Pro vs Roboto font rendering, iOS status bar style, system chrome, navigation bar style
>    - **Requires fix** (EVERYTHING else): wrong colors, different backgrounds, different button shapes, different accent colors, different text treatment (case, spacing), missing visual elements, different icon styles
>
> Save a visual parity report to `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/parity_report.md`
>
> Report: number of pairs compared, acceptable differences, issues requiring fix.

**Automatic fix loop**: If there are ANY issues requiring fix, IMMEDIATELY go back to Phase 3 — spawn the `mobile-ios-test-sync-expert` agent again with the specific visual issues as additional context. The agent must fix the iOS feature code styling and re-run the test. Then return to Phase 4 for re-verification. Repeat until all issues are resolved or max 3 visual fix cycles.

**The sync is NOT complete until Phase 4 reports zero issues requiring fix.** This is not optional.

### Phase 5: Final Report

Generate a sync report summarizing everything:

```
## Sync Report: {scenario}

### Android Test
- File: {path}
- Status: PASS
- Steps: {n}
- Screenshots: {n}

### iOS Test
- File: {path}
- Status: PASS / PARTIAL
- Steps: {n}
- Screenshots: {n}

### Files Created
- {list}

### Files Modified
- {list}

### Visual Parity
- Pairs compared: {n}
- Acceptable differences: {n}
- Issues: {list or "None"}

### Iterations
- Android test creation: {n}/10
- iOS sync: {n}/10
```

Save to `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/sync_report.md`.

## Sub-Agent Summary

This skill spawns 3 types of sub-agents:

| Agent | Spawned In | Purpose |
|-------|-----------|---------|
| `mobile-android-test-creator-expert` | Phase 1 | Creates Android test, iterates until green |
| `mobile-screenshot-artifact-expert` | Phase 2, 4 | Pulls screenshots, organizes artifacts, compares visuals |
| `mobile-ios-test-sync-expert` | Phase 3 | Creates iOS test + fixes iOS feature code, iterates until green |

## Constraints

- Never modify Android feature code — only Android test code can be created
- iOS feature code CAN and MUST be modified to match Android behavior AND styling
- **Visual parity is mandatory** — the sync is incomplete until iOS screenshots match Android (minus unavoidable platform differences)
- **iOS best practices are sacred** — never violate them when porting. Use @Observable (not init injection for ViewModels), @Environment (not constructor DI), SwiftUI modifiers (not imperative layout), async/await (not callbacks), protocol abstractions (not abstract classes)
- Human approval required before any `git push`
- Max 10 iterations per platform for test creation/fixing
- Max 3 visual fix cycles in Phase 4 before escalating to user
- Max 45 minutes total wall-clock time
- Always use `ScreenshotCapture` utility in Android tests
- Always include XCTAttachment screenshots in iOS tests
- Artifact directory: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/`
