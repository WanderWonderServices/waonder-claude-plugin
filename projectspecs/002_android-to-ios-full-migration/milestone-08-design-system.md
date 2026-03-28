# Milestone 08: Design System

**Status:** Not Started
**Dependencies:** Milestone 02
**Android Module:** `:core:design`
**iOS Target:** `CoreDesign`

---

## Objective

Migrate the complete design system — theme (colors, typography, shapes, shadows), all reusable Compose components to SwiftUI, and the Waonder visual identity.

---

## Deliverables

### 1. Theme (`Theme/`)
- [ ] `Color.swift` — All color definitions (hex values match Android)
- [ ] `ColorExtensions.swift` — Color utility extensions
- [ ] `ColorPalettes.swift` — Multiple color palette definitions
- [ ] `Fonts.swift` — Typography setup with custom fonts
- [ ] `Shadows.swift` — Shadow definitions (NSShadow / SwiftUI shadow)
- [ ] `Shapes.swift` — Custom shapes (RoundedRectangle configs, etc.)
- [ ] `TypographyExtensions.swift` — Font/text style extensions
- [ ] `WaonderAuthColors.swift` — Auth-specific color scheme
- [ ] `WaonderAuthTypography.swift` — Auth-specific typography

### 2. Components (`Components/`)
- [ ] `AnimatedSelectableWordText.swift` — Text with word-level animation
- [ ] `BlurContainer.swift` — UIVisualEffectView wrapper or Material blur
- [ ] `EmptyState.swift` — Empty state placeholder view
- [ ] `ErrorView.swift` — Error display component
- [ ] `HtmlSelectableWordText.swift` — HTML-attributed text rendering
- [ ] `LetterByLetterText.swift` — Animated letter reveal effect
- [ ] `LoadingIndicator.swift` — Custom loading spinner
- [ ] `MapLoadingView.swift` — Map-specific loading state
- [ ] `RapidReadCard.swift` — Card optimized for reading
- [ ] `RecentPlacesPathIcon.swift` — Icon component
- [ ] `SelectableWordText.swift` — Interactive word selection
- [ ] `ShadowedIcon.swift` — Icon with drop shadow
- [ ] `StatusBarEffect.swift` — Status bar appearance control
- [ ] `TimeShadowOffset.swift` — Time-based shadow positioning
- [ ] `VignetteOverlay.swift` — Vignette gradient overlay
- [ ] `WaonderButtons.swift` — All button styles (primary, secondary, text)
- [ ] `WaonderDialog.swift` — Custom dialog/alert presentation
- [ ] `WaonderText.swift` — Custom text component with Waonder styling
- [ ] `WordByWordText.swift` — Word-level animation component

### 3. Font Assets
- [ ] Bundle custom font files in CoreDesign package resources
- [ ] Register fonts via Info.plist or SPM resource processing

---

## Key Translation: Compose → SwiftUI Components

```kotlin
// Android (Compose)
@Composable
fun WaonderButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    style: WaonderButtonStyle = WaonderButtonStyle.Primary
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        colors = ButtonDefaults.buttonColors(containerColor = style.backgroundColor),
        modifier = modifier.fillMaxWidth().height(56.dp)
    ) {
        Text(text, style = MaterialTheme.typography.labelLarge)
    }
}
```

```swift
// iOS (SwiftUI)
struct WaonderButton: View {
    let text: String
    let action: () -> Void
    var isEnabled: Bool = true
    var style: WaonderButtonStyle = .primary

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(WaonderTypography.labelLarge)
        }
        .buttonStyle(WaonderButtonStyleModifier(style: style))
        .disabled(!isEnabled)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
    }
}
```

---

## Color Parity

Extract exact hex values from Android `Color.kt` and `ColorPalettes.kt`. Every named color must have an identical hex value on iOS.

```swift
// Example
extension Color {
    static let waonderPrimary = Color(hex: "#FF6B35")      // Must match Android
    static let waonderBackground = Color(hex: "#1A1A2E")   // Must match Android
    // ... every color from Android
}
```

---

## Verification

- [ ] `CoreDesign` target compiles
- [ ] Every Compose component has a SwiftUI View equivalent
- [ ] Color hex values match Android exactly
- [ ] Custom fonts load and display correctly
- [ ] Typography scale matches Android Material 3 scale
- [ ] Shadow definitions produce similar visual results
- [ ] Button styles match Android visual appearance
- [ ] Component count: 19 components match 19 Android composables
