---
name: generic-android-to-ios-retrofit
description: Migrate Android Retrofit (type-safe HTTP client with annotations, converters, call adapters) to iOS URLSession (native), Alamofire, or Moya for API layer definition and networking
type: generic
---

# generic-android-to-ios-retrofit

## Context
Retrofit is Android's de facto standard for type-safe HTTP APIs. It uses annotations (`@GET`, `@POST`, `@Path`, `@Query`, `@Body`, `@Header`) to declaratively define API endpoints, and pluggable converters (Moshi, Gson, kotlinx.serialization) for serialization. On iOS there is no single equivalent; the standard approaches are:
- **URLSession** (native): Apple's built-in networking API, fully async/await compatible since iOS 15.
- **Alamofire**: The most popular third-party HTTP library, providing a higher-level API over URLSession.
- **Moya**: An abstraction layer on top of Alamofire that uses enums to define API endpoints (closest to Retrofit's annotation style).

This skill covers migrating Retrofit API definitions, serialization configuration, interceptors (via call adapters), and authentication to idiomatic iOS networking.

## Android Best Practices (Retrofit)
- Define one `interface` per API domain with annotated methods.
- Use `suspend fun` for coroutine-based calls (with Retrofit's coroutine adapter).
- Configure a single `Retrofit` instance via builder pattern with base URL, converter factory, and OkHttp client.
- Use sealed classes or `Result<T>` wrappers for error handling.
- Separate API service interfaces from business logic.
- Use `@Headers` for static headers, OkHttp interceptors for dynamic headers.

### Kotlin Patterns

```kotlin
// --- API Service ---
interface WaonderApiService {
    @GET("v1/landmarks")
    suspend fun getLandmarks(
        @Query("page") page: Int,
        @Query("limit") limit: Int,
        @Query("lat") latitude: Double? = null,
        @Query("lng") longitude: Double? = null,
        @Query("radius") radiusKm: Double? = null
    ): PaginatedResponse<LandmarkDto>

    @GET("v1/landmarks/{id}")
    suspend fun getLandmark(@Path("id") id: String): LandmarkDto

    @POST("v1/landmarks")
    suspend fun createLandmark(@Body request: CreateLandmarkRequest): LandmarkDto

    @PUT("v1/landmarks/{id}")
    suspend fun updateLandmark(
        @Path("id") id: String,
        @Body request: UpdateLandmarkRequest
    ): LandmarkDto

    @DELETE("v1/landmarks/{id}")
    suspend fun deleteLandmark(@Path("id") id: String)

    @Multipart
    @POST("v1/landmarks/{id}/image")
    suspend fun uploadImage(
        @Path("id") id: String,
        @Part image: MultipartBody.Part
    ): ImageUploadResponse

    @GET("v1/landmarks/{id}/image")
    @Streaming
    suspend fun downloadImage(@Path("id") id: String): ResponseBody

    @Headers("Cache-Control: no-cache")
    @GET("v1/landmarks/featured")
    suspend fun getFeaturedLandmarks(): List<LandmarkDto>
}

// --- Retrofit builder ---
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient): Retrofit =
        Retrofit.Builder()
            .baseUrl("https://api.waonder.com/")
            .client(okHttpClient)
            .addConverterFactory(Json.asConverterFactory("application/json".toMediaType()))
            .build()

    @Provides
    @Singleton
    fun provideApiService(retrofit: Retrofit): WaonderApiService =
        retrofit.create(WaonderApiService::class.java)
}

// --- Request/Response models ---
@Serializable
data class CreateLandmarkRequest(
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val category: String,
    val description: String? = null
)

@Serializable
data class PaginatedResponse<T>(
    val data: List<T>,
    val page: Int,
    @SerialName("total_pages") val totalPages: Int,
    @SerialName("total_items") val totalItems: Int
)

// --- Call adapter for Result wrapping ---
suspend fun <T> safeApiCall(call: suspend () -> T): Result<T> =
    try {
        Result.success(call())
    } catch (e: HttpException) {
        Result.failure(e.toDomainError())
    } catch (e: IOException) {
        Result.failure(NetworkError.NoConnection)
    }
```

## iOS Best Practices

### URLSession (Native)
- Use `URLSession.shared` for simple cases; create a custom `URLSessionConfiguration` for custom settings.
- Leverage `async/await` APIs: `data(for:)`, `upload(for:with:)`, `bytes(for:)`.
- Use `JSONDecoder`/`JSONEncoder` for serialization; configure `keyDecodingStrategy` and `dateDecodingStrategy`.
- Build a thin `APIClient` wrapper to centralize URL construction, headers, and error handling.

### Alamofire
- Higher-level API with request chaining, automatic retry, and built-in validation.
- Use `Session` (not the global `AF`) for testability and custom configuration.
- Interceptors via `RequestInterceptor` protocol (adapt + retry).
- Built-in support for multipart uploads, download progress, and SSL pinning.

### Moya (Closest to Retrofit)
- Define all endpoints as cases of an enum conforming to `TargetType`.
- Each case specifies path, method, parameters, headers, and sample data.
- Built on Alamofire; provides plugin system for logging, auth, and caching.
- Excellent for testing with `MoyaProvider<T>(stubClosure: .immediate)`.

### Swift Patterns -- URLSession (Recommended for most cases)

```swift
// --- API Endpoint definition (replaces Retrofit annotations) ---
enum WaonderEndpoint {
    case getLandmarks(page: Int, limit: Int, latitude: Double?, longitude: Double?, radiusKm: Double?)
    case getLandmark(id: String)
    case createLandmark(CreateLandmarkRequest)
    case updateLandmark(id: String, UpdateLandmarkRequest)
    case deleteLandmark(id: String)
    case uploadImage(landmarkId: String, imageData: Data, filename: String)
    case downloadImage(landmarkId: String)
    case getFeaturedLandmarks
}

extension WaonderEndpoint {
    var path: String {
        switch self {
        case .getLandmarks: "v1/landmarks"
        case .getLandmark(let id): "v1/landmarks/\(id)"
        case .createLandmark: "v1/landmarks"
        case .updateLandmark(let id, _): "v1/landmarks/\(id)"
        case .deleteLandmark(let id): "v1/landmarks/\(id)"
        case .uploadImage(let id, _, _): "v1/landmarks/\(id)/image"
        case .downloadImage(let id): "v1/landmarks/\(id)/image"
        case .getFeaturedLandmarks: "v1/landmarks/featured"
        }
    }

    var method: String {
        switch self {
        case .getLandmarks, .getLandmark, .downloadImage, .getFeaturedLandmarks: "GET"
        case .createLandmark, .uploadImage: "POST"
        case .updateLandmark: "PUT"
        case .deleteLandmark: "DELETE"
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case let .getLandmarks(page, limit, lat, lng, radius):
            var items = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
            if let lat { items.append(URLQueryItem(name: "lat", value: "\(lat)")) }
            if let lng { items.append(URLQueryItem(name: "lng", value: "\(lng)")) }
            if let radius { items.append(URLQueryItem(name: "radius", value: "\(radius)")) }
            return items
        default: return nil
        }
    }

    var headers: [String: String] {
        switch self {
        case .getFeaturedLandmarks: ["Cache-Control": "no-cache"]
        default: [:]
        }
    }
}

// --- API Client (replaces Retrofit instance) ---
final class WaonderAPIClient: Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let tokenProvider: TokenProvider

    init(
        baseURL: URL = URL(string: "https://api.waonder.com")!,
        session: URLSession = .shared,
        tokenProvider: TokenProvider
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.decoder = {
            let d = JSONDecoder()
            d.keyDecodingStrategy = .convertFromSnakeCase
            d.dateDecodingStrategy = .iso8601
            return d
        }()
        self.encoder = {
            let e = JSONEncoder()
            e.keyEncodingStrategy = .convertToSnakeCase
            return e
        }()
    }

    // --- Generic request execution ---
    func request<T: Decodable>(_ endpoint: WaonderEndpoint) async throws -> T {
        let urlRequest = try buildRequest(endpoint)
        let (data, response) = try await session.data(for: urlRequest)
        try validate(response)
        return try decoder.decode(T.self, from: data)
    }

    func requestVoid(_ endpoint: WaonderEndpoint) async throws {
        let urlRequest = try buildRequest(endpoint)
        let (_, response) = try await session.data(for: urlRequest)
        try validate(response)
    }

    func upload(_ endpoint: WaonderEndpoint) async throws -> ImageUploadResponse {
        guard case let .uploadImage(_, imageData, filename) = endpoint else {
            fatalError("upload() called with non-upload endpoint")
        }
        let boundary = UUID().uuidString
        var request = try buildRequest(endpoint)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, response) = try await session.upload(for: request, from: body)
        try validate(response)
        return try decoder.decode(ImageUploadResponse.self, from: data)
    }

    func download(_ endpoint: WaonderEndpoint) async throws -> Data {
        let request = try buildRequest(endpoint)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return data
    }

    // --- Request building ---
    private func buildRequest(_ endpoint: WaonderEndpoint) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true)!
        components.queryItems = endpoint.queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = endpoint.method

        // Auth header
        if let token = tokenProvider.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Custom headers
        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Body encoding for POST/PUT
        switch endpoint {
        case .createLandmark(let body):
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .updateLandmark(_, let body):
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        default: break
        }

        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown("Invalid response")
        }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw NetworkError.unauthorized
        case 404: throw NetworkError.notFound
        case 429: throw NetworkError.rateLimited
        case 500..<600: throw NetworkError.serverError
        default: throw NetworkError.unknown("HTTP \(http.statusCode)")
        }
    }
}

// --- Usage (equivalent to calling Retrofit service methods) ---
let client = WaonderAPIClient(tokenProvider: authManager)

// GET with query parameters
let response: PaginatedResponseDTO<LandmarkDTO> = try await client.request(
    .getLandmarks(page: 1, limit: 20, latitude: nil, longitude: nil, radiusKm: nil)
)

// POST with body
let created: LandmarkDTO = try await client.request(
    .createLandmark(CreateLandmarkRequest(name: "Park", latitude: 40.7, longitude: -73.9, category: "nature"))
)

// DELETE
try await client.requestVoid(.deleteLandmark(id: "abc123"))

// File upload
let uploadResult = try await client.upload(.uploadImage(landmarkId: "abc", imageData: jpegData, filename: "photo.jpg"))

// Safe call wrapper (equivalent to safeApiCall)
func safeAPICall<T>(_ call: () async throws -> T) async -> Result<T, NetworkError> {
    do {
        return .success(try await call())
    } catch let error as NetworkError {
        return .failure(error)
    } catch is URLError {
        return .failure(.noConnection)
    } catch {
        return .failure(.unknown(error.localizedDescription))
    }
}
```

### Swift Patterns -- Moya (Closest to Retrofit's annotation style)

```swift
import Moya

// --- TargetType definition (replaces @GET/@POST annotations) ---
enum WaonderAPI {
    case getLandmarks(page: Int, limit: Int)
    case getLandmark(id: String)
    case createLandmark(CreateLandmarkRequest)
    case deleteLandmark(id: String)
}

extension WaonderAPI: TargetType {
    var baseURL: URL { URL(string: "https://api.waonder.com")! }

    var path: String {
        switch self {
        case .getLandmarks: "/v1/landmarks"
        case .getLandmark(let id): "/v1/landmarks/\(id)"
        case .createLandmark: "/v1/landmarks"
        case .deleteLandmark(let id): "/v1/landmarks/\(id)"
        }
    }

    var method: Moya.Method {
        switch self {
        case .getLandmarks, .getLandmark: .get
        case .createLandmark: .post
        case .deleteLandmark: .delete
        }
    }

    var task: Task {
        switch self {
        case let .getLandmarks(page, limit):
            .requestParameters(
                parameters: ["page": page, "limit": limit],
                encoding: URLEncoding.queryString
            )
        case .getLandmark, .deleteLandmark:
            .requestPlain
        case .createLandmark(let request):
            .requestJSONEncodable(request)
        }
    }

    var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }

    // For unit testing with stubs
    var sampleData: Data {
        Data() // Return sample JSON for tests
    }
}

// --- Provider setup ---
let provider = MoyaProvider<WaonderAPI>(
    plugins: [
        NetworkLoggerPlugin(),
        AuthPlugin(tokenProvider: authManager)
    ]
)

// --- Usage ---
let response = try await provider.async.request(.getLandmarks(page: 1, limit: 20))
let landmarks = try response.map(PaginatedResponseDTO<LandmarkDTO>.self)
```

## Concept Mapping

| Retrofit (Android) | URLSession (iOS) | Moya (iOS) |
|---|---|---|
| `interface ApiService` | Endpoint enum + APIClient | `TargetType` enum |
| `@GET("path")` | `endpoint.path` + `endpoint.method` | `.path` + `.method` |
| `@Path("id")` | String interpolation in path | String interpolation in path |
| `@Query("key")` | `URLQueryItem` | `.requestParameters(encoding: URLEncoding)` |
| `@Body` | `request.httpBody = encoder.encode()` | `.requestJSONEncodable()` |
| `@Header` / `@Headers` | `request.setValue()` | `var headers` |
| `@Multipart` / `@Part` | Manual multipart body | `.uploadMultipart()` |
| `@Streaming` | `session.bytes(for:)` | `.downloadDestination` |
| `Retrofit.Builder()` | `WaonderAPIClient` init | `MoyaProvider<T>()` |
| `addConverterFactory()` | `JSONDecoder` / `JSONEncoder` | Built-in Codable support |
| `retrofit.create()` | Direct client usage | Provider instantiation |
| `Call<T>` / `suspend fun` | `async throws -> T` | `provider.async.request()` |
| OkHttp Interceptors | `URLProtocol` subclass | Moya `PluginType` |

## Common Pitfalls
1. **No annotation equivalent**: iOS has no compile-time annotation processing like Retrofit. Use enums with computed properties to achieve type-safe endpoint definitions. This requires manual maintenance but provides similar safety.
2. **Converter mismatch**: Retrofit auto-detects the converter (Moshi, Gson). On iOS, configure `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` if the API uses snake_case. This avoids writing `CodingKeys` for every DTO.
3. **Multipart uploads**: Retrofit handles multipart with `@Multipart` and `@Part`. On iOS, you must manually build the multipart body with boundary strings, or use Alamofire's `upload(multipartFormData:)`.
4. **Streaming responses**: Retrofit's `@Streaming` with `ResponseBody` maps to `URLSession.bytes(for:)` for progressive data loading.
5. **Base URL trailing slash**: Retrofit requires a trailing slash on the base URL. URLSession does not care. Be consistent to avoid double-slash issues.
6. **Suspend vs async**: Retrofit's `suspend fun` maps directly to Swift's `async throws`. The error handling model differs: Retrofit throws `HttpException` while URLSession requires manual status code checking.
7. **Call adapter pattern**: Retrofit's `CallAdapter.Factory` (e.g., for RxJava, LiveData) has no iOS equivalent. Use the `safeAPICall` wrapper pattern or Combine publishers for reactive wrappers.

## Migration Checklist
- [ ] List all Retrofit API service interfaces and their endpoints
- [ ] Choose iOS networking approach: URLSession (recommended), Alamofire, or Moya
- [ ] Define endpoint enums with path, method, query parameters, headers, and body
- [ ] Create the `APIClient` wrapper with generic request/response handling
- [ ] Configure `JSONDecoder`/`JSONEncoder` to match Retrofit's converter behavior
- [ ] Migrate all `@Serializable` DTOs to `Codable` structs
- [ ] Implement authentication header injection (replaces OkHttp auth interceptor)
- [ ] Handle multipart uploads if `@Multipart` endpoints exist
- [ ] Handle streaming downloads if `@Streaming` endpoints exist
- [ ] Create `safeAPICall` wrapper for `Result<T, Error>` error handling
- [ ] Set up network error types matching the Android error hierarchy
- [ ] Write unit tests using `URLProtocol` stubs (URLSession) or stub closures (Moya)
- [ ] Verify all endpoints return identical data across platforms
- [ ] Add retry logic for transient failures (maps to OkHttp retry interceptor)
