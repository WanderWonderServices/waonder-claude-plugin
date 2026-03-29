---
name: mobile-android-automation-design-parity
description: Use when given design images and an automation test (or scenario) to make the Android UI match the design — analyzes the design, creates needed components in parallel, modifies feature code, runs tests on a dedicated emulator, captures screenshots, and iterates until screenshots match the design images. Typography differences are ignored.
type: generic
---

# Android Automation Design Parity

## Context

This skill is the main orchestrator for making Android UI match design mockups, verified through automation tests. Given design images and a test scenario, it:

1. Analyzes the design to identify components and changes needed
2. Creates missing components in the design system (in parallel)
3. Modifies the feature screen to use those components
4. Runs the automation test on a dedicated emulator
5. Captures screenshots and compares them to the design images
6. Iterates until screenshots match the design

**Core Principle**: The design images are the source of truth. The automation test is the verification mechanism. When the test passes and screenshots match the design, the work is done.

**Typography Exception**: Typography (font family, exact font sizes) is NEVER flagged as an issue. Use whatever typography the app already has. Only layout, colors, spacing, components, and icons must match the design.

## Input

This skill accepts:

1. **Design images** (required): One or more images showing the target UI design
2. **Automation test or scenario** (required): Either:
   - An existing test class name: `"HistoryScreenTest"`
   - A scenario to create a new test: `"test the history bottom sheet with place list"`

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

3. If OTHER emulators are running (active development) → create Design_Parity_API35:
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

### Phase 4: Emulator Setup & Test Execution

**Goal**: Run the automation test on the dedicated emulator.

1. **Set up the dedicated emulator** following the emulator management section above
2. **Create or locate the automation test**:
   - If an existing test class was provided, locate it
   - If a scenario was provided, **spawn `mobile-android-test-creator-expert` agent** to create it:

     > Create an Android automation test for: {scenario}
     > The test should verify the UI matches the design by navigating to {screen} and capturing screenshots at each step.
     > Include ScreenshotCapture at every key visual state.
     > Test credentials: phone `7865550001`, OTP `123456`
     > Max 10 iterations to get the test passing.

3. **Run the test**:
   ```bash
   cd ~/Documents/WaonderApps/waonder-android
   ./gradlew :waonder:connectedAndroidTest \
     -Pandroid.testInstrumentationRunnerArguments.class=com.app.waonder.<package>.<TestClass> \
     --info 2>&1 | tail -150
   ```

4. If the test fails, fix the issue (UI code or test code) and retry. Max 10 iterations.

5. Once passing, pull screenshots:
   ```bash
   mkdir -p ~/Documents/WaonderApps/sync-artifacts/{TestClassName}/screenshots/
   $ANDROID_HOME/platform-tools/adb pull \
     /sdcard/Pictures/waonder-test-screenshots/{TestClassName}/ \
     ~/Documents/WaonderApps/sync-artifacts/{TestClassName}/screenshots/
   ```

### Phase 5: Design Parity Comparison

**Goal**: Compare test screenshots to design images and fix differences.

**Spawn `mobile-android-design-parity-tester-expert` agent**:

> Compare the automation test screenshots against the design images.
>
> Design images: {paths to design images}
> Test screenshots: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/screenshots/`
> Design specification: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/design_spec.md`
>
> For each screenshot vs design pair:
> 1. Compare layout, colors, spacing, components, icons
> 2. IGNORE typography differences
> 3. Identify [MUST FIX] issues
> 4. Fix each issue in the source code (components or feature screen)
> 5. Re-run the test, re-capture, re-compare
> 6. Max 8 iterations
>
> Save parity report to: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/design_parity_report.md`

**Wait for completion.**

If issues remain after 8 iterations, proceed to Phase 6 and report them.

### Phase 6: Final Report

Generate a comprehensive report:

```markdown
# Design Parity Report: {TestClassName}

## Design Images
- {list of input images with descriptions}

## Components Created
| Component | File | Status |
|-----------|------|--------|
| CategoryChip | core/design/components/CategoryChip.kt | Created |
| TimeFilterBar | core/design/components/TimeFilterBar.kt | Created |
| AnimatedMapCard | — | Skipped (complex) |

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
- Screenshots matching design: {n}/{total}
- Typography-only differences: {n} (accepted)
- Unresolved issues: {n} (details below)

## Unresolved Issues
{list or "None"}

## Emulator
- Name: Design_Parity_API35
- Serial: {serial}

## Iterations
- Component creation: {n} agents spawned
- Test iterations: {n}/10
- Parity fix iterations: {n}/8
```

Save to `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/design_parity_final_report.md`

## Sub-Agent Summary

| Agent | Phase | Purpose | Parallelism |
|-------|-------|---------|-------------|
| `mobile-android-design-analyzer-expert` | 1 | Analyzes design images, produces specification | Single |
| `mobile-android-design-component-creator-expert` | 2 | Creates one component per agent | Up to 6 in parallel |
| `mobile-android-test-creator-expert` | 4 | Creates automation test if needed | Single |
| `mobile-android-design-parity-tester-expert` | 5 | Runs tests, compares screenshots, fixes UI | Single |

## Constraints

- **Typography is NEVER an issue** — use whatever the app already has
- **Colors, layout, spacing, icons MUST match** the design
- **Emulator only** — use `Design_Parity_API35`, never a physical device
- **If other emulators are running**, create `Design_Parity_API35` as a new one — never interfere with active development
- **Complex components** (> 150 lines) are skipped with a placeholder — report what was skipped
- **Max 6 parallel component agents** per batch
- **Max 10 iterations** for test creation/fixing
- **Max 8 iterations** for design parity fix loop
- **Max 5 iterations** per component compilation
- **Icons go in `core/design/src/main/res/drawable/`** — never in feature modules
- **Human approval required** before any `git push`
- **Single UiState per ViewModel** — never expose multiple StateFlows
- **Composables are thin UI wiring** — business logic lives in ViewModels
- Artifact directory: `~/Documents/WaonderApps/sync-artifacts/{TestClassName}/`
