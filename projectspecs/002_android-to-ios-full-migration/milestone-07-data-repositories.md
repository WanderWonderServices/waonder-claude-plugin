# Milestone 07: Data Layer Repositories

**Status:** Not Started
**Dependencies:** Milestones 05, 06
**Android Module:** `:core:data` (all repository implementations, data sources, DTOs, mappers)
**iOS Target:** `CoreDataLayer`

---

## Objective

Implement all repository classes, data sources (local + remote), DTOs, and mappers. After this milestone, the full data pipeline works: API → DTO → Mapper → Domain Model → Local Storage.

---

## Deliverables

### 1. Auth Data Layer (`Auth/`)
- [ ] `AuthAPI.swift` — Retrofit service implementation
- [ ] `FirebaseAuthRepositoryImpl.swift` — Firebase Auth integration
- [ ] `SessionRepositoryImpl.swift`
- [ ] `UserLocalDataSource.swift`
- [ ] `ActivityHolder.swift` / `AuthActivityHolder.swift` — adapt to iOS (UIViewController reference if needed)

### 2. Chat Data Layer (`Chat/`)

#### DTOs
- [ ] `ChatAnswerDTO.swift`
- [ ] `ChatApiErrorDTO.swift`
- [ ] `ChatExecuteResponseDTO.swift`
- [ ] `ChatQuestionDTO.swift`
- [ ] `ChatRelatedTopicDTO.swift`
- [ ] `ChatRelatedTopicsResponseDTO.swift`
- [ ] `ChatSourceDTO.swift`
- [ ] `ChatThreadDTO.swift`
- [ ] `ChatThreadsListResponseDTO.swift`
- [ ] `ConversationHistoryDTO.swift`
- [ ] `CreateThreadRequestDTO.swift`
- [ ] `DeleteResponseDTO.swift`
- [ ] `ExecuteQuestionRequestDTO.swift`
- [ ] `UpdateThreadRequestDTO.swift`

#### Mappers
- [ ] `ChatErrorMapper.swift`
- [ ] `ChatMappers.swift` — DTO ↔ Domain ↔ Entity mappers

#### Messages Repository
- [ ] `MessageLocalDataSource.swift` (protocol)
- [ ] `MessageLocalDataSourceImpl.swift`
- [ ] `MessageRemoteDataSource.swift` (protocol)
- [ ] `MessageRemoteDataSourceImpl.swift`
- [ ] `ThreadMessagesRepositoryImpl.swift`

#### Threads Repository
- [ ] `ThreadsLocalDataSource.swift` (protocol)
- [ ] `ThreadsLocalDataSourceImpl.swift`
- [ ] `ThreadsRemoteDataSource.swift` (protocol)
- [ ] `ThreadsRemoteDataSourceImpl.swift`
- [ ] `ThreadsRepositoryImpl.swift`

#### Related Topics Repository
- [ ] `RelatedTopicsLocalDataSource.swift` (protocol)
- [ ] `RelatedTopicsLocalDataSourceImpl.swift`
- [ ] `RelatedTopicsRemoteDataSource.swift` (protocol)
- [ ] `RelatedTopicsRemoteDataSourceImpl.swift`
- [ ] `ThreadRelatedTopicsRepositoryImpl.swift`

#### Cache
- [ ] `ChatCacheConfig.swift`
- [ ] `ChatCacheEvictionScheduler.swift`

### 3. Contexts Data Layer (`Contexts/`)
- [ ] `ContextDataDTO.swift`
- [ ] `ContextDTO.swift`
- [ ] `ContextEntityMappers.swift`
- [ ] `ContextMappers.swift`
- [ ] `ContextsLocalDataSource.swift`
- [ ] `ContextsRemoteDataSource.swift`
- [ ] `ContextsRepositoryImpl.swift`
- [ ] `MockContextsRepository.swift`
- [ ] `ArchetypeContextsDataLocalDataSource.swift`
- [ ] `ArchetypeContextsDataRemoteDataSource.swift`

### 4. Location Data Layer (`Location/`)
- [ ] `LocationClientLocalDataSourceImpl.swift` — CLLocationManager integration
- [ ] `LocationPermissionLocalSourceImpl.swift`
- [ ] `LocationPermissionsRepositoryImpl.swift`
- [ ] `LocationPermissionSystemSourceImpl.swift` — iOS authorization API
- [ ] `LocationServicesRepositoryImpl.swift`
- [ ] `LocationServicesSystemSourceImpl.swift`
- [ ] `TeleportLocalSourceImpl.swift`
- [ ] `TeleportLocationRepositoryImpl.swift`

### 5. Settings Data Layer (`Settings/`)
- [ ] `DeveloperSettingsRepositoryImpl.swift`
- [ ] `PaletteRepositoryImpl.swift`
- [ ] `TypographyRepositoryImpl.swift`
- [ ] `UserSettingsRepositoryImpl.swift`

### 6. Onboarding Data Layer (`Onboarding/`)
- [ ] `OnboardingPreferencesRepositoryImpl.swift`

### 7. Phone Data Layer (`Phone/`)
- [ ] `PhoneNumberFormatterImpl.swift` — PhoneNumberKit integration
- [ ] `PhoneNumberLocalDataSource.swift`
- [ ] `PhoneNumberRepositoryImpl.swift`

### 8. Device Data Layer (`Device/`)
- [ ] `DeviceLocaleProviderImpl.swift`

### 9. Logging (`Logging/`)
- [ ] `OSLogger.swift` — os.Logger implementation of Logger protocol

### 10. Utilities (`Util/`)
- [ ] `PermissionChecker.swift`

---

## Data Flow Pattern (Maintained 1:1)

```
API Response → DTO (Codable) → Mapper → Domain Model
                                           ↓
                                      Repository
                                      ↙        ↘
                              RemoteDataSource  LocalDataSource
                              (URLSession)      (SwiftData)
```

---

## Verification

- [ ] Every Android RepositoryImpl has an iOS counterpart
- [ ] Every DTO is Codable and matches API JSON structure
- [ ] Every mapper correctly translates DTO ↔ Domain ↔ Model
- [ ] Local data sources perform CRUD via SwiftData
- [ ] Remote data sources call correct API endpoints
- [ ] Repository implementations coordinate local + remote correctly
- [ ] File count matches Android data layer
