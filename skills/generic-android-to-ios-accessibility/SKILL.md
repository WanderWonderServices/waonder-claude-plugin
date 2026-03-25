---
name: generic-android-to-ios-accessibility
description: Guides migration of Android accessibility (contentDescription, AccessibilityNodeInfo, custom actions, live regions, TalkBack, AccessibilityService) to iOS equivalents (accessibilityLabel/Hint/Traits/Value, VoiceOver, accessibilityElement, Dynamic Type, reduce motion) with semantic equivalents, screen reader testing, and custom actions
type: generic
---

# generic-android-to-ios-accessibility

## Context

Android and iOS both provide rich accessibility frameworks, but they differ significantly in API design and terminology. Android uses `contentDescription`, `AccessibilityNodeInfo`, and `AccessibilityDelegate` with TalkBack as the primary screen reader. iOS uses `accessibilityLabel`, `accessibilityHint`, `accessibilityTraits`, and `accessibilityValue` with VoiceOver. SwiftUI provides declarative accessibility modifiers that are often more concise than their Android counterparts. This skill maps every major Android accessibility concept to its iOS/SwiftUI equivalent, covering screen readers, Dynamic Type (font scaling), reduced motion, and custom accessibility actions.

## Android Best Practices (Source Patterns)

### Content Descriptions

```kotlin
// Compose
Image(
    painter = painterResource(R.drawable.profile),
    contentDescription = "User profile photo"
)

// Decorative image (ignored by screen reader)
Image(
    painter = painterResource(R.drawable.divider),
    contentDescription = null
)

// View system (XML)
// android:contentDescription="User profile photo"
// android:importantForAccessibility="no" (decorative)
```

### Semantic Grouping and Merging

```kotlin
// Compose: merge descendants into single accessibility node
Row(
    modifier = Modifier.semantics(mergeDescendants = true) {
        contentDescription = "John Doe, Software Engineer, Online"
    }
) {
    Avatar(user)
    Column {
        Text("John Doe")
        Text("Software Engineer")
    }
    OnlineIndicator()
}

// Clickable item reads as one unit
Row(
    modifier = Modifier
        .clickable { onItemClick() }
        .semantics(mergeDescendants = true) {}
) {
    Text("Settings")
    Icon(Icons.Default.ChevronRight, contentDescription = null)
}
```

### Custom Accessibility Actions

```kotlin
Box(
    modifier = Modifier.semantics {
        contentDescription = "Email from John: Meeting tomorrow"
        customActions = listOf(
            CustomAccessibilityAction("Delete") { deleteEmail(); true },
            CustomAccessibilityAction("Archive") { archiveEmail(); true },
            CustomAccessibilityAction("Reply") { replyToEmail(); true }
        )
    }
)
```

### Live Regions (Dynamic Content Announcements)

```kotlin
// Compose
Text(
    text = "3 items in cart",
    modifier = Modifier.semantics {
        liveRegion = LiveRegionMode.Polite  // or Assertive
    }
)

// Imperative announcement
val context = LocalContext.current
fun announceChange(message: String) {
    val manager = context.getSystemService(Context.ACCESSIBILITY_SERVICE)
        as AccessibilityManager
    if (manager.isEnabled) {
        val event = AccessibilityEvent.obtain(
            AccessibilityEvent.TYPE_ANNOUNCEMENT
        ).apply {
            text.add(message)
        }
        manager.sendAccessibilityEvent(event)
    }
}
```

### Headings and Traversal Order

```kotlin
Text(
    text = "Account Settings",
    modifier = Modifier.semantics { heading() }
)

// Custom traversal order
Column(
    modifier = Modifier.semantics {
        traversalIndex = 1f  // Lower = earlier in reading order
    }
)
```

### State Descriptions

```kotlin
Switch(
    checked = isEnabled,
    onCheckedChange = { onToggle(it) },
    modifier = Modifier.semantics {
        stateDescription = if (isEnabled) "Enabled" else "Disabled"
        contentDescription = "Dark mode"
    }
)
```

### Accessibility Roles

```kotlin
Box(
    modifier = Modifier.semantics {
        role = Role.Button
        contentDescription = "Submit form"
    }
)

// Available roles: Button, Checkbox, Switch, RadioButton,
// Tab, Image, DropdownList
```

### Font Scaling Support

```kotlin
// Compose respects system font scale by default with sp units
Text(
    text = "Hello",
    fontSize = 16.sp  // Scales with system settings
)

// Prevent scaling for specific text
Text(
    text = "99+",
    fontSize = with(LocalDensity.current) { 12.dp.toSp() }  // Fixed size
)
```

## iOS Equivalent Patterns

### Accessibility Labels, Hints, and Traits

```swift
// Basic label (equivalent to contentDescription)
Image("profile")
    .accessibilityLabel("User profile photo")

// Decorative image (equivalent to importantForAccessibility="no")
Image("divider")
    .accessibilityHidden(true)

// Label + hint (hint describes what happens on activation)
Button(action: { submitForm() }) {
    Text("Submit")
}
.accessibilityLabel("Submit form")
.accessibilityHint("Double tap to submit your application")

// Value for dynamic content
Slider(value: $volume, in: 0...100)
    .accessibilityLabel("Volume")
    .accessibilityValue("\(Int(volume)) percent")
```

### Semantic Grouping and Element Combining

```swift
// Combine children into a single accessibility element
// Equivalent to mergeDescendants = true
HStack {
    Avatar(user: user)
    VStack(alignment: .leading) {
        Text("John Doe")
        Text("Software Engineer")
    }
    OnlineIndicator()
}
.accessibilityElement(children: .combine)

// Ignore children and provide custom label
HStack {
    Text("John Doe")
    Text("Software Engineer")
    Image(systemName: "circle.fill").foregroundColor(.green)
}
.accessibilityElement(children: .ignore)
.accessibilityLabel("John Doe, Software Engineer, Online")

// Clickable row as single unit
Button(action: { openSettings() }) {
    HStack {
        Text("Settings")
        Spacer()
        Image(systemName: "chevron.right")
    }
}
.accessibilityElement(children: .combine)
```

### Custom Accessibility Actions

```swift
// Equivalent to CustomAccessibilityAction
VStack {
    Text("Email from John")
    Text("Meeting tomorrow")
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Email from John: Meeting tomorrow")
.accessibilityAction(named: "Delete") {
    deleteEmail()
}
.accessibilityAction(named: "Archive") {
    archiveEmail()
}
.accessibilityAction(named: "Reply") {
    replyToEmail()
}

// Custom adjustable action (increment/decrement with swipe)
struct RatingView: View {
    @Binding var rating: Int

    var body: some View {
        HStack {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Rating")
        .accessibilityValue("\(rating) out of 5 stars")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                rating = min(5, rating + 1)
            case .decrement:
                rating = max(1, rating - 1)
            @unknown default:
                break
            }
        }
    }
}
```

### Live Regions and Announcements

```swift
// Equivalent to LiveRegionMode.Polite
Text("3 items in cart")
    .accessibilityLabel("3 items in cart")
    .accessibilityAddTraits(.updatesFrequently)

// Post announcement (equivalent to AccessibilityEvent.TYPE_ANNOUNCEMENT)
func announceChange(_ message: String) {
    UIAccessibility.post(
        notification: .announcement,
        argument: message
    )
}

// Screen changed announcement (after navigation)
func announceScreenChange(_ screenName: String) {
    UIAccessibility.post(
        notification: .screenChanged,
        argument: screenName
    )
}

// Layout changed (when elements are added/removed)
func announceLayoutChange(_ element: Any?) {
    UIAccessibility.post(
        notification: .layoutChanged,
        argument: element  // Pass the element to focus, or a string to announce
    )
}
```

### Headings and Sort Priority

```swift
// Mark as heading (equivalent to heading())
Text("Account Settings")
    .font(.title)
    .accessibilityAddTraits(.isHeader)

// Control reading order (equivalent to traversalIndex)
VStack {
    Text("Welcome message")
        .accessibilitySortPriority(2)  // Higher = read first
    Text("Main content")
        .accessibilitySortPriority(1)
}
```

### Accessibility Traits (Role Equivalents)

```swift
// Map of Android Role to iOS Trait
// Role.Button -> .isButton
// Role.Checkbox -> .isToggle (or custom)
// Role.Switch -> .isToggle
// Role.Image -> .isImage
// Role.Tab -> .isTabBar (on container)
// heading() -> .isHeader
// selected -> .isSelected

Text("Custom button")
    .accessibilityAddTraits(.isButton)
    .accessibilityRemoveTraits(.isStaticText)

// Multiple traits
Image("map_pin")
    .accessibilityAddTraits([.isImage, .isButton])
    .accessibilityLabel("Location pin")
    .accessibilityHint("Double tap to view location details")

// State description for toggles
Toggle("Dark Mode", isOn: $isDarkMode)
    .accessibilityLabel("Dark Mode")
    // SwiftUI Toggle handles on/off state automatically
```

### Dynamic Type (Font Scaling)

```swift
// SwiftUI scales text automatically with semantic fonts
Text("Hello")
    .font(.body)  // Scales with Dynamic Type

// Custom font with scaling
Text("Hello")
    .font(.custom("Avenir", size: 16, relativeTo: .body))

// Fixed size (does NOT scale - use sparingly)
Text("99+")
    .font(.system(size: 12))
    .dynamicTypeSize(.large)  // Lock to specific size

// Limit scaling range
Text("Badge count")
    .dynamicTypeSize(.small ... .xxxLarge)

// Respond to size category in layout
@Environment(\.dynamicTypeSize) var dynamicTypeSize

var body: some View {
    if dynamicTypeSize >= .accessibility1 {
        // Stack vertically for very large text
        VStack(alignment: .leading) {
            label
            value
        }
    } else {
        HStack {
            label
            Spacer()
            value
        }
    }
}

// Scaled metric for spacing/sizing
@ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 24
@ScaledMetric var spacing: CGFloat = 8

Image(systemName: "star")
    .frame(width: iconSize, height: iconSize)
```

### Reduce Motion

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var body: some View {
    ContentView()
        .animation(reduceMotion ? .none : .spring(), value: isExpanded)
        .transition(reduceMotion ? .opacity : .slide)
}

// Conditional animation
withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
    isExpanded.toggle()
}
```

### Reduce Transparency

```swift
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

var body: some View {
    Rectangle()
        .fill(reduceTransparency ? Color.black : Color.black.opacity(0.7))
}
```

### VoiceOver Detection

```swift
@Environment(\.accessibilityVoiceOverEnabled) var isVoiceOverRunning

var body: some View {
    if isVoiceOverRunning {
        // Provide alternative layout for VoiceOver users
        AccessibleChartView(data: chartData)
    } else {
        InteractiveChartView(data: chartData)
    }
}

// UIKit check
let isVoiceOverOn = UIAccessibility.isVoiceOverRunning

// Notification for changes
NotificationCenter.default.addObserver(
    forName: UIAccessibility.voiceOverStatusDidChangeNotification,
    object: nil,
    queue: .main
) { _ in
    // Update UI
}
```

### Accessibility Rotor (Custom Navigation)

```swift
// Allows VoiceOver users to navigate between specific elements
struct ArticleView: View {
    let headings: [Heading]
    let links: [Link]

    var body: some View {
        ScrollView {
            content
        }
        .accessibilityRotor("Headings") {
            ForEach(headings) { heading in
                AccessibilityRotorEntry(heading.text, id: heading.id)
            }
        }
        .accessibilityRotor("Links") {
            ForEach(links) { link in
                AccessibilityRotorEntry(link.title, id: link.id)
            }
        }
    }
}
```

### Accessibility in UIKit (for hybrid apps)

```swift
// UIKit equivalents
let imageView = UIImageView(image: UIImage(named: "profile"))
imageView.isAccessibilityElement = true
imageView.accessibilityLabel = "User profile photo"
imageView.accessibilityTraits = .image

// Container
let container = UIView()
container.isAccessibilityElement = false
container.accessibilityElements = [label, button]  // Explicit ordering

// Decorative
let decorativeView = UIView()
decorativeView.isAccessibilityElement = false

// Custom action
let cell = UITableViewCell()
cell.accessibilityCustomActions = [
    UIAccessibilityCustomAction(name: "Delete") { _ in
        self.deleteItem()
        return true
    },
    UIAccessibilityCustomAction(name: "Archive") { _ in
        self.archiveItem()
        return true
    }
]
```

## Concept Mapping

| Android | iOS (SwiftUI) |
|---------|---------------|
| `contentDescription` | `.accessibilityLabel()` |
| N/A (separate concept) | `.accessibilityHint()` (what happens on activation) |
| `stateDescription` | `.accessibilityValue()` |
| `Role.Button`, `Role.Image` | `.accessibilityAddTraits(.isButton)`, `.isImage` |
| `semantics { heading() }` | `.accessibilityAddTraits(.isHeader)` |
| `mergeDescendants = true` | `.accessibilityElement(children: .combine)` |
| `importantForAccessibility="no"` | `.accessibilityHidden(true)` |
| `CustomAccessibilityAction` | `.accessibilityAction(named:)` |
| `liveRegion = Polite` | `UIAccessibility.post(notification: .announcement)` |
| `traversalIndex` | `.accessibilitySortPriority()` |
| `AccessibilityEvent.TYPE_ANNOUNCEMENT` | `UIAccessibility.post(notification: .announcement)` |
| `sp` units (auto-scale) | `.font(.body)` semantic fonts (auto-scale) |
| `AccessibilityManager.isEnabled` | `UIAccessibility.isVoiceOverRunning` |
| TalkBack | VoiceOver |
| `AccessibilityNodeInfo` | `UIAccessibilityElement` |
| Notification channels (a11y) | N/A (different concept on iOS) |

## Common Pitfalls

1. **Not providing accessibilityHint** - Android only has `contentDescription`. iOS separates the label (what it is) from the hint (what happens). Always provide hints for interactive elements.

2. **Forgetting children: .combine for grouped content** - Without combining, VoiceOver reads each child separately. Group related content (e.g., name + subtitle) with `.accessibilityElement(children: .combine)`.

3. **Using fixed font sizes** - SwiftUI semantic fonts scale automatically with Dynamic Type. Using `.font(.system(size: 16))` defeats scaling. Always use `.body`, `.title`, etc., or `.custom(name:size:relativeTo:)`.

4. **Ignoring accessibility size categories** - When Dynamic Type is set to accessibility sizes (Accessibility1-5), layouts can break. Use `@Environment(\.dynamicTypeSize)` to provide alternative layouts.

5. **Animations without reduce motion check** - Always respect `@Environment(\.accessibilityReduceMotion)`. Users who enable this setting may experience motion sickness.

6. **Not testing with VoiceOver** - Enable VoiceOver in Settings > Accessibility > VoiceOver, or use the Accessibility Inspector in Xcode. Keyboard shortcut in Simulator: Cmd+F5.

7. **Over-using accessibilityHidden** - Hiding too many elements makes the app unusable for screen reader users. Only hide truly decorative elements.

8. **Not handling VoiceOver focus after navigation** - When presenting new content, post `.screenChanged` notification so VoiceOver focuses on the new screen.

## Migration Checklist

- [ ] Map all `contentDescription` to `.accessibilityLabel()` on every interactive and meaningful element
- [ ] Add `.accessibilityHint()` to buttons and interactive elements explaining what activation does
- [ ] Map `semantics(mergeDescendants = true)` to `.accessibilityElement(children: .combine)` or `.ignore`
- [ ] Convert `CustomAccessibilityAction` to `.accessibilityAction(named:)` modifiers
- [ ] Replace `liveRegion` with `UIAccessibility.post(notification: .announcement)` calls
- [ ] Map `heading()` to `.accessibilityAddTraits(.isHeader)` on section titles
- [ ] Map Android `Role` to iOS accessibility traits (`.isButton`, `.isImage`, `.isToggle`, etc.)
- [ ] Convert `traversalIndex` to `.accessibilitySortPriority()` (note: higher priority = read first, opposite of Android)
- [ ] Replace `sp`-based font sizing with SwiftUI semantic fonts for automatic Dynamic Type support
- [ ] Use `@ScaledMetric` for icon sizes and spacing that should scale with Dynamic Type
- [ ] Add `@Environment(\.dynamicTypeSize)` checks for alternative layouts at accessibility sizes
- [ ] Implement reduce motion support with `@Environment(\.accessibilityReduceMotion)`
- [ ] Test every screen with VoiceOver enabled (Settings > Accessibility > VoiceOver)
- [ ] Verify reading order is logical on every screen using VoiceOver navigation
- [ ] Run Accessibility Inspector (Xcode > Open Developer Tool) audit on all screens
- [ ] Test with largest Dynamic Type setting (Settings > Accessibility > Display & Text Size > Larger Text)
- [ ] Ensure color contrast meets WCAG 2.1 AA (4.5:1 for text, 3:1 for large text)
