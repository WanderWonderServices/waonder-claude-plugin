---
name: generic-android-to-ios-widgets
description: Use when migrating Android widget patterns (AppWidgetProvider, Glance Compose widgets, RemoteViews, widget configuration, update strategies) to iOS WidgetKit equivalents (Widget protocol, TimelineProvider, TimelineEntry, IntentConfiguration, interactive widgets iOS 17+) covering widget architecture, timeline-based updates, user configuration, interactivity, and deep linking
type: generic
---

# generic-android-to-ios-widgets

## Context

Android widgets are rendered in the launcher process using `RemoteViews` (or Jetpack Glance for a Compose-like API) and can update on schedules, broadcasts, or user interaction. iOS widgets use WidgetKit with a fundamentally different architecture: they are SwiftUI-based, timeline-driven, and rendered by the system from snapshots. Interactive widgets (buttons, toggles) were introduced in iOS 17. This skill maps Android widget patterns to idiomatic iOS WidgetKit equivalents, covering the architectural shift from on-demand rendering to timeline-based snapshots.

## Android Best Practices (Source Patterns)

### AppWidgetProvider (Classic)

```kotlin
// AndroidManifest.xml
// <receiver android:name=".widget.MyWidgetProvider" android:exported="true">
//     <intent-filter>
//         <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
//     </intent-filter>
//     <meta-data android:name="android.appwidget.provider"
//         android:resource="@xml/my_widget_info" />
// </receiver>

// res/xml/my_widget_info.xml
// <appwidget-provider
//     android:minWidth="250dp"
//     android:minHeight="100dp"
//     android:updatePeriodMillis="3600000"
//     android:initialLayout="@layout/widget_layout"
//     android:resizeMode="horizontal|vertical"
//     android:widgetCategory="home_screen"
//     android:configure="com.example.WidgetConfigActivity" />

class MyWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        for (widgetId in widgetIds) {
            updateWidget(context, manager, widgetId)
        }
    }

    private fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_layout)
        views.setTextViewText(R.id.widget_title, "Hello Widget")
        views.setTextViewText(R.id.widget_subtitle, "Last updated: ${Date()}")

        // Deep link on tap
        val intent = Intent(context, MainActivity::class.java).apply {
            data = Uri.parse("myapp://detail/123")
        }
        val pendingIntent = PendingIntent.getActivity(
            context, widgetId, intent, PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        manager.updateAppWidget(widgetId, views)
    }

    override fun onDeleted(context: Context, widgetIds: IntArray) {
        // Clean up per-widget data
    }
}
```

### Glance Widget (Compose-style)

```kotlin
class MyGlanceWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = fetchWidgetData()
        provideContent {
            MyWidgetContent(data)
        }
    }

    @Composable
    private fun MyWidgetContent(data: WidgetData) {
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(Color.White)
                .padding(16.dp)
                .clickable(actionStartActivity<MainActivity>(
                    actionParametersOf(ActionParameters.Key<String>("id") to data.id)
                ))
        ) {
            Text(
                text = data.title,
                style = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.Bold)
            )
            Spacer(modifier = GlanceModifier.height(8.dp))
            Text(text = data.subtitle)
            Button(
                text = "Refresh",
                onClick = actionRunCallback<RefreshAction>()
            )
        }
    }
}

class RefreshAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        MyGlanceWidget().update(context, glanceId)
    }
}
```

### Widget Configuration Activity

```kotlin
class WidgetConfigActivity : ComponentActivity() {

    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        // Show configuration UI, then:
        // saveConfiguration(widgetId, config)
        // updateWidget(widgetId)
        // setResult(RESULT_OK, Intent().putExtra(EXTRA_APPWIDGET_ID, widgetId))
        // finish()
    }
}
```

### Manual Widget Updates

```kotlin
// Trigger update from anywhere
fun updateAllWidgets(context: Context) {
    val manager = AppWidgetManager.getInstance(context)
    val ids = manager.getAppWidgetIds(ComponentName(context, MyWidgetProvider::class.java))
    val intent = Intent(context, MyWidgetProvider::class.java).apply {
        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
    }
    context.sendBroadcast(intent)
}

// Glance widget manual update
suspend fun updateGlanceWidget(context: Context) {
    MyGlanceWidget().updateAll(context)
}
```

### Key Android Patterns to Recognize

- `AppWidgetProvider.onUpdate` — called on schedule or broadcast
- `RemoteViews` — cross-process view rendering (limited view types)
- `GlanceAppWidget` — Compose-style widget API
- `AppWidgetManager.updateAppWidget` — pushes new content to the widget
- `updatePeriodMillis` — minimum update interval (30 minutes minimum)
- `setOnClickPendingIntent` — tap handling via PendingIntent
- Configure activity — setup UI shown when widget is first placed

## iOS Best Practices (Target Patterns)

### Basic Widget Structure

```swift
import WidgetKit
import SwiftUI

// Widget entry — represents a single point in time
struct MyWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let deepLinkID: String
}

// Timeline provider — supplies widget content
struct MyWidgetProvider: TimelineProvider {
    // Placeholder shown while widget loads
    func placeholder(in context: Context) -> MyWidgetEntry {
        MyWidgetEntry(date: .now, title: "Loading...", subtitle: "", deepLinkID: "")
    }

    // Snapshot for widget gallery preview
    func getSnapshot(in context: Context, completion: @escaping (MyWidgetEntry) -> Void) {
        let entry = MyWidgetEntry(
            date: .now,
            title: "Sample Title",
            subtitle: "Sample subtitle",
            deepLinkID: "123"
        )
        completion(entry)
    }

    // Full timeline with future entries
    func getTimeline(in context: Context, completion: @escaping (Timeline<MyWidgetEntry>) -> Void) {
        Task {
            let data = await fetchWidgetData()
            let entry = MyWidgetEntry(
                date: .now,
                title: data.title,
                subtitle: data.subtitle,
                deepLinkID: data.id
            )
            // Refresh after 1 hour
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// Widget view
struct MyWidgetView: View {
    let entry: MyWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title)
                .font(.headline)
            Text(entry.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(entry.date, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "myapp://detail/\(entry.deepLinkID)"))
    }
}

// Widget definition
@main
struct MyWidget: Widget {
    let kind = "MyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MyWidgetProvider()) { entry in
            MyWidgetView(entry: entry)
        }
        .configurationDisplayName("My Widget")
        .description("Shows the latest data.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
```

### Multiple Widget Sizes

```swift
struct MyWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: MyWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: MyWidgetEntry
    var body: some View {
        VStack {
            Text(entry.title)
                .font(.headline)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MediumWidgetView: View {
    let entry: MyWidgetEntry
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(entry.title).font(.headline)
                Text(entry.subtitle).font(.subheadline)
            }
            Spacer()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
```

### Configurable Widget (User Configuration)

```swift
import AppIntents

// iOS 17+ — AppIntent-based configuration
struct SelectCategoryIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Category"
    static var description = IntentDescription("Choose which category to display.")

    @Parameter(title: "Category", default: .general)
    var category: WidgetCategory
}

enum WidgetCategory: String, AppEnum {
    case general, sports, tech

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Category")
    static var caseDisplayRepresentations: [WidgetCategory: DisplayRepresentation] = [
        .general: "General",
        .sports: "Sports",
        .tech: "Technology"
    ]
}

struct ConfigurableProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MyWidgetEntry {
        MyWidgetEntry(date: .now, title: "Loading...", subtitle: "", deepLinkID: "")
    }

    func snapshot(for configuration: SelectCategoryIntent, in context: Context) async -> MyWidgetEntry {
        MyWidgetEntry(date: .now, title: "Preview", subtitle: configuration.category.rawValue, deepLinkID: "")
    }

    func timeline(for configuration: SelectCategoryIntent, in context: Context) async -> Timeline<MyWidgetEntry> {
        let data = await fetchData(for: configuration.category)
        let entry = MyWidgetEntry(date: .now, title: data.title, subtitle: data.subtitle, deepLinkID: data.id)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600)))
    }
}

struct ConfigurableWidget: Widget {
    let kind = "ConfigurableWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectCategoryIntent.self, provider: ConfigurableProvider()) { entry in
            MyWidgetView(entry: entry)
        }
        .configurationDisplayName("Category Widget")
        .description("Shows data for a selected category.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

### Interactive Widgets (iOS 17+)

```swift
// iOS 17+ — Buttons and toggles in widgets
struct InteractiveWidgetView: View {
    let entry: MyWidgetEntry

    var body: some View {
        VStack {
            Text(entry.title)
                .font(.headline)

            // Button that performs an AppIntent
            Button(intent: RefreshWidgetIntent()) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            // Toggle
            Toggle(isOn: entry.isFavorite, intent: ToggleFavoriteIntent(itemID: entry.deepLinkID)) {
                Label("Favorite", systemImage: "star")
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct RefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Widget"

    func perform() async throws -> some IntentResult {
        // Perform action
        WidgetCenter.shared.reloadTimelines(ofKind: "MyWidget")
        return .result()
    }
}

struct ToggleFavoriteIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Favorite"

    @Parameter(title: "Item ID")
    var itemID: String

    init() {}
    init(itemID: String) { self.itemID = itemID }

    func perform() async throws -> some IntentResult {
        // Toggle favorite in database
        await DataStore.shared.toggleFavorite(itemID)
        WidgetCenter.shared.reloadTimelines(ofKind: "MyWidget")
        return .result()
    }
}
```

### Triggering Widget Updates from the App

```swift
import WidgetKit

// Reload all timelines for a specific widget kind
WidgetCenter.shared.reloadTimelines(ofKind: "MyWidget")

// Reload all widget timelines
WidgetCenter.shared.reloadAllTimelines()

// Share data between app and widget using App Groups
// 1. Enable App Groups capability for both app target and widget extension
// 2. Use shared UserDefaults or shared container

let sharedDefaults = UserDefaults(suiteName: "group.com.myapp.shared")
sharedDefaults?.set("Updated data", forKey: "widgetData")

// In the TimelineProvider, read from the same shared container
let sharedDefaults = UserDefaults(suiteName: "group.com.myapp.shared")
let data = sharedDefaults?.string(forKey: "widgetData")
```

### Deep Linking from Widgets

```swift
// In widget view — single link for the entire widget (small)
struct SmallWidgetView: View {
    let entry: MyWidgetEntry
    var body: some View {
        Text(entry.title)
            .widgetURL(URL(string: "myapp://detail/\(entry.deepLinkID)"))
            .containerBackground(.fill.tertiary, for: .widget)
    }
}

// In medium/large widgets — multiple link targets
struct MediumWidgetView: View {
    let entries: [Item]
    var body: some View {
        VStack {
            ForEach(entries) { item in
                Link(destination: URL(string: "myapp://detail/\(item.id)")!) {
                    Text(item.title)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// Handle deep link in the app
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Parse url.path and navigate accordingly
                }
        }
    }
}
```

### Widget Bundle (Multiple Widgets)

```swift
@main
struct MyWidgetBundle: WidgetBundle {
    var body: some Widget {
        MyWidget()
        ConfigurableWidget()
        // Up to 5 widgets in a bundle (use WidgetBundleBuilder for more)
    }
}
```

## Migration Mapping Table

| Android | iOS (WidgetKit) |
|---|---|
| `AppWidgetProvider` | `Widget` protocol + `TimelineProvider` |
| `GlanceAppWidget` | `Widget` protocol (SwiftUI-native) |
| `RemoteViews` | SwiftUI views (rendered as snapshots) |
| `onUpdate()` callback | `getTimeline()` / `timeline(for:in:)` |
| `updatePeriodMillis` | `TimelineReloadPolicy` (`.after(date)`, `.atEnd`, `.never`) |
| `AppWidgetManager.updateAppWidget` | `WidgetCenter.shared.reloadTimelines(ofKind:)` |
| `setOnClickPendingIntent` | `.widgetURL()` or `Link(destination:)` |
| Widget configuration Activity | `AppIntentConfiguration` + `WidgetConfigurationIntent` |
| `@xml/appwidget_info` (sizes) | `.supportedFamilies([.systemSmall, ...])` |
| `resizeMode` | `.supportedFamilies` (discrete sizes, no free resizing) |
| Glance `Button` / `onClick` | `Button(intent:)` (iOS 17+) |
| `SharedPreferences` for widget data | `UserDefaults(suiteName:)` with App Groups |
| `WorkManager` for widget refresh | `TimelineReloadPolicy` + background app refresh |
| `onDeleted()` / `onDisabled()` | No direct equivalent (use `onBackgroundURLSessionEvents` if needed) |

## Common Pitfalls

1. **Expecting real-time updates** — iOS widgets are timeline-based snapshots. The system decides when to actually refresh the widget based on battery, usage patterns, and timeline policy. You cannot force an immediate visual update. Design for eventual consistency.

2. **Trying to use networking directly in widget views** — Widget views must be pure SwiftUI. All data fetching happens in the `TimelineProvider`. The view only renders from the `TimelineEntry`. Do not make network calls in the view body.

3. **Forgetting App Groups** — The widget extension runs in a separate process. It cannot access the main app's `UserDefaults`, Core Data, or file system unless you configure App Groups and use the shared container.

4. **Widget size assumptions** — Android widgets can be freely resized. iOS widgets come in fixed families (small, medium, large, extraLarge, accessory). Design for each supported size explicitly using `@Environment(\.widgetFamily)`.

5. **No persistent state in widgets** — iOS widgets are stateless snapshots. Each timeline reload creates fresh entries. Do not store mutable state in the widget — persist data in the shared App Group container and read it in `getTimeline()`.

6. **Interactive widgets require iOS 17+** — Buttons and toggles in widgets using `AppIntent` only work on iOS 17+. For earlier versions, all taps must use `widgetURL` or `Link` to deep link into the app. Plan your minimum deployment target accordingly.

7. **Timeline budget limits** — iOS imposes a daily budget for timeline reload requests. If you call `reloadTimelines` too frequently, the system will throttle your widget. Batch updates and use `.after(date)` reload policy wisely.

8. **Missing `containerBackground` modifier** — iOS 17+ requires `.containerBackground(for: .widget)` on widget views. Without it, the widget may render incorrectly or fail preview in Xcode.

## Migration Checklist

- [ ] Create a Widget Extension target in Xcode
- [ ] Configure App Groups capability for both app target and widget extension
- [ ] Define `TimelineEntry` struct with all data the widget needs to display
- [ ] Implement `TimelineProvider` (or `AppIntentTimelineProvider` for configurable widgets)
- [ ] Create SwiftUI views for each supported widget family (small, medium, large)
- [ ] Replace `RemoteViews` / Glance layouts with SwiftUI widget views
- [ ] Replace `setOnClickPendingIntent` with `.widgetURL()` and `Link(destination:)`
- [ ] Handle deep links in the main app via `.onOpenURL`
- [ ] Replace widget configuration Activity with `WidgetConfigurationIntent` (iOS 17+)
- [ ] Move data sharing to `UserDefaults(suiteName:)` via App Groups
- [ ] Replace `AppWidgetManager.updateAppWidget` with `WidgetCenter.shared.reloadTimelines(ofKind:)`
- [ ] Set appropriate `TimelineReloadPolicy` to replace `updatePeriodMillis`
- [ ] Add `Button(intent:)` for interactive elements if targeting iOS 17+
- [ ] Implement `.containerBackground(for: .widget)` for iOS 17+ compatibility
- [ ] Create a `WidgetBundle` if providing multiple widget types
- [ ] Test in widget gallery and on device (widgets behave differently in previews vs device)
