---
name: generic-android-to-ios-content-providers
description: Migrate Android ContentProvider patterns (CRUD via URI, ContentResolver, FileProvider) to iOS App Groups, UIActivityViewController, FileProvider extensions, and share extensions
type: generic
---

# generic-android-to-ios-content-providers

## Context

Android's `ContentProvider` is a component that manages access to a structured set of data, providing a standard CRUD interface via URIs. It enables inter-app data sharing (contacts, media, files) and intra-app data abstraction. `ContentResolver` is the client-side API for querying providers. `FileProvider` enables secure file sharing between apps via content URIs. iOS has no direct `ContentProvider` equivalent. Instead, iOS uses App Groups for sharing data between apps from the same developer, `UIActivityViewController` / `ShareLink` for user-initiated sharing, File Provider extensions for cloud storage integration, and Share extensions for receiving shared content from other apps.

## Concept Mapping

| Android | iOS |
|---|---|
| `ContentProvider` | No direct equivalent; see alternatives below |
| `ContentResolver.query()` | Direct database/file access within app; App Group shared container for cross-app |
| `ContentResolver.insert()` | Direct insert into local store |
| `ContentResolver.update()` | Direct update in local store |
| `ContentResolver.delete()` | Direct delete from local store |
| Content URI (`content://`) | No equivalent; use file URLs or App Group identifiers |
| `FileProvider` (share files via URI) | `UIActivityViewController` / `ShareLink` / File Provider extension |
| `ContentProvider` for Contacts | `CNContactStore` (Contacts framework) |
| `ContentProvider` for Media | `PHPhotoLibrary` (Photos framework) |
| `ContentProvider` for Calendar | `EKEventStore` (EventKit framework) |
| `ContentProvider` for Files | `UIDocumentPickerViewController` / `FileManager` |
| `ContentObserver` | `NSFetchedResultsController` / `NotificationCenter` / KVO |
| Cross-app data sharing | App Groups (shared `UserDefaults`, shared container) |
| Implicit intent for sharing | `UIActivityViewController` / `ShareLink` |
| Receiving shared content | Share Extension (app extension) |
| `getContentResolver()` | Framework-specific APIs (see above) |
| `CursorLoader` / `ContentProvider` query | SwiftData `@Query` / Core Data `NSFetchedResultsController` |
| `MediaStore` | `PHPhotoLibrary` |
| `DocumentsProvider` | File Provider extension |

## Code Patterns

### Intra-App Data Abstraction (ContentProvider as Repository)

**Android (ContentProvider for internal data):**
```kotlin
class ItemsProvider : ContentProvider() {
    private lateinit var database: AppDatabase

    override fun onCreate(): Boolean {
        database = AppDatabase.getInstance(context!!)
        return true
    }

    override fun query(
        uri: Uri,
        projection: Array<String>?,
        selection: String?,
        selectionArgs: Array<String>?,
        sortOrder: String?
    ): Cursor? {
        val cursor = when (uriMatcher.match(uri)) {
            ITEMS -> database.itemDao().getAllAsCursor()
            ITEM_ID -> database.itemDao().getByIdAsCursor(
                ContentUris.parseId(uri)
            )
            else -> throw IllegalArgumentException("Unknown URI: $uri")
        }
        cursor?.setNotificationUri(context?.contentResolver, uri)
        return cursor
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? {
        val id = database.itemDao().insert(Item.fromContentValues(values!!))
        context?.contentResolver?.notifyChange(uri, null)
        return ContentUris.withAppendedId(uri, id)
    }

    // update, delete similarly...
}

// Client code
val cursor = contentResolver.query(
    Uri.parse("content://com.myapp.provider/items"),
    null, null, null, null
)
```

**iOS (no ContentProvider needed -- use Repository pattern directly):**
```swift
// On iOS, there is no need for a ContentProvider abstraction for in-app data.
// Use a Repository pattern with SwiftData, Core Data, or any persistence layer.

import SwiftData

@Model
final class Item {
    var name: String
    var category: String
    var createdAt: Date

    init(name: String, category: String, createdAt: Date = .now) {
        self.name = name
        self.category = category
        self.createdAt = createdAt
    }
}

// Repository
@Observable
final class ItemRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll(sortBy: SortDescriptor<Item> = SortDescriptor(\.createdAt)) throws -> [Item] {
        let descriptor = FetchDescriptor<Item>(sortBy: [sortBy])
        return try modelContext.fetch(descriptor)
    }

    func fetchById(_ id: PersistentIdentifier) -> Item? {
        return modelContext.model(for: id) as? Item
    }

    func insert(_ item: Item) {
        modelContext.insert(item)
        try? modelContext.save()
    }

    func delete(_ item: Item) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}

// SwiftUI view with @Query (automatic observation, replaces ContentObserver)
struct ItemListView: View {
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List(items) { item in
            Text(item.name)
        }
    }
}
```

### ContentObserver to SwiftUI Observation

**Android:**
```kotlin
val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
    override fun onChange(selfChange: Boolean) {
        // Data changed, refresh UI
        loadItems()
    }
}
contentResolver.registerContentObserver(
    Uri.parse("content://com.myapp.provider/items"),
    true,
    observer
)

// Unregister
contentResolver.unregisterContentObserver(observer)
```

**iOS (SwiftData @Query -- automatic):**
```swift
// @Query automatically observes changes and updates the view
struct ItemListView: View {
    @Query private var items: [Item]

    var body: some View {
        List(items) { item in
            Text(item.name)
        }
        // View automatically refreshes when items change
    }
}

// Or with Core Data NSFetchedResultsController
final class ItemsViewModel: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    @Published var items: [ItemEntity] = []
    private let fetchedResultsController: NSFetchedResultsController<ItemEntity>

    init(context: NSManagedObjectContext) {
        let request = ItemEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ItemEntity.createdAt, ascending: false)]
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        super.init()
        fetchedResultsController.delegate = self
        try? fetchedResultsController.performFetch()
        items = fetchedResultsController.fetchedObjects ?? []
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        items = fetchedResultsController.fetchedObjects ?? []
    }
}
```

### FileProvider (Sharing Files Between Apps)

**Android:**
```xml
<!-- AndroidManifest.xml -->
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

```kotlin
// Share a file
val file = File(context.cacheDir, "shared_image.jpg")
val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)

val shareIntent = Intent(Intent.ACTION_SEND).apply {
    type = "image/jpeg"
    putExtra(Intent.EXTRA_STREAM, uri)
    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
}
startActivity(Intent.createChooser(shareIntent, "Share Image"))
```

**iOS (UIActivityViewController / ShareLink):**
```swift
// SwiftUI (iOS 16+)
struct ShareFileView: View {
    let fileURL: URL

    var body: some View {
        ShareLink(item: fileURL) {
            Label("Share File", systemImage: "square.and.arrow.up")
        }
    }
}

// Or share an image
struct ShareImageView: View {
    let image: Image

    var body: some View {
        ShareLink(
            item: image,
            preview: SharePreview("My Image", image: image)
        ) {
            Label("Share Image", systemImage: "square.and.arrow.up")
        }
    }
}

// Programmatic sharing (UIKit-based)
func shareFile(_ fileURL: URL, from viewController: UIViewController) {
    let activityVC = UIActivityViewController(
        activityItems: [fileURL],
        applicationActivities: nil
    )
    // Exclude specific activity types if needed
    activityVC.excludedActivityTypes = [.addToReadingList]
    viewController.present(activityVC, animated: true)
}

// SwiftUI wrapper for UIActivityViewController
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Usage
.sheet(isPresented: $showShare) {
    ActivityView(activityItems: [fileURL])
}
```

### Cross-App Data Sharing (App Groups)

**Android (ContentProvider for cross-app data):**
```kotlin
// App A exposes data via ContentProvider
class SharedDataProvider : ContentProvider() {
    override fun query(uri: Uri, ...): Cursor? {
        // Return shared data
    }
}

// App B queries it
val cursor = contentResolver.query(
    Uri.parse("content://com.myapp.a.provider/shared_data"),
    null, null, null, null
)
```

**iOS (App Groups -- only between apps from the same developer):**
```swift
// 1. Enable App Groups capability in both apps
// 2. Add the same App Group identifier: "group.com.mycompany.shared"

// App A: Write shared data
let sharedDefaults = UserDefaults(suiteName: "group.com.mycompany.shared")
sharedDefaults?.set("shared_value", forKey: "sharedKey")
sharedDefaults?.set(["item1", "item2"], forKey: "sharedList")

// App B: Read shared data
let sharedDefaults = UserDefaults(suiteName: "group.com.mycompany.shared")
let value = sharedDefaults?.string(forKey: "sharedKey")
let list = sharedDefaults?.stringArray(forKey: "sharedList")

// Shared file container (for larger data)
let containerURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.mycompany.shared"
)

// App A: Write a file
if let fileURL = containerURL?.appendingPathComponent("shared_data.json") {
    let data = try JSONEncoder().encode(sharedItems)
    try data.write(to: fileURL)
}

// App B: Read the file
if let fileURL = containerURL?.appendingPathComponent("shared_data.json") {
    let data = try Data(contentsOf: fileURL)
    let items = try JSONDecoder().decode([SharedItem].self, from: data)
}

// Shared Core Data / SwiftData store
// Point both apps at the same store in the shared container
let storeURL = containerURL?.appendingPathComponent("SharedStore.sqlite")
```

### Accessing System Content Providers

#### Contacts

**Android:**
```kotlin
val cursor = contentResolver.query(
    ContactsContract.Contacts.CONTENT_URI,
    arrayOf(ContactsContract.Contacts.DISPLAY_NAME),
    null, null, null
)
cursor?.use {
    while (it.moveToNext()) {
        val name = it.getString(0)
    }
}
```

**iOS:**
```swift
import Contacts

func fetchContacts() async throws -> [CNContact] {
    let store = CNContactStore()

    // Request access
    let authorized = try await store.requestAccess(for: .contacts)
    guard authorized else { throw ContactError.notAuthorized }

    let keys = [CNContactGivenNameKey, CNContactFamilyNameKey,
                CNContactPhoneNumbersKey] as [CNKeyDescriptor]
    let request = CNContactFetchRequest(keysToFetch: keys)

    var contacts: [CNContact] = []
    try store.enumerateContacts(with: request) { contact, _ in
        contacts.append(contact)
    }
    return contacts
}

// SwiftUI contact picker
import ContactsUI

struct ContactPickerButton: UIViewControllerRepresentable {
    @Binding var selectedContact: CNContact?

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController,
                                context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerButton
        init(_ parent: ContactPickerButton) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController,
                           didSelect contact: CNContact) {
            parent.selectedContact = contact
        }
    }
}
```

#### Photos / Media

**Android:**
```kotlin
val cursor = contentResolver.query(
    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
    arrayOf(MediaStore.Images.Media._ID, MediaStore.Images.Media.DISPLAY_NAME),
    null, null,
    "${MediaStore.Images.Media.DATE_ADDED} DESC"
)
```

**iOS:**
```swift
import Photos
import PhotosUI

// Fetch photos programmatically
func fetchPhotos() async -> [PHAsset] {
    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    guard status == .authorized || status == .limited else { return [] }

    let options = PHFetchOptions()
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    options.fetchLimit = 50

    let result = PHAsset.fetchAssets(with: .image, options: options)
    var assets: [PHAsset] = []
    result.enumerateObjects { asset, _, _ in
        assets.append(asset)
    }
    return assets
}

// SwiftUI PhotosPicker (recommended, iOS 16+)
import PhotosUI

struct PhotoPickerExample: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    var body: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: 5,
            matching: .images
        ) {
            Text("Select Photos")
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                selectedImages = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImages.append(image)
                    }
                }
            }
        }
    }
}
```

#### Calendar

**Android:**
```kotlin
val cursor = contentResolver.query(
    CalendarContract.Events.CONTENT_URI,
    arrayOf(CalendarContract.Events.TITLE, CalendarContract.Events.DTSTART),
    null, null, null
)
```

**iOS:**
```swift
import EventKit

@Observable
final class CalendarService {
    private let eventStore = EKEventStore()

    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [EKEvent] {
        let granted = try await eventStore.requestFullAccessToEvents()
        guard granted else { throw CalendarError.notAuthorized }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        return eventStore.events(matching: predicate)
    }

    func createEvent(title: String, startDate: Date, endDate: Date) async throws {
        let granted = try await eventStore.requestFullAccessToEvents()
        guard granted else { throw CalendarError.notAuthorized }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent)
    }
}
```

### Share Extension (Receiving Shared Content)

**Android (receiving shared content):**
```kotlin
class ReceiveShareActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (intent?.action) {
            Intent.ACTION_SEND -> {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                val imageUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                // Handle shared content
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val imageUris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                // Handle multiple shared items
            }
        }
    }
}
```

**iOS (Share Extension):**
```swift
// 1. Add a Share Extension target to your Xcode project
// 2. Configure supported types in Info.plist of the extension

// ShareViewController.swift (in the extension target)
import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    override func didSelectPost() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }

        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, error in
                    if let text = item as? String {
                        // Save to App Group shared container
                        let sharedDefaults = UserDefaults(
                            suiteName: "group.com.myapp.shared"
                        )
                        sharedDefaults?.set(text, forKey: "sharedText")
                    }
                    self.extensionContext?.completeRequest(returningItems: nil)
                }
            }

            if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.image.identifier) { item, error in
                    if let url = item as? URL {
                        // Copy image to shared container
                        let containerURL = FileManager.default.containerURL(
                            forSecurityApplicationGroupIdentifier: "group.com.myapp.shared"
                        )
                        let destURL = containerURL?.appendingPathComponent("shared_image.jpg")
                        try? FileManager.default.copyItem(at: url, to: destURL!)
                    }
                    self.extensionContext?.completeRequest(returningItems: nil)
                }
            }
        }
    }

    override func configurationItems() -> [Any]! {
        return []
    }
}

// In the main app, check for shared content on launch
func checkForSharedContent() {
    let sharedDefaults = UserDefaults(suiteName: "group.com.myapp.shared")
    if let sharedText = sharedDefaults?.string(forKey: "sharedText") {
        handleSharedText(sharedText)
        sharedDefaults?.removeObject(forKey: "sharedText")
    }
}
```

### File Provider Extension (Cloud Storage)

**Android (DocumentsProvider):**
```kotlin
class CloudStorageProvider : DocumentsProvider() {
    override fun queryRoots(projection: Array<String>?): Cursor { /* ... */ }
    override fun queryDocument(documentId: String, projection: Array<String>?): Cursor { /* ... */ }
    override fun queryChildDocuments(parentDocumentId: String, projection: Array<String>?, sortOrder: String?): Cursor { /* ... */ }
    override fun openDocument(documentId: String, mode: String, signal: CancellationSignal?): ParcelFileDescriptor { /* ... */ }
}
```

**iOS (File Provider extension):**
```swift
// 1. Add a File Provider Extension target
// 2. Implement NSFileProviderExtension or NSFileProviderReplicatedExtension

// Modern File Provider (iOS 16+)
class FileProviderExtension: NSObject, NSFileProviderReplicatedExtension {
    required init(domain: NSFileProviderDomain) {
        super.init()
    }

    func item(for identifier: NSFileProviderItemIdentifier,
              request: NSFileProviderRequest,
              completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void)
    -> Progress {
        // Return item metadata
        let item = FileProviderItem(identifier: identifier)
        completionHandler(item, nil)
        return Progress()
    }

    func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier,
                       version requestedVersion: NSFileProviderItemVersion?,
                       request: NSFileProviderRequest,
                       completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void)
    -> Progress {
        // Download file content and return local URL
        let progress = Progress(totalUnitCount: 100)
        Task {
            let localURL = try await downloadFile(for: itemIdentifier)
            let item = FileProviderItem(identifier: itemIdentifier)
            completionHandler(localURL, item, nil)
        }
        return progress
    }

    // Also implement: createItem, modifyItem, deleteItem, enumerator
}
```

### Document Picker (Picking Files from Other Apps)

**Android:**
```kotlin
val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
    addCategory(Intent.CATEGORY_OPENABLE)
    type = "*/*"
}
openDocumentLauncher.launch(intent)
```

**iOS:**
```swift
import UniformTypeIdentifiers

struct DocumentPickerView: View {
    @State private var showPicker = false
    @State private var selectedURL: URL?

    var body: some View {
        Button("Pick File") { showPicker = true }
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: [.pdf, .image, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    // Must access security-scoped resource
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }

                    // Copy file to app's container
                    let destination = FileManager.default.temporaryDirectory
                        .appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.copyItem(at: url, to: destination)
                    selectedURL = destination

                case .failure(let error):
                    print("Picker error: \(error)")
                }
            }
    }
}

// Export (save) a file
struct DocumentExportView: View {
    @State private var showExporter = false
    let document: MyDocument

    var body: some View {
        Button("Export") { showExporter = true }
            .fileExporter(
                isPresented: $showExporter,
                document: document,
                contentType: .json,
                defaultFilename: "export.json"
            ) { result in
                switch result {
                case .success(let url): print("Saved to \(url)")
                case .failure(let error): print("Export error: \(error)")
                }
            }
    }
}
```

## Best Practices

1. **Do not replicate ContentProvider on iOS** -- iOS apps are sandboxed. There is no URI-based content resolution system. Use direct data access within your app and App Groups for cross-app sharing.
2. **Use framework-specific APIs for system data** -- Contacts (`CNContactStore`), Photos (`PHPhotoLibrary`), Calendar (`EKEventStore`), and Health (`HKHealthStore`) each have dedicated frameworks. Do not try to create a generic "content resolver" abstraction.
3. **Use App Groups for cross-app data sharing** -- This is the closest iOS equivalent to a ContentProvider for sharing data between your own apps. It requires both apps to be from the same developer.
4. **Use Share Extensions to receive data from other apps** -- This replaces the `ACTION_SEND` intent filter pattern. The extension runs in a separate process with limited memory.
5. **Use `ShareLink` for sharing data out** -- This replaces `Intent.createChooser` with `ACTION_SEND`. It is the standard iOS sharing mechanism.
6. **Use `@Query` for automatic data observation** -- SwiftData's `@Query` property wrapper automatically observes changes and refreshes views, replacing `ContentObserver` and cursor loaders.
7. **Security-scoped resources require explicit access** -- When receiving file URLs from document pickers or other apps, call `startAccessingSecurityScopedResource()` before reading and `stopAccessingSecurityScopedResource()` when done.

## Common Pitfalls

- **Trying to build a ContentProvider-like abstraction** -- iOS does not have or need a URI-based content resolution system. The Repository pattern with direct database access is the idiomatic approach.
- **Assuming cross-app data access works like Android** -- On iOS, apps cannot access each other's data. Only App Groups (same developer) and explicit sharing (Share Extension, document picker) allow data exchange.
- **Forgetting security-scoped resource access** -- Files received from document pickers or other apps are security-scoped. Failing to call `startAccessingSecurityScopedResource()` results in permission errors.
- **Share Extension memory limits** -- Share Extensions run in a separate process with approximately 120MB memory limit. Do not load large files into memory. Process them incrementally or pass them to the main app via App Groups.
- **Expecting File Provider to work like Android's DocumentsProvider** -- iOS File Provider is specifically designed for cloud storage integration into the Files app. It is not a general-purpose file sharing mechanism.
- **Not handling authorization properly** -- All system data access (contacts, photos, calendar) requires explicit user authorization. Always handle denied/restricted states gracefully.

## Migration Checklist

- [ ] Audit all `ContentProvider` subclasses and categorize: internal data, system data, cross-app sharing, file sharing
- [ ] Replace internal `ContentProvider` with Repository pattern (SwiftData, Core Data, or direct file access)
- [ ] Replace `ContentObserver` with SwiftData `@Query` or Core Data `NSFetchedResultsController`
- [ ] Replace system `ContentProvider` access with framework-specific APIs (CNContactStore, PHPhotoLibrary, EKEventStore)
- [ ] Replace `FileProvider` file sharing with `ShareLink` / `UIActivityViewController`
- [ ] Replace cross-app `ContentProvider` with App Groups (shared UserDefaults + shared container)
- [ ] Implement Share Extension for receiving shared content from other apps
- [ ] Replace `ACTION_OPEN_DOCUMENT` with `.fileImporter`
- [ ] Replace `ACTION_CREATE_DOCUMENT` with `.fileExporter`
- [ ] Implement File Provider extension if app provides cloud storage functionality
- [ ] Handle security-scoped resource access for all externally provided file URLs
- [ ] Request and handle authorization for all system data access (contacts, photos, calendar)
- [ ] Configure App Group identifiers in both Xcode project capabilities and provisioning profiles
- [ ] Test Share Extension with various content types and from multiple source apps
- [ ] Verify App Group data sharing between your apps on a real device
