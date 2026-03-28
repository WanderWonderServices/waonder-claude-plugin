---
name: generic-android-to-ios-remote-datasource
description: Use when migrating Android remote data source pattern (interface + Retrofit implementation, DTOs, mappers) to iOS remote data source pattern (protocol + URLSession/Alamofire implementation, Codable, mappers)
type: generic
---

# generic-android-to-ios-remote-datasource

## Context
The remote data source pattern provides an abstraction between the repository and the network layer. On Android this is typically an interface with a Retrofit-backed implementation that uses DTOs (Data Transfer Objects) and mappers to convert API responses into domain models. On iOS the equivalent is a Swift protocol with an implementation using URLSession or Alamofire, leveraging `Codable` for serialization and dedicated mappers for domain conversion.

This skill covers the full remote data source migration: API abstraction, DTO design, error handling, request/response mapping, and pagination support.

## Android Best Practices (Remote Data Source)
- Define the remote data source as an interface exposing domain-oriented methods (not HTTP-specific).
- Use DTOs (suffixed with `Dto` or `Response`) for API serialization; never expose raw JSON or Retrofit types.
- Map DTOs to domain models in the data source implementation, not in the repository.
- Handle HTTP errors, network errors, and serialization errors, translating them to domain-level exceptions.
- Support pagination via a generic `PaginatedResponse<T>` wrapper.
- Inject the Retrofit API service via Hilt/Dagger.
- Use `suspend` functions for all network calls.

### Kotlin Patterns

```kotlin
// --- DTOs ---
@Serializable
data class LandmarkDto(
    @SerialName("id") val id: String,
    @SerialName("name") val name: String,
    @SerialName("lat") val latitude: Double,
    @SerialName("lng") val longitude: Double,
    @SerialName("category") val category: String,
    @SerialName("image_url") val imageUrl: String?,
    @SerialName("created_at") val createdAt: String
)

@Serializable
data class PaginatedResponse<T>(
    @SerialName("data") val data: List<T>,
    @SerialName("page") val page: Int,
    @SerialName("total_pages") val totalPages: Int,
    @SerialName("total_items") val totalItems: Int
)

@Serializable
data class ApiError(
    @SerialName("code") val code: String,
    @SerialName("message") val message: String
)

// --- Retrofit API service ---
interface LandmarkApiService {
    @GET("v1/landmarks")
    suspend fun getLandmarks(
        @Query("page") page: Int = 1,
        @Query("limit") limit: Int = 20,
        @Query("category") category: String? = null
    ): PaginatedResponse<LandmarkDto>

    @GET("v1/landmarks/{id}")
    suspend fun getLandmark(@Path("id") id: String): LandmarkDto

    @POST("v1/landmarks")
    suspend fun createLandmark(@Body body: CreateLandmarkRequest): LandmarkDto

    @PUT("v1/landmarks/{id}")
    suspend fun updateLandmark(
        @Path("id") id: String,
        @Body body: UpdateLandmarkRequest
    ): LandmarkDto

    @DELETE("v1/landmarks/{id}")
    suspend fun deleteLandmark(@Path("id") id: String)
}

// --- Remote data source interface ---
interface LandmarkRemoteDataSource {
    suspend fun getLandmarks(page: Int, limit: Int, category: LandmarkCategory?): PaginatedResult<Landmark>
    suspend fun getLandmark(id: String): Landmark
    suspend fun createLandmark(landmark: Landmark): Landmark
    suspend fun updateLandmark(landmark: Landmark): Landmark
    suspend fun deleteLandmark(id: String)
}

// Domain-level pagination result
data class PaginatedResult<T>(
    val items: List<T>,
    val page: Int,
    val totalPages: Int,
    val hasMore: Boolean
)

// --- Implementation ---
class RetrofitLandmarkRemoteDataSource @Inject constructor(
    private val api: LandmarkApiService
) : LandmarkRemoteDataSource {

    override suspend fun getLandmarks(
        page: Int,
        limit: Int,
        category: LandmarkCategory?
    ): PaginatedResult<Landmark> {
        return try {
            val response = api.getLandmarks(page, limit, category?.name?.lowercase())
            PaginatedResult(
                items = response.data.map { it.toDomain() },
                page = response.page,
                totalPages = response.totalPages,
                hasMore = response.page < response.totalPages
            )
        } catch (e: HttpException) {
            throw e.toDomainError()
        } catch (e: IOException) {
            throw NetworkError.NoConnection
        }
    }

    override suspend fun getLandmark(id: String): Landmark {
        return try {
            api.getLandmark(id).toDomain()
        } catch (e: HttpException) {
            throw e.toDomainError()
        } catch (e: IOException) {
            throw NetworkError.NoConnection
        }
    }

    override suspend fun createLandmark(landmark: Landmark): Landmark {
        return try {
            val request = CreateLandmarkRequest(
                name = landmark.name,
                latitude = landmark.location.latitude,
                longitude = landmark.location.longitude,
                category = landmark.category.name.lowercase()
            )
            api.createLandmark(request).toDomain()
        } catch (e: HttpException) {
            throw e.toDomainError()
        }
    }

    override suspend fun updateLandmark(landmark: Landmark): Landmark {
        return try {
            val request = UpdateLandmarkRequest(
                name = landmark.name,
                latitude = landmark.location.latitude,
                longitude = landmark.location.longitude,
                category = landmark.category.name.lowercase()
            )
            api.updateLandmark(landmark.id, request).toDomain()
        } catch (e: HttpException) {
            throw e.toDomainError()
        }
    }

    override suspend fun deleteLandmark(id: String) {
        try {
            api.deleteLandmark(id)
        } catch (e: HttpException) {
            throw e.toDomainError()
        }
    }
}

// --- Mappers ---
fun LandmarkDto.toDomain() = Landmark(
    id = id,
    name = name,
    location = LatLng(latitude, longitude),
    category = LandmarkCategory.entries.find { it.name.equals(category, ignoreCase = true) }
        ?: LandmarkCategory.GENERAL,
    imageUrl = imageUrl,
    createdAt = Instant.parse(createdAt)
)

// --- Error mapping ---
sealed class NetworkError : Exception() {
    data object NoConnection : NetworkError()
    data object Unauthorized : NetworkError()
    data object NotFound : NetworkError()
    data object ServerError : NetworkError()
    data class Unknown(override val message: String) : NetworkError()
}

fun HttpException.toDomainError(): NetworkError = when (code()) {
    401 -> NetworkError.Unauthorized
    404 -> NetworkError.NotFound
    in 500..599 -> NetworkError.ServerError
    else -> NetworkError.Unknown(message())
}
```

## iOS Best Practices (Remote Data Source)
- Define the remote data source as a Swift protocol with `async throws` methods.
- Use `Codable` structs for DTOs; never expose `URLResponse` or `Data` through the protocol.
- Map DTOs to domain models in the data source implementation.
- Create a dedicated `APIClient` or use URLSession/Alamofire for the HTTP layer.
- Handle HTTP status codes, decoding errors, and connectivity errors, translating them to domain errors.
- Use generics for paginated responses.
- Mark the protocol as `Sendable` for safe concurrent use.

### Swift Patterns

```swift
// --- DTOs ---
struct LandmarkDTO: Codable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double
    let category: String
    let imageUrl: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, lat, lng, category
        case imageUrl = "image_url"
        case createdAt = "created_at"
    }
}

struct PaginatedResponseDTO<T: Codable>: Codable {
    let data: [T]
    let page: Int
    let totalPages: Int
    let totalItems: Int

    enum CodingKeys: String, CodingKey {
        case data, page
        case totalPages = "total_pages"
        case totalItems = "total_items"
    }
}

struct APIErrorDTO: Codable {
    let code: String
    let message: String
}

struct CreateLandmarkRequestDTO: Codable {
    let name: String
    let latitude: Double
    let longitude: Double
    let category: String
}

struct UpdateLandmarkRequestDTO: Codable {
    let name: String
    let latitude: Double
    let longitude: Double
    let category: String
}

// --- Domain pagination result ---
struct PaginatedResult<T: Sendable>: Sendable {
    let items: [T]
    let page: Int
    let totalPages: Int
    let hasMore: Bool
}

// --- Remote data source protocol ---
protocol LandmarkRemoteDataSource: Sendable {
    func getLandmarks(page: Int, limit: Int, category: LandmarkCategory?) async throws -> PaginatedResult<Landmark>
    func getLandmark(id: String) async throws -> Landmark
    func createLandmark(_ landmark: Landmark) async throws -> Landmark
    func updateLandmark(_ landmark: Landmark) async throws -> Landmark
    func deleteLandmark(id: String) async throws
}

// --- URLSession-backed implementation ---
final class URLSessionLandmarkRemoteDataSource: LandmarkRemoteDataSource {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func getLandmarks(page: Int, limit: Int, category: LandmarkCategory?) async throws -> PaginatedResult<Landmark> {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let category {
            queryItems.append(URLQueryItem(name: "category", value: category.rawValue))
        }

        let response: PaginatedResponseDTO<LandmarkDTO> = try await client.get(
            path: "v1/landmarks",
            queryItems: queryItems
        )
        return PaginatedResult(
            items: response.data.map { $0.toDomain() },
            page: response.page,
            totalPages: response.totalPages,
            hasMore: response.page < response.totalPages
        )
    }

    func getLandmark(id: String) async throws -> Landmark {
        let dto: LandmarkDTO = try await client.get(path: "v1/landmarks/\(id)")
        return dto.toDomain()
    }

    func createLandmark(_ landmark: Landmark) async throws -> Landmark {
        let request = CreateLandmarkRequestDTO(
            name: landmark.name,
            latitude: landmark.location.latitude,
            longitude: landmark.location.longitude,
            category: landmark.category.rawValue
        )
        let dto: LandmarkDTO = try await client.post(path: "v1/landmarks", body: request)
        return dto.toDomain()
    }

    func updateLandmark(_ landmark: Landmark) async throws -> Landmark {
        let request = UpdateLandmarkRequestDTO(
            name: landmark.name,
            latitude: landmark.location.latitude,
            longitude: landmark.location.longitude,
            category: landmark.category.rawValue
        )
        let dto: LandmarkDTO = try await client.put(path: "v1/landmarks/\(landmark.id)", body: request)
        return dto.toDomain()
    }

    func deleteLandmark(id: String) async throws {
        try await client.delete(path: "v1/landmarks/\(id)")
    }
}

// --- API Client (reusable HTTP layer) ---
final class APIClient: Sendable {
    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let tokenProvider: TokenProvider

    init(
        baseURL: URL,
        session: URLSession = .shared,
        tokenProvider: TokenProvider
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func get<T: Decodable>(path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        let request = try buildRequest(method: "GET", path: path, queryItems: queryItems)
        return try await execute(request)
    }

    func post<Body: Encodable, T: Decodable>(path: String, body: Body) async throws -> T {
        var request = try buildRequest(method: "POST", path: path)
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    func put<Body: Encodable, T: Decodable>(path: String, body: Body) async throws -> T {
        var request = try buildRequest(method: "PUT", path: path)
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    func delete(path: String) async throws {
        let request = try buildRequest(method: "DELETE", path: path)
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    private func buildRequest(method: String, path: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        if !queryItems.isEmpty { components.queryItems = queryItems }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        if let token = tokenProvider.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown("Invalid response type")
        }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw NetworkError.unauthorized
        case 404: throw NetworkError.notFound
        case 500..<600: throw NetworkError.serverError
        default: throw NetworkError.unknown("HTTP \(http.statusCode)")
        }
    }
}

// --- Mappers ---
extension LandmarkDTO {
    func toDomain() -> Landmark {
        Landmark(
            id: id,
            name: name,
            location: Coordinate(latitude: lat, longitude: lng),
            category: LandmarkCategory(rawValue: category) ?? .general,
            imageUrl: imageUrl.flatMap { URL(string: $0) },
            createdAt: ISO8601DateFormatter().date(from: createdAt) ?? .now
        )
    }
}

// --- Error types ---
enum NetworkError: Error, Equatable {
    case noConnection
    case unauthorized
    case notFound
    case serverError
    case decodingFailed(Error)
    case unknown(String)

    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.noConnection, .noConnection),
             (.unauthorized, .unauthorized),
             (.notFound, .notFound),
             (.serverError, .serverError):
            return true
        case let (.unknown(l), .unknown(r)):
            return l == r
        default:
            return false
        }
    }
}

// --- DI registration ---
import Factory

extension Container {
    var landmarkRemoteDataSource: Factory<LandmarkRemoteDataSource> {
        Factory(self) {
            URLSessionLandmarkRemoteDataSource(client: self.apiClient())
        }
        .singleton
    }

    var apiClient: Factory<APIClient> {
        Factory(self) {
            APIClient(
                baseURL: URL(string: "https://api.waonder.com")!,
                tokenProvider: self.tokenProvider()
            )
        }
        .singleton
    }
}

// --- Mock for testing ---
final class MockLandmarkRemoteDataSource: LandmarkRemoteDataSource {
    var getLandmarksResult: Result<PaginatedResult<Landmark>, Error> = .success(
        PaginatedResult(items: [], page: 1, totalPages: 1, hasMore: false)
    )
    var getLandmarkResult: Result<Landmark, Error> = .failure(NetworkError.notFound)

    private(set) var getLandmarksCallCount = 0
    private(set) var deletedIds: [String] = []

    func getLandmarks(page: Int, limit: Int, category: LandmarkCategory?) async throws -> PaginatedResult<Landmark> {
        getLandmarksCallCount += 1
        return try getLandmarksResult.get()
    }

    func getLandmark(id: String) async throws -> Landmark {
        return try getLandmarkResult.get()
    }

    func createLandmark(_ landmark: Landmark) async throws -> Landmark { landmark }
    func updateLandmark(_ landmark: Landmark) async throws -> Landmark { landmark }

    func deleteLandmark(id: String) async throws {
        deletedIds.append(id)
    }
}
```

## Concept Mapping

| Android (Retrofit) | iOS (URLSession) | Notes |
|---|---|---|
| `interface LandmarkApiService` | `APIClient` (generic HTTP layer) | iOS has no annotation-based API definition |
| `@GET`, `@POST`, etc. | `client.get()`, `client.post()` | Method calls replace annotations |
| `@Serializable` DTO | `Codable` struct | Both handle JSON serialization |
| `@SerialName("field")` | `CodingKeys` enum | Custom JSON key mapping |
| `HttpException` | `HTTPURLResponse.statusCode` | Check status codes manually |
| `IOException` | `URLError` | Network connectivity errors |
| `suspend fun` | `async throws` | Direct equivalent |
| Moshi/Gson converters | `JSONDecoder` / `JSONEncoder` | Built into Foundation |
| `@Inject constructor` | Factory / Swinject | No built-in DI on iOS |

## Common Pitfalls
1. **DTO leakage**: Never return DTOs from the remote data source protocol. Always map to domain models. DTOs are tied to the API contract; domain models represent the app's business logic.
2. **Date parsing**: Android often uses `kotlinx.serialization` with custom serializers for dates. iOS should use `ISO8601DateFormatter` or configure `JSONDecoder.dateDecodingStrategy`. Be consistent about time zones.
3. **Error type mismatch**: Retrofit throws `HttpException` for HTTP errors and `IOException` for network errors. URLSession throws `URLError` for network issues. HTTP errors must be manually checked via status code on iOS.
4. **Pagination contracts**: Ensure the `PaginatedResult` type is identical between platforms. Verify `hasMore` logic matches (some APIs use `hasNext`, others infer from `page < totalPages`).
5. **Token refresh**: On Android, OkHttp Authenticator handles 401 retries. On iOS, implement retry logic in the `APIClient` or use an `URLProtocol` subclass. Coordinate with the auth layer.
6. **Request body encoding**: Retrofit auto-serializes `@Body` parameters. On iOS, manually encode the body with `JSONEncoder` and set the `Content-Type` header.
7. **Null safety**: Kotlin's null safety maps well to Swift optionals, but pay attention to nullable fields in DTOs. A missing JSON field in Kotlin `@Serializable` with no default crashes; in Swift `Codable` it requires an explicit optional or `decodeIfPresent`.

## Migration Checklist
- [ ] Inventory all Retrofit API service interfaces and their endpoints
- [ ] Create corresponding `Codable` DTO structs for all request and response types
- [ ] Map `@SerialName` annotations to `CodingKeys` enums
- [ ] Define the remote data source protocol with `async throws` methods
- [ ] Implement `APIClient` with generic `get`, `post`, `put`, `delete` methods
- [ ] Implement the remote data source using `APIClient`
- [ ] Create DTO-to-domain mapper extensions
- [ ] Define domain-level `NetworkError` enum matching Android's error hierarchy
- [ ] Implement error mapping from HTTP status codes to domain errors
- [ ] Set up authentication header injection in `APIClient`
- [ ] Create mock implementations for unit testing
- [ ] Write integration tests using `URLProtocol` stubs
- [ ] Verify pagination logic produces identical results across platforms
- [ ] Handle token refresh / 401 retry logic in the API client
