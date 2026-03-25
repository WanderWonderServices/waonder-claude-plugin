---
name: generic-android-to-ios-local-assets
description: Guides migration of Android local assets (res/drawable vectors/bitmaps/9-patch, res/raw, res/font, assets/ directory, density qualifiers) to iOS equivalents (Asset Catalogs .xcassets with image sets/symbol images, SF Symbols, Bundle resources, custom fonts via Info.plist, @1x/@2x/@3x density handling)
type: generic
---

# generic-android-to-ios-local-assets

## Context

Android manages local assets through the `res/` directory hierarchy (drawable, raw, font, mipmap) with density qualifiers (`-mdpi`, `-hdpi`, `-xhdpi`, `-xxhdpi`, `-xxxhdpi`) for automatic device-appropriate resource selection. The `assets/` directory provides raw file access via `AssetManager`. iOS uses Asset Catalogs (`.xcassets`) for images, colors, and data with `@1x`/`@2x`/`@3x` scale variants, SF Symbols for system iconography, and the app Bundle for raw file access. This skill maps every Android asset type to its idiomatic iOS equivalent.

## Concept Mapping

| Android | iOS |
|---------|-----|
| `res/drawable/` (bitmap) | Asset Catalog Image Set (`.imageset`) |
| `res/drawable/` (vector XML) | Asset Catalog SVG/PDF or SF Symbol |
| `res/drawable/` (9-patch `.9.png`) | `UIImage.resizableImage(withCapInsets:)` or Asset Catalog Slicing |
| `res/mipmap/` (app icon) | Asset Catalog AppIcon (`.appiconset`) |
| `res/raw/` | Bundle resource (added to target) |
| `res/font/` | Bundle font + Info.plist `UIAppFonts` entry |
| `assets/` directory | Bundle resource or Asset Catalog Data Set (`.dataset`) |
| Density qualifiers (`-mdpi`, `-xxhdpi`) | Scale variants `@1x`, `@2x`, `@3x` |
| `VectorDrawable` (XML) | SF Symbol or SVG in Asset Catalog (Preserve Vector Data) |
| `AnimatedVectorDrawable` | Lottie animation or `UIImage.animatedImage` |
| `LayerDrawable` | `ZStack` with multiple `Image` views or custom drawing |
| `StateListDrawable` | SwiftUI conditional rendering or `UIImage` symbol configurations |
| `ShapeDrawable` | SwiftUI `Shape` (`RoundedRectangle`, `Circle`, `Capsule`) |
| `GradientDrawable` | SwiftUI `LinearGradient`, `RadialGradient`, `AngularGradient` |
| `R.drawable.name` | `Image("name")` or `UIImage(named: "name")` |
| `R.font.name` | `Font.custom("FontName", size:)` or `UIFont(name:size:)` |
| `R.raw.name` | `Bundle.main.url(forResource:withExtension:)` |

## Android Best Practices (Source Patterns)

### Vector Drawables

```xml
<!-- res/drawable/ic_landmark.xml -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="?attr/colorControlNormal">
    <path
        android:fillColor="@android:color/white"
        android:pathData="M12,2C8.13,2 5,5.13 5,9c0,5.25 7,13 7,13s7,-7.75 7,-13c0,-3.87 -3.13,-7 -7,-7z
            M12,11.5c-1.38,0 -2.5,-1.12 -2.5,-2.5s1.12,-2.5 2.5,-2.5 2.5,1.12 2.5,2.5 -1.12,2.5 -2.5,2.5z" />
</vector>
```

### Bitmap Drawables with Density Qualifiers

```
res/
  drawable-mdpi/       → @1x (baseline, 160 dpi)
    landmark_hero.png  → 100x100 px
  drawable-hdpi/       → @1.5x (240 dpi)
    landmark_hero.png  → 150x150 px
  drawable-xhdpi/      → @2x (320 dpi)
    landmark_hero.png  → 200x200 px
  drawable-xxhdpi/     → @3x (480 dpi)
    landmark_hero.png  → 300x300 px
  drawable-xxxhdpi/    → @4x (640 dpi, rare)
    landmark_hero.png  → 400x400 px
```

### 9-Patch Images

```
res/
  drawable/
    button_background.9.png   ← Stretchable regions defined by 1px border
```

### Font Resources

```xml
<!-- res/font/inter.xml (font family definition) -->
<font-family xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto">
    <font
        android:fontStyle="normal"
        android:fontWeight="400"
        android:font="@font/inter_regular"
        app:fontStyle="normal"
        app:fontWeight="400"
        app:font="@font/inter_regular" />
    <font
        android:fontStyle="normal"
        android:fontWeight="600"
        android:font="@font/inter_semibold"
        app:fontStyle="normal"
        app:fontWeight="600"
        app:font="@font/inter_semibold" />
    <font
        android:fontStyle="normal"
        android:fontWeight="700"
        android:font="@font/inter_bold"
        app:fontStyle="normal"
        app:fontWeight="700"
        app:font="@font/inter_bold" />
</font-family>
```

```
res/
  font/
    inter_regular.ttf
    inter_semibold.ttf
    inter_bold.ttf
    inter.xml          ← Font family definition
```

### Raw Resources and Assets

```kotlin
// Accessing raw resources
val inputStream = resources.openRawResource(R.raw.sample_data)
val jsonString = inputStream.bufferedReader().use { it.readText() }

// Accessing assets/ directory
val assetManager = context.assets
val configStream = assetManager.open("config/defaults.json")
val fileList = assetManager.list("maps/tiles")

// Drawable usage in Compose
Image(
    painter = painterResource(id = R.drawable.ic_landmark),
    contentDescription = "Landmark",
    modifier = Modifier.size(24.dp)
)

// Tinting vectors in Compose
Icon(
    painter = painterResource(id = R.drawable.ic_landmark),
    contentDescription = "Landmark",
    tint = MaterialTheme.colorScheme.primary
)
```

### Drawable Types in XML

```xml
<!-- StateListDrawable: different images per state -->
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:state_pressed="true" android:drawable="@drawable/btn_pressed" />
    <item android:state_enabled="false" android:drawable="@drawable/btn_disabled" />
    <item android:drawable="@drawable/btn_normal" />
</selector>

<!-- GradientDrawable -->
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <gradient
        android:startColor="#FF6200EE"
        android:endColor="#FF03DAC5"
        android:angle="135" />
    <corners android:radius="12dp" />
</shape>

<!-- LayerDrawable -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape android:shape="rectangle">
            <solid android:color="@color/surface" />
            <corners android:radius="16dp" />
        </shape>
    </item>
    <item android:gravity="center">
        <bitmap android:src="@drawable/ic_landmark" />
    </item>
</layer-list>
```

## iOS Equivalent Patterns

### Asset Catalog Image Sets

Each image set is a `.imageset` directory inside `.xcassets` containing scale variants and a `Contents.json`:

```json
// Images.xcassets/LandmarkHero.imageset/Contents.json
{
  "images": [
    {
      "filename": "landmark_hero.png",
      "idiom": "universal",
      "scale": "1x"
    },
    {
      "filename": "landmark_hero@2x.png",
      "idiom": "universal",
      "scale": "2x"
    },
    {
      "filename": "landmark_hero@3x.png",
      "idiom": "universal",
      "scale": "3x"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

```swift
// Using Asset Catalog images in SwiftUI
Image("LandmarkHero")
    .resizable()
    .aspectRatio(contentMode: .fill)
    .frame(width: 200, height: 200)
    .clipped()

// UIKit equivalent
let image = UIImage(named: "LandmarkHero")
```

### Density Mapping

```
Android density qualifier → iOS scale factor

mdpi    (160 dpi, 1x)    → @1x (rarely needed, iPad 2 era)
hdpi    (240 dpi, 1.5x)  → No direct equivalent (not used on iOS)
xhdpi   (320 dpi, 2x)    → @2x (standard retina: iPhone SE, iPad)
xxhdpi  (480 dpi, 3x)    → @3x (iPhone 6 Plus and later, Super Retina)
xxxhdpi (640 dpi, 4x)    → No equivalent (iOS caps at @3x)

Practical rule: Provide @2x and @3x. @1x is optional (no modern iOS devices use it).
```

### SVG and PDF Vector Assets (Replacing VectorDrawables)

```json
// Images.xcassets/Landmark.imageset/Contents.json
// For SVG with "Preserve Vector Data" enabled
{
  "images": [
    {
      "filename": "landmark.svg",
      "idiom": "universal"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  },
  "properties": {
    "preserves-vector-representation": true
  }
}
```

```swift
// SVG/PDF vector images render at any size without pixelation
Image("Landmark")
    .resizable()
    .frame(width: 48, height: 48)

// For template rendering (equivalent to android:tint on VectorDrawable)
Image("Landmark")
    .renderingMode(.template)
    .foregroundStyle(.waonderPrimary)
```

### SF Symbols (Replacing Common Material Icons)

SF Symbols is Apple's icon library with 5000+ symbols. It replaces most Material Icons and custom vector drawables for standard UI iconography.

```swift
// Common Android Material Icon → SF Symbol mapping
// ic_home         → "house.fill"
// ic_search       → "magnifyingglass"
// ic_settings     → "gearshape.fill"
// ic_location     → "location.fill"
// ic_map          → "map.fill"
// ic_bookmark     → "bookmark.fill"
// ic_share        → "square.and.arrow.up"
// ic_camera       → "camera.fill"
// ic_close        → "xmark"
// ic_back_arrow   → "chevron.left"
// ic_more_vert    → "ellipsis"
// ic_add          → "plus"
// ic_check        → "checkmark"
// ic_error        → "exclamationmark.triangle.fill"
// ic_person       → "person.fill"
// ic_star         → "star.fill"
// ic_navigate     → "arrow.triangle.turn.up.right.diamond.fill"

// Using SF Symbols in SwiftUI
Image(systemName: "mappin.circle.fill")
    .font(.title2)
    .foregroundStyle(.waonderPrimary)

// With symbol configuration (equivalent to tint + size)
Image(systemName: "location.fill")
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(.waonderPrimary)
    .font(.system(size: 24, weight: .medium))

// Multicolor SF Symbols
Image(systemName: "externaldrive.badge.checkmark")
    .symbolRenderingMode(.multicolor)

// Symbol with variable value (e.g., signal strength)
Image(systemName: "wifi", variableValue: 0.7)
    .symbolRenderingMode(.hierarchical)

// Symbol effect (animated, iOS 17+)
Image(systemName: "location.fill")
    .symbolEffect(.pulse, isActive: isSearching)
```

### App Icon (Replacing res/mipmap/)

```json
// Assets.xcassets/AppIcon.appiconset/Contents.json
// Since Xcode 15, a single 1024x1024 PNG is sufficient
{
  "images": [
    {
      "filename": "AppIcon.png",
      "idiom": "universal",
      "platform": "ios",
      "size": "1024x1024"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

### Custom Fonts (Replacing res/font/)

1. Add font files (`.ttf` or `.otf`) to the Xcode project and ensure they are included in the target.

2. Register fonts in Info.plist:

```xml
<key>UIAppFonts</key>
<array>
    <string>Inter-Regular.ttf</string>
    <string>Inter-SemiBold.ttf</string>
    <string>Inter-Bold.ttf</string>
</array>
```

3. Use in code:

```swift
// SwiftUI
Text("Landmark Name")
    .font(.custom("Inter-SemiBold", size: 18, relativeTo: .headline))

Text("Description")
    .font(.custom("Inter-Regular", size: 16, relativeTo: .body))

// UIKit
let titleFont = UIFont(name: "Inter-SemiBold", size: 18)
let bodyFont = UIFont(name: "Inter-Regular", size: 16)

// Font with Dynamic Type support (scales with accessibility settings)
let scaledFont = UIFontMetrics(forTextStyle: .headline)
    .scaledFont(for: UIFont(name: "Inter-SemiBold", size: 18)!)

// Design system font extension
extension Font {
    static func waonderHeadline(_ size: CGFloat = 18) -> Font {
        .custom("Inter-SemiBold", size: size, relativeTo: .headline)
    }

    static func waonderBody(_ size: CGFloat = 16) -> Font {
        .custom("Inter-Regular", size: size, relativeTo: .body)
    }

    static func waonderBold(_ size: CGFloat = 18) -> Font {
        .custom("Inter-Bold", size: size, relativeTo: .headline)
    }
}

// Usage
Text("Landmark Name")
    .font(.waonderHeadline())
```

### Resizable Images (Replacing 9-Patch)

```swift
// Programmatic slicing (equivalent to 9-patch stretchable regions)
let buttonBg = UIImage(named: "ButtonBackground")?
    .resizableImage(
        withCapInsets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12),
        resizingMode: .stretch
    )

// In Asset Catalog: Use Xcode's Slicing editor
// 1. Select the image set in Asset Catalog
// 2. Click "Show Slicing" in the bottom bar
// 3. Define horizontal and vertical insets
// The result is equivalent to 9-patch stretchable regions
```

### Bundle Resources (Replacing res/raw/ and assets/)

```swift
// Reading a raw file from the bundle (equivalent to R.raw.sample_data)
guard let url = Bundle.main.url(forResource: "sample_data", withExtension: "json") else {
    fatalError("Missing sample_data.json in bundle")
}
let data = try Data(contentsOf: url)
let json = try JSONDecoder().decode(SampleData.self, from: data)

// Reading text file
guard let path = Bundle.main.path(forResource: "terms", ofType: "txt") else { return }
let text = try String(contentsOfFile: path, encoding: .utf8)

// Listing files in a bundle subdirectory (equivalent to AssetManager.list())
guard let resourcePath = Bundle.main.resourcePath else { return }
let mapTilesPath = (resourcePath as NSString).appendingPathComponent("MapTiles")
let files = try FileManager.default.contentsOfDirectory(atPath: mapTilesPath)

// Asset Catalog Data Set for arbitrary files
// Create a .dataset in the Asset Catalog, add the file, access via NSDataAsset:
guard let asset = NSDataAsset(name: "DefaultConfig") else { return }
let config = try JSONDecoder().decode(Config.self, from: asset.data)
```

### Drawable Types Converted to SwiftUI

```swift
// GradientDrawable → SwiftUI LinearGradient
RoundedRectangle(cornerRadius: 12)
    .fill(
        LinearGradient(
            colors: [Color(hex: "#6200EE"), Color(hex: "#03DAC5")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

// StateListDrawable → Conditional rendering in SwiftUI
struct StatefulButton: View {
    let isEnabled: Bool
    @State private var isPressed = false

    var body: some View {
        Image(isEnabled ? (isPressed ? "btn_pressed" : "btn_normal") : "btn_disabled")
    }
}

// Or using ButtonStyle for proper press state handling
struct WaonderIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// LayerDrawable → ZStack
ZStack {
    RoundedRectangle(cornerRadius: 16)
        .fill(Color.waonderSurface)
    Image("Landmark")
        .resizable()
        .frame(width: 48, height: 48)
}

// ShapeDrawable → SwiftUI Shape
struct WaonderBadge: View {
    var body: some View {
        Capsule()
            .fill(Color.waonderPrimary)
            .frame(width: 80, height: 32)
            .overlay {
                Text("NEW")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
            }
    }
}
```

## Key Differences and Pitfalls

### 1. iOS Uses 3 Scale Factors, Not 5 Density Buckets
Android has mdpi through xxxhdpi (5 densities). iOS has @1x, @2x, @3x (3 scales). Modern iOS devices only use @2x and @3x, so providing just those two is sufficient. There is no @1.5x equivalent for hdpi.

### 2. VectorDrawable XML Cannot Be Used Directly
Android's VectorDrawable XML format is proprietary. Convert vectors to SVG (preferred) or PDF for Asset Catalogs. Alternatively, find an equivalent SF Symbol. Do not try to parse Android vector XML on iOS.

### 3. SF Symbols Replace Most Icon Assets
Before creating custom image assets, check if an SF Symbol exists. SF Symbols automatically support Dynamic Type scaling, accessibility, weight variants, and rendering modes. They also match the platform's native look.

### 4. 9-Patch Has No Direct Format Equivalent
iOS does not support `.9.png` files. Use Asset Catalog slicing (configured in Xcode's image editor) or `UIImage.resizableImage(withCapInsets:)` to achieve the same stretchable behavior.

### 5. Font Registration Requires Info.plist Entry
Unlike Android where fonts in `res/font/` are automatically available, iOS requires each font file to be listed in Info.plist under `UIAppFonts`. Missing this entry causes `UIFont(name:size:)` to return `nil` silently.

### 6. Asset Catalog Names Are Case-Sensitive
Android resource names are lowercase with underscores (`ic_landmark`). Asset Catalog names are case-sensitive and conventionally use PascalCase (`Landmark`) or the original filename. Establish a consistent naming convention during migration.

### 7. Bundle Resources Are Read-Only
Both Android `res/raw/` and iOS Bundle resources are read-only. However, Android's `assets/` directory can be listed with `AssetManager.list()`. On iOS, listing Bundle subdirectory contents requires using `FileManager` rather than a simple API call.

### 8. Animated Vector Drawables Need Lottie or Manual Conversion
Android's `AnimatedVectorDrawable` has no direct iOS equivalent. Use Lottie (After Effects animations exported as JSON) for complex animations, or recreate the animation using SwiftUI's animation system for simple path morphing.

### 9. Template Rendering Mode Must Be Set Explicitly
Android's `android:tint` on vector drawables automatically applies tinting. In SwiftUI, you must explicitly set `.renderingMode(.template)` on the `Image` to enable tinting via `.foregroundStyle()`. Asset Catalog images can also be configured as "Template Image" in Xcode.

## Migration Checklist

- [ ] Audit all `res/drawable/` vector XMLs; convert to SVG or identify equivalent SF Symbols
- [ ] Export bitmap drawables at @2x and @3x scales; create Asset Catalog Image Sets
- [ ] Convert the app icon from `res/mipmap/` to a single 1024x1024 PNG in AppIcon asset
- [ ] Convert 9-patch images to Asset Catalog images with slicing configured in Xcode
- [ ] Migrate `res/font/` files: add `.ttf`/`.otf` to the Xcode target and register in Info.plist `UIAppFonts`
- [ ] Create type-safe `Font` extensions for the design system fonts with Dynamic Type support
- [ ] Move `res/raw/` files to the Xcode target as Bundle resources
- [ ] Move `assets/` files to Bundle resources or Asset Catalog Data Sets (`.dataset`)
- [ ] Replace `StateListDrawable` selectors with `ButtonStyle` or conditional SwiftUI rendering
- [ ] Replace `GradientDrawable` shapes with SwiftUI `LinearGradient`/`RadialGradient` and `Shape` types
- [ ] Replace `LayerDrawable` layer-lists with `ZStack` compositions
- [ ] Map all Material Icons to SF Symbols using the SF Symbols app's search
- [ ] Set rendering mode to `.template` on all icons that need tinting
- [ ] Enable "Preserve Vector Data" on SVG/PDF assets that render at multiple sizes
- [ ] Verify custom fonts render correctly at all Dynamic Type sizes
- [ ] Test Asset Catalog images on both @2x devices (iPhone SE) and @3x devices (iPhone 15)
