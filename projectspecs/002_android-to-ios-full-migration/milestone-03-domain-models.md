# Milestone 03: Domain Models & Protocols

**Status:** Not Started
**Dependencies:** Milestone 02
**Android Module:** `:core:domain` (models + repository interfaces)
**iOS Target:** `CoreDomain`

---

## Objective

Migrate all domain models (data classes → structs) and repository interfaces (Kotlin interfaces → Swift protocols). This is the contract layer that every other module depends on.

---

## Deliverables

### 1. Domain Models (`model/` → `Models/`)

#### Auth Models
- [ ] `AuthResult.swift` — from `model/auth/AuthResult.kt`
- [ ] `AuthState.swift` — sealed class → enum with associated values
- [ ] `OtpMethod.swift` — from `model/auth/OtpMethod.kt`
- [ ] `OtpResult.swift` — from `model/auth/OtpResult.kt`

#### Chat Models
- [ ] `ChatAnswer.swift` — from `model/chat/ChatAnswer.kt`
- [ ] `ChatExecuteResult.swift`
- [ ] `ChatMessage.swift`
- [ ] `ChatMessageRole.swift` — enum
- [ ] `ChatRelatedTopic.swift`
- [ ] `ChatSource.swift`
- [ ] `ChatThread.swift`
- [ ] `ConversationData.swift`
- [ ] `MessageStatus.swift` — enum

#### Context Models
- [ ] `ContextAnnotation.swift`
- [ ] `ContextInput.swift`
- [ ] `ProgressiveLoadPhase.swift`
- [ ] `ProgressiveLoadRings.swift`

#### Location Models
- [ ] `DeviceLocation.swift`
- [ ] `LocationPermissionStatus.swift` — enum
- [ ] `LocationServicesState.swift`
- [ ] `LocationState.swift`
- [ ] `UserLocationPreferences.swift`

#### Map Models
- [ ] `CameraPosition.swift`
- [ ] `CameraPositioningState.swift`
- [ ] `LatLng.swift`
- [ ] `MapState.swift`
- [ ] `ScreenPoint.swift`

#### Theme Models
- [ ] `FontCombinationId.swift`
- [ ] `PaletteId.swift`
- [ ] `PaletteSettings.swift`
- [ ] `TypographySettings.swift`

#### User Models
- [ ] `User.swift`
- [ ] `UserSettings.swift`

#### Other Models
- [ ] `TeleportState.swift`
- [ ] `DeveloperSettings.swift`
- [ ] `LocationProjection.swift`
- [ ] `AnnotationRequest.swift`

### 2. Repository Protocols (`repository/` → `Repositories/`)
- [ ] `AuthRepositoryProtocol.swift`
- [ ] `ContextsRepositoryProtocol.swift`
- [ ] `DeveloperSettingsRepositoryProtocol.swift`
- [ ] `LocationDataSourceProtocol.swift`
- [ ] `LocationPermissionLocalSourceProtocol.swift`
- [ ] `LocationPermissionsRepositoryProtocol.swift`
- [ ] `LocationPermissionSystemSourceProtocol.swift`
- [ ] `LocationServicesRepositoryProtocol.swift`
- [ ] `LocationServicesSystemSourceProtocol.swift`
- [ ] `PaletteRepositoryProtocol.swift`
- [ ] `SessionRepositoryProtocol.swift`
- [ ] `TeleportLocalSourceProtocol.swift`
- [ ] `TeleportLocationRepositoryProtocol.swift`
- [ ] `ThreadMessagesRepositoryProtocol.swift`
- [ ] `ThreadRelatedTopicsRepositoryProtocol.swift`
- [ ] `ThreadsRepositoryProtocol.swift`
- [ ] `TypographyRepositoryProtocol.swift`
- [ ] `UserSettingsRepositoryProtocol.swift`

### 3. Cache Protocols
- [ ] `ChatCache.swift` — protocol
- [ ] `MessageCache.swift` — protocol
- [ ] `RelatedTopicsCache.swift` — protocol
- [ ] `ThreadCache.swift` — protocol

### 4. Error Types
- [ ] `ChatError.swift` — sealed class → enum
- [ ] `ContextsError.swift` — sealed class → enum

### 5. Network Protocol
- [ ] `NetworkMonitorProtocol.swift`

### 6. Phone Protocols
- [ ] `Country.swift` — model
- [ ] `PhoneNumberFormatterProtocol.swift`
- [ ] `PhoneNumberRepositoryProtocol.swift`

---

## Key Translation Patterns

```kotlin
// Android
sealed class AuthState {
    data object Unauthenticated : AuthState()
    data object Authenticated : AuthState()
    data object Loading : AuthState()
}
```

```swift
// iOS
enum AuthState {
    case unauthenticated
    case authenticated
    case loading
}
```

```kotlin
// Android
interface AuthRepository {
    suspend fun sendOtp(phone: String): OtpResult
    fun observeAuthState(): Flow<AuthState>
}
```

```swift
// iOS
protocol AuthRepositoryProtocol {
    func sendOtp(phone: String) async throws -> OtpResult
    func observeAuthState() -> AsyncStream<AuthState>
}
```

---

## Verification

- [ ] `CoreDomain` target compiles
- [ ] Every Android model in `domain/model/` has a Swift struct/enum equivalent
- [ ] Every Android interface in `domain/repository/` has a Swift protocol equivalent
- [ ] All sealed classes are translated to Swift enums
- [ ] All data classes are translated to Swift structs with Equatable/Hashable where needed
- [ ] File count matches Android (excluding allowed naming changes)
