# Milestone 05: Networking Foundation

**Status:** Not Started
**Dependencies:** Milestone 03
**Android Module:** `:core:data` (network package)
**iOS Target:** `CoreDataLayer`

---

## Objective

Build the networking layer that mirrors Retrofit + OkHttp using URLSession. This includes the API client, interceptors, token management, and all API service protocols.

---

## Deliverables

### 1. API Client (`Network/`)
- [ ] `APIClient.swift` — URLSession wrapper matching Retrofit's role
  - Generic request method: `func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T`
  - Support for GET, POST, PUT, DELETE, PATCH
  - JSON encoding/decoding with Codable
  - Error mapping to domain errors
- [ ] `APIEndpoint.swift` — Enum/struct defining all endpoints (replaces Retrofit annotations)
- [ ] `APIError.swift` — Network error types

### 2. Interceptors (Mirror OkHttp Interceptors)
- [ ] `AuthTokenInterceptor.swift` — Adds bearer token to requests
  - Reads token from session/auth manager
  - Attaches `Authorization: Bearer <token>` header
- [ ] `RequestHeadersInterceptor.swift` — Adds app version, platform headers
- [ ] `NetworkChaosInterceptor.swift` — Debug-only network chaos simulation
- [ ] `TokenAuthenticator.swift` — Token refresh logic on 401 responses

### 3. Retry Logic
- [ ] `RetryConfig.swift` — Retry configuration (max attempts, backoff)
- [ ] `RetryExecutor.swift` — Retry execution with exponential backoff

### 4. API Service Protocols (mirrors Retrofit interfaces)
- [ ] `AuthAPI.swift` — Auth endpoints
  - `POST /auth/send-otp`
  - `POST /auth/verify-otp`
  - `POST /auth/logout`
- [ ] `ChatAPI.swift` — Chat endpoints
  - `POST /threads`
  - `GET /threads`
  - `POST /threads/{id}/messages`
  - `GET /threads/{id}/messages`
  - `POST /threads/{id}/messages/execute`
  - `GET /threads/{id}/related-topics`
- [ ] `ContextsAPI.swift` — Context/places endpoints
  - `GET /contexts?lat={lat}&lng={lng}&radius={radius}`
- [ ] `ArchetypeContextsDataAPI.swift` — Archetype context data endpoints

### 5. Network Monitor
- [ ] `NetworkMonitorImpl.swift` — NWPathMonitor-based implementation of `NetworkMonitorProtocol`

---

## Architecture Pattern

```
Android:
  Retrofit Interface → OkHttp → Interceptors → Server

iOS:
  APIService Protocol → APIClient (URLSession) → Middleware → Server
```

### Example Translation

```kotlin
// Android (Retrofit)
interface ChatApiService {
    @POST("threads")
    suspend fun createThread(@Body request: CreateThreadRequestDto): ChatThreadDto

    @GET("threads/{threadId}/messages")
    suspend fun getMessages(@Path("threadId") id: String): List<ChatMessageDto>
}
```

```swift
// iOS
enum ChatEndpoint {
    case createThread(CreateThreadRequestDTO)
    case getMessages(threadId: String)
}

extension ChatEndpoint: APIEndpoint {
    var path: String {
        switch self {
        case .createThread: "/threads"
        case .getMessages(let id): "/threads/\(id)/messages"
        }
    }
    var method: HTTPMethod {
        switch self {
        case .createThread: .post
        case .getMessages: .get
        }
    }
    var body: Encodable? {
        switch self {
        case .createThread(let request): request
        case .getMessages: nil
        }
    }
}

protocol ChatAPI {
    func createThread(request: CreateThreadRequestDTO) async throws -> ChatThreadDTO
    func getMessages(threadId: String) async throws -> [ChatMessageDTO]
}

struct ChatAPIImpl: ChatAPI {
    private let client: APIClient

    func createThread(request: CreateThreadRequestDTO) async throws -> ChatThreadDTO {
        try await client.request(.createThread(request))
    }
}
```

---

## Verification

- [ ] `CoreDataLayer` compiles with networking code
- [ ] APIClient can make requests to staging API
- [ ] Auth token interceptor attaches headers correctly
- [ ] Token refresh flow works on 401
- [ ] Retry logic respects backoff configuration
- [ ] NetworkMonitor correctly reports connectivity changes
- [ ] All API service protocols match Android Retrofit interfaces
