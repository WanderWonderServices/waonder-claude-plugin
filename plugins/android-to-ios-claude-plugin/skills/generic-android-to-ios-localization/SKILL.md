---
name: generic-android-to-ios-localization
description: Guides migration of Android localization (strings.xml, values-es/, plurals, string arrays, format args, translation management) to iOS equivalents (String Catalogs .xcstrings Xcode 15+, Localizable.strings legacy, String(localized:), plurals, device variations) with file format mapping, plural handling, format arguments, RTL support, and testing
type: generic
---

# generic-android-to-ios-localization

## Context

Android localization centers on `strings.xml` files organized in locale-specific `values-*` directories, with built-in support for plurals, string arrays, and format arguments. iOS has evolved significantly: Xcode 15 introduced String Catalogs (`.xcstrings`), a JSON-based unified format that replaces the legacy `Localizable.strings` and `Localizable.stringsdict` files. Modern iOS localization uses `String(localized:)` for runtime lookup, supports plurals and device variations natively in String Catalogs, and integrates with Xcode's export/import workflow for translator handoff. This skill maps Android's localization patterns to their modern iOS equivalents, covering both String Catalogs and legacy formats.

## Android Best Practices (Source Patterns)

### Basic Strings (strings.xml)

```xml
<!-- res/values/strings.xml (default / English) -->
<resources>
    <string name="app_name">Waonder</string>
    <string name="welcome_message">Welcome to Waonder</string>
    <string name="login_button">Log In</string>
    <string name="greeting">Hello, %1$s!</string>
    <string name="item_count">You have %1$d items</string>
    <string name="price_format">%1$s%.2f</string>
    <string name="terms_html"><![CDATA[By continuing, you agree to our <b>Terms of Service</b>]]></string>
</resources>

<!-- res/values-es/strings.xml (Spanish) -->
<resources>
    <string name="app_name">Waonder</string>
    <string name="welcome_message">Bienvenido a Waonder</string>
    <string name="login_button">Iniciar Sesión</string>
    <string name="greeting">¡Hola, %1$s!</string>
    <string name="item_count">Tienes %1$d elementos</string>
</resources>
```

### Plurals

```xml
<!-- res/values/strings.xml -->
<plurals name="messages_count">
    <item quantity="zero">No messages</item>
    <item quantity="one">%d message</item>
    <item quantity="other">%d messages</item>
</plurals>

<plurals name="days_remaining">
    <item quantity="one">%d day remaining</item>
    <item quantity="other">%d days remaining</item>
</plurals>
```

```kotlin
// Usage in Kotlin
val text = resources.getQuantityString(R.plurals.messages_count, count, count)
```

### String Arrays

```xml
<string-array name="sort_options">
    <item>Name</item>
    <item>Date</item>
    <item>Size</item>
    <item>Type</item>
</string-array>
```

```kotlin
val options = resources.getStringArray(R.array.sort_options)
```

### Format Arguments in Compose

```kotlin
// Using stringResource
@Composable
fun Greeting(name: String) {
    Text(text = stringResource(R.string.greeting, name))
}

@Composable
fun ItemCount(count: Int) {
    Text(text = pluralStringResource(R.plurals.messages_count, count, count))
}
```

### Configuration Qualifiers

```
res/
  values/          (default)
  values-es/       (Spanish)
  values-es-rMX/   (Mexican Spanish)
  values-fr/       (French)
  values-zh-rCN/   (Simplified Chinese)
  values-ar/       (Arabic - RTL)
  values-land/     (landscape)
  values-sw600dp/  (tablet)
```

## iOS Equivalent Patterns

### String Catalogs (.xcstrings) - Xcode 15+

```
// File: Localizable.xcstrings (created via File > New > String Catalog)
// This is a JSON file managed by Xcode. You typically edit it in Xcode's
// String Catalog editor, not manually.

// In Xcode UI, you see a table:
// Key                    | English              | Spanish
// -----------------------|----------------------|------------------------
// welcome_message        | Welcome to Waonder   | Bienvenido a Waonder
// login_button           | Log In               | Iniciar Sesión
// greeting %@            | Hello, %@!           | ¡Hola, %@!
// item_count %lld        | You have %lld items  | Tienes %lld elementos
```

The JSON structure (for reference, not manual editing):
```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "welcome_message" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Welcome to Waonder"
          }
        },
        "es" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Bienvenido a Waonder"
          }
        }
      }
    }
  }
}
```

### Basic String Usage in Swift

```swift
// Modern approach: String(localized:) - iOS 16+
let welcome = String(localized: "welcome_message")
let login = String(localized: "login_button")

// With format arguments
// The key in String Catalog: "greeting \(name)"
// or explicitly: "Hello, \(name)!"
let greeting = String(localized: "Hello, \(name)!")

// With explicit table (file) reference
let text = String(localized: "key", table: "FeatureStrings")

// With default value and comment for translators
let label = String(
    localized: "welcome_message",
    defaultValue: "Welcome to Waonder",
    comment: "Shown on the home screen when user first opens the app"
)

// Legacy approach: NSLocalizedString (still works)
let legacy = NSLocalizedString("welcome_message", comment: "Welcome screen title")
let legacyFormatted = String(format: NSLocalizedString("greeting", comment: ""), name)
```

### String Usage in SwiftUI

```swift
// SwiftUI Text automatically looks up localization keys
struct WelcomeView: View {
    let name: String
    let count: Int

    var body: some View {
        VStack {
            // Automatic lookup - "welcome_message" is the key
            Text("welcome_message")

            // With interpolation - key includes the interpolation
            Text("Hello, \(name)!")

            // Explicit LocalizedStringKey
            Text(LocalizedStringKey("login_button"))

            // Verbatim (NOT localized)
            Text(verbatim: "Not a localization key")
        }
    }
}
```

### Plurals in String Catalogs

```swift
// In the String Catalog editor, create a key with "Vary by Plural"
// Key: "%lld messages"
// Variations:
//   zero:  "No messages"
//   one:   "%lld message"
//   other: "%lld messages"

// Usage in Swift
let messageCount = String(localized: "\(count) messages")

// In SwiftUI
Text("\(count) messages")

// For more complex plural strings
// Key: "%lld days remaining"
// one:   "%lld day remaining"
// other: "%lld days remaining"
let daysText = String(localized: "\(days) days remaining")
```

### Legacy Plurals (Localizable.stringsdict)

```xml
<!-- Localizable.stringsdict (before String Catalogs) -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>messages_count</key>
    <dict>
        <key>NSStringLocalizedFormatKey</key>
        <string>%#@count@</string>
        <key>count</key>
        <dict>
            <key>NSStringFormatSpecTypeKey</key>
            <string>NSStringPluralRuleType</string>
            <key>NSStringFormatValueTypeKey</key>
            <string>d</string>
            <key>zero</key>
            <string>No messages</string>
            <key>one</key>
            <string>%d message</string>
            <key>other</key>
            <string>%d messages</string>
        </dict>
    </dict>
</dict>
</plist>
```

### String Arrays Equivalent

```swift
// iOS has no direct string array localization.
// Option 1: Localize each item individually
let sortOptions = [
    String(localized: "sort_name"),
    String(localized: "sort_date"),
    String(localized: "sort_size"),
    String(localized: "sort_type")
]

// Option 2: Use a plist with localized variants
// SortOptions.plist in each .lproj folder

// Option 3: Numbered keys
let sortOptions = (0..<4).map { index in
    String(localized: "sort_option_\(index)")
}
```

### Format Arguments Mapping

```swift
// Android: %1$s    ->  iOS: %@ (positional: %1$@)
// Android: %1$d    ->  iOS: %lld (positional: %1$lld)
// Android: %1$.2f  ->  iOS: %.2f (positional: %1$.2f)

// With String(localized:) and interpolation (preferred)
let greeting = String(localized: "Hello, \(name)!")
let price = String(localized: "Price: \(price, specifier: "%.2f")")

// With NSLocalizedString + String(format:) (legacy)
let greeting = String(
    format: NSLocalizedString("greeting", comment: ""),
    name
)

// SwiftUI with specifier
Text("Price: \(price, specifier: "%.2f")")
```

### Device Variations in String Catalogs

```swift
// String Catalogs support device-specific variations
// In the editor, select a key and choose "Vary by Device"
// Options: iPhone, iPad, Apple Watch, Apple TV, Mac

// Key: "tap_to_continue"
// iPhone: "Tap to continue"
// iPad:   "Tap or click to continue"
// Mac:    "Click to continue"

// Usage is the same - the system selects automatically
Text("tap_to_continue")
```

### RTL Support

```swift
// SwiftUI handles RTL layout automatically when locale is RTL
// Leading/trailing are preferred over left/right

VStack(alignment: .leading) {  // Flips for RTL
    Text("content")
        .frame(maxWidth: .infinity, alignment: .leading)
}
.padding(.leading, 16)  // Flips for RTL

// Force specific direction (rare)
Text("English text in RTL context")
    .environment(\.layoutDirection, .leftToRight)

// Image flipping for RTL
Image(systemName: "arrow.right")
    .flipsForRightToLeftLayoutDirection(true)

// Check current layout direction
@Environment(\.layoutDirection) var layoutDirection

var body: some View {
    if layoutDirection == .rightToLeft {
        // RTL-specific adjustments
    }
}

// Semantic content attribute (UIKit)
view.semanticContentAttribute = .forceLeftToRight  // Prevents flipping
```

### Locale-Aware Formatting

```swift
// Numbers
let formatted = count.formatted()  // Locale-aware by default
let currency = price.formatted(.currency(code: "USD"))
let percent = ratio.formatted(.percent)

// Dates
let dateString = date.formatted(date: .abbreviated, time: .shortened)
let relative = date.formatted(.relative(presentation: .named))

// Measurements
let distance = Measurement(value: 5.0, unit: UnitLength.kilometers)
    .formatted(.measurement(width: .abbreviated))

// Lists
let list = ["Apple", "Banana", "Cherry"]
    .formatted(.list(type: .and))  // "Apple, Banana, and Cherry"
```

### Translation Workflow

```swift
// 1. Add all user-facing strings in code using String(localized:) or SwiftUI Text
// 2. Build the project - Xcode auto-discovers strings and adds to String Catalog
// 3. Export for translation:
//    Product > Export Localizations... (generates .xcloc files)
// 4. Send .xcloc files to translators
// 5. Import translations:
//    Product > Import Localizations... (imports .xcloc files)

// Adding a new language:
// Project > Info > Localizations > + > Select language
// Xcode automatically creates entries in String Catalogs

// String extraction comments (help translators)
Text("greeting \(name)", comment: "Shown on home screen after login. 'name' is the user's first name.")
```

## File Format Mapping

| Android | iOS (Modern) | iOS (Legacy) |
|---------|-------------|-------------|
| `res/values/strings.xml` | `Localizable.xcstrings` (single file, all locales) | `en.lproj/Localizable.strings` |
| `res/values-es/strings.xml` | Same `.xcstrings` file (Spanish column) | `es.lproj/Localizable.strings` |
| `res/values-es-rMX/strings.xml` | String Catalog with `es-MX` locale | `es-MX.lproj/Localizable.strings` |
| Plurals in `strings.xml` | "Vary by Plural" in String Catalog | `Localizable.stringsdict` |
| `string-array` | No equivalent; use individual keys | No equivalent |
| `R.string.key` | `String(localized: "key")` | `NSLocalizedString("key", comment: "")` |
| `stringResource()` in Compose | `Text("key")` in SwiftUI | `Text(LocalizedStringKey("key"))` |
| Format `%1$s` | `\(variable)` in String interpolation | `%@` |
| Format `%1$d` | `\(variable)` | `%lld` |
| `values-land/` | Device variations in String Catalog | N/A |

## Common Pitfalls

1. **Using String(verbatim:) or raw strings accidentally** - `Text("hello")` is a localization key lookup. `Text(verbatim: "hello")` or `Text(someStringVariable)` is not. Be intentional about which is used.

2. **Not adding translator comments** - String Catalogs support comments. Always add context for translators, especially for format strings or ambiguous words.

3. **Hardcoded format specifiers** - When migrating from `%1$s`/`%1$d`, use Swift string interpolation with `String(localized:)` instead of `String(format:)` whenever possible. It is safer and works seamlessly with String Catalogs.

4. **Forgetting plural categories** - Arabic requires `zero`, `one`, `two`, `few`, `many`, and `other`. Russian needs `one`, `few`, `many`, `other`. Always provide all CLDR-required plural categories for each target language.

5. **Not testing with pseudolocalization** - Enable "Show non-localized strings" and "Double-length pseudolanguage" in scheme settings (Edit Scheme > Run > Options > App Language) to catch layout issues.

6. **Using left/right instead of leading/trailing** - For RTL support, always use `.leading`/`.trailing` in SwiftUI and avoid hardcoded `.left`/`.right` margins or alignments.

7. **Mixing String Catalogs and legacy files** - While both can coexist, avoid having the same key in both `.xcstrings` and `.strings` files. String Catalogs take precedence but this creates confusion.

8. **Not exporting for translation** - Xcode's Export Localizations generates `.xcloc` packages that translators can open in standard tools. Do not ask translators to edit `.xcstrings` JSON directly.

## Migration Checklist

- [ ] Create a `Localizable.xcstrings` String Catalog in the Xcode project (File > New > String Catalog)
- [ ] Add all target languages in Project > Info > Localizations
- [ ] Migrate all `strings.xml` keys to Swift code using `String(localized:)` or SwiftUI `Text("key")`
- [ ] Convert format strings from `%1$s`/`%1$d` to Swift string interpolation `\(variable)`
- [ ] Migrate plurals from `<plurals>` XML to String Catalog "Vary by Plural" entries
- [ ] Replace `string-array` items with individual localized string keys
- [ ] Add translator comments to all strings, especially format strings and ambiguous terms
- [ ] Replace left/right layout references with leading/trailing for RTL support
- [ ] Add `.flipsForRightToLeftLayoutDirection(true)` to directional images
- [ ] Use `Formatters` (`.formatted()`) for numbers, dates, and currencies instead of manual formatting
- [ ] Build the project to auto-populate String Catalog with discovered strings
- [ ] Export localizations (Product > Export Localizations) and send `.xcloc` files to translators
- [ ] Import completed translations (Product > Import Localizations)
- [ ] Test with pseudolocalization (Edit Scheme > Run > Options > App Language > Double Length)
- [ ] Test with RTL languages (Arabic, Hebrew) to verify layout flipping
- [ ] Test with the largest Dynamic Type setting to ensure localized text does not overflow
- [ ] Verify all String Catalog entries show "Translated" state (not "New" or "Needs Review")
