---
name: generic-android-to-ios-dependency-injection
description: Migrates Android dependency injection patterns (Hilt, Dagger, Koin) to iOS equivalents (protocol-based injection, Swinject, swift-dependencies, @Environment)
type: generic
---

# generic-android-to-ios-dependency-injection

## Context

Android and iOS have fundamentally different approaches to dependency injection. Android leans on annotation-driven frameworks (Hilt/Dagger) or DSL-based containers (Koin) that rely on runtime or compile-time code generation. iOS favors protocol-oriented design with constructor injection, optional third-party containers (Swinject), the Point-Free swift-dependencies library, or SwiftUI's built-in `@Environment`. This skill guides the migration from Android DI patterns to idiomatic iOS equivalents.

## Android Best Practices (Source Patterns)

### Hilt (Recommended Android DI)

```kotlin
// Application-level setup
@HiltAndroidApp
class MyApplication : Application()

// Module providing dependencies
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides
    @Singleton
    fun provideHttpClient(): OkHttpClient {
        return OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .build()
    }

    @Provides
    @Singleton
    fun provideApiService(client: OkHttpClient): ApiService {
        return Retrofit.Builder()
            .client(client)
            .baseUrl("https://api.example.com")
            .build()
            .create(ApiService::class.java)
    }
}

// Scoped to ViewModel lifecycle
@Module
@InstallIn(ViewModelComponent::class)
object ViewModelModule {
    @Provides
    @ViewModelScoped
    fun provideUseCase(repo: Repository): GetItemsUseCase {
        return GetItemsUseCase(repo)
    }
}

// Constructor injection in ViewModel
@HiltViewModel
class ItemsViewModel @Inject constructor(
    private val getItems: GetItemsUseCase,
    private val analytics: AnalyticsService
) : ViewModel()

// Field injection in Activity/Fragment
@AndroidEntryPoint
class ItemsFragment : Fragment() {
    private val viewModel: ItemsViewModel by viewModels()
}
```

### Hilt Scopes

| Hilt Scope            | Android Component      | Lifecycle              |
|-----------------------|------------------------|------------------------|
| `@Singleton`          | `SingletonComponent`   | Application            |
| `@ActivityScoped`     | `ActivityComponent`    | Activity               |
| `@ViewModelScoped`    | `ViewModelComponent`   | ViewModel              |
| `@FragmentScoped`     | `FragmentComponent`    | Fragment               |
| `@ViewScoped`         | `ViewComponent`        | View                   |

### Koin (DSL-Based)

```kotlin
val appModule = module {
    single { OkHttpClient.Builder().build() }
    single { ApiService(get()) }
    factory { GetItemsUseCase(get()) }
    viewModel { ItemsViewModel(get(), get()) }
}

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin {
            modules(appModule)
        }
    }
}

// Usage in Activity
class ItemsActivity : AppCompatActivity() {
    private val viewModel: ItemsViewModel by viewModel()
}
```

## iOS Best Practices (Target Patterns)

### Protocol-Based Constructor Injection (Preferred)

```swift
// 1. Define protocols (equivalent to interfaces for @Provides)
protocol HTTPClientProtocol: Sendable {
    func execute(_ request: URLRequest) async throws -> (Data, URLResponse)
}

protocol APIServiceProtocol: Sendable {
    func fetchItems() async throws -> [Item]
}

protocol GetItemsUseCaseProtocol: Sendable {
    func execute() async throws -> [Item]
}

// 2. Concrete implementations
final class HTTPClient: HTTPClientProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

final class APIService: APIServiceProtocol {
    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    func fetchItems() async throws -> [Item] {
        // implementation
    }
}

// 3. Constructor injection in ViewModel
@Observable
final class ItemsViewModel {
    private let getItems: GetItemsUseCaseProtocol
    private let analytics: AnalyticsServiceProtocol

    init(
        getItems: GetItemsUseCaseProtocol,
        analytics: AnalyticsServiceProtocol
    ) {
        self.getItems = getItems
        self.analytics = analytics
    }
}
```

### Factory / DI Container Pattern

```swift
// Centralized dependency container (equivalent to Hilt modules)
@MainActor
final class DependencyContainer {
    // Singleton scope — equivalent to @Singleton + SingletonComponent
    lazy var httpClient: HTTPClientProtocol = HTTPClient()

    lazy var apiService: APIServiceProtocol = APIService(
        client: httpClient
    )

    lazy var repository: ItemsRepositoryProtocol = ItemsRepository(
        apiService: apiService
    )

    // Factory scope — equivalent to @Provides without scope (new instance each time)
    func makeGetItemsUseCase() -> GetItemsUseCaseProtocol {
        GetItemsUseCase(repository: repository)
    }

    // ViewModel factory — equivalent to @HiltViewModel
    func makeItemsViewModel() -> ItemsViewModel {
        ItemsViewModel(
            getItems: makeGetItemsUseCase(),
            analytics: analyticsService
        )
    }
}

// Usage in SwiftUI
struct ItemsScreen: View {
    @State private var viewModel: ItemsViewModel

    init(container: DependencyContainer) {
        _viewModel = State(initialValue: container.makeItemsViewModel())
    }

    var body: some View {
        // ...
    }
}
```

### Swinject (Third-Party Container)

```swift
import Swinject

let container = Container()

// Equivalent to Hilt @Module + @Provides
container.register(HTTPClientProtocol.self) { _ in
    HTTPClient()
}.inObjectScope(.container) // Singleton scope

container.register(APIServiceProtocol.self) { resolver in
    APIService(client: resolver.resolve(HTTPClientProtocol.self)!)
}.inObjectScope(.container)

container.register(ItemsViewModel.self) { resolver in
    ItemsViewModel(
        getItems: resolver.resolve(GetItemsUseCaseProtocol.self)!,
        analytics: resolver.resolve(AnalyticsServiceProtocol.self)!
    )
}.inObjectScope(.transient) // New instance each time (factory)

// Swinject scopes mapping
// .container  → @Singleton
// .transient  → no scope (factory)
// .weak       → kept alive while referenced
// .graph      → shared within single resolve call
```

### swift-dependencies (Point-Free)

```swift
import Dependencies

// 1. Define the dependency key
struct APIServiceKey: DependencyKey {
    static let liveValue: APIServiceProtocol = APIService(client: HTTPClient())
    static let testValue: APIServiceProtocol = MockAPIService()
    static let previewValue: APIServiceProtocol = PreviewAPIService()
}

extension DependencyValues {
    var apiService: APIServiceProtocol {
        get { self[APIServiceKey.self] }
        set { self[APIServiceKey.self] = newValue }
    }
}

// 2. Use in ViewModel
@Observable
final class ItemsViewModel {
    @ObservationIgnored
    @Dependency(\.apiService) private var apiService

    func loadItems() async throws {
        // uses apiService
    }
}

// 3. Override in tests
@Test func testLoadItems() async throws {
    let viewModel = withDependencies {
        $0.apiService = MockAPIService(items: [.sample])
    } operation: {
        ItemsViewModel()
    }
    // ...
}
```

### SwiftUI @Environment

```swift
// Define environment key (useful for view-level dependencies)
struct AnalyticsServiceKey: EnvironmentKey {
    static let defaultValue: AnalyticsServiceProtocol = AnalyticsService()
}

extension EnvironmentValues {
    var analyticsService: AnalyticsServiceProtocol {
        get { self[AnalyticsServiceKey.self] }
        set { self[AnalyticsServiceKey.self] = newValue }
    }
}

// Inject via environment
struct ItemsScreen: View {
    @Environment(\.analyticsService) private var analytics

    var body: some View {
        // ...
    }
}

// Override in parent
ContentView()
    .environment(\.analyticsService, MockAnalyticsService())
```

## Mapping Reference

| Android (Hilt/Dagger)                  | iOS Equivalent                                      |
|-----------------------------------------|-----------------------------------------------------|
| `@HiltAndroidApp`                      | App entry point creates `DependencyContainer`       |
| `@Module` + `@InstallIn`               | Module struct/class or Container extension           |
| `@Provides`                            | Factory method or `lazy var` in container            |
| `@Inject constructor(...)`             | Swift `init(dep: ProtocolType)`                     |
| `@Singleton`                           | `lazy var` / `.container` scope / `static let`       |
| `@ViewModelScoped`                     | ViewModel owns it; created by factory                |
| `@ActivityScoped`                      | `@State` or `@StateObject` at View level             |
| `@Binds` (interface → impl)           | Protocol conformance, registered in container        |
| `@Qualifier`                           | Separate protocol or named registration              |
| Koin `single { ... }`                  | `lazy var` in container                              |
| Koin `factory { ... }`                 | `func make...()` in container                        |
| Koin `get()`                           | Constructor parameter or `@Dependency`               |
| Dagger `Component`                     | `DependencyContainer` class                          |
| Dagger `Subcomponent`                  | Child container or scoped extension                  |

## Compile-Time vs Runtime DI

### Android
- **Dagger/Hilt**: Compile-time via annotation processing (kapt/ksp). Errors caught at build time.
- **Koin**: Runtime resolution. Missing dependencies crash at runtime.

### iOS
- **Constructor injection**: Compile-time. The compiler enforces all dependencies are provided.
- **Swinject**: Runtime resolution (like Koin). Force-unwrapping `resolve()` can crash.
- **swift-dependencies**: Compile-time safety via `DependencyKey` with required `liveValue`.
- **@Environment**: Runtime with default values; missing overrides use defaults silently.

**Recommendation**: Prefer constructor injection for core dependencies (compile-time safe). Use `@Environment` or swift-dependencies for cross-cutting concerns.

## Testing with Fakes

### Android (Hilt Testing)
```kotlin
@HiltAndroidTest
class ItemsViewModelTest {
    @BindValue
    val fakeRepo: Repository = FakeRepository()

    @Test
    fun `loads items`() = runTest {
        val vm = ItemsViewModel(GetItemsUseCase(fakeRepo), FakeAnalytics())
        vm.loadItems()
        assertEquals(2, vm.state.value.items.size)
    }
}
```

### iOS (Constructor Injection)
```swift
@Test func loadItems() async throws {
    let fakeRepo = FakeRepository(items: [.sample, .sample2])
    let vm = ItemsViewModel(
        getItems: GetItemsUseCase(repository: fakeRepo),
        analytics: FakeAnalyticsService()
    )
    await vm.loadItems()
    #expect(vm.items.count == 2)
}
```

### iOS (swift-dependencies)
```swift
@Test func loadItems() async throws {
    let vm = withDependencies {
        $0.repository = FakeRepository(items: [.sample, .sample2])
        $0.analyticsService = FakeAnalyticsService()
    } operation: {
        ItemsViewModel()
    }
    await vm.loadItems()
    #expect(vm.items.count == 2)
}
```

## Common Pitfalls

1. **Force-unwrapping Swinject resolves**: Always use `resolver.resolve(T.self)!` carefully or add a safe wrapper that provides a clear error message.
2. **Overusing singletons**: In Android, Hilt scopes are tied to component lifecycles. In iOS, a `lazy var` in a container lives forever. Be deliberate about lifecycle management.
3. **Missing protocol abstraction**: Android interfaces map to Swift protocols. Do not inject concrete types directly; always inject protocol types to maintain testability.
4. **Circular dependencies**: Both platforms can suffer from this. In iOS constructor injection, the compiler catches it. In Swinject/runtime DI, it causes infinite loops or crashes.
5. **Thread safety**: Mark protocols as `Sendable` when dependencies will be shared across concurrency domains.
6. **SwiftUI @Environment limitations**: `@Environment` only works in View bodies. For ViewModels, use constructor injection or swift-dependencies.

## Migration Checklist

- [ ] Identify all `@Module` and `@Provides` declarations in Android code
- [ ] Create corresponding Swift protocols for each injected interface
- [ ] Implement concrete classes conforming to the protocols
- [ ] Choose a DI strategy: constructor injection (preferred), Swinject, or swift-dependencies
- [ ] Build a `DependencyContainer` or register dependencies in chosen framework
- [ ] Map Hilt scopes to iOS lifecycle equivalents
- [ ] Migrate `@Inject constructor` to Swift `init(dep:)` parameters
- [ ] Create fakes/mocks for all protocols for testing
- [ ] Verify compile-time safety: all dependencies resolved without force-unwraps where possible
- [ ] Add `Sendable` conformance to protocols used across concurrency boundaries
- [ ] Write unit tests using injected fakes to validate the wiring
