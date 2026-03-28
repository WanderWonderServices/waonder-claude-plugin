# iOS Automation Tests — Android to iOS Migration

**Milestone**: 004_ios-automation-tests
**Created**: 2026-03-28
**Status**: In Progress

## Overview

Migrate all active Android automation tests (Compose UI Testing + Espresso + UI Automator) to iOS XCUITest equivalents. Tests are ordered from simplest to most complex based on the number of screens navigated and system-level interactions required.

## Goals

- Achieve 1:1 parity with every active Android UI automation test
- Establish XCUITest infrastructure (test utilities, helpers, wait patterns)
- Validate each test independently on iOS Simulator before moving to the next

## Test Credentials

| Field | Value |
|-------|-------|
| Phone | `7865550001` |
| OTP   | `123456` |

---

## Test Catalog — Ordered Simple to Complex

### Tier 1 — Smoke (app launch)

#### T1. ColdStartScreenTest

| Property | Value |
|----------|-------|
| Screens | 1 |
| Steps | 3 |
| System dialogs | None |
| Complexity | Trivial |

**Flow:**
1. Launch the app
2. Wait for the Cold Start screen to fully load (map ready, buttons visible)
3. Assert: "New explorer" and "Sign in" buttons are visible and enabled

**iOS mapping:**
- `XCUIApplication().launch()`
- `app.buttons["New explorer"].waitForExistence(timeout: 30)` — map must load before buttons appear
- `app.buttons["Sign in"].waitForExistence(timeout: 30)`
- Both buttons must be hittable (enabled + visible)

---

### Tier 2 — Simple (1-4 screens)

#### T2. LoginFlowTest

| Property | Value |
|----------|-------|
| Android file | `waonder/src/androidTest/.../auth/LoginFlowTest.kt` |
| Screens | 4 |
| Steps | 9 |
| System dialogs | None |
| Complexity | Low |

**Flow:**
1. Wait for Cold Start screen — "Sign in" button enabled (map loaded)
2. Tap "Sign in"
3. Wait for Phone Input screen (30s)
4. Clear pre-filled phone, enter `7865550001`
5. Tap "Send code"
6. Wait for OTP screen — "Verify your number" (30s)
7. Enter `123456`
8. Wait for onboarding UI to disappear (30s)
9. Assert: home screen is visible (Settings button present)

**iOS mapping:**
- `app.buttons["Sign in"]` on Cold Start
- `app.textFields.firstMatch` for phone input
- `app.staticTexts["Verify your number"]` for OTP screen detection
- `app.buttons["Settings"]` for home screen verification
- Keyboard must be dismissed before tapping "Send code" (`app.swipeDown()`)

---

### Tier 3 — Medium (6+ screens, single flow)

#### T3. LogoutAndLoginBackTest

| Property | Value |
|----------|-------|
| Android file | `waonder/src/androidTest/.../session/LogoutAndLoginBackTest.kt` |
| Screens | 6+ (11 total with re-login) |
| Steps | 16 |
| System dialogs | None |
| Complexity | Medium |

**Flow:**
1. **Phase 1 — Sign in** (reuse LoginFlowTest helper)
   - Tap "Sign in" → phone → OTP → home
2. **Phase 2 — Navigate to logout**
   - Wait for Settings icon (accessibilityLabel "Settings") on home (30s)
   - Tap Settings icon
   - Wait for "Account" text (15s), tap it
   - Wait for "Logout" button (15s), tap it
3. **Phase 3 — Confirm logout**
   - Wait for logout confirmation dialog (10s)
   - Tap the confirm "Logout" button
4. **Phase 4 — Verify logout**
   - Wait for Cold Start to reappear: "Sign in" button (30s)
5. **Phase 5 — Login again** (reuse helper)
6. **Phase 6 — Verify home**
   - Settings icon visible again (30s)

**iOS mapping:**
- Navigation via `app.buttons["Settings"]`
- `app.staticTexts["Account"].tap()`
- Dialog disambiguation: use `app.alerts.buttons["Logout"]` for confirmation
- Reusable `loginAsReturningUser()` helper method

---

#### T4. OnboardingSkipLocationTest

| Property | Value |
|----------|-------|
| Android file | `waonder/src/androidTest/.../onboarding/OnboardingSkipLocationTest.kt` |
| Screens | 10 |
| Steps | 11 |
| System dialogs | None |
| Complexity | Medium |

**Flow:**
1. Wait for "New explorer" enabled (60s, map loading)
2. Tap "New explorer"
3. Navigate 3 Welcome Moments — each has a MoveButton, wait for enabled (45s), tap, brief pause between
4. Wait for Location Priming — "Clear the fog" visible (45s)
5. Tap "Not now" to skip
6. Wait for User Location Clearing — "Reveal" button (45s), tap
7. Wait for Teaser Place Clearing — "Continue your journey" (45s), tap
8. Wait for Phone Input (30s), enter `7865550001`, tap "Send code"
9. Wait for OTP (30s), enter `123456`
10. Wait for onboarding to disappear (30s)

**iOS mapping:**
- `app.buttons["New explorer"]`
- Welcome moments: `app.buttons["Explore"]`, `app.buttons["Move forward"]`, `app.buttons["Continue"]`
- `app.buttons["Not now"].tap()`
- `app.buttons["Reveal"].tap()`
- `app.buttons["Continue your journey"].tap()`
- Phone/OTP entry via text fields

---

### Tier 4 — Complex (10+ screens, system dialogs)

#### T5. OnboardingGrantLocationTest

| Property | Value |
|----------|-------|
| Android file | `waonder/src/androidTest/.../onboarding/OnboardingGrantLocationTest.kt` |
| Screens | 11 |
| Steps | 13 |
| System dialogs | Location permission |
| Complexity | High |

**Flow:**
1-4. Same as OnboardingSkipLocationTest (cold start → 3 welcome moments)
5. Wait for Location Priming — "Clear the fog" (30s)
6. Tap "Clear the fog"
7. **System dialog**: iOS location permission alert appears
   - Tap "Allow While Using App" (or equivalent)
8. Wait for User Location Clearing (45s), tap "Reveal"
9. Wait for Teaser Place Clearing (45s), tap "Continue your journey"
10-13. Phone + OTP + verify home

**iOS mapping:**
- System alert: `addUIInterruptionMonitor(withDescription:)` or `app.alerts.buttons["Allow While Using App"].tap()`
- Must handle `springboard` for system dialogs

---

#### T6. OnboardingDenyLocationTest

| Property | Value |
|----------|-------|
| Android file | `waonder/src/androidTest/.../onboarding/OnboardingDenyLocationTest.kt` |
| Screens | 11 |
| Steps | 13 |
| System dialogs | Location permission (denied) |
| Complexity | High |

**Flow:**
1-6. Same as T5 up to system dialog
7. **System dialog**: Tap "Don't Allow"
8-13. Continue through clearing → auth → home

**iOS mapping:**
- `app.alerts.buttons["Don't Allow"].tap()`

---

#### T7. OnboardingLocationServicesDisabledTest

| Property | Value |
|----------|-------|
| Android file | `waonder/src/androidTest/.../onboarding/OnboardingLocationServicesDisabledTest.kt` |
| Screens | 10 |
| Steps | 12 |
| System dialogs | None (services off at OS level) |
| Complexity | High |

**Flow:**
1. **Setup**: Disable location services (iOS: via Simulator settings or launch arguments)
2-5. Cold start → 3 welcome moments
6. Location Priming shows settings redirect:
   - Verify "Open settings" button visible
   - Verify "Not now" button visible
   - Verify "Location is off" text visible
7. Tap "Not now"
8-12. Clearing → auth → home
13. **Teardown**: Re-enable location services

**iOS mapping:**
- Simulator location services: disabled via launch arguments or Xcode scheme settings
- Note: iOS Simulator has limited support for disabling location services programmatically; may need alternative approach

---

#### T8. OnboardingPermissionPermanentlyDeniedTest

| Property | Value |
|----------|-------|
| Android file | `waonder/src/androidTest/.../onboarding/OnboardingPermissionPermanentlyDeniedTest.kt` |
| Screens | 13 |
| Steps | 15 |
| System dialogs | Permission dialog (first denial) |
| Complexity | High |

**Flow:**
1. **Setup**: Revoke location permissions (iOS: reset authorization via `XCUIApplication().resetAuthorizationStatus(for:)`)
2-5. Cold start → 3 welcome moments
6. Tap "Clear the fog"
7. Handle system dialog if present (deny)
8. Wait for Settings Redirect screen — "Not now" visible (30s)
9. Tap "Not now"
10-15. Clearing → auth → home
16. **Teardown**: Reset permissions

**iOS mapping:**
- `app.resetAuthorizationStatus(for: .location)` in `setUp()`
- System alert denial handling
- Settings redirect detection

---

### Tier 5 — Very Complex (multi-scenario, restarts)

#### T9. OnboardingPermissionRestartScenariosTest

| Property | Value |
|----------|-------|
| Android file | `waonder/src/androidTest/.../onboarding/OnboardingPermissionRestartScenariosTest.kt` |
| Screens | Varies per scenario |
| Sub-scenarios | 5 |
| System dialogs | Yes (multiple) |
| Complexity | Very High |

**Sub-scenarios:**

**T9.1** `skipLocation_restart_skipAgain_completesOnboarding`
- Skip location → terminate app → relaunch → skip again → complete auth
- Verifies permission screen reappears after restart

**T9.2** `denyPermission_restart_grantPermission_completesOnboarding`
- Deny in dialog → terminate → relaunch → grant in dialog → complete auth
- Verifies user can grant on second attempt

**T9.3** `grantPermission_restart_autoSkipsPriming_completesOnboarding`
- Pre-grant permissions → restart → priming auto-skips → complete auth
- Verifies app remembers granted permission

**T9.4** `servicesDisabled_restart_servicesEnabled_completesOnboarding`
- Disable services → navigate → verify redirect → enable services → restart → verify normal priming
- Verifies app responds to service state changes

**T9.5** `denyPermission_restart_denyAgain_completesViaSkip`
- Deny → restart → deny again → complete via "Not now"
- Verifies recovery from repeated denials

**iOS mapping:**
- App restart: `app.terminate()` + `app.launch()`
- Permission pre-granting: launch arguments or `resetAuthorizationStatus`
- Note: iOS has stricter permission model — some Android behaviors (like re-prompting after denial) differ on iOS

---

## Excluded Tests

| Test | Reason |
|------|--------|
| FogScenePerformanceTest (5 tests) | Native graphics layer, not UI automation |
| FogSceneThreadingTest (7 tests) | Native threading, not UI automation |
| FogSceneViewLifecycleTest (9 tests) | Surface lifecycle, not UI automation |
| ExampleInstrumentedTest (2 files) | Trivial stubs |
| HomeScreenCoordinatorConfigChangeTest | Disabled (`@Ignore`), API outdated |

---

## Requirements

### Functional Requirements
- [x] T1: ColdStartScreenTest passes on iOS Simulator
- [ ] T2: LoginFlowTest equivalent passes on iOS Simulator
- [ ] T3: LogoutAndLoginBackTest equivalent passes
- [ ] T4: OnboardingSkipLocationTest equivalent passes
- [ ] T5: OnboardingGrantLocationTest equivalent passes
- [ ] T6: OnboardingDenyLocationTest equivalent passes
- [ ] T7: OnboardingLocationServicesDisabledTest equivalent passes
- [ ] T8: OnboardingPermissionPermanentlyDeniedTest equivalent passes
- [ ] T9: OnboardingPermissionRestartScenariosTest (5 sub-scenarios) pass

### Non-Functional Requirements
- [ ] Tests run independently (no inter-test dependencies)
- [ ] Tests complete within reasonable timeouts (similar to Android counterparts)
- [ ] Reusable helpers extracted (login, onboarding navigation, wait utilities)

## Technical Approach

- **Framework**: XCUITest (XCTestCase subclass)
- **Wait strategy**: `waitForExistence(timeout:)` + custom `waitUntil` helpers
- **System dialogs**: `addUIInterruptionMonitor` or direct alert button access
- **App restart**: `XCUIApplication().terminate()` + `.launch()`
- **Permission reset**: `XCUIApplication().resetAuthorizationStatus(for:)`
- **Test structure**: One test class per Android test file, mirroring folder structure
- **Test mode**: `-UITestMode` launch argument disables Firebase app verification for Simulator testing

## Tasks

- [x] Set up XCUITest target in iOS project
- [x] Implement T1: ColdStartScreenTest
- [ ] Implement T2: LoginFlowTest
- [ ] Implement T3: LogoutAndLoginBackTest
- [ ] Implement T4: OnboardingSkipLocationTest
- [ ] Implement T5: OnboardingGrantLocationTest
- [ ] Implement T6: OnboardingDenyLocationTest
- [ ] Implement T7: OnboardingLocationServicesDisabledTest
- [ ] Implement T8: OnboardingPermissionPermanentlyDeniedTest
- [ ] Implement T9: OnboardingPermissionRestartScenariosTest (5 sub-tests)
- [ ] Extract shared test helpers into reusable utilities

## Dependencies

- [002_android-to-ios-full-migration](../002_android-to-ios-full-migration/) — iOS app must have onboarding, auth, settings, and location flows implemented
- Backend test environment must accept test credentials (phone: `7865550001`, OTP: `123456`)

## Success Criteria

- All 9 test classes (with 14 total test methods) pass on iOS Simulator
- No flaky tests — all waits use proper timeout mechanisms
- Test helpers are reusable across test classes

## Notes

- Android uses `waitUntil(timeoutMillis) { condition }` — iOS equivalent is `waitForExistence(timeout:)` or custom polling
- Android uses UiAutomator for system dialogs — iOS uses `addUIInterruptionMonitor` or direct `springboard` access
- Android tests manipulate permissions via `pm grant/revoke` shell commands — iOS uses `resetAuthorizationStatus(for:)` and Simulator settings
- iOS has a stricter permission model: once denied, the system never re-prompts (unlike Android). Test T9.2 may need adaptation.
- Welcome Moments have typing animations with delays — iOS tests must account for animation completion
- Firebase Phone Auth on Simulator requires `-UITestMode` launch arg + test mode bypass in `FirebaseAuthRepositoryImpl` due to Firebase SDK checking notification forwarding before the `isAppVerificationDisabledForTesting` flag
- The `OnboardingViewModel.restoreProgressIfNeeded()` has a guard to prevent zombie ViewModel instances from resetting navigation mid-flow
