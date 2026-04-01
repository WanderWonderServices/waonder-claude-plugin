---
name: generic-mobile-automation-test-sync
description: Use when synchronizing a feature between Android and iOS via automation tests — takes a scenario description (new test) or "continue: TestClassName" (resume existing test), creates a passing Android test, captures screenshots, then syncs to iOS with visual and functional parity
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

This skill supports two modes:

### Mode A: New scenario (default)
A scenario description to create a new test from scratch.
```
"test the login flow — sign in with phone and OTP"
"test onboarding with location permission granted"
"test cold start screen loads correctly"
```

### Mode B: Continue existing test
A test class name prefixed with `continue:` to resume work on an existing test.
```
"continue: SignInScreenTest"
"continue: OnboardingGrantLocationTest"
```

## Instructions

### Mode Detection

1. If the input starts with `continue:`, extract the test class name and enter **continuation mode**.
2. Otherwise, treat the input as a new scenario description and enter **new scenario mode**.

### Continuation Mode — Auto-detect completed phases

When continuing an existing test, check what work has already been done and skip completed phases:

```
Artifact directory: ~/Documents/WaonderApps/sync-artifacts/{TestClassName}/

Phase 1 (Android test) is DONE if:
  - Android test file exists in ~/Documents/WaonderApps/waonder-android/waonder/src/androidTest/
    (search for {TestClassName}.kt)
  - Re-run the test on the emulator to verify it still passes
  - If the test FAILS, stay in Phase 1 to fix it (test code only)

Phase 2 (Screenshots & artifacts) is DONE if ALL of:
  - sync-artifacts/{TestClassName}/android/ contains PNG screenshots
  - sync-artifacts/{TestClassName}/spec.md exists
  - Screenshots are up-to-date (re-pull from emulator after Phase 1 re-run)

Phase 3 (Resource parity) is DONE if:
  - sync-artifacts/{TestClassName}/resource_map.md exists
  - sync-artifacts/{TestClassName}/resource_parity.md exists
  - Re-run resource parity check to verify no new mismatches

Phase 4 (iOS test & sync) is DONE if:
  - iOS test file exists in ~/Documents/WaonderApps/waonder-ios/WaonderUITests/
    (search for {TestClassName}.swift)
  - Re-run the iOS test on the simulator to verify it still passes
  - If the test FAILS, stay in Phase 4 to fix it
  - If the test PASSES, re-capture iOS screenshots

Phase 5 (Visual parity) — ALWAYS re-run this phase, even if a previous
  parity_report.md exists. Visual parity must be verified against the
  CURRENT state of both apps.
```

**Continuation mode steps:**
1. Check each phase's completion status as described above.
2. Log which phases are being skipped and why:
   ```
   Phase 1: SKIP — SignInScreenTest.kt exists, re-run PASSED
   Phase 2: SKIP — spec.md and 6 android screenshots present, re-pulled
   Phase 3: SKIP — resource_map.md and resource_parity.md exist, re-checked
   Phase 4: SKIP — SignInScreenTest.swift exists, re-run PASSED, screenshots re-captured
   Phase 5: RUN — always re-verify visual parity
   ```
3. Start execution from the first phase that is NOT done.
4. If all phases through 3 are done, go directly to Phase 4.
5. If Phase 1 is done but Phase 2 is not, start from Phase 2 (re-pull fresh screenshots from the emulator since the test was just re-run).

**Important**: Even when skipping phases, always re-run the existing tests to confirm they still pass. Code may have changed since the last run. If a previously-passing test now fails, that phase is NOT done — stay and fix it.

### New Scenario Mode

When this skill is invoked with a scenario description, execute all phases from Phase 1. Each phase uses sub-agents spawned in parallel where possible.

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

### Phase 3: Resource Parity Audit & Fix

**Goal**: Ensure all Android resources (strings, colors, drawables, dimensions) used by the tested screens have matching iOS equivalents before the iOS test runs.

**Spawn `mobile-resource-parity-expert` agent**:

> Audit resource parity between Android and iOS for the test `{TestClassName}`.
>
> **Android feature files involved**: `{list of android feature files from Phase 2 mapping}`
> **Android repo**: `~/Documents/WaonderApps/waonder-android`
> **iOS repo**: `~/Documents/WaonderApps/waonder-ios`
> **Test class name**: `{TestClassName}`
>
> Your job:
> 1. Read each Android feature file and trace ALL resource references:
>    - `R.string.*` → look up in `strings.xml`
>    - `R.color.*` → look up in `colors.xml`
>    - `R.drawable.*` → identify drawable file
>    - `R.dimen.*` → look up in `dimens.xml`
>    - Material icons → note SF Symbol equivalents
>
> 2. Build a resource map documenting every resource, its value, and which screen uses it.
>    Save to `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/resource_map.md`
>
> 3. Check iOS for each resource:
>    - Strings: check `waonder/en.lproj/Localizable.strings`
>    - Colors: check Asset Catalogs and Color extensions
>    - Drawables: check SF Symbols usage and Asset Catalogs
>    - Dimensions: check spacing constants
>
> 4. **Auto-fix** missing or mismatched resources on iOS:
>    - Add missing strings to `Localizable.strings`
>    - Fix mismatched string values
>    - Flag missing custom assets for manual intervention
>    - SF Symbol substitution for Material Icons is acceptable
>
> 5. Save a parity report to `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/resource_parity.md`
>
> Report: total resources traced, matched count, auto-fixed count, remaining issues.

**Wait for the resource parity agent to finish.** If it reports remaining issues that require manual intervention (e.g., custom image assets), log them but continue — the iOS test sync agent will encounter these as visual differences and they'll be caught in Phase 5.

**CRITICAL — Hardcoded String Gate**: If the resource parity agent reports ANY `RESOURCE USAGE ERROR` (hardcoded English strings in iOS Swift source files), these MUST be included in the Phase 4 prompt to the iOS test sync agent as mandatory fixes. The iOS test sync agent MUST replace all hardcoded strings with `String(localized: "key")` calls before the test is considered passing. Do NOT proceed to Phase 5 with hardcoded strings still in iOS feature code — this is a code defect, not a visual parity issue.

### Phase 4: iOS Test Creation & Feature Sync

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
   > - Resource parity report: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/resource_parity.md` — read this first for known resource issues
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

### Phase 5: Visual Parity Verification & Automatic Fix Loop

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

**Automatic fix loop with issue rotation**: If there are issues requiring fix:

1. Create a numbered list of all issues from the parity report.
2. **Process issues ONE AT A TIME, sequentially** — NEVER in parallel. Multiple agents fixing different issues simultaneously will produce conflicting file changes, merge conflicts, and broken builds. Each issue must be fully resolved (or marked unresolved) before starting the next.
3. **For each issue, in order:**
   a. **Instrument**: Spawn `mobile-automation-bug-instrumentation-expert` — it reads the issue, traces the relevant code paths, and adds targeted temporary log statements (max 10 per issue) with the `WAONDER-DEBUG-{ISSUE_ID}` tag. It saves an instrumentation manifest to `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/instrumentation_{ISSUE_ID}.md`. Wait for it to finish.
   b. **Fix**: Spawn `mobile-ios-test-sync-expert` with ONLY this specific issue, plus the full context (spec, screenshots, file mapping) AND the instrumentation manifest. The fixer gets **max 3 attempts**. On each attempt it must:
      - Run the test with simulator log capture enabled
      - Read the `WAONDER-DEBUG-{ISSUE_ID}` log output to understand what's happening
      - Apply the fix based on log evidence
      - If it cannot solve the issue in 3 attempts, save a diagnostic report to `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/issue_{n}_diagnostic.md` with: what was tried, error logs, instrumented log output, and hypothesis for why it failed. Report back as "UNRESOLVED".
   c. **Cleanup**: Spawn `mobile-automation-bug-instrumentation-expert` in cleanup mode — it removes all `WAONDER-DEBUG-{ISSUE_ID}` log statements it added, verifies the build still compiles, and deletes the instrumentation manifest. Debug logs must NEVER remain in the codebase after an issue is resolved OR marked unresolved. Wait for cleanup to finish before proceeding to the next issue.
4. After all issues have been processed sequentially, re-run the full visual parity verification (spawn `mobile-screenshot-artifact-expert` again).
5. If previously-unresolved issues remain, try them again — solving other issues first may have unblocked them. Each gets 3 fresh attempts with fresh instrumentation. Process them sequentially again.
6. Repeat until all issues are resolved or all remaining issues have failed twice (6 total attempts across 2 rounds).
7. **Final cleanup**: After the entire Phase 5 completes, verify NO `WAONDER-DEBUG-` strings remain in the iOS codebase. If any do, spawn one final instrumentation cleanup agent to remove them.

**The sync is NOT complete until Phase 5 reports zero issues requiring fix.** If issues remain after the full rotation, report them to the user with the diagnostic files.

**iOS log capture**: Every sub-agent fixing an iOS issue MUST capture simulator logs during test runs to aid debugging. See the iOS test sync agent for the log capture protocol.

### Phase 6: Final Report

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

### Resource Parity
- Resources traced: {n}
- Matched: {n}
- Auto-fixed: {n}
- Manual required: {n}

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

This skill spawns 5 types of sub-agents:

| Agent | Spawned In | Purpose |
|-------|-----------|---------|
| `mobile-android-test-creator-expert` | Phase 1 | Creates Android test, iterates until green (emulator only) |
| `mobile-screenshot-artifact-expert` | Phase 2, 5 | Pulls screenshots, organizes artifacts, compares visuals |
| `mobile-resource-parity-expert` | Phase 3 | Traces all Android resources (strings, colors, drawables, dimensions) used by tested screens, maps them to iOS equivalents, auto-fixes missing/mismatched resources (especially Localizable.strings), and produces a parity report. Runs BEFORE iOS test creation so resources are correct from the start. |
| `mobile-ios-test-sync-expert` | Phase 4, 5 | Creates iOS test + fixes iOS feature code (simulator only). In Phase 5, one instance per visual issue processed SEQUENTIALLY (never parallel) with 3-attempt limit. |
| `mobile-automation-bug-instrumentation-expert` | Phase 5 | Instruments app with targeted temporary log statements before each fix attempt. Adds max 10 logs per issue at decision points/data boundaries. Cleans up all instrumentation after each issue is resolved. Debug logs never ship. |

## Constraints

- **Emulator/Simulator ONLY** — tests MUST run on emulators (Android) and simulators (iOS), NEVER on real physical devices. Real devices are reserved for active local development. If no emulator/simulator is running, launch one before proceeding. Never attempt to connect to or run tests on a physical device.
- Never modify Android feature code — only Android test code can be created
- iOS feature code CAN and MUST be modified to match Android behavior AND styling
- **Visual parity is mandatory** — the sync is incomplete until iOS screenshots match Android (minus unavoidable platform differences)
- **iOS best practices are sacred** — never violate them when porting. Use @Observable (not init injection for ViewModels), @Environment (not constructor DI), SwiftUI modifiers (not imperative layout), async/await (not callbacks), protocol abstractions (not abstract classes)
- **String localization is mandatory** — ZERO TOLERANCE for hardcoded user-facing strings in iOS feature code. All text must use `String(localized: "key")` or SwiftUI `Text("key")` localization lookup. Hardcoded English strings in Views are code defects that MUST be caught in Phase 3 (resource parity audit) and fixed in Phase 4 (iOS sync). The sync is NOT complete if hardcoded strings remain.
- Human approval required before any `git push`
- Max 10 iterations per platform for test creation/fixing
- Max 3 attempts per individual visual parity issue before rotating to another issue
- Max 45 minutes total wall-clock time
- Always use `ScreenshotCapture` utility in Android tests
- Always include XCTAttachment screenshots in iOS tests
- Always capture iOS simulator logs during test runs for debugging
- Artifact directory: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/`
