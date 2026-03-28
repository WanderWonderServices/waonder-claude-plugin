# Milestone 14: Settings & Remaining Features

**Status:** Not Started
**Dependencies:** Milestones 08, 10
**Android Modules:** `:feature:settings`, `:feature:developer`, `:feature:errors`, `:feature:theme`, `:feature:remote-visit`
**iOS Targets:** `FeatureSettings`, `FeatureDeveloper`, `FeatureErrors`, `FeatureTheme`, `FeatureRemoteVisit`

---

## Objective

Migrate all remaining feature modules — settings hub, developer tools, error components, theme provider, and remote visit. These are smaller, self-contained features.

---

## Deliverables

### 1. FeatureSettings (`FeatureSettings/`)

#### Screens (`Screens/`)
- [ ] Account settings screen (phone number display, logout)
- [ ] Appearance settings screen (theme, palette, typography selection)
- [ ] Privacy settings screen (location tracking preferences)
- [ ] About screen (version, legal info)

#### Components (`Components/`)
- [ ] Settings list items
- [ ] Settings section headers
- [ ] Toggle/switch components
- [ ] Navigation hub layout

#### ViewModels
- [ ] SettingsViewModel (or per-screen VMs matching Android)

**File count target:** 18 files (matching Android)

### 2. FeatureDeveloper (`FeatureDeveloper/`)
- [ ] `DeveloperOptionsView.swift` — Developer options screen
- [ ] `DeveloperOptionsViewModel.swift`
- [ ] `ColorPaletteShowcaseView.swift` — All colors displayed
- [ ] `TypographyShowcaseView.swift` — All text styles displayed
- [ ] Access via 3-finger gesture on home screen (match Android)

**File count target:** 6 files

### 3. FeatureErrors (`FeatureErrors/`)
- [ ] `NoConnectivityVignette.swift` — Network error overlay

**File count target:** 1 file

### 4. FeatureTheme (`FeatureTheme/`)
- [ ] `ThemeProviderView.swift` — Theme wrapper for app
- [ ] `ColorProvider.swift` — Dynamic color provision based on palette

**File count target:** 2 files

### 5. FeatureRemoteVisit (`FeatureRemoteVisit/`)
- [ ] `RemoteVisitCard.swift` — Remote visit UI card
- [ ] `RemoteVisitViewModel.swift`

**File count target:** 2 files

---

## Settings Flow

```
Settings Hub
├── Account
│   ├── Phone number (display only)
│   └── Logout button → SessionViewModel.logout()
├── Appearance
│   ├── Palette picker → PaletteRepository
│   └── Typography picker → TypographyRepository
├── Privacy
│   └── Location preferences → UserSettingsRepository
└── About
    ├── App version
    └── Legal/Terms links
```

---

## Theme System

The theme system must support dynamic switching:

```swift
// FeatureTheme
@Observable
final class ThemeProvider {
    var currentPalette: PaletteSettings
    var currentTypography: TypographySettings

    // Computed colors based on palette
    var primaryColor: Color { ... }
    var backgroundColor: Color { ... }
    // etc.
}

// Usage in app
struct WaonderThemeView<Content: View>: View {
    @Environment(ThemeProvider.self) var theme
    let content: () -> Content

    var body: some View {
        content()
            .environment(\.colorScheme, theme.colorScheme)
    }
}
```

---

## Verification

- [ ] Settings hub navigates to all sub-screens
- [ ] Account screen shows phone number
- [ ] Logout clears session and returns to onboarding
- [ ] Appearance changes apply immediately (palette, typography)
- [ ] Developer options accessible via 3-finger gesture
- [ ] Color palette showcase displays all colors
- [ ] Typography showcase displays all text styles
- [ ] No connectivity vignette appears when offline
- [ ] Theme provider wraps entire app
- [ ] Remote visit card displays correctly
- [ ] Total file count across all 5 modules: ~29 files
