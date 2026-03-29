# Test-Driven Android-to-iOS Feature Synchronizer

**Milestone**: 005_automation-test-synchronizer
**Created**: 2026-03-28
**Status**: Draft
**Depends on**: 002_android-to-ios-full-migration, 004_ios-automation-tests

## Overview

A workflow where Claude autonomously synchronizes an iOS feature to match its Android counterpart, using automation tests as both the specification and the verification mechanism. The workflow starts from a **scenario description** — not an existing test. Claude first creates and validates the automation test on Android, then uses that passing test as the single source of truth to reproduce the same behavior on iOS.

**In one sentence**: Everything starts with a scenario description, becomes a passing Android automation test, and finishes with a passing iOS automation test that behaves exactly the same.

---

## Problem Statement

The Android app is the source of truth. Features are built and validated on Android first. When the same feature exists on iOS, its state is unknown — it may be partially implemented, broken, visually mismatched, or missing entirely. Today, a human must:

1. Manually run the Android app and observe the feature
2. Mentally translate what they see to iOS expectations
3. Manually check the iOS app
4. Manually fix any differences
5. Manually verify the fix

This is slow, error-prone, and bottlenecked on Gabriel (who is new to iOS). The insight: **an automation test captures everything Claude needs to know** — the screens, the flow, the expected UI elements, the timing, and the visual output. If Claude can create a test for a scenario, run it on Android, read its artifacts, and reproduce the same on iOS, it can close the loop autonomously.

---

## Core Concept: Tests as Specifications

An automation test is more than a test — it's a **machine-readable feature specification**:

| Test Artifact | What It Tells Claude |
|--------------|---------------------|
| Test steps (tap, type, swipe) | The user flow / interaction sequence |
| Assertions (element exists, text matches) | The expected UI state at each step |
| Screenshots captured during the test | The exact visual appearance at each checkpoint |
| Test logs | Timing, network calls, state transitions |
| Element identifiers used | The accessibility structure of the UI |
| Wait conditions | What async operations the feature depends on |

By creating a test for a scenario, running it on Android, and collecting these artifacts, Claude gets a complete specification of the feature without any human writing a requirements document.

---

## Workflow

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  INPUT: Scenario description (e.g., "test the login flow")         │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────┐       │
│  │ PHASE 1: Android Test Creation & Validation              │       │
│  │                                                          │       │
│  │  1. Explore the Android feature code                     │       │
│  │  2. Check if Android test already exists                 │       │
│  │     - If yes: run it, verify it passes                   │       │
│  │     - If no: create the automation test                  │       │
│  │  3. Iterate until Android test passes (fix test code)    │       │
│  │  4. Android test is GREEN — locked as reference          │       │
│  └────────────────────────┬─────────────────────────────────┘       │
│                           │                                         │
│                           ▼                                         │
│  ┌──────────────────────────────────────────────────────────┐       │
│  │ PHASE 2: Android Reference Capture                       │       │
│  │                                                          │       │
│  │  1. Run the passing Android test with screenshot capture │       │
│  │  2. Capture full test logs                               │       │
│  │  3. Read the Android feature source code                 │       │
│  │  4. Produce a Feature Behavior Specification             │       │
│  └────────────────────────┬─────────────────────────────────┘       │
│                           │                                         │
│                           ▼                                         │
│  ┌──────────────────────────────────────────────────────────┐       │
│  │ PHASE 3: iOS State Assessment                            │       │
│  │                                                          │       │
│  │  1. Find the corresponding iOS feature code              │       │
│  │  2. Check if an iOS test already exists                  │       │
│  │  3. If test exists: run it, analyze failures             │       │
│  │  4. If no test: create it from the Android spec          │       │
│  │  5. Identify gaps (missing screens, broken flows, etc.)  │       │
│  └────────────────────────┬─────────────────────────────────┘       │
│                           │                                         │
│                           ▼                                         │
│  ┌──────────────────────────────────────────────────────────┐       │
│  │ PHASE 4: iOS Fix & Iterate (autonomous loop)             │       │
│  │                                                          │       │
│  │  ┌─────────────────────────────────────────────┐         │       │
│  │  │ 4a. Analyze test failure / screenshot diff   │         │       │
│  │  │ 4b. Fix iOS feature code (or test code)      │         │       │
│  │  │ 4c. Build iOS project                        │         │       │
│  │  │ 4d. Run iOS test                             │         │       │
│  │  │ 4e. Capture iOS screenshots + logs           │         │       │
│  │  │ 4f. Compare with Android reference           │◄──┐     │       │
│  │  └──────────────────┬──────────────────────────┘   │     │       │
│  │                     │                              │     │       │
│  │                     ▼                              │     │       │
│  │              Pass? ──No──► Fix again ──────────────┘     │       │
│  │                │                  (max N iterations)      │       │
│  │               Yes                                        │       │
│  │                │                                         │       │
│  └────────────────┼─────────────────────────────────────────┘       │
│                   ▼                                                  │
│  ┌──────────────────────────────────────────────────────────┐       │
│  │ PHASE 5: Parity Verification                             │       │
│  │                                                          │       │
│  │  1. iOS test passes (functional parity)                  │       │
│  │  2. Screenshot comparison (visual parity)                │       │
│  │  3. Structural parity (folder/file matching)             │       │
│  │  4. Generate sync report                                 │       │
│  └──────────────────────────────────────────────────────────┘       │
│                                                                     │
│  OUTPUT: Both tests passing + iOS feature matching Android          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

### Phase 1: Android Test Creation & Validation

**Goal**: Ensure a passing Android automation test exists for the given scenario.

The Android app is the source of truth, but it might not have an automation test for every feature. This phase bridges that gap — Claude explores the Android feature, writes the test if needed, and iterates until it passes.

**The Android repo already has a complete testing infrastructure** with established patterns, helpers, and conventions. The agent creating the test MUST follow these exactly — not invent new patterns.

**Steps**:

1. **Understand the scenario** — Parse the user's description to identify:
   - Which feature area is being tested (auth, onboarding, settings, map, etc.)
   - The expected user flow (screens, interactions, outcomes)
   - Any special conditions (permissions, system dialogs, test data)

2. **Explore the Android feature code** — Navigate the codebase to find:
   - Which Screens, ViewModels, Repositories are involved
   - The navigation graph for this feature
   - Existing accessibility labels / test tags on UI elements
   - Existing test utilities and helpers

3. **Study existing tests as reference** — Before writing anything, read existing tests in `waonder/src/androidTest/java/com/app/waonder/` to learn the project's patterns:
   - Simple flow: `auth/LoginFlowTest.kt`
   - Medium flow with reusable helpers: `session/LogoutAndLoginBackTest.kt`
   - Complex flow with permissions: `onboarding/OnboardingGrantLocationTest.kt`
   - Multi-scenario with restarts: `onboarding/OnboardingPermissionRestartScenariosTest.kt`
   - Logcat-based verification: `home/HistoryModeAnnotationTest.kt`

4. **Check if Android test already exists**:
   - Search `waonder/src/androidTest/` for a matching test class
   - If found → run it → verify it passes → go to Phase 2
   - If found but failing → fix the test → iterate until green
   - If not found → create it (next step)

5. **Create the Android automation test** following the established infrastructure:

   **Test class skeleton** (every test follows this structure):
   ```kotlin
   @HiltAndroidTest
   @RunWith(AndroidJUnit4::class)
   class <FeatureName>Test {

       @get:Rule(order = 0)
       val hiltRule = HiltAndroidRule(this)

       @get:Rule(order = 1)
       val composeTestRule = createAndroidComposeRule<MainActivity>()

       // Only if test interacts with system dialogs (permissions, etc.)
       private lateinit var device: UiDevice

       @Before
       fun setup() {
           hiltRule.inject()
           // Only if using UiDevice:
           device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
       }

       @After
       fun tearDown() {
           // Reset any modified state (permissions, location services)
       }

       @Test
       fun <descriptive_test_name>() {
           // Test body
       }
   }
   ```

   **Rule ordering is critical**: `HiltAndroidRule` MUST be `order = 0`, `createAndroidComposeRule` MUST be `order = 1`.

   **Compose UI interactions** (for app screens):
   ```kotlin
   // Find elements
   composeTestRule.onNodeWithText("Button text")
   composeTestRule.onNode(hasContentDescription("icon label"))
   composeTestRule.onNode(hasSetTextAction())  // text fields
   composeTestRule.onAllNodes(hasText("text") and isEnabled())

   // Wait for elements with timeout
   composeTestRule.waitUntil(timeoutMillis = 30_000) {
       composeTestRule.onAllNodes(hasText("Expected text"))
           .fetchSemanticsNodes().isNotEmpty()
   }

   // Interact
   .performClick()
   .performTextClearance()
   .performTextInput("7865550001")
   .assertIsDisplayed()
   ```

   **UiAutomator** (for system dialogs — permissions, alerts):
   ```kotlin
   // Permission grant
   val allowButton = device.findObject(
       UiSelector().textMatches("(?i)(While using the app|Allow|ALLOW)")
   )
   if (allowButton.waitForExists(10_000)) {
       allowButton.click()
   }

   // Permission deny
   val denyButton = device.findObject(
       UiSelector().textMatches("(?i)(Don't allow|Deny|DENY)")
   )
   if (denyButton.waitForExists(10_000)) {
       denyButton.click()
   }
   ```

   **Shell commands** (for permission/settings manipulation):
   ```kotlin
   val uiAutomation = InstrumentationRegistry.getInstrumentation().uiAutomation

   // Grant permission
   uiAutomation.executeShellCommand(
       "pm grant com.app.waonder.debug android.permission.ACCESS_FINE_LOCATION"
   ).close()

   // Revoke permission
   uiAutomation.executeShellCommand(
       "pm revoke com.app.waonder.debug android.permission.ACCESS_FINE_LOCATION"
   ).close()

   // Disable location services
   uiAutomation.executeShellCommand("settings put secure location_mode 0").close()

   // Enable location services
   uiAutomation.executeShellCommand("settings put secure location_mode 3").close()
   ```

   **App restart pattern**:
   ```kotlin
   private fun restartActivity() {
       composeTestRule.activityRule.scenario.onActivity { it.finish() }
       Thread.sleep(2000)
       val intent = Intent(ApplicationProvider.getApplicationContext(), MainActivity::class.java).apply {
           addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
       }
       ActivityScenario.launch<MainActivity>(intent)
       Thread.sleep(3000)
   }
   ```

   **Logcat verification** (when UI assertions aren't enough):
   ```kotlin
   private fun clearLogcat() {
       InstrumentationRegistry.getInstrumentation().uiAutomation
           .executeShellCommand("logcat -c").close()
   }

   private fun captureLogcat(): String {
       val pfd = InstrumentationRegistry.getInstrumentation().uiAutomation
           .executeShellCommand("logcat -d -s TagName:D")
       return try {
           java.io.FileInputStream(pfd.fileDescriptor).bufferedReader().readText()
       } finally {
           pfd.close()
       }
   }
   ```

   **Timeout conventions** (from existing tests):
   | Timeout | Use case |
   |---------|----------|
   | 60,000ms | Cold start / initial map loading |
   | 45,000ms | Screen transitions with heavy animations |
   | 30,000ms | Standard UI operations, authentication screens |
   | 15,000ms | Dialog appearance, quick transitions |
   | 10,000ms | System dialogs (permission prompts) |
   | 5,000ms | Brief operations, logcat propagation |
   | 1,000-2,000ms | Pauses between rapid interactions |

   **Test placement**: `waonder/src/androidTest/java/com/app/waonder/<feature>/` — mirroring the feature module structure.

   **Test credentials**: Phone `7865550001`, OTP `123456` (hardcoded, pre-configured in backend).

   **Dependencies available** (already in `build.gradle.kts`):
   - `androidx.compose.ui:ui-test-junit4` — Compose testing
   - `androidx.test.espresso:espresso-core` — Espresso
   - `androidx.test.uiautomator:uiautomator` — System dialog interaction
   - `com.google.dagger:hilt-android-testing` — Hilt test support
   - `androidx.test.ext:junit` — AndroidJUnit4 runner

6. **Run the test on emulator**:
   ```bash
   cd ~/Documents/WaonderApps/waonder-android
   ./gradlew :waonder:connectedAndroidTest \
     -Pandroid.testInstrumentationRunnerArguments.class=com.app.waonder.<package>.<TestClass> \
     --info
   ```

7. **Iterate until Android test passes** (max 10 iterations):
   - If it fails: read the error, fix the **test code only** (not the feature — Android feature code is assumed correct)
   - Common fixes: wrong element text/ID, wrong wait timeout, wrong navigation step, missing test setup, race condition needing a `Thread.sleep()`
   - Re-run until green

8. **Lock the reference** — Once the Android test passes:
   - The test code is finalized (no more changes to Android)
   - The passing test becomes the source of truth for iOS

**Critical rule**: In this phase, Claude only fixes the **test code**, never the Android feature code. The feature is already working — the test must be adapted to match reality.

**Important**: No screenshot capture infrastructure exists in the Android repo yet. The agent must add screenshot capture to the test it creates (see Screenshot Strategy section below). This is a test-only addition — it doesn't change feature code.

---

### Phase 2: Android Reference Capture

**Goal**: Produce a complete Feature Behavior Specification from the passing Android test.

**Steps**:

1. **Read the Android test source** — Parse the test class to extract:
   - Flow steps (what actions are taken)
   - Assertions (what is expected at each step)
   - Screen identifiers (accessibility labels, view IDs)
   - Test helpers used (login helpers, wait utilities)
   - Setup/teardown (permissions, test data)

2. **Read the Android feature source** — Follow imports from the test to understand:
   - Which ViewModels, Screens, Repositories are involved
   - The navigation graph for this feature
   - The data models used

3. **Run the Android test with full artifact capture**:
   ```bash
   cd ~/Documents/WaonderApps/waonder-android
   ./gradlew connectedAndroidTest \
     -Pandroid.testInstrumentationRunnerArguments.class=<test.class.Name> \
     --info
   ```
   - Screenshots: Captured at each step via test screenshot rules
   - Logs: Captured from `adb logcat` during test execution
   - Video: Optional — `adb screenrecord` for complex flows

4. **Produce the Feature Behavior Specification** — A structured document:
   ```
   Feature: Login Flow
   Source Test: LoginFlowTest.kt
   Screens: [ColdStart, PhoneInput, OTP, Home]
   Steps:
     1. Screen: ColdStart → Assert: "Sign in" button visible → Screenshot: step_01.png
     2. Action: Tap "Sign in" → Screen: PhoneInput → Screenshot: step_02.png
     3. Action: Enter phone → Tap "Send code" → Screen: OTP → Screenshot: step_03.png
     ...
   UI Elements per screen:
     ColdStart: [Button("New explorer"), Button("Sign in"), MapView]
     PhoneInput: [TextField(phone), Button("Send code")]
     ...
   ```

---

### Phase 3: iOS State Assessment

**Goal**: Determine what state the iOS feature is in and what needs to change.

**Steps**:

1. **Map Android files to iOS counterparts** using structural parity rules:
   - `LoginFlowTest.kt` → `LoginFlowTest.swift`
   - `LoginViewModel.kt` → `LoginViewModel.swift`
   - Same folder hierarchy, iOS naming conventions

2. **Check if iOS test exists**:
   - If yes → run it → capture results → identify failures
   - If no → create it (translate from Android using the Feature Behavior Specification)

3. **Run a preliminary iOS build** to identify compilation issues:
   ```bash
   cd ~/Documents/WaonderApps/waonder-ios
   xcodebuild build-for-testing \
     -scheme WaonderUITests \
     -destination 'platform=iOS Simulator,name=iPhone 16'
   ```

4. **Classify the iOS state** into one of:
   - **Green**: Test exists and passes → go to Phase 5 (verification only)
   - **Yellow**: Test exists but fails → go to Phase 4 (fix feature code)
   - **Orange**: No test exists, feature code exists → create test, go to Phase 4
   - **Red**: No test, no feature code → full implementation needed, go to Phase 4

---

### Phase 4: iOS Fix & Iterate

**Goal**: Autonomously fix the iOS feature until the test passes.

This is the core autonomous loop. Claude has:
- The Android Feature Behavior Specification (what it should look like)
- The Android screenshots (visual reference)
- The Android feature source code (reference implementation)
- The iOS test failure logs (what's currently wrong)
- The iOS source code (what to fix)
- The existing android-to-ios translation skills (how to fix it)

**Critical difference from Phase 1**: Here Claude fixes **both test code AND feature code**. The iOS feature may be broken, incomplete, or missing — unlike Android where only the test needed fixing.

**Iteration Loop** (max 10 iterations):

1. **Analyze the failure**:
   - Build error → fix compilation (missing imports, type mismatches)
   - Test assertion failure → fix feature code (wrong text, missing element)
   - Test timeout → fix async behavior (missing state updates, wrong wait)
   - Screenshot mismatch → fix layout/styling (wrong colors, spacing, alignment)

2. **Determine fix scope**:
   - Is it a test issue? (wrong accessibility label, wrong wait time)
   - Is it a feature code issue? (ViewModel logic, View layout, navigation)
   - Is it a structural issue? (missing file, wrong dependency)

3. **Apply the fix** using the appropriate android-to-ios skill:
   - UI fixes → `generic-android-to-ios-compose` / `composable` / `material-design`
   - ViewModel fixes → `generic-android-to-ios-viewmodel` / `stateflow`
   - Navigation fixes → `generic-android-to-ios-navigation`
   - Data layer fixes → `generic-android-to-ios-repository` / `retrofit`
   - Concurrency fixes → `generic-android-to-ios-coroutines` / `flows`

4. **Rebuild and re-run**:
   ```bash
   xcodebuild test \
     -scheme WaonderUITests \
     -destination 'platform=iOS Simulator,name=iPhone 16' \
     -only-testing:WaonderUITests/<TestClass>/<testMethod>
   ```

5. **Capture iOS screenshots** at the same checkpoints as Android.

6. **Compare** — If test passes, go to Phase 5. If not, loop back to step 1.

**Escalation**: After max iterations, stop and report to Gabriel:
- What works, what doesn't
- The remaining failures with context
- Suggested manual next steps

---

### Phase 5: Parity Verification

**Goal**: Confirm that the iOS feature matches Android in function, visuals, and structure.

1. **Functional parity**: iOS test passes with the same steps and assertions
2. **Visual parity**: Side-by-side screenshot comparison (Claude reads both images)
3. **Structural parity**: iOS files mirror Android folder structure
4. **Report generation**: Summary of what was done, what matches, any remaining gaps

---

## Screenshot Strategy

Screenshots are the key enabler for Claude to work autonomously. Both platforms must capture screenshots at the same logical checkpoints.

### Android Screenshot Capture (implemented)

**Utility**: `waonder/src/androidTest/java/com/app/waonder/screenshot/ScreenshotCapture.kt`

Uses `UiDevice.takeScreenshot()` — no new dependency needed (`uiautomator` already in `build.gradle.kts`).

```kotlin
// In test class
private lateinit var screenshots: ScreenshotCapture

@Before
fun setup() {
    screenshots = ScreenshotCapture("LoginFlowTest")
    screenshots.cleanPrevious()
}

@Test
fun myTest() {
    // ... wait for screen ...
    screenshots.capture("01_cold_start")
    // ... interact ...
    screenshots.capture("02_phone_input")
}
```

Screenshots saved to: `/sdcard/Pictures/waonder-test-screenshots/<TestName>/`

Pull after test:
```bash
adb pull /sdcard/Pictures/waonder-test-screenshots/<TestName>/ \
  ~/Documents/WaonderApps/sync-artifacts/<TestName>/android/
```

### iOS Screenshot Capture

XCUITest has built-in screenshot support via `XCTAttachment`:

```swift
private func captureScreenshot(name: String) {
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
}
```

Screenshots are saved in the `.xcresult` bundle:
```bash
RESULT=$(find ~/Library/Developer/Xcode/DerivedData -name "*.xcresult" -maxdepth 4 | sort -t/ -k8 | tail -1)
xcrun xcresulttool get test-results attachments \
  --path "$RESULT" \
  --output-path ~/Documents/WaonderApps/sync-artifacts/<TestName>/ios/
```

### Comparison

Claude reads both Android and iOS screenshots directly (multimodal). No pixel-diff tooling needed — Claude can assess:
- Layout matches (element positions, sizes)
- Text matches (labels, buttons, content)
- Color/style matches (theme, fonts, spacing)
- State matches (loading indicators, enabled/disabled states)

The `mobile-screenshot-artifact-expert` agent handles all screenshot operations: pull, organize, describe, and compare.

---

## Feature Behavior Specification Format

The intermediate artifact that bridges Android → iOS:

```yaml
feature: Login Flow
source:
  test_class: com.waonder.app.auth.LoginFlowTest
  test_file: waonder/src/androidTest/.../auth/LoginFlowTest.kt
  feature_files:
    - presentation/auth/LoginViewModel.kt
    - presentation/auth/LoginScreen.kt
    - domain/auth/LoginUseCase.kt
    - data/auth/AuthRepositoryImpl.kt

screens:
  - name: ColdStart
    elements:
      - type: button, label: "New explorer", required: true
      - type: button, label: "Sign in", required: true
      - type: view, label: "MapView", required: true
    screenshot: android/step_01_cold_start.png

  - name: PhoneInput
    elements:
      - type: text_field, label: "Phone number", required: true
      - type: button, label: "Send code", required: true
    screenshot: android/step_02_phone_input.png

flow:
  - step: 1
    screen: ColdStart
    action: wait
    assert: "Sign in button visible and enabled"
  - step: 2
    screen: ColdStart
    action: tap "Sign in"
    navigate_to: PhoneInput
  - step: 3
    screen: PhoneInput
    action: type "7865550001" in phone field
  - step: 4
    screen: PhoneInput
    action: tap "Send code"
    navigate_to: OTP
    # ... etc

test_setup:
  permissions: none
  test_data:
    phone: "7865550001"
    otp: "123456"
  launch_arguments: ["-UITestMode"]

ios_mapping:
  test_class: LoginFlowTest (XCTestCase)
  test_file: WaonderUITests/auth/LoginFlowTest.swift
  feature_files:
    - Presentation/Auth/LoginViewModel.swift
    - Presentation/Auth/LoginScreen.swift
    - Domain/Auth/LoginUseCase.swift
    - Data/Auth/AuthRepositoryImpl.swift
```

---

## Skills & Agents Architecture

The previous design had 6 separate agents for each micro-step. The new design collapses this into **1 orchestrator skill + 3 focused sub-agents**. The skill is the brain; the agents are the hands. Sub-agents are spawned in parallel where possible and contribute back to the orchestrator.

### Orchestrator Skill: `generic-mobile-automation-test-sync`

**Type**: user-invocable
**Trigger**: `/sync-feature-test <scenario description>`
**Location**: `plugins/waonder-mobile-claude-plugin/skills/generic-mobile-automation-test-sync/SKILL.md`
**Purpose**: Main entry point and coordinator for the entire workflow.

**The skill itself coordinates the phases** — it is NOT a passive document. It contains the full prompt templates for each sub-agent and the logic for deciding what to do next based on sub-agent results.

**Input examples**:
```bash
/sync-feature-test "test the login flow — sign in with phone and OTP"
/sync-feature-test "test onboarding with location permission granted"
/sync-feature-test "test logout then login again"
/sync-feature-test "test cold start screen loads correctly"
```

**Phase-to-agent mapping**:
| Phase | Agent spawned | Runs in parallel? |
|-------|--------------|-------------------|
| 1 — Android test creation | `mobile-android-test-creator-expert` | No (sequential — must finish before Phase 2) |
| 2 — Screenshot capture + spec | `mobile-screenshot-artifact-expert` (2 instances) | Yes (pull screenshots + map file structure in parallel) |
| 3 — iOS test creation + feature fix | `mobile-ios-test-sync-expert` | No (sequential — needs Phase 2 output) |
| 4 — Visual parity | `mobile-screenshot-artifact-expert` (comparison mode) | No (needs Phase 3 screenshots) |
| 5 — Report | Orchestrator itself | — |

---

### Sub-Agent 1: `mobile-android-test-creator-expert`

**Location**: `plugins/waonder-mobile-claude-plugin/agents/mobile-android-test-creator-expert.md`
**Spawned in**: Phase 1
**Purpose**: Creates the Android automation test and iterates until it passes.

**What it does**:
1. Reads 2+ existing tests as reference (mandatory before writing anything)
2. Explores the Android feature code to understand screens, ViewModels, navigation
3. Creates the test using the project's exact infrastructure:
   - `@HiltAndroidTest`, `HiltAndroidRule` (order=0), `createAndroidComposeRule` (order=1)
   - Compose Testing for app UI, UiAutomator for system dialogs
   - `ScreenshotCapture` utility for screenshots at every step
4. Runs the test on the Android emulator via Gradle
5. Reads failures, fixes **test code only**, re-runs (max 10 iterations)

**Key constraint**: NEVER modifies Android feature code — only test code.

**Key infrastructure**: Uses `ScreenshotCapture` at `waonder/src/androidTest/java/com/app/waonder/screenshot/ScreenshotCapture.kt` which saves screenshots to `/sdcard/Pictures/waonder-test-screenshots/<TestName>/` using `UiDevice.takeScreenshot()`.

---

### Sub-Agent 2: `mobile-screenshot-artifact-expert`

**Location**: `plugins/waonder-mobile-claude-plugin/agents/mobile-screenshot-artifact-expert.md`
**Spawned in**: Phase 2 (capture + spec), Phase 4 (visual comparison)
**Purpose**: Handles all screenshot/artifact operations — pull, organize, describe, compare.

**Three modes of operation**:

1. **Pull & Organize** — extracts screenshots from Android emulator or iOS Simulator, saves to artifact directory
2. **Produce Feature Behavior Specification** — reads test code + screenshots, produces the structured spec that bridges Android → iOS
3. **Visual Parity Comparison** — reads Android + iOS screenshots side-by-side (multimodal), classifies differences as acceptable (platform-native) or requiring fix

**This agent is read-only for code** — it never edits test or feature files.

---

### Sub-Agent 3: `mobile-ios-test-sync-expert`

**Location**: `plugins/waonder-mobile-claude-plugin/agents/mobile-ios-test-sync-expert.md`
**Spawned in**: Phase 3
**Purpose**: The iOS workhorse — creates the iOS test, fixes iOS feature code, iterates until green.

**What it does**:
1. Reads the Feature Behavior Specification and Android screenshots as reference
2. Creates/fixes the iOS XCUITest (translating Android patterns to XCUITest)
3. Builds the iOS project via `xcodebuild`
4. Runs the test, reads failures
5. Fixes **both test code AND feature code** on iOS (unlike Android where only test is touched)
6. Iterates (max 10 times) until the test passes
7. Captures iOS screenshots at matching steps

**Key difference from the Android agent**: This agent fixes feature code too. The iOS feature may be broken, incomplete, or missing — the Android reference tells it what the correct behavior should be.

---

### Summary: Skill + 3 Sub-Agents (replaces previous 6 agents)

| Type | Name | Purpose |
|------|------|---------|
| **Skill** | `generic-mobile-automation-test-sync` | Orchestrator — coordinates phases, spawns sub-agents |
| **Agent** | `mobile-android-test-creator-expert` | Phase 1 — create Android test, iterate until green |
| **Agent** | `mobile-screenshot-artifact-expert` | Phase 2+4 — screenshots, specs, visual comparison |
| **Agent** | `mobile-ios-test-sync-expert` | Phase 3 — create iOS test + fix iOS feature code |

### Existing Skills & Agents Leveraged

The sub-agents (especially `mobile-ios-test-sync-expert`) internally reference patterns from the existing 63 android-to-ios skills and 10 expert agents when fixing iOS code. The key ones:

| Type | Name | Used By |
|------|------|---------|
| Skill | `generic-android-to-ios-ui-testing` | iOS test sync — Espresso → XCUITest patterns |
| Skill | `generic-android-to-ios-viewmodel` | iOS test sync — ViewModel fixes |
| Skill | `generic-android-to-ios-compose` | iOS test sync — UI fixes |
| Skill | `generic-android-to-ios-navigation` | iOS test sync — navigation fixes |
| Skill | `generic-android-to-ios-stateflow` | iOS test sync — state management fixes |
| Agent | `generic-android-to-ios-testing-expert` | iOS test sync — testing pattern guidance |
| Agent | `generic-android-to-ios-structure-expert` | Screenshot artifact — structural parity |

### Android Screenshot Infrastructure

**New file added to the Android repo**:
- `waonder/src/androidTest/java/com/app/waonder/screenshot/ScreenshotCapture.kt`

Uses `UiDevice.takeScreenshot()` (no new dependency — `uiautomator` already in `build.gradle.kts`). Saves PNGs to `/sdcard/Pictures/waonder-test-screenshots/<TestName>/`. Tests integrate with 3 additions:
1. Declare `private lateinit var screenshots: ScreenshotCapture`
2. Initialize in `@Before`: `screenshots = ScreenshotCapture("TestClassName")`
3. Call `screenshots.capture("step_name")` after each key step

Pull screenshots after test execution:
```bash
adb pull /sdcard/Pictures/waonder-test-screenshots/<TestName>/ ~/Documents/WaonderApps/sync-artifacts/<TestName>/android/
```

---

## Iteration Limits & Escalation

| Metric | Limit | Action on Exceed |
|--------|-------|-----------------|
| Max iterations for Android test creation (Phase 1) | 10 | Stop, report to user |
| Max iterations for iOS fix (Phase 4) | 10 | Stop, report to user |
| Max build retries per iteration | 3 | Move to next failure type |
| Max time per sync | 45 minutes | Stop, report progress |
| Max files changed per iteration | 20 | Pause, ask user to review |

**Escalation report format**:
```
## Sync Report: Login Flow

### Android Test: LoginFlowTest.kt
- Status: GREEN (created in 3 iterations)
- Steps: 9
- Screenshots: 4

### iOS Test: LoginFlowTest.swift
- Status: PARTIAL (7/9 steps passing)

### What works:
- Steps 1-5: Cold start → Phone input → OTP screen ✓
- Steps 6-7: OTP entry → Navigation ✓

### What's broken:
- Step 8: Home screen verification — Settings button not found
  - Root cause: Settings icon uses wrong accessibility label
  - Attempted fixes: 3 (renamed label, changed modifier, checked hierarchy)
  - Suggestion: Check SettingsButton.swift accessibilityLabel

### Iterations used: Android 3/10, iOS 10/10
### Files created: 2 (Android test, iOS test)
### Files modified: 4 (iOS feature code)
### Screenshots: ./sync-artifacts/LoginFlowTest/
```

---

## Artifact Storage

All sync artifacts are stored in a predictable location:

```
~/Documents/WaonderApps/sync-artifacts/
└── <TestClassName>/
    └── <timestamp>/
        ├── spec.yaml                    # Feature Behavior Specification
        ├── android/
        │   ├── step_01_cold_start.png
        │   ├── step_02_phone_input.png
        │   └── test_log.txt
        ├── ios/
        │   ├── step_01_cold_start.png
        │   ├── step_02_phone_input.png
        │   └── test_log.txt
        ├── comparison/
        │   └── visual_parity_report.md
        └── sync_report.md              # Final report
```

---

## Structural Parity Rules

The iOS test and feature code must mirror the Android structure:

| Android | iOS |
|---------|-----|
| `waonder/src/androidTest/.../auth/LoginFlowTest.kt` | `WaonderUITests/Auth/LoginFlowTest.swift` |
| `feature/auth/presentation/LoginViewModel.kt` | `Feature/Auth/Presentation/LoginViewModel.swift` |
| `feature/auth/presentation/LoginScreen.kt` | `Feature/Auth/Presentation/LoginScreen.swift` |
| `feature/auth/domain/LoginUseCase.kt` | `Feature/Auth/Domain/LoginUseCase.swift` |
| `feature/auth/data/AuthRepositoryImpl.kt` | `Feature/Auth/Data/AuthRepositoryImpl.swift` |

**Test structure mirrors feature structure.** If Android has `auth/LoginFlowTest.kt`, iOS has `Auth/LoginFlowTest.swift` — same nesting, same grouping.

---

## Prerequisites

Before this workflow can operate:

1. **Android emulator running** — with the Waonder app installed and test-ready
2. **iOS Simulator available** — with the Waonder iOS app buildable
3. **Both repos cloned locally**:
   - Android: `~/Documents/WaonderApps/waonder-android`
   - iOS: `~/Documents/WaonderApps/waonder-ios`
4. **Test credentials configured** — backend accepts phone `7865550001` with OTP `123456`
5. **`-UITestMode` launch argument** — disables Firebase verification on both platforms

---

## Constraints

- **Never modify Android feature code** — Android feature code is the source of truth, read-only. Only Android test code can be created/modified (Phase 1).
- **iOS must follow iOS standards** — not a line-for-line port; idiomatic Swift/SwiftUI
- **Structural parity is mandatory** — same modules, folders, and file names (with platform conventions)
- **Tests must be independent** — no inter-test dependencies, each sync is self-contained
- **Human approval before git push** — Claude can commit locally but must ask before pushing
- **Screenshots are mandatory** — both Android and iOS tests must capture screenshots at each step; no sync is complete without visual comparison

---

## Example: Full Walkthrough

**Input**: `/sync-feature-test "test the login flow — sign in with phone and OTP, verify home screen"`

**Phase 1** — Claude explores `waonder-android`: finds `LoginViewModel`, `PhoneInputScreen`, `OtpScreen`, `HomeScreen`. Searches `androidTest/` — no existing test for login flow. Creates `LoginFlowTest.kt` with 9 steps, screenshot capture at each screen. Runs it — fails on step 4 (wrong element ID for Send Code button). Fixes the test to use the correct `testTag`. Re-runs — passes. Android test locked.

**Phase 2** — Claude runs `LoginFlowTest.kt` again with full capture. Pulls 4 screenshots from the emulator. Reads the feature source files. Produces a Feature Behavior Specification with 9 steps across 4 screens.

**Phase 3** — Claude checks iOS. Finds `LoginScreen.swift` exists but no `LoginFlowTest.swift`. Creates the XCUITest from the spec. Classifies iOS state as **Orange** (feature code exists, no test).

**Phase 4, Iteration 1** — iOS test build fails: `PhoneInputScreen.swift` missing `.accessibilityIdentifier("phoneInput")`. Claude adds it. Rebuilds.

**Phase 4, Iteration 2** — Test runs, fails at step 7: keyboard covering OTP field. Claude adds scroll-to-dismiss in the test. Re-runs.

**Phase 4, Iteration 3** — All 9 steps pass. iOS screenshots captured.

**Phase 5** — Claude compares all 4 screenshot pairs (reads images directly). Android and iOS match in layout and content. Minor difference: iOS uses SF Pro vs Android Roboto — classified as acceptable. Report generated.

**Output**: Both `LoginFlowTest.kt` (Android) and `LoginFlowTest.swift` (iOS) pass. 1 Android file created, 1 iOS file created, 1 iOS file modified. Sync complete.

---

## Tasks

### Phase 0: Foundation
- [x] Create `ScreenshotCapture.kt` utility for Android tests (uses `UiDevice.takeScreenshot()`, no new dependency)
- [x] Create `ScreenshotExample.kt` reference showing integration pattern
- [ ] Define iOS screenshot capture helper (reusable XCTestCase extension)
- [ ] Define the Feature Behavior Specification markdown schema
- [ ] Create artifact storage directory: `~/Documents/WaonderApps/sync-artifacts/`

### Phase 1: Build the Skill + Agents
- [x] Create `generic-mobile-automation-test-sync` orchestrator skill
- [x] Create `mobile-android-test-creator-expert` agent
- [x] Create `mobile-screenshot-artifact-expert` agent
- [x] Create `mobile-ios-test-sync-expert` agent

### Phase 2: Validate End-to-End
- [ ] Test with "cold start screen loads" — simplest, smoke test the workflow
- [ ] Test with "login flow" — first real feature sync
- [ ] Test with "onboarding with location permission" — system dialogs
- [ ] Test with "app restart scenarios" — most complex

### Phase 3: Polish
- [ ] Refine iteration limits based on real-world experience
- [ ] Improve failure classification accuracy
- [ ] Add support for running multiple scenarios in sequence
- [ ] Add `--dry-run` mode (assess only, don't fix)
- [ ] Add `--android-only` mode (just create/validate Android test)
- [ ] Add `--ios-only` mode (skip Phase 1-2, assume Android test exists)

---

## Relationship to Other Specs

| Spec | Relationship |
|------|-------------|
| **002 — Full Migration** | Must complete first. Provides the iOS codebase that this workflow operates on. |
| **003 — Automated Pipeline** | Complementary. Spec 003 translates commits (code-level). This spec verifies features (behavior-level). They can run together: 003 translates the code, 005 verifies it works. |
| **004 — iOS Automation Tests** | Superseded in scope. Spec 004 defines a manual test catalog. This spec automates the entire process — creating Android tests, translating them, and validating iOS. The test catalog from 004 can serve as input scenarios for this workflow. |

---

## Success Criteria

1. Running `/sync-feature-test "<scenario>"` produces passing tests on both platforms
2. Android test is created automatically when it doesn't exist
3. iOS test exercises the same screens, actions, and assertions as Android
4. Screenshots show visual parity (accounting for platform-appropriate differences)
5. iOS code follows structural parity rules (same modules, folders, file names)
6. The workflow completes within 45 minutes for a typical feature (4-10 screens)
7. At least 70% of sync attempts complete without manual intervention
8. Escalation reports are actionable — when Claude can't fix it, the report tells Gabriel exactly what to do

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Android test can't be created (feature too complex) | Workflow can't start | Escalate with partial spec; user can provide hints |
| Android test is flaky | Unreliable reference | Retry Android test 2x; only lock as reference if consistently green |
| iOS feature is too broken to test | Infinite iteration loop | Max iteration limit + escalation report |
| Emulator/Simulator not running | Can't execute tests | Pre-check in Phase 0; clear error message |
| Test flakiness (timing-dependent) | False failures waste iterations | Retry failed tests once before counting as real failure |
| Claude misinterprets screenshot | Wrong fix applied | Compare functional (assertion) AND visual (screenshot) — both must pass |
| Complex native code (C++, Metal) | Can't be auto-fixed | Flag for manual review, don't attempt |
| Scenario description is too vague | Wrong test created | Ask user for clarification before starting Phase 1 |

---

## Notes

- This workflow is **feature-scoped**, not commit-scoped. It doesn't care which commit introduced the feature — it only cares whether the iOS version matches Android right now.
- The Feature Behavior Specification is ephemeral — it's generated fresh each run, not stored permanently. Artifacts (screenshots, reports) are stored for reference.
- This is the workflow that makes spec 003 (automated pipeline) reliable: after translating code, run this to verify it actually works.
- Start simple: "cold start screen loads" is 3 steps with no system dialogs. Get the workflow working end-to-end on that before tackling complex scenarios.
- The test catalog from spec 004 provides ready-made scenarios. Each entry in that catalog (T1-T9) can be passed as input to this workflow.
- Phase 1 (Android test creation) is valuable even without the iOS sync — it automates Android test coverage growth.
