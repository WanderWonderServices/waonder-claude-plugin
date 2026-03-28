# Milestone 06: Database & Local Storage

**Status:** Not Started
**Dependencies:** Milestone 03
**Android Module:** `:core:data` (database, cache, settings packages)
**iOS Target:** `CoreDataLayer`

---

## Objective

Set up SwiftData persistence layer mirroring Room, DataStore preferences, and in-memory caching.

---

## Deliverables

### 1. SwiftData Models (Room @Entity → SwiftData @Model)

#### Chat Models
- [ ] `ChatMessageModel.swift` — mirrors `ChatMessageEntity`
  ```swift
  @Model final class ChatMessageModel {
      @Attribute(.unique) var id: String
      var threadId: String
      var role: String
      var content: String
      var timestamp: Date
  }
  ```
- [ ] `ChatThreadModel.swift` — mirrors `ChatThreadEntity`
- [ ] `ChatRelatedTopicModel.swift` — mirrors `ChatRelatedTopicEntity`

#### Context Models
- [ ] `ContextModel.swift` — mirrors `ContextEntity`
- [ ] `ArchetypeContextDataModel.swift` — mirrors `ArchetypeContextDataEntity`

### 2. Store Classes (Room @Dao → Store)

#### Chat Store
- [ ] `ChatStore.swift` — mirrors `ChatDao`
  - CRUD operations for messages, threads, related topics
  - Query by thread ID
  - Delete expired entries

#### Context Store
- [ ] `ContextsStore.swift` — mirrors `ContextsDao`
- [ ] `ArchetypeContextsDataStore.swift` — mirrors `ArchetypeContextsDataDao`

### 3. Database Container (Room Database → ModelContainer)
- [ ] `AppDatabase.swift` — mirrors `AppDatabase.kt`
  - Configure ModelContainer with all @Model types
  - Migration handling
- [ ] `DatabaseSizeConfig.swift` — size limits and cleanup config

### 4. In-Memory Cache
- [ ] `ChatL1Cache.swift` — mirrors `ChatL1Cache.kt`
  - HashMap with size limit
  - LRU eviction policy
- [ ] `MemoryCacheSizeConfig.swift` — cache size configuration

### 5. Preferences (DataStore → UserDefaults/@AppStorage)
- [ ] `OnboardingPreferences.swift` — mirrors `OnboardingPreferences.kt`
  - Onboarding completion state
  - User locale preferences
- [ ] Developer settings storage
- [ ] Palette/typography preferences
- [ ] User settings preferences

### 6. Cache Eviction
- [ ] `ChatCacheEvictionScheduler.swift` — mirrors `ChatCacheEvictionScheduler.kt`
  - Use BGTaskScheduler for periodic cleanup (vs WorkManager)
  - Fallback: cleanup on app launch

---

## Key Translation: Room → SwiftData

```kotlin
// Android (Room)
@Entity(tableName = "chat_messages")
data class ChatMessageEntity(
    @PrimaryKey val id: String,
    val threadId: String,
    val role: String,
    val content: String,
    val timestamp: Long
)

@Dao
interface ChatDao {
    @Query("SELECT * FROM chat_messages WHERE threadId = :threadId ORDER BY timestamp ASC")
    fun getMessages(threadId: String): Flow<List<ChatMessageEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMessage(message: ChatMessageEntity)
}
```

```swift
// iOS (SwiftData)
@Model
final class ChatMessageModel {
    @Attribute(.unique) var id: String
    var threadId: String
    var role: String
    var content: String
    var timestamp: Date

    init(id: String, threadId: String, role: String, content: String, timestamp: Date) {
        self.id = id
        self.threadId = threadId
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

final class ChatStore {
    private let modelContext: ModelContext

    func getMessages(threadId: String) -> [ChatMessageModel] {
        let predicate = #Predicate<ChatMessageModel> { $0.threadId == threadId }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.timestamp)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func insertMessage(_ message: ChatMessageModel) throws {
        modelContext.insert(message)
        try modelContext.save()
    }
}
```

---

## Verification

- [ ] All SwiftData @Model classes mirror Room @Entity classes
- [ ] Store classes provide equivalent query methods to DAOs
- [ ] ModelContainer initializes without errors
- [ ] CRUD operations work for all entity types
- [ ] In-memory cache respects size limits
- [ ] Preferences read/write correctly via UserDefaults
- [ ] Cache eviction runs on schedule
