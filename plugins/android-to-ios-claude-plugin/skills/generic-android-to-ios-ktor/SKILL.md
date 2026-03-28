---
name: generic-android-to-ios-ktor
description: Use when migrating Android Ktor Client (multiplatform HTTP client with plugins, content negotiation, platform engines) to iOS via shared KMP module or native URLSession alternative
type: generic
---

# generic-android-to-ios-ktor

## Context
Ktor Client is JetBrains' multiplatform HTTP client designed for Kotlin Multiplatform (KMP) projects. It features a plugin-based architecture, content negotiation (kotlinx.serialization, Gson, Jackson), platform-specific engines (OkHttp on Android, Darwin/URLSession on iOS), and coroutine-native async APIs. When migrating to iOS, there are two primary strategies:
1. **Shared via KMP**: Keep the Ktor client in shared Kotlin code, using the Darwin engine on iOS. The networking code is written once and compiled for both platforms.
2. **Native iOS alternative**: Replace Ktor with native URLSession or Alamofire, rewriting the API layer in Swift.

This skill covers both strategies, the Ktor plugin system, engine configuration, and platform-specific considerations.

## Android Best Practices (Ktor Client)
- Use the `HttpClient` with an explicit engine (OkHttp for Android, Darwin for iOS in KMP).
- Install plugins declaratively: `ContentNegotiation`, `Auth`, `Logging`, `HttpTimeout`, `DefaultRequest`.
- Use `kotlinx.serialization` for content negotiation (works cross-platform).
- Define API calls as extension functions on `HttpClient` or in a dedicated API class.
- Handle errors with `HttpResponseValidator` for consistent error mapping.
- Use `expectSuccess = true` (default) to throw on non-2xx responses.

### Kotlin Patterns (Shared KMP / Android)

```kotlin
// --- HttpClient setup (shared module, works on both Android and iOS) ---
fun createHttpClient(engine: HttpClientEngine, tokenProvider: TokenProvider): HttpClient {
    return HttpClient(engine) {
        // Content negotiation (JSON serialization)
        install(ContentNegotiation) {
            json(Json {
                ignoreUnknownKeys = true
                isLenient = true
                encodeDefaults = true
                prettyPrint = false
            })
        }

        // Logging
        install(Logging) {
            logger = Logger.DEFAULT
            level = LogLevel.HEADERS
            sanitizeHeader { header -> header == HttpHeaders.Authorization }
        }

        // Timeouts
        install(HttpTimeout) {
            requestTimeoutMillis = 30_000
            connectTimeoutMillis = 15_000
            socketTimeoutMillis = 30_000
        }

        // Default request configuration
        install(DefaultRequest) {
            url("https://api.waonder.com/")
            header(HttpHeaders.ContentType, ContentType.Application.Json)
            header("X-Platform", getPlatformName()) // expect fun in shared
            header("X-App-Version", getAppVersion())
        }

        // Auth (Bearer token with refresh)
        install(Auth) {
            bearer {
                loadTokens {
                    BearerTokens(
                        accessToken = tokenProvider.accessToken ?: "",
                        refreshToken = tokenProvider.refreshToken ?: ""
                    )
                }
                refreshTokens {
                    val response = client.post("v1/auth/refresh") {
                        setBody(RefreshTokenRequest(oldTokens?.refreshToken ?: ""))
                    }.body<TokenResponse>()
                    tokenProvider.saveTokens(response.accessToken, response.refreshToken)
                    BearerTokens(response.accessToken, response.refreshToken)
                }
            }
        }

        // Response validation
        HttpResponseValidator {
            validateResponse { response ->
                when (response.status.value) {
                    in 200..299 -> Unit
                    401 -> throw NetworkError.Unauthorized
                    404 -> throw NetworkError.NotFound
                    in 500..599 -> throw NetworkError.ServerError
                    else -> throw NetworkError.Unknown("HTTP ${response.status.value}")
                }
            }
            handleResponseExceptionWithRequest { exception, _ ->
                when (exception) {
                    is ConnectTimeoutException -> throw NetworkError.Timeout
                    is SocketTimeoutException -> throw NetworkError.Timeout
                    is IOException -> throw NetworkError.NoConnection
                }
            }
        }
    }
}

// --- Platform-specific engine (in androidMain / iosMain) ---
// androidMain:
actual fun createPlatformEngine(): HttpClientEngine = OkHttp.create {
    config {
        connectTimeout(15, TimeUnit.SECONDS)
        // Additional OkHttp configuration
    }
}

// iosMain:
actual fun createPlatformEngine(): HttpClientEngine = Darwin.create {
    configureRequest {
        setAllowsCellularAccess(true)
    }
    configureSession {
        // URLSessionConfiguration properties
        timeoutIntervalForRequest = 30.0
    }
}

// --- API service class ---
class WaonderApiClient(private val client: HttpClient) {

    suspend fun getLandmarks(page: Int, limit: Int, category: String? = null): PaginatedResponse<LandmarkDto> {
        return client.get("v1/landmarks") {
            parameter("page", page)
            parameter("limit", limit)
            category?.let { parameter("category", it) }
        }.body()
    }

    suspend fun getLandmark(id: String): LandmarkDto {
        return client.get("v1/landmarks/$id").body()
    }

    suspend fun createLandmark(request: CreateLandmarkRequest): LandmarkDto {
        return client.post("v1/landmarks") {
            setBody(request)
        }.body()
    }

    suspend fun updateLandmark(id: String, request: UpdateLandmarkRequest): LandmarkDto {
        return client.put("v1/landmarks/$id") {
            setBody(request)
        }.body()
    }

    suspend fun deleteLandmark(id: String) {
        client.delete("v1/landmarks/$id")
    }

    suspend fun uploadImage(id: String, imageBytes: ByteArray, filename: String): ImageUploadResponse {
        return client.submitFormWithBinaryData(
            url = "v1/landmarks/$id/image",
            formData = formData {
                append("image", imageBytes, Headers.build {
                    append(HttpHeaders.ContentDisposition, "filename=\"$filename\"")
                    append(HttpHeaders.ContentType, "image/jpeg")
                })
            }
        ).body()
    }
}

// --- DTOs (shared, cross-platform) ---
@Serializable
data class LandmarkDto(
    val id: String,
    val name: String,
    @SerialName("lat") val latitude: Double,
    @SerialName("lng") val longitude: Double,
    val category: String,
    @SerialName("image_url") val imageUrl: String? = null,
    @SerialName("created_at") val createdAt: String
)

@Serializable
data class PaginatedResponse<T>(
    val data: List<T>,
    val page: Int,
    @SerialName("total_pages") val totalPages: Int,
    @SerialName("total_items") val totalItems: Int
)

// --- Custom plugin example ---
class RequestIdPlugin : HttpClientPlugin<Unit, RequestIdPlugin> {
    override val key = AttributeKey<RequestIdPlugin>("RequestIdPlugin")
    override fun prepare(block: Unit.() -> Unit) = RequestIdPlugin()
    override fun install(plugin: RequestIdPlugin, scope: HttpClient) {
        scope.requestPipeline.intercept(HttpRequestPipeline.State) {
            context.headers.append("X-Request-Id", UUID.randomUUID().toString())
        }
    }

    companion object : HttpClientPlugin<Unit, RequestIdPlugin> by RequestIdPlugin()
}
```

## iOS Integration Strategies

### Strategy 1: Shared KMP Module (Recommended for KMP projects)
Keep the Ktor client code in the shared module. The iOS app calls Kotlin code directly.

```swift
// --- Using shared Ktor client from Swift ---
import SharedModule // The KMP shared framework

class LandmarkService {
    private let apiClient: WaonderApiClient

    init() {
        let engine = DarwinEngineFactory().create() // or use createPlatformEngine()
        let tokenProvider = iOSTokenProvider()
        let httpClient = HttpClientFactory().createHttpClient(
            engine: engine,
            tokenProvider: tokenProvider
        )
        self.apiClient = WaonderApiClient(client: httpClient)
    }

    func getLandmarks(page: Int, limit: Int) async throws -> [Landmark] {
        // Kotlin suspend functions are exposed as async functions via SKIE or KMP-NativeCoroutines
        let response = try await apiClient.getLandmarks(page: Int32(page), limit: Int32(limit), category: nil)
        return response.data.map { $0.toDomain() }
    }
}

// --- iOS-side token provider implementing the shared interface ---
class iOSTokenProvider: TokenProvider {
    private let keychain = KeychainManager.shared

    var accessToken: String? {
        keychain.getString(forKey: "access_token")
    }

    var refreshToken: String? {
        keychain.getString(forKey: "refresh_token")
    }

    func saveTokens(accessToken: String, refreshToken: String) {
        keychain.set(accessToken, forKey: "access_token")
        keychain.set(refreshToken, forKey: "refresh_token")
    }

    func clearTokens() {
        keychain.delete(forKey: "access_token")
        keychain.delete(forKey: "refresh_token")
    }
}

// --- SKIE configuration for better Swift interop ---
// In shared build.gradle.kts:
// skie {
//     features {
//         coroutinesInterop.set(true)
//         sealedInterop.set(true)
//     }
// }

// With SKIE, Kotlin suspend functions become native Swift async:
// suspend fun getLandmarks(...) -> exposed as: func getLandmarks(...) async throws
// Flow<T> -> exposed as: AsyncSequence<T>
// sealed class -> exposed as: Swift enum
```

### Strategy 2: Native iOS Replacement (When not using KMP)
Replace Ktor with native URLSession, replicating the plugin behavior.

```swift
// --- Native API client (replaces Ktor HttpClient) ---
final class WaonderAPIClient: Sendable {
    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let tokenProvider: TokenProvider
    private let plugins: [APIPlugin]

    init(
        baseURL: URL = URL(string: "https://api.waonder.com")!,
        tokenProvider: TokenProvider,
        plugins: [APIPlugin] = []
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.plugins = plugins

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "X-Platform": "ios",
            "X-App-Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func get<T: Decodable>(path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        var request = buildRequest(path: path, method: "GET", queryItems: queryItems)
        request = applyPlugins(to: request)
        return try await execute(request)
    }

    func post<Body: Encodable, T: Decodable>(path: String, body: Body) async throws -> T {
        var request = buildRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        request = applyPlugins(to: request)
        return try await execute(request)
    }

    func put<Body: Encodable, T: Decodable>(path: String, body: Body) async throws -> T {
        var request = buildRequest(path: path, method: "PUT")
        request.httpBody = try encoder.encode(body)
        request = applyPlugins(to: request)
        return try await execute(request)
    }

    func delete(path: String) async throws {
        var request = buildRequest(path: path, method: "DELETE")
        request = applyPlugins(to: request)
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    private func buildRequest(path: String, method: String, queryItems: [URLQueryItem] = []) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        if !queryItems.isEmpty { components.queryItems = queryItems }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        if let token = tokenProvider.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func applyPlugins(to request: URLRequest) -> URLRequest {
        plugins.reduce(request) { req, plugin in plugin.adapt(req) }
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validate(response)
        plugins.forEach { $0.didReceive(data: data, response: response) }
        return try decoder.decode(T.self, from: data)
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown("Invalid response")
        }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw NetworkError.unauthorized
        case 404: throw NetworkError.notFound
        case 408, 504: throw NetworkError.timeout
        case 500..<600: throw NetworkError.serverError
        default: throw NetworkError.unknown("HTTP \(http.statusCode)")
        }
    }
}

// --- Plugin protocol (replaces Ktor HttpClientPlugin) ---
protocol APIPlugin {
    func adapt(_ request: URLRequest) -> URLRequest
    func didReceive(data: Data, response: URLResponse)
}

extension APIPlugin {
    func didReceive(data: Data, response: URLResponse) {} // Default no-op
}

// --- Logging plugin (replaces Ktor Logging plugin) ---
struct LoggingPlugin: APIPlugin {
    func adapt(_ request: URLRequest) -> URLRequest {
        #if DEBUG
        print("---> \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "")")
        #endif
        return request
    }

    func didReceive(data: Data, response: URLResponse) {
        #if DEBUG
        if let http = response as? HTTPURLResponse {
            print("<--- \(http.statusCode) \(http.url?.absoluteString ?? "")")
        }
        #endif
    }
}

// --- Request ID plugin (replaces custom Ktor plugin) ---
struct RequestIdPlugin: APIPlugin {
    func adapt(_ request: URLRequest) -> URLRequest {
        var mutable = request
        mutable.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-Id")
        return mutable
    }
}

// --- Multipart upload (replaces Ktor submitFormWithBinaryData) ---
extension WaonderAPIClient {
    func uploadMultipart<T: Decodable>(
        path: String,
        fieldName: String,
        fileData: Data,
        filename: String,
        mimeType: String
    ) async throws -> T {
        let boundary = UUID().uuidString
        var request = buildRequest(path: path, method: "POST")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, response) = try await session.upload(for: request, from: body)
        try validate(response)
        return try decoder.decode(T.self, from: data)
    }
}
```

## Concept Mapping

| Ktor Client (Kotlin) | KMP Shared (iOS) | Native Swift |
|---|---|---|
| `HttpClient(engine)` | Same (Darwin engine) | `URLSession(configuration:)` |
| `ContentNegotiation { json() }` | Same | `JSONDecoder` / `JSONEncoder` |
| `Logging` plugin | Same | `LoggingPlugin` / `URLProtocol` |
| `HttpTimeout` plugin | Same | `URLSessionConfiguration.timeoutInterval*` |
| `DefaultRequest` plugin | Same | `httpAdditionalHeaders` + `buildRequest()` |
| `Auth { bearer { } }` plugin | Same | Token injection in `buildRequest()` + retry handler |
| `HttpResponseValidator` | Same | `validate(_ response:)` method |
| `client.get("path") { }.body<T>()` | Called from Swift via SKIE | `client.get(path:) async throws -> T` |
| `parameter("key", value)` | Same | `URLQueryItem(name:value:)` |
| `setBody(request)` | Same | `encoder.encode(body)` |
| `submitFormWithBinaryData` | Same | `session.upload(for:from:)` |
| Custom `HttpClientPlugin` | Same | `APIPlugin` protocol |
| `OkHttp` engine | `Darwin` engine | `URLSession` directly |
| `HttpClient.close()` | Same | `session.invalidateAndCancel()` |

## KMP-Specific Considerations

### SKIE vs KMP-NativeCoroutines
- **SKIE** (by Touchlab): Automatically generates Swift-friendly wrappers for Kotlin suspend functions and Flow. Suspend functions become `async throws`, and Flow becomes `AsyncSequence`.
- **KMP-NativeCoroutines**: An alternative library that wraps Kotlin coroutines for Swift. Requires explicit wrapper usage on the Swift side.
- Without either library, Kotlin suspend functions are exposed as callback-based APIs (`completionHandler: (T?, Error?) -> Void`), which is cumbersome.

### Engine Selection
```kotlin
// In shared build.gradle.kts:
// sourceSets {
//     commonMain { dependencies { implementation("io.ktor:ktor-client-core:$ktorVersion") } }
//     androidMain { dependencies { implementation("io.ktor:ktor-client-okhttp:$ktorVersion") } }
//     iosMain { dependencies { implementation("io.ktor:ktor-client-darwin:$ktorVersion") } }
// }
```

### Platform-Specific Engine Config
- The **Darwin engine** uses `URLSession` under the hood. Configure it via `configureSession` and `configureRequest` blocks.
- The **OkHttp engine** allows direct access to the `OkHttpClient.Builder` for Android-specific features (certificate pinning, connection pool).
- Both engines share the same Ktor plugin stack, so `ContentNegotiation`, `Auth`, `Logging`, etc., work identically.

## Common Pitfalls
1. **KMP suspend function interop**: Without SKIE or KMP-NativeCoroutines, Kotlin suspend functions are unusable in Swift async/await. Always add one of these libraries to your KMP project.
2. **Flow observation**: Ktor's streaming APIs return `Flow`. On iOS without SKIE, collecting a Flow requires manual coroutine scope management. SKIE converts Flow to `AsyncSequence` automatically.
3. **Darwin engine limitations**: The Darwin engine does not support all OkHttp features (e.g., `CertificatePinner`). For SSL pinning on iOS, configure it via `URLSessionDelegate` on the native side, not through Ktor.
4. **Serialization format**: Ktor's `ContentNegotiation` with `kotlinx.serialization` produces JSON compatible with Swift's `Codable`. However, if you use the shared module, you do not need Swift Codable -- the Kotlin DTOs are used directly.
5. **Error types**: Ktor throws `ResponseException` (or custom exceptions from `HttpResponseValidator`). When called from Swift via SKIE, these become `NSError` instances. Map them to Swift error types on the iOS side.
6. **Memory management**: Kotlin objects used from Swift are reference-counted. Long-lived `HttpClient` instances should be stored as properties, not re-created per call. Call `client.close()` on deallocation.
7. **Binary size**: Including Ktor in a KMP framework increases the iOS binary size. If the app only targets iOS and does not share code, using native URLSession is significantly smaller.
8. **Plugin ordering**: Ktor plugins are applied in installation order. The `Auth` plugin should be installed after `ContentNegotiation` to ensure token refresh requests can deserialize responses.

## Migration Checklist

### If keeping KMP shared module:
- [ ] Add Darwin engine dependency to `iosMain` source set
- [ ] Configure `Darwin.create { }` with appropriate URLSession settings
- [ ] Add SKIE or KMP-NativeCoroutines for Swift-friendly suspend/Flow interop
- [ ] Verify all Ktor plugins work with the Darwin engine (especially Auth, Logging)
- [ ] Implement `TokenProvider` interface on the iOS side (Keychain-backed)
- [ ] Handle SSL pinning via native `URLSessionDelegate` if required
- [ ] Test suspend function calls from Swift using async/await
- [ ] Test Flow collection from Swift using AsyncSequence
- [ ] Profile binary size impact of including Ktor in the iOS framework

### If replacing with native URLSession:
- [ ] Inventory all Ktor `HttpClient` usages and installed plugins
- [ ] Create `WaonderAPIClient` with equivalent configuration (timeouts, headers, auth)
- [ ] Implement `APIPlugin` protocol equivalents for each Ktor plugin
- [ ] Migrate `ContentNegotiation` configuration to `JSONDecoder`/`JSONEncoder` settings
- [ ] Rewrite all API call functions using URLSession async/await
- [ ] Replicate `HttpResponseValidator` logic in the `validate` method
- [ ] Migrate `Auth { bearer { } }` to a token refresh handler with retry-on-401
- [ ] Convert `@Serializable` DTOs to `Codable` structs
- [ ] Handle multipart uploads using manual boundary construction
- [ ] Write unit tests using `URLProtocol` stubs
- [ ] Verify all endpoints produce identical responses across platforms
