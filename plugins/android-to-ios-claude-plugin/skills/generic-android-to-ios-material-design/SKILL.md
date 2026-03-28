---
name: generic-android-to-ios-material-design
description: Use when migrating Android Material Design 3 theming (MaterialTheme, dynamic color, typography, shapes, components) to iOS Human Interface Guidelines equivalents (native components, SF Symbols, system colors, dynamic type)
type: generic
---

# generic-android-to-ios-material-design

## Context

Android's visual language is built on Material Design 3 (Material You), which provides a comprehensive system of colors, typography, shapes, and components through the `MaterialTheme` composable and XML theme system. iOS follows Apple's Human Interface Guidelines (HIG), which emphasize native platform feel, SF Symbols, system colors that adapt to light/dark mode, and Dynamic Type for accessibility.

Migrating from Material Design to HIG is not a one-to-one translation. The goal is not to replicate Material Design on iOS but to translate the design intent into iOS-native patterns. This skill covers how Material Design 3 concepts map to iOS equivalents and where to embrace platform differences rather than forcing cross-platform consistency.

Use this skill when migrating the visual design layer of an Android feature to iOS. For layout migration, see `generic-android-to-ios-compose`. For component behavior patterns, see `generic-android-to-ios-composable`.

## Concept Mapping

| Material Design 3 (Android) | Human Interface Guidelines (iOS) |
|-----------------------------|----------------------------------|
| `MaterialTheme` | System appearance + custom `Theme` environment |
| `MaterialTheme.colorScheme` | `Color(.systemBackground)`, `Color.accentColor`, asset catalog colors |
| Dynamic Color (Material You) | System tint color / app accent color |
| `MaterialTheme.typography` | `Font.TextStyle` (`.headline`, `.body`, etc.) with Dynamic Type |
| `MaterialTheme.shapes` | `RoundedRectangle`, `Capsule`, `Circle` |
| `Surface` | Plain `View` with `.background()` |
| `Card` | Grouped list row or custom view with `.background()` + corner radius |
| `TopAppBar` | `.navigationTitle()` + `.navigationBarTitleDisplayMode()` |
| `BottomNavigation` / `NavigationBar` | `TabView` with `.tabItem` |
| `FloatingActionButton` | `.toolbar` button or custom overlay |
| `Snackbar` | No built-in equivalent; use banner or custom toast |
| `AlertDialog` | `.alert()` modifier |
| `BottomSheet` / `ModalBottomSheet` | `.sheet()` or `.presentationDetents()` |
| `NavigationDrawer` | `NavigationSplitView` (iPad) or custom side menu |
| `Chip` | No built-in equivalent; use `Button` with custom style or `Menu` |
| `Switch` | `Toggle` |
| `Checkbox` | `Toggle` (with `.toggleStyle(.checkbox)` on macOS, custom on iOS) |
| `RadioButton` | `Picker` with `.pickerStyle(.inline)` |
| `Slider` | `Slider` |
| `ProgressIndicator` (linear) | `ProgressView` with `.progressViewStyle(.linear)` |
| `ProgressIndicator` (circular) | `ProgressView` (default circular style) |
| `TextField` (outlined) | `TextField` with `.textFieldStyle(.roundedBorder)` |
| `TextField` (filled) | `TextField` with custom background |
| `DropdownMenu` | `Menu` or `Picker` |
| `TabRow` / `ScrollableTabRow` | Segmented `Picker` or custom tab bar |
| `Icon` (Material Icons) | `Image(systemName:)` (SF Symbols) |
| `Divider` | `Divider` |
| `Badge` | `.badge()` modifier |
| `ElevatedButton` | `Button` with `.buttonStyle(.borderedProminent)` |
| `OutlinedButton` | `Button` with `.buttonStyle(.bordered)` |
| `TextButton` | `Button` with `.buttonStyle(.plain)` or `.buttonStyle(.borderless)` |
| `IconButton` | `Button` with `Label` or `Image(systemName:)` |
| `ExtendedFloatingActionButton` | `.toolbar` with custom button |
| Ripple effect | Highlight state (automatic in SwiftUI buttons) |
| `elevation` / `tonalElevation` | `.shadow()` modifier (used sparingly on iOS) |

## Color System Migration

### Material Design 3 Color Roles to iOS

```kotlin
// Android: Material Design 3 color usage
MaterialTheme.colorScheme.primary         // Primary brand color
MaterialTheme.colorScheme.onPrimary       // Text/icon on primary
MaterialTheme.colorScheme.primaryContainer // Lighter primary for containers
MaterialTheme.colorScheme.secondary       // Secondary brand color
MaterialTheme.colorScheme.surface         // Background for cards, sheets
MaterialTheme.colorScheme.onSurface       // Primary text color
MaterialTheme.colorScheme.surfaceVariant  // Slightly different surface
MaterialTheme.colorScheme.onSurfaceVariant // Secondary text color
MaterialTheme.colorScheme.background      // Screen background
MaterialTheme.colorScheme.error           // Error states
MaterialTheme.colorScheme.outline         // Borders, dividers
```

```swift
// iOS: Equivalent system colors
Color.accentColor                          // Primary brand color (set in asset catalog)
Color.white                                // Text on accent (or use contrast)
Color.accentColor.opacity(0.15)            // Lighter primary for containers
Color(.secondaryLabel)                     // Secondary content
Color(.systemBackground)                   // Screen background
Color(.secondarySystemBackground)          // Card/surface background
Color(.tertiarySystemBackground)           // Grouped content background
Color(.label)                              // Primary text
Color(.secondaryLabel)                     // Secondary text
Color(.tertiaryLabel)                      // Tertiary text
Color.red                                  // Error states (or Color(.systemRed))
Color(.separator)                          // Borders, dividers
Color(.systemGroupedBackground)            // Grouped table background
```

### Custom Color Scheme for iOS

```swift
// iOS: Define a custom color theme using asset catalog colors
// In Assets.xcassets, create color sets with Light/Dark variants

// Access in code:
extension Color {
    static let brandPrimary = Color("BrandPrimary")
    static let brandSecondary = Color("BrandSecondary")
    static let brandSurface = Color("BrandSurface")
}

// Or define programmatically with adaptive colors:
extension UIColor {
    static let brandPrimary = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0)
            : UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
    }
}
```

### Dynamic Color (Material You) to iOS

Material You generates a color scheme from the user's wallpaper. iOS does not have an equivalent system. Instead:

- Use the app's **accent color** (set in the asset catalog) as the primary brand color.
- Use **system colors** (`Color(.systemBlue)`, `Color(.systemBackground)`, etc.) which automatically adapt to light/dark mode and accessibility settings.
- Do not attempt to replicate wallpaper-based dynamic color on iOS -- it is not part of the platform idiom.

## Typography Migration

```kotlin
// Android: Material Design 3 typography
MaterialTheme.typography.displayLarge    // 57sp
MaterialTheme.typography.displayMedium   // 45sp
MaterialTheme.typography.displaySmall    // 36sp
MaterialTheme.typography.headlineLarge   // 32sp
MaterialTheme.typography.headlineMedium  // 28sp
MaterialTheme.typography.headlineSmall   // 24sp
MaterialTheme.typography.titleLarge      // 22sp
MaterialTheme.typography.titleMedium     // 16sp medium
MaterialTheme.typography.titleSmall      // 14sp medium
MaterialTheme.typography.bodyLarge       // 16sp
MaterialTheme.typography.bodyMedium      // 14sp
MaterialTheme.typography.bodySmall       // 12sp
MaterialTheme.typography.labelLarge      // 14sp medium
MaterialTheme.typography.labelMedium     // 12sp medium
MaterialTheme.typography.labelSmall      // 11sp medium
```

```swift
// iOS: Dynamic Type text styles (automatically scale with user preference)
Font.largeTitle          // ~34pt - maps to displaySmall/headlineLarge
Font.title               // ~28pt - maps to headlineMedium
Font.title2              // ~22pt - maps to titleLarge
Font.title3              // ~20pt - maps to titleMedium
Font.headline            // ~17pt semibold - maps to titleMedium (bold)
Font.body                // ~17pt - maps to bodyLarge
Font.callout             // ~16pt - maps to bodyMedium
Font.subheadline         // ~15pt - maps to bodyMedium/bodySmall
Font.footnote            // ~13pt - maps to labelLarge
Font.caption             // ~12pt - maps to labelMedium
Font.caption2            // ~11pt - maps to labelSmall

// Custom font with Dynamic Type support:
Font.custom("BrandFont-Regular", size: 16, relativeTo: .body)
```

### Custom Typography System

```swift
// iOS: Custom typography theme
enum AppTypography {
    static let displayLarge = Font.system(size: 57, weight: .regular, design: .default)
    static let headlineMedium = Font.system(size: 28, weight: .regular, design: .default)
    static let titleLarge = Font.system(size: 22, weight: .regular, design: .default)
    static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
    static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
}

// Prefer system text styles for Dynamic Type support:
Text("Hello")
    .font(.headline)  // Automatically scales with user settings
```

## Shape System Migration

```kotlin
// Android: Material Design 3 shapes
MaterialTheme.shapes.extraSmall  // 4.dp corner radius
MaterialTheme.shapes.small       // 8.dp
MaterialTheme.shapes.medium      // 12.dp
MaterialTheme.shapes.large       // 16.dp
MaterialTheme.shapes.extraLarge  // 28.dp
```

```swift
// iOS: Equivalent shape usage
RoundedRectangle(cornerRadius: 4)   // extraSmall
RoundedRectangle(cornerRadius: 8)   // small
RoundedRectangle(cornerRadius: 12)  // medium
RoundedRectangle(cornerRadius: 16)  // large
RoundedRectangle(cornerRadius: 28)  // extraLarge
Capsule()                            // fully rounded (pill shape)
Circle()                             // circular

// iOS convention: use continuous corner curves for a more natural look
.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
```

## Icon Migration: Material Icons to SF Symbols

Material Icons do not exist on iOS. Replace them with SF Symbols, Apple's built-in icon library with 5,000+ symbols.

| Material Icon | SF Symbol |
|---------------|-----------|
| `Icons.Default.Home` | `house` or `house.fill` |
| `Icons.Default.Search` | `magnifyingglass` |
| `Icons.Default.Settings` | `gearshape` or `gearshape.fill` |
| `Icons.Default.Person` | `person` or `person.fill` |
| `Icons.Default.Add` | `plus` |
| `Icons.Default.Delete` | `trash` or `trash.fill` |
| `Icons.Default.Edit` | `pencil` |
| `Icons.Default.Share` | `square.and.arrow.up` |
| `Icons.Default.Close` | `xmark` |
| `Icons.Default.ArrowBack` | `chevron.left` (auto in navigation) |
| `Icons.Default.Check` | `checkmark` |
| `Icons.Default.Star` | `star` or `star.fill` |
| `Icons.Default.Favorite` | `heart` or `heart.fill` |
| `Icons.Default.Notifications` | `bell` or `bell.fill` |
| `Icons.Default.Email` | `envelope` or `envelope.fill` |
| `Icons.Default.Phone` | `phone` or `phone.fill` |
| `Icons.Default.Camera` | `camera` or `camera.fill` |
| `Icons.Default.Map` / `Icons.Default.Place` | `map` or `mappin` |
| `Icons.Default.MoreVert` | `ellipsis` |
| `Icons.Default.Menu` | `line.3.horizontal` |
| `Icons.Default.Refresh` | `arrow.clockwise` |
| `Icons.Default.Download` | `arrow.down.circle` |
| `Icons.Default.Info` | `info.circle` |
| `Icons.Default.Warning` | `exclamationmark.triangle` |
| `Icons.Default.Error` | `exclamationmark.circle` |

```kotlin
// Android
Icon(
    imageVector = Icons.Default.Favorite,
    contentDescription = "Like",
    tint = MaterialTheme.colorScheme.primary
)
```

```swift
// iOS
Image(systemName: "heart.fill")
    .foregroundStyle(Color.accentColor)
    .accessibilityLabel("Like")

// With rendering mode for multicolor symbols:
Image(systemName: "heart.fill")
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(.red)
```

## Component Migration Examples

### Top App Bar to Navigation Bar

```kotlin
// Android
@Composable
fun MyScreen() {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("My Screen") },
                navigationIcon = {
                    IconButton(onClick = { /* back */ }) {
                        Icon(Icons.AutoMirrored.Default.ArrowBack, "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { /* settings */ }) {
                        Icon(Icons.Default.Settings, "Settings")
                    }
                }
            )
        }
    ) { padding ->
        Content(modifier = Modifier.padding(padding))
    }
}
```

```swift
// iOS
struct MyScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ContentView()
            .navigationTitle("My Screen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // settings
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
    }
}
// Note: Back button is automatic in NavigationStack
```

### Bottom Navigation to TabView

```kotlin
// Android
@Composable
fun MainScreen() {
    val navController = rememberNavController()
    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    icon = { Icon(Icons.Default.Home, "Home") },
                    label = { Text("Home") },
                    selected = currentRoute == "home",
                    onClick = { navController.navigate("home") }
                )
                NavigationBarItem(
                    icon = { Icon(Icons.Default.Search, "Search") },
                    label = { Text("Search") },
                    selected = currentRoute == "search",
                    onClick = { navController.navigate("search") }
                )
                NavigationBarItem(
                    icon = { Icon(Icons.Default.Person, "Profile") },
                    label = { Text("Profile") },
                    selected = currentRoute == "profile",
                    onClick = { navController.navigate("profile") }
                )
            }
        }
    ) { padding ->
        NavHost(navController, startDestination = "home", modifier = Modifier.padding(padding)) {
            composable("home") { HomeScreen() }
            composable("search") { SearchScreen() }
            composable("profile") { ProfileScreen() }
        }
    }
}
```

```swift
// iOS
struct MainView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person")
            }
        }
    }
}
```

### AlertDialog

```kotlin
// Android
AlertDialog(
    onDismissRequest = { showDialog = false },
    title = { Text("Delete Item") },
    text = { Text("Are you sure you want to delete this item?") },
    confirmButton = {
        TextButton(onClick = { deleteItem(); showDialog = false }) {
            Text("Delete")
        }
    },
    dismissButton = {
        TextButton(onClick = { showDialog = false }) {
            Text("Cancel")
        }
    }
)
```

```swift
// iOS
.alert("Delete Item", isPresented: $showDialog) {
    Button("Delete", role: .destructive) {
        deleteItem()
    }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("Are you sure you want to delete this item?")
}
```

### BottomSheet

```kotlin
// Android
ModalBottomSheet(
    onDismissRequest = { showSheet = false },
    sheetState = rememberModalBottomSheetState()
) {
    Column(modifier = Modifier.padding(16.dp)) {
        Text("Sheet Content")
    }
}
```

```swift
// iOS
.sheet(isPresented: $showSheet) {
    VStack {
        Text("Sheet Content")
    }
    .padding(16)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
}
```

## Common Pitfalls and Gotchas

1. **Do not replicate Material Design on iOS** -- iOS users expect native-looking apps. Using Material Design patterns (FABs, snackbars, navigation drawers) on iOS feels foreign. Translate the design intent, not the design system.

2. **Elevation and shadows** -- Material Design uses `tonalElevation` extensively (surface tint changes with elevation). iOS uses shadows sparingly. Prefer using background color differentiation (`systemBackground` vs `secondarySystemBackground`) over shadow-based elevation.

3. **Ripple effect** -- Material Design's ripple touch feedback has no iOS equivalent. SwiftUI buttons provide their own highlight states automatically. Do not add custom ripple effects on iOS.

4. **Dynamic Color is not a thing on iOS** -- Material You's wallpaper-based theming does not translate. Use the app's accent color and system adaptive colors instead.

5. **Typography scaling** -- Material Design uses `sp` (scalable pixels). iOS uses Dynamic Type, which is similar but has different scaling curves. Always use `Font.TextStyle` presets for accessibility compliance.

6. **Icon inconsistency** -- Material Icons and SF Symbols have different visual weights and styles. When mapping icons, match the semantic meaning, not the visual appearance. Use the SF Symbols app to find the best match.

7. **Navigation patterns differ** -- Android uses a bottom-up back stack with the system back button. iOS uses a left-edge swipe gesture and navigation bar back button. Do not override iOS's native back navigation behavior.

8. **Chip components** -- Material Design's `Chip` (filter, input, suggestion, assist) has no direct SwiftUI equivalent. Use `Button` with custom styling, `Menu`, or `Picker` depending on the chip's role.

9. **Snackbar replacement** -- iOS does not have a snackbar pattern. Use `.alert()`, a banner view at the top of the screen, or a temporary overlay. Consider whether the feedback is even necessary on iOS.

10. **Tab behavior** -- Material Design's `TabRow` with swipeable pages maps to a segmented `Picker` for few items, or a custom scrolling tab bar. `TabView` with `TabViewStyle.page` provides swipeable pages but looks different from Material tabs.

11. **Dark mode** -- Both platforms support dark mode, but iOS system colors adapt automatically. If using custom colors, define Light and Dark variants in the asset catalog. Avoid hard-coding color values.

12. **Safe area handling** -- Material Design's `Scaffold` handles system bars via `padding`. SwiftUI views automatically respect safe areas. Use `.ignoresSafeArea()` only when intentionally drawing behind system bars (e.g., full-bleed images).

## Migration Checklist

1. **Audit the Material Design theme** -- Document all custom colors, typography overrides, and shape customizations in the Android app's theme.
2. **Map colors to iOS equivalents** -- Replace Material color roles with iOS system colors. Create custom color sets in the asset catalog for brand colors with light/dark variants.
3. **Set the accent color** -- Define the app's accent color in the asset catalog (this replaces Material's primary color).
4. **Replace typography** -- Map Material typography styles to iOS `Font.TextStyle` presets. Use `Font.custom()` with `relativeTo:` for custom fonts that support Dynamic Type.
5. **Replace Material Icons with SF Symbols** -- Map every `Icon` usage to an SF Symbol. Use the SF Symbols app to find matches. For custom icons not in SF Symbols, import SVG assets.
6. **Convert Material components to native iOS** -- Replace `TopAppBar` with `.navigationTitle`, `NavigationBar` with `TabView`, `AlertDialog` with `.alert()`, `BottomSheet` with `.sheet()`.
7. **Remove Material-specific patterns** -- Remove FABs (use toolbar buttons), ripple effects (automatic in SwiftUI), and snackbars (use alerts or banners).
8. **Handle elevation** -- Replace `tonalElevation` and `shadowElevation` with background color differentiation. Use `.shadow()` sparingly and only for floating elements.
9. **Verify dark mode** -- Test all custom colors in both light and dark mode. Ensure sufficient contrast ratios (4.5:1 for text).
10. **Verify Dynamic Type** -- Test all text at the largest and smallest Dynamic Type sizes. Ensure layouts adapt without truncation or overflow.
11. **Test accessibility** -- Verify VoiceOver reads all interactive elements correctly. Ensure touch targets are at least 44x44 points (iOS minimum).
12. **Review with HIG** -- Compare the final iOS implementation against Apple's Human Interface Guidelines for the specific components used.
