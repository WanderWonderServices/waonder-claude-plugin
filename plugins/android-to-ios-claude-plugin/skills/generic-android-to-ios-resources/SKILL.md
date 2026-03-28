---
name: generic-android-to-ios-resources
description: Use when migrating Android resource system (strings.xml, dimens.xml, colors.xml, styles.xml, themes.xml, resource qualifiers for locale/density/screen size/night mode) to iOS equivalents (String Catalogs .xcstrings, Asset Catalogs for colors/data, SwiftUI environment values, system colors, Dynamic Type)
type: generic
---

# generic-android-to-ios-resources

## Context

Android's resource system is file-based, using XML files organized by type (`values/strings.xml`, `values/colors.xml`, `values/dimens.xml`) with resource qualifiers on folder names to handle locale, screen density, dark mode, and screen size variations. iOS distributes these concerns across String Catalogs (`.xcstrings`) for localization, Asset Catalogs (`.xcassets`) for colors and images, SwiftUI environment values for dynamic sizing, and system-level APIs for theming. This skill maps every major Android resource type to its idiomatic iOS equivalent.

## Concept Mapping

| Android | iOS |
|---------|-----|
| `strings.xml` | String Catalog (`.xcstrings`) or `Localizable.strings` (legacy) |
| `plurals` in `strings.xml` | String Catalog with plural variations |
| `string-array` in `strings.xml` | String Catalog or Swift array with `String(localized:)` |
| `colors.xml` | Asset Catalog Color Set (`.colorset`) |
| `colors.xml` with `night` qualifier | Asset Catalog Color Set with Any/Dark appearances |
| `dimens.xml` | Swift constants, Dynamic Type, or `@ScaledMetric` |
| `styles.xml` | `ViewModifier` or `ButtonStyle` / `LabelStyle` |
| `themes.xml` | `UIAppearance` (UIKit) or custom `EnvironmentKey` (SwiftUI) |
| Resource qualifier `-es`, `-fr` | String Catalog locale columns or `.lproj` folders |
| Resource qualifier `-night` | Asset Catalog appearance variants |
| Resource qualifier `-sw600dp` | SwiftUI `@Environment(\.horizontalSizeClass)` or `GeometryReader` |
| Resource qualifier `-land` | `@Environment(\.verticalSizeClass)` |
| `@string/key` reference | `String(localized: "key")` |
| `@color/name` reference | `Color("name")` (Asset Catalog) or `Color.colorName` (extension) |
| `@dimen/name` reference | Swift constant or `@ScaledMetric var name` |
| `?attr/colorPrimary` theme attribute | `Color.accentColor` or custom `EnvironmentKey` |
| `MaterialTheme` colors | SwiftUI `ShapeStyle` and semantic system colors |

## Android Best Practices (Source Patterns)

### strings.xml with Plurals and Format Args

```xml
<!-- values/strings.xml -->
<resources>
    <string name="app_name">Waonder</string>
    <string name="welcome_message">Welcome, %1$s!</string>
    <string name="landmark_distance">%1$.1f km away</string>
    <string name="error_network">Unable to connect. Please check your internet connection.</string>

    <plurals name="landmarks_count">
        <item quantity="zero">No landmarks found</item>
        <item quantity="one">%d landmark found</item>
        <item quantity="other">%d landmarks found</item>
    </plurals>

    <string-array name="categories">
        <item>Nature</item>
        <item>History</item>
        <item>Architecture</item>
        <item>Culture</item>
    </string-array>
</resources>

<!-- values-es/strings.xml -->
<resources>
    <string name="app_name">Waonder</string>
    <string name="welcome_message">Bienvenido, %1$s!</string>
    <string name="landmark_distance">a %1$.1f km</string>
</resources>
```

### colors.xml with Night Mode

```xml
<!-- values/colors.xml -->
<resources>
    <color name="primary">#FF6200EE</color>
    <color name="primary_variant">#FF3700B3</color>
    <color name="secondary">#FF03DAC5</color>
    <color name="background">#FFFFFFFF</color>
    <color name="surface">#FFFFFFFF</color>
    <color name="on_primary">#FFFFFFFF</color>
    <color name="on_background">#FF1C1B1F</color>
    <color name="on_surface">#FF1C1B1F</color>
    <color name="landmark_pin">#FFFF5722</color>
    <color name="text_secondary">#FF757575</color>
</resources>

<!-- values-night/colors.xml -->
<resources>
    <color name="primary">#FFD0BCFF</color>
    <color name="primary_variant">#FFB39DDB</color>
    <color name="background">#FF1C1B1F</color>
    <color name="surface">#FF1C1B1F</color>
    <color name="on_primary">#FF381E72</color>
    <color name="on_background">#FFE6E1E5</color>
    <color name="on_surface">#FFE6E1E5</color>
</resources>
```

### dimens.xml

```xml
<!-- values/dimens.xml -->
<resources>
    <dimen name="spacing_xs">4dp</dimen>
    <dimen name="spacing_sm">8dp</dimen>
    <dimen name="spacing_md">16dp</dimen>
    <dimen name="spacing_lg">24dp</dimen>
    <dimen name="spacing_xl">32dp</dimen>

    <dimen name="text_body">16sp</dimen>
    <dimen name="text_title">24sp</dimen>
    <dimen name="text_headline">32sp</dimen>

    <dimen name="corner_radius_sm">8dp</dimen>
    <dimen name="corner_radius_md">12dp</dimen>
    <dimen name="corner_radius_lg">16dp</dimen>

    <dimen name="icon_size_sm">24dp</dimen>
    <dimen name="icon_size_md">48dp</dimen>
</resources>

<!-- values-sw600dp/dimens.xml (tablet overrides) -->
<resources>
    <dimen name="spacing_md">24dp</dimen>
    <dimen name="spacing_lg">32dp</dimen>
    <dimen name="text_headline">40sp</dimen>
</resources>
```

### styles.xml and themes.xml

```xml
<!-- values/styles.xml -->
<resources>
    <style name="Widget.Waonder.Button.Primary" parent="Widget.Material3.Button">
        <item name="cornerRadius">@dimen/corner_radius_md</item>
        <item name="android:minHeight">48dp</item>
        <item name="android:textAppearance">@style/TextAppearance.Waonder.Button</item>
    </style>

    <style name="TextAppearance.Waonder.Button" parent="TextAppearance.Material3.LabelLarge">
        <item name="android:textSize">16sp</item>
        <item name="android:fontFamily">@font/inter_semibold</item>
    </style>
</resources>

<!-- values/themes.xml -->
<resources>
    <style name="Theme.Waonder" parent="Theme.Material3.DayNight.NoActionBar">
        <item name="colorPrimary">@color/primary</item>
        <item name="colorOnPrimary">@color/on_primary</item>
        <item name="colorSecondary">@color/secondary</item>
        <item name="android:statusBarColor">@android:color/transparent</item>
        <item name="android:navigationBarColor">@android:color/transparent</item>
    </style>
</resources>
```

### Accessing Resources in Kotlin

```kotlin
// String resources
val welcome = getString(R.string.welcome_message, userName)
val count = resources.getQuantityString(R.plurals.landmarks_count, total, total)

// Color resources
val pinColor = ContextCompat.getColor(context, R.color.landmark_pin)

// Dimension resources
val spacing = resources.getDimensionPixelSize(R.dimen.spacing_md)

// Compose equivalents
Text(stringResource(R.string.welcome_message, userName))
Box(modifier = Modifier.background(colorResource(R.color.primary)))
```

## iOS Equivalent Patterns

### String Catalog (.xcstrings)

String Catalogs are the modern replacement for `Localizable.strings`. They are JSON-based, support pluralization natively, and integrate with Xcode's localization editor.

```swift
// Accessing localized strings in SwiftUI
// The key maps to the String Catalog entry
Text("welcome_message \(userName)")  // SwiftUI auto-localizes string literals

// Explicit localization
let welcome = String(localized: "welcome_message \(userName)")

// With a table name (for multiple .xcstrings files)
let msg = String(localized: "error_network", table: "Errors")

// Plurals -- String Catalogs handle this natively via stringsdict-style rules
// In the .xcstrings file, configure plural variations for each locale
let landmarkCount = String(localized: "landmarks_count \(total)")
// The String Catalog editor lets you define: zero, one, two, few, many, other
```

**String Catalog JSON structure** (managed by Xcode, shown for reference):
```json
{
  "sourceLanguage": "en",
  "strings": {
    "welcome_message %@": {
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Welcome, %@!"
          }
        },
        "es": {
          "stringUnit": {
            "state": "translated",
            "value": "Bienvenido, %@!"
          }
        }
      }
    },
    "landmarks_count %lld": {
      "localizations": {
        "en": {
          "variations": {
            "plural": {
              "zero": {
                "stringUnit": { "state": "translated", "value": "No landmarks found" }
              },
              "one": {
                "stringUnit": { "state": "translated", "value": "%lld landmark found" }
              },
              "other": {
                "stringUnit": { "state": "translated", "value": "%lld landmarks found" }
              }
            }
          }
        }
      }
    }
  }
}
```

### Asset Catalog Color Sets (Replacing colors.xml)

Each color is a `.colorset` directory inside `.xcassets` with a `Contents.json`:

```json
// Colors.xcassets/Primary.colorset/Contents.json
{
  "colors": [
    {
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.384",
          "green": "0.000",
          "blue": "0.933",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    },
    {
      "appearances": [
        {
          "appearance": "luminosity",
          "value": "dark"
        }
      ],
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.816",
          "green": "0.737",
          "blue": "1.000",
          "alpha": "1.000"
        }
      },
      "idiom": "universal"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

```swift
// Using Asset Catalog colors in SwiftUI
// Automatically resolves light/dark based on system setting
Text("Hello")
    .foregroundStyle(Color("Primary"))

// Type-safe color access via extension (preferred)
extension Color {
    static let waonderPrimary = Color("Primary")
    static let waonderPrimaryVariant = Color("PrimaryVariant")
    static let waonderSecondary = Color("Secondary")
    static let waonderBackground = Color("Background")
    static let waonderSurface = Color("Surface")
    static let waonderOnPrimary = Color("OnPrimary")
    static let waonderOnBackground = Color("OnBackground")
    static let waonderOnSurface = Color("OnSurface")
    static let waonderLandmarkPin = Color("LandmarkPin")
    static let waonderTextSecondary = Color("TextSecondary")
}

extension ShapeStyle where Self == Color {
    static var waonderPrimary: Color { Color("Primary") }
}

// Usage
Text("Title")
    .foregroundStyle(.waonderPrimary)
```

### Dimension Constants and Dynamic Type (Replacing dimens.xml)

```swift
// Design system spacing constants (equivalent to dimens.xml spacing values)
enum WaonderSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum WaonderCornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
}

enum WaonderIconSize {
    static let sm: CGFloat = 24
    static let md: CGFloat = 48
}

// For text sizes, use Dynamic Type instead of fixed sp values.
// Dynamic Type is the iOS equivalent of sp (scale-independent pixels).
// SwiftUI text styles map to Android text appearances:

// Android: @dimen/text_body (16sp)    -> iOS: .body
// Android: @dimen/text_title (24sp)   -> iOS: .title2
// Android: @dimen/text_headline (32sp) -> iOS: .largeTitle

Text("Landmark Name")
    .font(.title2)          // Equivalent to 24sp, scales with accessibility settings
Text("Description")
    .font(.body)            // Equivalent to 16sp
Text("Section Header")
    .font(.largeTitle)      // Equivalent to 32sp

// Custom font with Dynamic Type scaling
Text("Custom")
    .font(.custom("Inter-SemiBold", size: 16, relativeTo: .body))

// @ScaledMetric for dimensions that should scale with Dynamic Type
// (equivalent to sp-based dimensions that scale with font size)
struct LandmarkCard: View {
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var cardPadding: CGFloat = 16

    var body: some View {
        HStack(spacing: WaonderSpacing.sm) {
            Image(systemName: "mappin.circle.fill")
                .frame(width: iconSize, height: iconSize)
            Text("Landmark")
        }
        .padding(cardPadding)
    }
}
```

### Adaptive Layout for Screen Sizes (Replacing sw600dp Qualifiers)

```swift
// Equivalent to values-sw600dp resource qualifiers
struct AdaptiveLandmarkList: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            // Tablet / iPad layout (equivalent to sw600dp)
            NavigationSplitView {
                LandmarkListView()
            } detail: {
                LandmarkDetailView()
            }
        } else {
            // Phone layout (default)
            NavigationStack {
                LandmarkListView()
            }
        }
    }
}

// Adaptive spacing based on size class
struct AdaptiveSpacing {
    static func md(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 24 : 16  // sw600dp: 24, default: 16
    }

    static func lg(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 32 : 24
    }
}

// ViewModifier for landscape detection (equivalent to -land qualifier)
struct LandscapeAwareModifier: ViewModifier {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, isLandscape ? WaonderSpacing.xl : WaonderSpacing.md)
    }
}
```

### Style System (Replacing styles.xml and themes.xml)

```swift
// ViewModifier (equivalent to a <style> in styles.xml)
struct WaonderPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Inter-SemiBold", size: 16, relativeTo: .body))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.waonderPrimary)
            .foregroundStyle(Color.waonderOnPrimary)
            .clipShape(RoundedRectangle(cornerRadius: WaonderCornerRadius.md))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// Usage
Button("Explore Landmark") { }
    .buttonStyle(WaonderPrimaryButtonStyle())

// Theme via Environment (equivalent to Theme.Waonder attributes)
struct WaonderTheme {
    let primaryColor: Color
    let secondaryColor: Color
    let backgroundColor: Color
    let surfaceColor: Color
    let onPrimaryColor: Color
    let onBackgroundColor: Color

    static let `default` = WaonderTheme(
        primaryColor: .waonderPrimary,
        secondaryColor: .waonderSecondary,
        backgroundColor: .waonderBackground,
        surfaceColor: .waonderSurface,
        onPrimaryColor: .waonderOnPrimary,
        onBackgroundColor: .waonderOnBackground
    )
}

private struct WaonderThemeKey: EnvironmentKey {
    static let defaultValue = WaonderTheme.default
}

extension EnvironmentValues {
    var waonderTheme: WaonderTheme {
        get { self[WaonderThemeKey.self] }
        set { self[WaonderThemeKey.self] = newValue }
    }
}

// Apply theme at app root
@main
struct WaonderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.waonderTheme, .default)
                .tint(.waonderPrimary)  // Sets accentColor globally
        }
    }
}

// Consume theme in any view
struct LandmarkHeader: View {
    @Environment(\.waonderTheme) private var theme

    var body: some View {
        Text("Landmark")
            .foregroundStyle(theme.onBackgroundColor)
            .background(theme.backgroundColor)
    }
}
```

## Key Differences and Pitfalls

### 1. No Automatic Resource Qualification on iOS
Android's folder-based qualifier system (`values-es/`, `values-night/`, `values-sw600dp/`) automatically selects the right resource at runtime. iOS requires explicit code to check `horizontalSizeClass`, `colorScheme`, or locale. Only Asset Catalog colors and String Catalogs handle variant resolution automatically.

### 2. String Format Specifiers Differ
Android uses `%1$s`, `%2$d` positional format specifiers. iOS uses `%@` (any object), `%lld` (integer), `%f` (float). When migrating format strings, convert all specifiers. String interpolation in Swift (`\(variable)`) is the preferred modern approach in String Catalogs.

### 3. Pluralization Rules Vary by Locale
Android's `<plurals>` supports `zero`, `one`, `two`, `few`, `many`, `other` quantities. iOS String Catalogs support the same CLDR categories. Ensure you define all required categories for each target locale (e.g., Arabic needs `zero`, `one`, `two`, `few`, `many`, `other`).

### 4. Dark Mode is Handled Differently
Android uses `-night` resource qualifiers on folders. iOS uses Asset Catalog appearance variants (Any Appearance + Dark). SwiftUI views automatically adapt when using `Color("name")` from Asset Catalogs or system colors. There is no need to manually observe dark mode changes.

### 5. sp Units Map to Dynamic Type, Not Fixed Points
Android's `sp` (scale-independent pixels) scale with the user's font size preference. The iOS equivalent is Dynamic Type, accessed via `.font(.body)` or `@ScaledMetric`. Never use fixed `CGFloat` values for text sizes -- always use text styles or `relativeTo:` to maintain accessibility compliance.

### 6. dp Maps to Points, Not Pixels
Android's `dp` (density-independent pixels) map directly to iOS `points` (`CGFloat`). Both are abstract units that the system maps to physical pixels. A `16dp` margin in Android becomes a `16` point margin in iOS. No conversion is needed.

### 7. Theme Attributes Require Manual Environment Setup
Android's `?attr/colorPrimary` resolves theme attributes automatically. SwiftUI has `.accentColor` / `.tint` for the primary color, but custom theme attributes require explicit `EnvironmentKey` definitions. There is no built-in equivalent to Android's full theme attribute system.

### 8. String Arrays Have No Direct Catalog Support
Android's `<string-array>` in `strings.xml` has no direct equivalent in String Catalogs. Define arrays in Swift code with individually localized strings using `String(localized:)`.

## Migration Checklist

- [ ] Export all `strings.xml` entries to a String Catalog (`.xcstrings`) file
- [ ] Convert `<plurals>` entries to String Catalog plural variations with correct CLDR categories
- [ ] Convert format specifiers: `%1$s` to `%@`, `%1$d` to `%lld`, `%1$.1f` to `%.1f`
- [ ] Create Asset Catalog Color Sets for every entry in `colors.xml`, including dark variants from `values-night/colors.xml`
- [ ] Replace `@color/name` references with `Color("Name")` or type-safe `Color.waonderName` extensions
- [ ] Convert `dimens.xml` spacing values to a Swift `enum` with static `CGFloat` constants
- [ ] Map `dimens.xml` text sizes to Dynamic Type text styles (`.body`, `.title2`, `.largeTitle`)
- [ ] Use `@ScaledMetric` for dimensions that should scale with Dynamic Type
- [ ] Replace `-sw600dp` resource qualifiers with `@Environment(\.horizontalSizeClass)` checks
- [ ] Replace `-land` resource qualifiers with `@Environment(\.verticalSizeClass)` checks
- [ ] Convert `styles.xml` widget styles to `ButtonStyle`, `LabelStyle`, or `ViewModifier` types
- [ ] Convert `themes.xml` to a `WaonderTheme` struct with an `EnvironmentKey`
- [ ] Set `.tint(.waonderPrimary)` at the app root to replicate `colorPrimary` theme attribute
- [ ] Verify all localized strings appear in the String Catalog for every supported locale
- [ ] Test Dynamic Type at all accessibility sizes (xSmall through AX5)
- [ ] Test dark mode with Asset Catalog colors to confirm all variants render correctly
