---
name: generic-android-to-ios-okhttp
description: Use when migrating Android OkHttp (HTTP engine, interceptors, SSL pinning, caching, connection pooling) to iOS URLSessionConfiguration, URLProtocol, ATS, URLCache, and certificate pinning
type: generic
---

# generic-android-to-ios-okhttp

## Context
OkHttp is the foundational HTTP engine on Android, used directly or via Retrofit. It provides interceptors (logging, auth, headers), certificate pinning, connection pooling, caching, and timeout configuration. On iOS, the equivalent foundation is `URLSession` with `URLSessionConfiguration`, supplemented by `URLProtocol` for request interception, App Transport Security (ATS) for TLS enforcement, `URLCache` for response caching, and Security framework APIs for certificate pinning.

This skill covers the low-level HTTP engine migration: interceptors, SSL/TLS configuration, caching strategy, logging, timeouts, and connection management.

## Android Best Practices (OkHttp)
- Configure a single `OkHttpClient` instance and share it across the app (reuse connection pool).
- Use application interceptors for logic that runs once per request (logging, headers).
- Use network interceptors for logic that runs per network call (cache headers, retry-after).
- Pin certificates via `CertificatePinner` with SHA-256 hashes of the server certificate chain.
- Set explicit timeouts: `connectTimeout`, `readTimeout`, `writeTimeout`, `callTimeout`.
- Enable response caching with `Cache(directory, maxSize)` for GET requests.
- Use `Authenticator` for automatic 401 retry with refreshed tokens.

### Kotlin Patterns

```kotlin
// --- OkHttpClient configuration ---
@Module
@InstallIn(SingletonComponent::class)
object OkHttpModule {
    @Provides
    @Singleton
    fun provideOkHttpClient(
        authInterceptor: AuthInterceptor,
        loggingInterceptor: HttpLoggingInterceptor,
        tokenAuthenticator: TokenAuthenticator,
        @ApplicationContext context: Context
    ): OkHttpClient {
        val cacheDir = File(context.cacheDir, "http_cache")
        val cache = Cache(cacheDir, 50L * 1024 * 1024) // 50 MB

        return OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(60, TimeUnit.SECONDS)
            .callTimeout(120, TimeUnit.SECONDS)
            .cache(cache)
            .addInterceptor(authInterceptor)           // Application interceptor
            .addInterceptor(loggingInterceptor)
            .addNetworkInterceptor(CacheInterceptor())  // Network interceptor
            .authenticator(tokenAuthenticator)
            .certificatePinner(
                CertificatePinner.Builder()
                    .add("api.waonder.com", "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
                    .add("api.waonder.com", "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=")
                    .build()
            )
            .connectionPool(ConnectionPool(5, 5, TimeUnit.MINUTES))
            .build()
    }
}

// --- Auth Interceptor (adds Bearer token to every request) ---
class AuthInterceptor @Inject constructor(
    private val tokenManager: TokenManager
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request().newBuilder().apply {
            tokenManager.accessToken?.let { token ->
                addHeader("Authorization", "Bearer $token")
            }
            addHeader("Accept", "application/json")
            addHeader("X-App-Version", BuildConfig.VERSION_NAME)
            addHeader("X-Platform", "android")
        }.build()
        return chain.proceed(request)
    }
}

// --- Token Authenticator (handles 401 with token refresh) ---
class TokenAuthenticator @Inject constructor(
    private val tokenManager: TokenManager,
    private val authApi: Provider<AuthApiService> // Lazy to avoid circular dependency
) : Authenticator {
    private val lock = Mutex()

    override fun authenticate(route: Route?, response: Response): Request? {
        if (response.responseCount > 2) return null // Prevent infinite loops

        return runBlocking {
            lock.withLock {
                val newToken = try {
                    val refreshResult = authApi.get().refreshToken(
                        RefreshTokenRequest(tokenManager.refreshToken ?: return@withLock null)
                    )
                    tokenManager.saveTokens(refreshResult.accessToken, refreshResult.refreshToken)
                    refreshResult.accessToken
                } catch (e: Exception) {
                    tokenManager.clearTokens()
                    return@withLock null
                }
                response.request.newBuilder()
                    .header("Authorization", "Bearer $newToken")
                    .build()
            }
        }
    }
}

private val Response.responseCount: Int
    get() = generateSequence(this) { it.priorResponse }.count()

// --- Logging Interceptor ---
val loggingInterceptor = HttpLoggingInterceptor().apply {
    level = if (BuildConfig.DEBUG) {
        HttpLoggingInterceptor.Level.BODY
    } else {
        HttpLoggingInterceptor.Level.NONE
    }
}

// --- Cache Interceptor (network interceptor) ---
class CacheInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val response = chain.proceed(chain.request())
        val cacheControl = CacheControl.Builder()
            .maxAge(5, TimeUnit.MINUTES)
            .build()
        return response.newBuilder()
            .removeHeader("Pragma")
            .removeHeader("Cache-Control")
            .header("Cache-Control", cacheControl.toString())
            .build()
    }
}

// --- Certificate Pinner ---
val certPinner = CertificatePinner.Builder()
    .add("api.waonder.com", "sha256/AAAA...")
    .add("*.waonder.com", "sha256/BBBB...")
    .build()
```

## iOS Best Practices

### URLSessionConfiguration
- Use `URLSessionConfiguration.default` for standard behavior; customize timeouts, cache policy, and headers.
- Use `.ephemeral` for sessions that should not persist cookies, cache, or credentials.
- Use `.background(withIdentifier:)` for uploads/downloads that continue when the app is backgrounded.
- Set `httpAdditionalHeaders` for headers that apply to every request.
- Configure `timeoutIntervalForRequest` and `timeoutIntervalForResource`.

### URLProtocol (Interceptors)
- Subclass `URLProtocol` to intercept, modify, or mock requests at the URL loading system level.
- Register custom protocols via `URLSessionConfiguration.protocolClasses`.
- Use for logging, request modification, and testing (mock responses).

### ATS (App Transport Security)
- ATS enforces HTTPS by default (equivalent to OkHttp's default TLS behavior).
- Configure exceptions in `Info.plist` only when necessary (e.g., local development).
- ATS is stricter than OkHttp's defaults: TLS 1.2+, forward secrecy, and SHA-256+ certificates.

### Certificate Pinning
- Use `URLSessionDelegate` method `urlSession(_:didReceive:completionHandler:)`.
- Evaluate server trust with `SecTrust` APIs.
- Pin against public key hashes (more resilient to certificate rotation) or certificate data.

### URLCache
- Configure via `URLSessionConfiguration.urlCache` or `URLCache.shared`.
- Set `requestCachePolicy` on the configuration or individual requests.
- Control cache size with `memoryCapacity` and `diskCapacity`.

### Swift Patterns

```swift
// --- URLSession configuration (equivalent to OkHttpClient.Builder) ---
final class NetworkSessionFactory {
    static func makeSession(tokenProvider: TokenProvider) -> URLSession {
        let config = URLSessionConfiguration.default

        // Timeouts (equivalent to OkHttp timeouts)
        config.timeoutIntervalForRequest = 30   // connectTimeout + readTimeout
        config.timeoutIntervalForResource = 120 // callTimeout

        // Cache (equivalent to OkHttp Cache)
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("http_cache")
        config.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,  // 10 MB memory
            diskCapacity: 50 * 1024 * 1024,     // 50 MB disk
            directory: cacheDirectory
        )
        config.requestCachePolicy = .useProtocolCachePolicy

        // Default headers (equivalent to AuthInterceptor static headers)
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "X-App-Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "X-Platform": "ios"
        ]

        // Connection management (URLSession manages its own pool)
        config.httpMaximumConnectionsPerHost = 6
        config.shouldUseExtendedBackgroundIdleMode = true

        // Register custom URL protocol for logging
        #if DEBUG
        config.protocolClasses = [LoggingURLProtocol.self]
        #endif

        let delegate = PinningSessionDelegate(tokenProvider: tokenProvider)
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }
}

// --- Auth header injection (equivalent to AuthInterceptor) ---
// Option 1: Via httpAdditionalHeaders (static)
// Option 2: Per-request in the APIClient (dynamic, preferred)
extension URLRequest {
    mutating func applyAuth(tokenProvider: TokenProvider) {
        if let token = tokenProvider.accessToken {
            setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}

// --- Certificate Pinning (equivalent to CertificatePinner) ---
final class PinningSessionDelegate: NSObject, URLSessionDelegate {
    private let tokenProvider: TokenProvider

    // SHA-256 hashes of public keys (same format as OkHttp pins)
    private let pinnedHashes: Set<String> = [
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
    ]

    init(tokenProvider: TokenProvider) {
        self.tokenProvider = tokenProvider
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              challenge.protectionSpace.host == "api.waonder.com"
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Evaluate the trust
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Check pinned public key hashes
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        var matched = false

        for i in 0..<certificateCount {
            guard let certificate = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
                  i < certificate.count else { continue }

            let publicKey = SecCertificateCopyKey(certificate[i])
            if let publicKeyData = publicKey.flatMap({ SecKeyCopyExternalRepresentation($0, nil) }) as Data? {
                let hash = publicKeyData.sha256Base64()
                if pinnedHashes.contains(hash) {
                    matched = true
                    break
                }
            }
        }

        if matched {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

extension Data {
    func sha256Base64() -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        withUnsafeBytes { CC_SHA256($0.baseAddress, CC_LONG(count), &hash) }
        return Data(hash).base64EncodedString()
    }
}

// --- Logging URLProtocol (equivalent to HttpLoggingInterceptor) ---
final class LoggingURLProtocol: URLProtocol {
    private var dataTask: URLSessionDataTask?
    private static let handledKey = "LoggingURLProtocolHandled"

    override class func canInit(with request: URLRequest) -> Bool {
        guard URLProtocol.property(forKey: handledKey, in: request) == nil else { return false }
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)

        // Log request
        #if DEBUG
        print("---> \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "")")
        request.allHTTPHeaderFields?.forEach { print("  \($0.key): \($0.value)") }
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("  Body: \(bodyString)")
        }
        #endif

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        dataTask = session.dataTask(with: mutableRequest as URLRequest) { [weak self] data, response, error in
            guard let self else { return }

            #if DEBUG
            if let httpResponse = response as? HTTPURLResponse {
                print("<--- \(httpResponse.statusCode) \(self.request.url?.absoluteString ?? "")")
                if let data, let body = String(data: data, encoding: .utf8) {
                    print("  Body: \(body.prefix(500))")
                }
            }
            #endif

            if let data { self.client?.urlProtocol(self, didLoad: data) }
            if let response { self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed) }
            if let error { self.client?.urlProtocol(self, didFailWithError: error) }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        dataTask?.resume()
    }

    override func stopLoading() {
        dataTask?.cancel()
    }
}

// --- Token refresh (equivalent to OkHttp Authenticator) ---
actor TokenRefreshHandler {
    private let tokenManager: TokenManager
    private let authClient: AuthAPIClient
    private var refreshTask: Task<String, Error>?

    init(tokenManager: TokenManager, authClient: AuthAPIClient) {
        self.tokenManager = tokenManager
        self.authClient = authClient
    }

    func refreshIfNeeded() async throws -> String {
        // Coalesce concurrent refresh requests
        if let existingTask = refreshTask {
            return try await existingTask.value
        }

        let task = Task {
            defer { refreshTask = nil }

            guard let refreshToken = tokenManager.refreshToken else {
                tokenManager.clearTokens()
                throw NetworkError.unauthorized
            }

            let result = try await authClient.refreshToken(refreshToken)
            tokenManager.saveTokens(accessToken: result.accessToken, refreshToken: result.refreshToken)
            return result.accessToken
        }

        refreshTask = task
        return try await task.value
    }
}

// --- Retry-on-401 wrapper (equivalent to Authenticator behavior) ---
extension WaonderAPIClient {
    func requestWithRetry<T: Decodable>(_ endpoint: WaonderEndpoint) async throws -> T {
        do {
            return try await request(endpoint)
        } catch NetworkError.unauthorized {
            // Refresh token and retry once
            let _ = try await tokenRefreshHandler.refreshIfNeeded()
            return try await request(endpoint)
        }
    }
}

// --- Cache policy per request (equivalent to CacheControl) ---
extension URLRequest {
    static func cached(url: URL, maxAge: TimeInterval = 300) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("max-age=\(Int(maxAge))", forHTTPHeaderField: "Cache-Control")
        return request
    }

    static func noCache(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }
}
```

## Concept Mapping

| OkHttp (Android) | iOS Equivalent | Notes |
|---|---|---|
| `OkHttpClient.Builder()` | `URLSessionConfiguration` | Both configure the HTTP engine |
| Application Interceptor | `URLRequest` mutation / middleware | Run once per logical request |
| Network Interceptor | `URLProtocol` subclass | Runs at the network layer |
| `HttpLoggingInterceptor` | Custom `URLProtocol` / `OSLog` | No built-in logging interceptor |
| `CertificatePinner` | `URLSessionDelegate` + `SecTrust` | Manual pin validation |
| `Authenticator` | Retry-on-401 wrapper + `TokenRefreshHandler` | No built-in authenticator |
| `Cache(dir, size)` | `URLCache(memory, disk, dir)` | Similar API |
| `CacheControl.Builder()` | `URLRequest.cachePolicy` | Less granular on iOS |
| `ConnectionPool` | Managed by URLSession internally | Not directly configurable |
| `connectTimeout` | `timeoutIntervalForRequest` | Combined with read timeout |
| `readTimeout` | `timeoutIntervalForRequest` | No separate read timeout |
| `writeTimeout` | No direct equivalent | Upload timeouts handled by `timeoutIntervalForResource` |
| `callTimeout` | `timeoutIntervalForResource` | Total request duration limit |
| `Dispatcher` | URLSession's internal `OperationQueue` | Configure `httpMaximumConnectionsPerHost` |

## Common Pitfalls
1. **Interceptor model**: OkHttp has a clear distinction between application interceptors (run once) and network interceptors (run per redirect/retry). iOS has no direct equivalent. `URLProtocol` is closest to network interceptors, but request mutation in the API client is closer to application interceptors. Do not try to replicate OkHttp's chain model exactly.
2. **Certificate pinning lifecycle**: OkHttp pins are configured once. On iOS, the delegate method is called per TLS challenge. Ensure the delegate is retained (use a strong reference from `URLSession`).
3. **Timeout granularity**: OkHttp has separate connect, read, write, and call timeouts. iOS has only `timeoutIntervalForRequest` (covers connect + read) and `timeoutIntervalForResource` (total duration). Set the request timeout to the smaller of connect + read, and resource timeout to the call timeout.
4. **Connection pooling**: OkHttp exposes `ConnectionPool`. URLSession manages connections internally with HTTP/2 multiplexing. You can tune `httpMaximumConnectionsPerHost` but cannot directly control connection keep-alive or pool size.
5. **Cache behavior**: OkHttp's cache respects `Cache-Control` headers by default. URLSession's cache behavior depends on `requestCachePolicy` and server headers. Use `.useProtocolCachePolicy` to respect server headers (closest to OkHttp default).
6. **Logging in production**: OkHttp's logging interceptor can be set to `NONE` in release builds. On iOS, wrap logging in `#if DEBUG` or use `OSLog` with appropriate log levels to avoid exposing sensitive data in production.
7. **Token refresh race condition**: OkHttp's `Authenticator` serializes 401 retries. On iOS, use an `actor` (as shown) to coalesce concurrent refresh requests and prevent multiple simultaneous token refresh calls.
8. **ATS vs OkHttp defaults**: ATS is more restrictive than OkHttp's defaults (requires TLS 1.2+, forward secrecy). If connecting to servers that only support TLS 1.0/1.1, you need ATS exceptions in `Info.plist`. OkHttp supports older TLS by default.

## Migration Checklist
- [ ] Inventory all OkHttp interceptors (application and network) and their purpose
- [ ] Configure `URLSessionConfiguration` with matching timeouts and cache settings
- [ ] Migrate static header injection to `httpAdditionalHeaders` or per-request mutation
- [ ] Implement certificate pinning via `URLSessionDelegate` with matching pin hashes
- [ ] Create logging infrastructure using `URLProtocol` (debug) or `OSLog` (production)
- [ ] Implement token refresh handler using `actor` to coalesce concurrent refresh attempts
- [ ] Implement retry-on-401 logic in the API client (replaces OkHttp Authenticator)
- [ ] Configure `URLCache` with appropriate memory and disk capacity
- [ ] Verify ATS settings in `Info.plist` match the TLS requirements
- [ ] Migrate `CacheControl` header manipulation to `URLRequest.cachePolicy` settings
- [ ] Test certificate pinning with a proxy tool (Charles/Proxyman) to verify pins reject unknown certs
- [ ] Verify background session behavior if the app uses OkHttp for long-running transfers
- [ ] Remove any OkHttp-specific retry logic that is now handled by URLSession's built-in retry
