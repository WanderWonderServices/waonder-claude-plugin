---
name: mobile-android-automation-design-parity
description: Use when given design images and a scenario (or "continue: TestClassName") to make Android UI match the design — analyzes the design, creates needed components in parallel, assembles the feature screen, runs tests on a dedicated emulator, captures screenshots, compares them against the design images, and automatically fixes all issues until screenshots match. Typography differences are ignored.
type: generic
---

# Android Automation Design Parity

## Context

This skill is the main orchestrator for making Android UI match design mockups, verified through automation tests. Given design images and a scenario, it:

1. Analyzes the design to identify components and changes needed
2. Creates missing components in the design system (in parallel)
3. Assembles the feature screen using those components
4. Runs the automation test on a dedicated emulator and captures screenshots
5. Compares screenshots against design images and **automatically fixes all differences**
6. Iterates compare-fix-rebuild-retest until screenshots match the design or limits are reached

**Core Principle**: The design images are the source of truth. The automation test is the verification mechanism. The skill does ALL the work — analyze, build, test, compare, fix, iterate — until the screenshots match the design images. The user does not fix issues; the skill fixes them automatically.

**Typography Exception**: Typography (font family, exact font sizes) is NEVER flagged as an issue. Use whatever typography the app already has. Only layout, colors, spacing, components, and icons must match the design.

## Input

This skill supports two modes:

### Mode A: New scenario (default)
Design images and a scenario description to create a new test from scratch.
```
"test the history bottom sheet with place list" + [design images]
"test onboarding with location permission granted" + [design images]
```

### Mode B: Continue existing test
A test class name prefixed with `continue:` to resume work on an existing test.
```
"continue: HistoryScreenTest"
"continue: OnboardingGrantLocationTest"
```

Optional:
- Feature area hint: `"feature/history"` — helps locate relevant code faster

## Dedicated Emulator Management

This skill uses a dedicated emulator to avoid conflicts with active development.

### Emulator ID Convention
- Name: `Design_Parity_API35`
- Fixed emulator — reused across runs

### Before Any Test Execution

```
1. Check running emulators:
   $ANDROID_HOME/platform-tools/adb devices

2. If Design_Parity_API35 is already running → use it

3. If OTHER emulators are running (active development) → create Design_Parity_API35 as a NEW emulator:
   $ANDROID_HOME/emulator/emulator -avd Design_Parity_API35 -no-snapshot-load -no-audio -no-boot-anim &

4. If Design_Parity_API35 doesn't exist as an AVD → create it:
   $ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd \
     -n Design_Parity_API35 \
     -k "system-images;android-35;google_apis;arm64-v8a" \
     -d pixel_6

5. Wait for boot:
   $ANDROID_HOME/platform-tools/adb -s <serial> wait-for-device
   $ANDROID_HOME/platform-tools/adb -s <serial> shell getprop sys.boot_completed

6. Install the app if needed:
   cd ~/Documents/WaonderApps/waonder-android
   ./gradlew installDebug

7. Save the emulator serial to:
   ~/Documents/WaonderApps/sync-artifacts/{TestClassName}/emulator_id.txt
```

## Instructions

### Mode Detection

1. If the input starts with `continue:`, extract the test class name and enter **continuation mode**.
2. Otherwise, treat the input as a new scenario description and enter **new scenario mode**.

### Continuation Mode — Auto-detect completed phases

When continuing an existing test, check what work has already been done and skip completed phases:

```
Artifact directory: ~/Documents/WaonderApps/sync-artifacts/{TestClassName}/

Phase 1 (Design analysis) is DONE if:
  - sync-artifacts/{TestClassName}/design_spec.md exists

Phase 2 (Component creation) is DONE if:
  - design_spec.md exists AND all components listed as "new" in it exist in
    core/design/src/main/java/com/app/waonder/core/design/components/

Phase 3 (Feature assembly) is DONE if:
  - The feature screen file exists and imports the new components

Phase 4 (Test execution) is DONE if:
  - Test file exists in waonder/src/androidTest/
  - Re-run the test to verify it still passes
  - If test FAILS, stay in Phase 4

Phase 5 (Design parity — compare + fix) — ALWAYS re-run
  - Screenshots may be stale after user changes
  - Always re-capture, re-compare, and fix any remaining issues

Phase 6 (Final report) — ALWAYS re-generate
```

**Continuation mode steps:**
1. Check each phase's completion status as described above.
2. Log which phases are being skipped and why:
   ```
   Phase 1: SKIP — design_spec.md exists
   Phase 2: SKIP — all new components exist in core/design/components/
   Phase 3: SKIP — HistoryScreen.kt exists and imports new components
   Phase 4: SKIP — HistoryScreenTest.kt exists, re-run PASSED
   Phase 5: RUN — always re-verify and fix design parity
   Phase 6: RUN — always re-generate final report
   ```
3. Start execution from the first phase that is NOT done.
4. If all phases through 4 are done, go directly to Phase 5.

**Important**: Even when skipping phases, always re-run the existing test (Phase 4) to confirm it still passes. Code may have changed since the last run. If a previously-passing test now fails, that phase is NOT done — stay and fix it.

### New Scenario Mode

When this skill is invoked with design images and a scenario description, execute all phases from Phase 1. Each phase uses sub-agents spawned in parallel where possible.

### Phase 1: Design Analysis

**Goal**: Understand what needs to be built/changed.

**Spawn `mobile-android-design-analyzer-expert` agent**:

> You are analyzing design images for the Waonder Android app.
>
> Android repo: `~/Documents/WaonderApps/waonder-android`
>
> Design images provided: {list of image paths or inline images}
> Feature area: {feature hint if provided, otherwise "determine from design"}
>
> BEFORE analyzing:
> 1. Read the existing feature screen code (if it exists)
> 2. Read `core/design/src/main/java/com/app/waonder/core/design/components/` to see existing components
> 3. Read theme files (Color.kt, Type.kt, Shape.kt)
>
> Analyze the design images and produce a Design Specification with:
> - Component inventory (existing to modify, new to create, feature-specific)
> - Color tokens comparison
> - Layout specification
> - Modification checklist
>
> Save to: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/design_spec.md`
>
> IMPORTANT: Typography differences are NOT issues. Use whatever typography the app has.

**Wait for completion.** The design specification drives all subsequent phases.

### Phase 2: Component Creation (Parallel)

**Goal**: Create all new design system components identified in Phase 1.

Read the design specification. For each new component marked as `simple` or `medium` complexity:

**Spawn one `mobile-android-design-component-creator-expert` agent per component** (in parallel):

> You are creating a Compose component for the Waonder design system.
>
> Component: {component_name}
> Module: core/design
> Complexity: {simple|medium}
> Description: {from design spec}
> Parameters: {from design spec}
>
> Reference design: {relevant section of design spec or image description}
>
> Follow existing patterns in `core/design/src/main/java/com/app/waonder/core/design/components/`.
> Include @Preview functions.
> Verify it compiles with `./gradlew :core:design:compileDebugKotlin`.

For components marked `complex`:
- **Skip them.** Create a simple placeholder component instead (basic Card or Box with text description).
- Log what was skipped and why.

**Cap**: Max 6 component agents in parallel. If more than 6 components needed, batch in groups of 6.

**Wait for ALL component agents to finish.** Collect results:
- Which components were created successfully
- Which failed to compile (need manual intervention)
- Which were skipped as too complex

### Phase 3: Feature Screen Assembly

**Goal**: Wire the new/modified components into the feature screen.

This phase is done by the main orchestrator (this skill), NOT a sub-agent, because it requires understanding the full picture.

1. **Read the design specification** (design_spec.md)
2. **Read all newly created components** to understand their APIs
3. **Read the existing feature screen** (if it exists)
4. **Modify or create the feature screen** to use the new components:
   - Follow the screen organization pattern: `ui/feature/screens/screenname/`
   - Keep composables thin — UI wiring only
   - Use method references for ViewModel callbacks
   - Single UiState pattern if ViewModel is involved
5. **Verify compilation**:
   ```bash
   cd ~/Documents/WaonderApps/waonder-android
   ./gradlew :waonder:compileDebugKotlin 2>&1 | tail -50
   ```
6. **If compilation fails**, fix errors and retry. Max 5 iterations.

### Phase 4: Test Execution on Dedicated Emulator

**Goal**: Run the automation test on the dedicated emulator and capture screenshots.

1. **Set up the dedicated emulator** following the emulator management section above.
2. **Create or locate the automation test**:
   - If an existing test class was provided, locate it
   - If a scenario was provided, **spawn `mobile-android-test-creator-expert` agent** to create it:

     > Create an Android automation test for: {scenario}
     > The test should verify the UI matches the design by navigating to {screen} and capturing screenshots at each step.
     > Include ScreenshotCapture at every key visual state.
     > Target emulator: Design_Parity_API35 (serial in ~/Documents/WaonderApps/sync-artifacts/{TestClassName}/emulator_id.txt)
     > Test credentials: phone `7865550001`, OTP `123456`
     > Max 10 iterations to get the test passing.

3. **Run the test targeting the dedicated emulator**:
   ```bash
   cd ~/Documents/WaonderApps/waonder-android
   SERIAL=$(cat ~/Documents/WaonderApps/sync-artifacts/{TestClassName}/emulator_id.txt)
   ./gradlew :waonder:connectedAndroidTest \
     -Pandroid.testInstrumentationRunnerArguments.class=com.app.waonder.<package>.<TestClass> \
     -Pandroid.builder.testDeviceSerials=$SERIAL \
     --info 2>&1 | tail -150
   ```

4. If the test fails, fix the issue (UI code or test code) and retry. Max 10 iterations.

5. Once passing, pull screenshots:
   ```bash
   SERIAL=$(cat ~/Documents/WaonderApps/sync-artifacts/{TestClassName}/emulator_id.txt)
   mkdir -p ~/Documents/WaonderApps/sync-artifacts/{TestClassName}/screenshots/
   $ANDROID_HOME/platform-tools/adb -s $SERIAL pull \
     /sdcard/Pictures/waonder-test-screenshots/{TestClassName}/ \
     ~/Documents/WaonderApps/sync-artifacts/{TestClassName}/screenshots/
   ```

### Phase 5: Design Parity — Compare + Fix Loop

**Goal**: Compare test screenshots to design images and **automatically fix all differences** until screenshots match. This is NOT detection-only — this phase fixes issues.

**Spawn `mobile-android-design-parity-tester-expert` agent**:

> Compare the automation test screenshots against the design images and FIX all differences.
>
> Design images: {paths to design images}
> Test screenshots: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/screenshots/`
> Design specification: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/design_spec.md`
> Emulator serial: read from `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/emulator_id.txt`
> Test class: `com.app.waonder.<package>.<TestClass>`
>
> Your job is to:
> 1. Read each screenshot and the corresponding design image
> 2. Identify all differences (IGNORE typography)
> 3. Fix each difference in the source code (components, feature screen, or theme)
> 4. Rebuild, re-run the test, re-capture screenshots
> 5. Re-compare to verify the fix worked
> 6. Repeat until all issues are resolved or limits are reached
>
> Rules:
> - Fix ONE issue at a time, rebuild, verify, then next
> - Max 8 total fix cycles
> - Max 3 attempts per individual issue — if still broken, skip and move to next
> - Can modify: component files, feature screen files, theme files
> - Cannot modify: test files, ViewModel logic
> - Typography is NEVER an issue
>
> Save report to: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/design_parity_report.md`

**Wait for completion.**

### Phase 6: Final Report

Generate a comprehensive report summarizing everything:

```markdown
# Design Parity Report: {TestClassName}

## Design Images
- {list of input images with descriptions}

## Components Created
| Component | File | Status |
|-----------|------|--------|
| CategoryChip | core/design/components/CategoryChip.kt | Created |
| TimeFilterBar | core/design/components/TimeFilterBar.kt | Created |
| AnimatedMapCard | --- | Skipped (complex) |

## Components Modified
| Component | File | Change |
|-----------|------|--------|
| WaonderButton | core/design/components/WaonderButton.kt | Added outline variant |

## Feature Files Modified
| File | Change |
|------|--------|
| feature/history/HistoryScreen.kt | Rewired to use new components |

## Test
- Class: {TestClassName}
- File: {path}
- Status: PASS
- Screenshots: {n}

## Visual Parity
- Screenshots compared: {n}/{total}
- Typography-only differences: {n} (accepted)
- Issues fixed automatically: {n}
- Issues unresolved: {n}

## Resolved Issues
{Numbered list of each issue that was fixed:}
1. **Issue**: Card background was #FFFFFF, design shows #16213E
   **File fixed**: core/design/components/WaonderCard.kt
   **Fix applied**: Changed containerColor to #16213E
   **Attempts**: 1

## Unresolved Issues (if any)
{Numbered list of issues that could not be fixed after max attempts:}
1. **Issue**: {description}
   **File**: {path}
   **Attempts**: 3 (max reached)
   **Reason**: {why it couldn't be fixed}

{or "None — all screenshots match the design."}

## Emulator
- Name: Design_Parity_API35
- Serial: {serial}

## Iterations
- Component creation: {n} agents spawned
- Test iterations: {n}/10
- Parity fix cycles: {n}/8
```

Save to `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/design_parity_final_report.md`

## Sub-Agent Summary

| Agent | Phase | Purpose | Parallelism |
|-------|-------|---------|-------------|
| `mobile-android-design-analyzer-expert` | 1 | Analyzes design images, produces specification. Never modifies source code. | Single |
| `mobile-android-design-component-creator-expert` | 2 | Creates one component per agent in core/design/components/ | Up to 6 in parallel |
| `mobile-android-test-creator-expert` | 4 | Creates automation test if needed | Single |
| `mobile-android-design-parity-tester-expert` | 5 | Compares screenshots against design, **fixes all differences automatically**, rebuilds, re-tests, iterates until match | Single |

## Constraints

- **The skill fixes issues automatically** — Phase 5 compares AND fixes, iterating until screenshots match
- **Typography is NEVER an issue** — use whatever the app already has
- **Colors, layout, spacing, icons MUST match** the design
- **Emulator only** — use `Design_Parity_API35`, never a physical device
- **If other emulators are running**, create `Design_Parity_API35` as a new one — never interfere with active development
- **Store emulator serial** in `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/emulator_id.txt`
- **On test execution, always target the dedicated emulator** using the stored serial
- **Complex components** (> 150 lines) are skipped with a placeholder — report what was skipped
- **Max 6 parallel component agents** per batch
- **Max 10 iterations** for test creation/fixing
- **Max 5 iterations** per component compilation
- **Max 8 total parity fix cycles** in Phase 5
- **Max 3 attempts per individual parity issue** — skip and move to next if still broken
- **Icons go in `core/design/src/main/res/drawable/`** — never in feature modules
- **Human approval required** before any `git push`
- **Single UiState per ViewModel** — never expose multiple StateFlows
- **Composables are thin UI wiring** — business logic lives in ViewModels
- Artifact directory: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/`
