---
name: generic-android-to-ios-clean-architecture
description: Guides migration of Android Clean Architecture (domain/data/presentation layers, Gradle modules, dependency rules) to iOS equivalents (MVVM-C / TCA / VIP, SPM modules, layer boundaries) with module structure and navigation patterns
type: generic
---

# generic-android-to-ios-clean-architecture

## Context

Clean Architecture on Android typically splits the codebase into domain, data, and presentation layers, each in its own Gradle module, with the dependency rule flowing inward (presentation -> domain <- data). On iOS, the same architectural principles apply but use SPM (Swift Package Manager) modules, SwiftUI for the presentation layer, and different navigation patterns (Coordinator, NavigationStack path-based, TCA reducer trees). This skill provides a complete mapping for migrating an Android Clean Architecture codebase to an idiomatic iOS equivalent.

## Android Best Practices (Source Patterns)

### Typical Gradle Module Structure

```
app/
  build.gradle.kts
feature/
  feature-home/
    build.gradle.kts          // depends on :domain:home, :core:ui
  feature-profile/
    build.gradle.kts          // depends on :domain:profile, :core:ui
domain/
  domain-home/
    build.gradle.kts          // pure Kotlin, no Android deps
  domain-profile/
    build.gradle.kts          // pure Kotlin, no Android deps
data/
  data-user/
    build.gradle.kts          // depends on :domain:profile, :core:network
  data-content/
    build.gradle.kts          // depends on :domain:home, :core:database
core/
  core-network/
    build.gradle.kts          // Retrofit, OkHttp
  core-database/
    build.gradle.kts          // Room
  core-ui/
    build.gradle.kts          // shared Compose components
  core-common/
    build.gradle.kts          // shared utilities
```

### Dependency Rule

```
Presentation (feature-*) --> Domain (domain-*) <-- Data (data-*)
                                    ^
                                    |
                              Core modules
```

The domain layer has ZERO dependencies on Android framework, data layer, or presentation layer. It defines only:
- Domain models (pure Kotlin data classes)
- Repository interfaces
- Use Cases

### Domain Layer

```kotlin
// domain/domain-profile/src/.../model/User.kt
data class User(
    val id: String,
    val name: String,
    val email: String,
    val avatarUrl: String?
)

// domain/domain-profile/src/.../repository/UserRepository.kt
interface UserRepository {
    fun observeUser(userId: String): Flow<User>
    suspend fun refreshUser(userId: String): Result<User>
}

// domain/domain-profile/src/.../usecase/GetUserUseCase.kt
class GetUserUseCase @Inject constructor(
    private val userRepository: UserRepository
) {
    suspend operator fun invoke(userId: String): Result<User> {
        return userRepository.refreshUser(userId)
    }
}
```

### Data Layer

```kotlin
// data/data-user/src/.../remote/UserApi.kt
interface UserApi {
    @GET("users/{id}")
    suspend fun getUser(@Path("id") userId: String): UserDto
}

// data/data-user/src/.../local/UserDao.kt
@Dao
interface UserDao {
    @Query("SELECT * FROM users WHERE id = :userId")
    fun observeUser(userId: String): Flow<UserEntity>

    @Upsert
    suspend fun upsert(user: UserEntity)
}

// data/data-user/src/.../UserRepositoryImpl.kt
class UserRepositoryImpl @Inject constructor(
    private val userApi: UserApi,
    private val userDao: UserDao
) : UserRepository {
    override fun observeUser(userId: String): Flow<User> {
        return userDao.observeUser(userId)
            .map { it.toDomain() }
            .onStart { refreshUser(userId) }
    }

    override suspend fun refreshUser(userId: String): Result<User> {
        return runCatching {
            val dto = userApi.getUser(userId)
            userDao.upsert(dto.toEntity())
            dto.toDomain()
        }
    }
}

// data/data-user/src/.../mapper/UserMapper.kt
fun UserDto.toDomain() = User(id = id, name = name, email = email, avatarUrl = avatarUrl)
fun UserDto.toEntity() = UserEntity(id = id, name = name, email = email, avatarUrl = avatarUrl)
fun UserEntity.toDomain() = User(id = id, name = name, email = email, avatarUrl = avatarUrl)
```

### Presentation Layer

```kotlin
// feature/feature-profile/src/.../ProfileScreen.kt
@Composable
fun ProfileScreen(
    viewModel: ProfileViewModel = hiltViewModel(),
    onNavigateToSettings: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    ProfileContent(
        state = uiState,
        onRetry = viewModel::loadUser,
        onSettingsTap = onNavigateToSettings
    )
}

// feature/feature-profile/src/.../ProfileViewModel.kt
@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val getUserUseCase: GetUserUseCase,
    private val observeUserUseCase: ObserveUserUseCase
) : ViewModel() {
    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init { loadUser() }

    fun loadUser() {
        viewModelScope.launch {
            observeUserUseCase("current")
                .collect { user ->
                    _uiState.update { it.copy(user = user, isLoading = false) }
                }
        }
    }
}
```

### Navigation (NavGraph)

```kotlin
// app/src/.../navigation/AppNavigation.kt
@Composable
fun AppNavGraph(navController: NavHostController) {
    NavHost(navController = navController, startDestination = "home") {
        composable("home") {
            HomeScreen(onNavigateToProfile = { navController.navigate("profile/$it") })
        }
        composable(
            route = "profile/{userId}",
            arguments = listOf(navArgument("userId") { type = NavType.StringType })
        ) { backStackEntry ->
            ProfileScreen(
                onNavigateToSettings = { navController.navigate("settings") }
            )
        }
        composable("settings") {
            SettingsScreen()
        }
    }
}
```

### DI Module (Hilt)

```kotlin
@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {
    @Binds
    abstract fun bindUserRepository(impl: UserRepositoryImpl): UserRepository
}

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides
    @Singleton
    fun provideRetrofit(): Retrofit { ... }

    @Provides
    fun provideUserApi(retrofit: Retrofit): UserApi =
        retrofit.create(UserApi::class.java)
}
```

## iOS Best Practices (Target Patterns)

### SPM Module Structure

```
App/
  WaonderApp/                      // Main app target
    WaonderApp.swift
    DI/
      DependencyContainer.swift
    Navigation/
      AppCoordinator.swift
Features/
  FeatureHome/
    Package.swift                  // depends on DomainHome, CoreUI
    Sources/
      HomeView.swift
      HomeViewModel.swift
  FeatureProfile/
    Package.swift                  // depends on DomainProfile, CoreUI
    Sources/
      ProfileView.swift
      ProfileViewModel.swift
Domain/
  DomainHome/
    Package.swift                  // no dependencies (pure Swift)
    Sources/
      Models/
        Content.swift
      Repositories/
        ContentRepository.swift    // protocol only
      UseCases/
        GetContentUseCase.swift
  DomainProfile/
    Package.swift                  // no dependencies (pure Swift)
    Sources/
      Models/
        User.swift
      Repositories/
        UserRepository.swift       // protocol only
      UseCases/
        GetUserUseCase.swift
Data/
  DataUser/
    Package.swift                  // depends on DomainProfile, CoreNetwork, CoreDatabase
    Sources/
      Remote/
        UserAPI.swift
        UserDTO.swift
      Local/
        UserModel.swift            // SwiftData @Model
        UserStore.swift
      UserRepositoryImpl.swift
      Mappers/
        UserMapper.swift
  DataContent/
    Package.swift                  // depends on DomainHome, CoreNetwork, CoreDatabase
Core/
  CoreNetwork/
    Package.swift
    Sources/
      APIClient.swift
      APIError.swift
  CoreDatabase/
    Package.swift
    Sources/
      DatabaseContainer.swift
  CoreUI/
    Package.swift
    Sources/
      Components/
        LoadingView.swift
        ErrorView.swift
  CoreCommon/
    Package.swift
    Sources/
      Extensions/
```

### SPM Package.swift Examples

```swift
// Domain/DomainProfile/Package.swift — ZERO external dependencies
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DomainProfile",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "DomainProfile", targets: ["DomainProfile"])
    ],
    targets: [
        .target(name: "DomainProfile"),
        .testTarget(name: "DomainProfileTests", dependencies: ["DomainProfile"])
    ]
)
```

```swift
// Data/DataUser/Package.swift — depends on domain + core
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DataUser",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "DataUser", targets: ["DataUser"])
    ],
    dependencies: [
        .package(path: "../../Domain/DomainProfile"),
        .package(path: "../../Core/CoreNetwork"),
        .package(path: "../../Core/CoreDatabase"),
    ],
    targets: [
        .target(
            name: "DataUser",
            dependencies: ["DomainProfile", "CoreNetwork", "CoreDatabase"]
        ),
        .testTarget(
            name: "DataUserTests",
            dependencies: ["DataUser"]
        )
    ]
)
```

```swift
// Features/FeatureProfile/Package.swift — depends on domain + coreUI
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureProfile",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureProfile", targets: ["FeatureProfile"])
    ],
    dependencies: [
        .package(path: "../../Domain/DomainProfile"),
        .package(path: "../../Core/CoreUI"),
    ],
    targets: [
        .target(
            name: "FeatureProfile",
            dependencies: ["DomainProfile", "CoreUI"]
        ),
        .testTarget(
            name: "FeatureProfileTests",
            dependencies: ["FeatureProfile"]
        )
    ]
)
```

### Dependency Rule (Same Principle)

```
Presentation (Feature*) --> Domain (Domain*) <-- Data (Data*)
                                    ^
                                    |
                              Core modules
```

Feature modules NEVER import Data modules directly. They depend only on Domain protocols.

### Domain Layer (Pure Swift)

```swift
// Domain/DomainProfile/Sources/Models/User.swift
public struct User: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let email: String
    public let avatarURL: URL?

    public init(id: String, name: String, email: String, avatarURL: URL?) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarURL = avatarURL
    }
}

// Domain/DomainProfile/Sources/Repositories/UserRepository.swift
public protocol UserRepositoryProtocol: Sendable {
    func observeUser(userId: String) -> AsyncThrowingStream<User, Error>
    func refreshUser(userId: String) async throws -> User
}

// Domain/DomainProfile/Sources/UseCases/GetUserUseCase.swift
public protocol GetUserUseCaseProtocol: Sendable {
    func execute(userId: String) async throws -> User
}

public struct GetUserUseCase: GetUserUseCaseProtocol {
    private let userRepository: UserRepositoryProtocol

    public init(userRepository: UserRepositoryProtocol) {
        self.userRepository = userRepository
    }

    public func execute(userId: String) async throws -> User {
        try await userRepository.refreshUser(userId: userId)
    }
}
```

### Data Layer

```swift
// Data/DataUser/Sources/Remote/UserDTO.swift
struct UserDTO: Codable, Sendable {
    let id: String
    let name: String
    let email: String
    let avatarUrl: String?
}

// Data/DataUser/Sources/Mappers/UserMapper.swift
import DomainProfile

extension UserDTO {
    func toDomain() -> User {
        User(
            id: id,
            name: name,
            email: email,
            avatarURL: avatarUrl.flatMap(URL.init(string:))
        )
    }
}

extension UserModel {
    func toDomain() -> User {
        User(id: id, name: name, email: email, avatarURL: avatarURL)
    }

    func update(from user: User) {
        name = user.name
        email = user.email
        avatarURL = user.avatarURL
    }
}

// Data/DataUser/Sources/UserRepositoryImpl.swift
import DomainProfile
import CoreNetwork
import CoreDatabase

public final class UserRepositoryImpl: UserRepositoryProtocol, Sendable {
    private let userAPI: UserAPIProtocol
    private let userStore: UserStoreProtocol

    public init(userAPI: UserAPIProtocol, userStore: UserStoreProtocol) {
        self.userAPI = userAPI
        self.userStore = userStore
    }

    public func observeUser(userId: String) -> AsyncThrowingStream<User, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                Task { try? await refreshUser(userId: userId) }
                do {
                    for try await user in userStore.observe(userId: userId) {
                        continuation.yield(user)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @discardableResult
    public func refreshUser(userId: String) async throws -> User {
        let dto = try await userAPI.getUser(userId: userId)
        let user = dto.toDomain()
        try await userStore.upsert(user)
        return user
    }
}
```

### Presentation Layer

```swift
// Features/FeatureProfile/Sources/ProfileViewModel.swift
import DomainProfile
import SwiftUI

@Observable
public final class ProfileViewModel {
    private let getUserUseCase: GetUserUseCaseProtocol
    private let observeUserUseCase: ObserveUserUseCaseProtocol

    public var uiState = ProfileUiState()

    private var observeTask: Task<Void, Never>?

    public init(
        getUserUseCase: GetUserUseCaseProtocol,
        observeUserUseCase: ObserveUserUseCaseProtocol
    ) {
        self.getUserUseCase = getUserUseCase
        self.observeUserUseCase = observeUserUseCase
    }

    @MainActor
    public func startObserving(userId: String) {
        observeTask?.cancel()
        observeTask = Task { [weak self] in
            guard let self else { return }
            uiState.isLoading = true
            do {
                for try await user in observeUserUseCase.execute(userId: userId) {
                    uiState.user = user
                    uiState.isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                uiState.error = error.localizedDescription
                uiState.isLoading = false
            }
        }
    }

    deinit {
        observeTask?.cancel()
    }
}

public struct ProfileUiState {
    public var user: User?
    public var isLoading: Bool = false
    public var error: String?
}

// Features/FeatureProfile/Sources/ProfileView.swift
import SwiftUI
import DomainProfile
import CoreUI

public struct ProfileView: View {
    @State private var viewModel: ProfileViewModel
    private let userId: String
    private let onNavigateToSettings: () -> Void

    public init(
        userId: String,
        getUserUseCase: GetUserUseCaseProtocol,
        observeUserUseCase: ObserveUserUseCaseProtocol,
        onNavigateToSettings: @escaping () -> Void
    ) {
        self.userId = userId
        self._viewModel = State(initialValue: ProfileViewModel(
            getUserUseCase: getUserUseCase,
            observeUserUseCase: observeUserUseCase
        ))
        self.onNavigateToSettings = onNavigateToSettings
    }

    public var body: some View {
        ProfileContent(
            state: viewModel.uiState,
            onRetry: { viewModel.startObserving(userId: userId) },
            onSettingsTap: onNavigateToSettings
        )
        .task {
            viewModel.startObserving(userId: userId)
        }
    }
}
```

### Navigation — Coordinator Pattern (NavGraph Equivalent)

```swift
// App/WaonderApp/Navigation/AppCoordinator.swift
import SwiftUI
import FeatureHome
import FeatureProfile

enum AppRoute: Hashable {
    case home
    case profile(userId: String)
    case settings
}

@Observable
final class AppCoordinator {
    var path = NavigationPath()

    func navigateToProfile(userId: String) {
        path.append(AppRoute.profile(userId: userId))
    }

    func navigateToSettings() {
        path.append(AppRoute.settings)
    }

    func pop() {
        path.removeLast()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}

// App/WaonderApp/Navigation/AppNavigationView.swift
struct AppNavigationView: View {
    @State private var coordinator = AppCoordinator()
    private let container: DependencyContainer

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            HomeView(
                onProfileTap: { userId in
                    coordinator.navigateToProfile(userId: userId)
                }
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .home:
                    HomeView(onProfileTap: { coordinator.navigateToProfile(userId: $0) })
                case .profile(let userId):
                    ProfileView(
                        userId: userId,
                        getUserUseCase: container.makeGetUserUseCase(),
                        observeUserUseCase: container.makeObserveUserUseCase(),
                        onNavigateToSettings: { coordinator.navigateToSettings() }
                    )
                case .settings:
                    SettingsView()
                }
            }
        }
        .environment(coordinator)
    }
}
```

### Dependency Injection Container (Hilt Module Equivalent)

```swift
// App/WaonderApp/DI/DependencyContainer.swift
import DomainProfile
import DataUser
import CoreNetwork
import CoreDatabase

@MainActor
final class DependencyContainer {
    // MARK: - Core
    private lazy var apiClient: APIClient = APIClient(baseURL: URL(string: "https://api.waonder.com")!)
    private lazy var databaseContainer: DatabaseContainer = DatabaseContainer()

    // MARK: - Data
    private lazy var userAPI: UserAPIProtocol = UserAPI(apiClient: apiClient)
    private lazy var userStore: UserStoreProtocol = UserStore(container: databaseContainer.container)
    private lazy var userRepository: UserRepositoryProtocol = UserRepositoryImpl(
        userAPI: userAPI,
        userStore: userStore
    )

    // MARK: - Use Cases
    func makeGetUserUseCase() -> GetUserUseCaseProtocol {
        GetUserUseCase(userRepository: userRepository)
    }

    func makeObserveUserUseCase() -> ObserveUserUseCaseProtocol {
        ObserveUserUseCase(userRepository: userRepository)
    }
}
```

## Migration Mapping Table

| Android | iOS |
|---|---|
| Gradle module (`:domain:profile`) | SPM package (`DomainProfile`) |
| `build.gradle.kts` dependencies | `Package.swift` dependencies |
| `@Module @InstallIn(SingletonComponent)` | `DependencyContainer` class (or Swinject/Factory) |
| `@Binds` / `@Provides` | `lazy var` / factory methods in container |
| `@HiltViewModel` | Manual injection via `init` |
| `NavHost` + `composable()` routes | `NavigationStack` + `.navigationDestination` |
| `NavController.navigate()` | Coordinator `path.append()` |
| `navArgument` | Route enum associated values |
| `NavBackStackEntry` | Automatic via `NavigationPath` |
| `hiltViewModel()` | `@State` + DI container factory |
| Feature module | SPM Feature package |
| `:core:network` (Retrofit/OkHttp) | `CoreNetwork` SPM (URLSession) |
| `:core:database` (Room) | `CoreDatabase` SPM (SwiftData/CoreData) |
| `:core:ui` (shared Compose) | `CoreUI` SPM (shared SwiftUI components) |

## Layer Boundary Rules

### What Each Layer May Import

| Layer | May Import | Must NOT Import |
|---|---|---|
| Domain | Nothing (pure Swift) | Data, Feature, Core, UIKit, SwiftUI |
| Data | Domain, Core | Feature, UIKit, SwiftUI |
| Feature (Presentation) | Domain, CoreUI | Data, other Features |
| Core | CoreCommon only | Domain, Data, Feature |
| App | Everything | (it is the composition root) |

### Enforcing Boundaries with SPM

SPM naturally enforces these boundaries because a package can only see its declared dependencies. If `FeatureProfile` does not list `DataUser` in its `Package.swift`, it physically cannot import it. This is stricter than Android Gradle modules where accidental transitive dependencies can leak.

## Navigation Patterns Comparison

### Pattern 1: Coordinator (Recommended for Complex Apps)

The Coordinator pattern maps most closely to Android's NavGraph approach. A coordinator object owns the navigation path and provides methods to navigate, mimicking `NavController`.

### Pattern 2: NavigationPath with Enums (Simple Apps)

For simpler apps, skip the coordinator and use `NavigationPath` directly in the root view with route enums.

### Pattern 3: TCA (The Composable Architecture)

If adopting TCA, navigation is handled via reducer composition and `@Presents` / `.navigationDestination(store:)`. This is a more opinionated approach but provides excellent testability.

```swift
// TCA example sketch
@Reducer
struct AppFeature {
    @ObservableState
    struct State {
        var path = StackState<Path.State>()
    }

    enum Action {
        case path(StackActionOf<Path>)
    }

    @Reducer
    enum Path {
        case profile(ProfileFeature)
        case settings(SettingsFeature)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            // handle root actions
            .none
        }
        .forEach(\.path, action: \.path)
    }
}
```

## Testing Strategy per Layer

### Domain Tests (Unit Tests — No Dependencies)

```swift
@Test func getUserUseCase_delegatesToRepository() async throws {
    let mockRepo = MockUserRepository(user: .stub)
    let useCase = GetUserUseCase(userRepository: mockRepo)

    let user = try await useCase.execute(userId: "1")
    #expect(user.id == "1")
}
```

### Data Tests (Integration Tests — Mock Network + Real DB)

```swift
@Test func repositoryImpl_cachesRemoteData() async throws {
    let mockAPI = MockUserAPI(user: .dtoStub)
    let store = InMemoryUserStore()
    let repo = UserRepositoryImpl(userAPI: mockAPI, userStore: store)

    let user = try await repo.refreshUser(userId: "1")
    let cached = try await store.get(userId: "1")

    #expect(user.name == cached?.name)
}
```

### Feature Tests (ViewModel Tests — Mock Use Cases)

```swift
@Test @MainActor func viewModel_showsUser() async throws {
    let mockUseCase = MockObserveUserUseCase(user: .stub)
    let vm = ProfileViewModel(
        getUserUseCase: MockGetUserUseCase(),
        observeUserUseCase: mockUseCase
    )

    vm.startObserving(userId: "1")
    try await Task.sleep(for: .milliseconds(100))

    #expect(vm.uiState.user?.name == "Test User")
    #expect(vm.uiState.isLoading == false)
}
```

## Common Pitfalls

1. **Feature modules importing Data modules** — This violates the dependency rule. Features should only depend on Domain protocols. Wire concrete implementations in the App's DI container.

2. **Domain layer importing Foundation unnecessarily** — Keep the domain layer as pure Swift as possible. `Foundation` is acceptable for `URL`, `Date`, `UUID`, but avoid `URLSession`, `JSONDecoder`, or any I/O types.

3. **Circular SPM dependencies** — SPM does not allow circular dependencies. If two features need to communicate, introduce a shared Domain module or use a coordinator/event bus at the App level.

4. **Monolithic DI container** — For large apps, split `DependencyContainer` into feature-scoped containers or use a DI library (Swinject, Factory, swift-dependencies) to avoid a single massive file.

5. **Navigation logic in ViewModels** — ViewModels should emit navigation intents (via callbacks or events), not directly manipulate `NavigationPath`. The coordinator or view handles actual navigation.

6. **Forgetting `public` access control in SPM** — Types in SPM packages are `internal` by default. Domain models, protocols, and use cases must be marked `public` to be visible to other packages.

7. **Over-modularizing** — Start with one domain, one data, and one feature module per bounded context. Do not create a separate SPM package for every single file. Aim for 5-15 modules in a mid-size app.

8. **Not using protocol suffixes consistently** — Use `Protocol` suffix for repository and use case protocols (`UserRepositoryProtocol`, `GetUserUseCaseProtocol`) to avoid naming collisions with concrete types.

## Migration Checklist

- [ ] Map every Gradle module to an equivalent SPM package
- [ ] Create `Package.swift` for each module with correct dependency declarations
- [ ] Verify domain packages have ZERO framework dependencies (no SwiftUI, UIKit, Foundation I/O)
- [ ] Migrate domain models as `struct` with `Sendable`, `Equatable`, `Identifiable`
- [ ] Migrate repository interfaces as `public protocol` in domain packages
- [ ] Migrate use cases as `public struct` with protocol conformance in domain packages
- [ ] Migrate data layer implementations in data packages (API + Store + Mappers)
- [ ] Migrate ViewModels to `@Observable` classes in feature packages
- [ ] Migrate Compose screens to SwiftUI views in feature packages
- [ ] Create DI container in the App target wiring protocols to concrete implementations
- [ ] Implement navigation using Coordinator pattern or NavigationStack paths
- [ ] Replace Hilt `@Module`/`@Binds`/`@Provides` with DI container factory methods
- [ ] Add `public` access control to all types used across module boundaries
- [ ] Verify no feature module imports any data module directly
- [ ] Verify no circular dependencies between SPM packages
- [ ] Create shared `CoreUI` package for reusable SwiftUI components
- [ ] Set up test targets in each `Package.swift`
- [ ] Write unit tests per layer: domain (pure logic), data (mock network), feature (mock use cases)
- [ ] Configure Xcode workspace to include all local SPM packages
