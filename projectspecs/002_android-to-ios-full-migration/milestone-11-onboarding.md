# Milestone 11: Onboarding Feature

**Status:** Not Started
**Dependencies:** Milestones 08, 09, 10
**Android Modules:** `:feature:onboarding`, `:feature:permissions`
**iOS Targets:** `FeatureOnboarding`, `FeaturePermissions`

---

## Objective

Migrate the complete onboarding flow — welcome sequence, phone auth screens, location priming, and teaser place experience. This is one of the most UI-intensive milestones with complex animations.

---

## Deliverables

### 1. FeaturePermissions (`FeaturePermissions/`)
- [ ] `LocationPermissionCard.swift` — Permission request card
- [ ] `LocationServicesCard.swift` — Location services enablement
- [ ] `PermissionDialog.swift` — System permission dialog coordination
- [ ] `PermissionViewModel.swift` (if exists on Android)
- [ ] String resources (English + Spanish)

### 2. FeatureOnboarding — Screens

#### Welcome Screen (`Screens/Welcome/`)
- [ ] `WelcomeView.swift` — mirrors `WelcomeScreen.kt`
- [ ] `WelcomeViewModel.swift`
- [ ] `ColdStartContent.swift` — Initial loading state
- [ ] `Moment1Content.swift` — First welcome moment
- [ ] `Moment2Content.swift` — Second welcome moment
- [ ] `Moment3Content.swift` — Third welcome moment

#### Auth Screen (`Screens/Auth/`)
- [ ] `WaonderAuthView.swift` — mirrors `WaonderAuthScreen.kt`
- [ ] `WaonderAuthViewModel.swift`
- [ ] `PhoneInputContent.swift` — Phone number input
- [ ] `OtpVerificationContent.swift` — OTP code entry

#### Location Priming (`Screens/Location/`)
- [ ] `LocationPrimingView.swift` — "Why we need location"
- [ ] `LocationPrimingViewModel.swift`
- [ ] `LocationPrimingContent.swift`
- [ ] `LocationSettingsContent.swift`

#### Teaser Place Clearing (`Screens/TeaserPlaceClearing/`)
- [ ] `TeaserPlaceClearingView.swift`
- [ ] `TeaserPlaceClearingViewModel.swift`
- [ ] `TeaserPlaceClearingContent.swift`

#### User Location Clearing (`Screens/UserLocationClearing/`)
- [ ] `UserLocationClearingView.swift`
- [ ] `UserLocationClearingViewModel.swift`
- [ ] `UserLocationClearingContent.swift`

### 3. Auth Components (`Auth/Components/`)
- [ ] `CountryPickerBottomSheet.swift` — Country code picker
- [ ] `OtpProgressLine.swift` — OTP progress indicator
- [ ] `PhoneNumberVisualTransformation.swift` — Phone formatting display
- [ ] `ResendCodeSection.swift` — Resend OTP button with timer
- [ ] `WaonderOtpDigitBox.swift` — Single OTP digit input
- [ ] `WaonderOtpInput.swift` — Full OTP input row
- [ ] `WaonderPhoneInput.swift` — Phone number input field

### 4. Shared Components (`Components/`)
- [ ] `DebugBackButton.swift`
- [ ] `LinearGradientOverlay.swift`
- [ ] `MoveButton.swift` — Navigation button
- [ ] `NightShiftOverlay.swift`
- [ ] `OnboardingContainer.swift` — Layout container
- [ ] `OnboardingCopyText.swift`
- [ ] `OnboardingHeroText.swift`
- [ ] `OnboardingPreviewTheme.swift`
- [ ] `OnboardingScreenWrapper.swift`
- [ ] `OnboardingWordmark.swift`
- [ ] `ShadowedIcon.swift`
- [ ] `TeaserPlaceCard.swift` — Place preview card
- [ ] `TeaserRevealEffect.swift` — Reveal animation
- [ ] `TransitionOverlay.swift`
- [ ] `WordByWordText.swift`

### 5. Map Integration (`Map/`)
- [ ] `FogOnboardingViewModel.swift`
- [ ] `MapEngineV2FogOnboardingView.swift` — Map with fog during onboarding
- [ ] `OnboardingFogScene.swift`

#### Map Annotations (`Map/Annotations/`)
- [ ] `TeaserAnnotationBuilder.swift`

#### Map Effects (`Map/Effects/`)
- [ ] `OnboardingDriftConfig.swift`
- [ ] `OnboardingMapCameraEffect.swift`
- [ ] `OnboardingMev2FogEffect.swift`
- [ ] `TeaserAnnotationEffect.swift`
- [ ] `TeaserHaloEffect.swift` — Halo effect around place
- [ ] `UserLocationClearingDotEffect.swift`

### 6. Overlay Components (`Overlay/Components/`)
- [ ] `MapLoadingErrorVignette.swift`
- [ ] `NoConnectivityVignette.swift`

### 7. Navigation & Coordination
- [ ] `OnboardingNavigation.swift` — Route definitions
- [ ] `OnboardingView.swift` — Main coordinator screen
- [ ] `OnboardingViewModel.swift`
- [ ] `OnboardingConstants.swift`

### 8. Utilities
- [ ] `ContextExtensions.swift`

---

## Animation Parity

The onboarding is heavily animated. Key animations to match:

| Animation | Android Implementation | iOS Implementation |
|-----------|----------------------|-------------------|
| Letter-by-letter text | Custom Compose animation | SwiftUI `.animation` with delay per character |
| Word-by-word text | Custom Compose animation | SwiftUI `.animation` with delay per word |
| Map fog drift | Camera animation loop | MapLibre camera animation |
| Teaser reveal | Custom Compose transition | SwiftUI `.transition` + `.animation` |
| Place halo | Compose canvas animation | SwiftUI Canvas or Circle animation |
| Screen transitions | Compose AnimatedContent | SwiftUI `.transition` |

---

## Verification

- [ ] Complete onboarding flow from welcome to home screen
- [ ] Phone number input with country picker works
- [ ] OTP verification succeeds with Firebase
- [ ] Location permission request shows system dialog
- [ ] Map with fog renders during onboarding
- [ ] Teaser place card reveals with animation
- [ ] All text animations play correctly
- [ ] Flow state persists (resume from last step after app kill)
- [ ] 60+ files match Android onboarding module
