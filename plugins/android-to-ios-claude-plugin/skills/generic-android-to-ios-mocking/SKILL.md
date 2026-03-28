---
name: generic-android-to-ios-mocking
description: Use when migrating Android mocking patterns (MockK with every/verify/coEvery/slot/relaxed mocks, Mockito-Kotlin, Turbine for Flow testing) to iOS equivalents (protocol-based manual mocks, Mockolo code generation, Combine testing with expectations), covering why Swift cannot do runtime mocking, protocol-oriented design for testability, fake vs mock vs stub patterns, and testing async code
type: generic
---

# generic-android-to-ios-mocking

## Context

Android benefits from runtime mocking libraries (MockK, Mockito) that use bytecode manipulation and reflection to create mock objects on the fly. Swift's static type system and lack of runtime reflection make this approach impossible. iOS testing relies on protocol-based design, manual test doubles, and code generation tools. This is the most significant mindset shift in the migration: you must design for testability upfront rather than mocking after the fact.

## Why Swift Cannot Do Runtime Mocking

Kotlin/JVM allows libraries to generate subclasses at runtime, intercept method calls, and record interactions. Swift does not support this because:

- **No runtime class generation**: Swift does not have a classloader that can create types at runtime
- **Final by default**: Swift classes, structs, and methods are not open for subclassing by default
- **Value types**: Structs (heavily used in Swift) cannot be subclassed at all
- **Protocol witness tables**: Protocol dispatch uses a different mechanism than virtual dispatch, making interception infeasible

**Consequence**: Every dependency you want to mock in Swift must be abstracted behind a protocol (or closure) at compile time.

## Quick Reference: Concept Mapping

| Android (MockK/Mockito) | iOS Equivalent | Notes |
|---|---|---|
| `mockk<UserRepository>()` | Define `protocol UserRepositoryProtocol`, create `MockUserRepository` class | Manual or Mockolo-generated |
| `every { mock.getUser(any()) } returns user` | `mock.getUserResult = user` (property on fake) | No DSL, explicit setup |
| `verify { mock.getUser("1") }` | `XCTAssertEqual(mock.getUserCallCount, 1)` | Track calls manually |
| `coEvery { mock.fetchData() } returns data` | `mock.fetchDataResult = data` | Same pattern, async is transparent |
| `slot<String>()` | `mock.capturedArguments: [String]` | Array property on fake |
| `relaxed = true` | Provide default return values in mock | No auto-relaxation |
| `confirmVerified(mock)` | Assert on call counts | Manual verification |
| `Turbine` (Flow testing) | Combine + `XCTestExpectation` or custom collector | See async testing section |
| `spyk(realObject)` | Subclass + override (classes only) | Very limited in Swift |

## Android Source Patterns

### MockK: Basic Mocking

```kotlin
class UserViewModelTest {

    private val repository = mockk<UserRepository>()
    private lateinit var viewModel: UserViewModel

    @Before
    fun setUp() {
        viewModel = UserViewModel(repository)
    }

    @Test
    fun `loadUser updates state with user data`() = runTest {
        val user = User(id = "1", name = "Alice")
        coEvery { repository.getUser("1") } returns user

        viewModel.loadUser("1")

        assertEquals(user, viewModel.uiState.value.user)
        coVerify(exactly = 1) { repository.getUser("1") }
    }

    @Test
    fun `loadUser sets error state on failure`() = runTest {
        coEvery { repository.getUser(any()) } throws NetworkException("timeout")

        viewModel.loadUser("1")

        assertNotNull(viewModel.uiState.value.error)
        assertEquals("timeout", viewModel.uiState.value.error)
    }
}
```

### MockK: Argument Capturing

```kotlin
@Test
fun `saveUser passes correct data to repository`() = runTest {
    val slot = slot<User>()
    coEvery { repository.saveUser(capture(slot)) } returns Unit

    viewModel.updateProfile(name = "Alice", email = "alice@example.com")

    assertTrue(slot.isCaptured)
    assertEquals("Alice", slot.captured.name)
    assertEquals("alice@example.com", slot.captured.email)
}
```

### MockK: Relaxed Mocks and Verification Order

```kotlin
@Test
fun `checkout flow calls services in order`() = runTest {
    val cartService = mockk<CartService>(relaxed = true)
    val paymentService = mockk<PaymentService>(relaxed = true)
    val orderService = mockk<OrderService>(relaxed = true)
    val checkout = CheckoutManager(cartService, paymentService, orderService)

    checkout.processCheckout(cartId = "cart-1")

    verifyOrder {
        cartService.validateCart("cart-1")
        paymentService.processPayment(any())
        orderService.createOrder(any())
    }
}
```

### Mockito-Kotlin

```kotlin
class OrderServiceTest {

    private val paymentGateway: PaymentGateway = mock()
    private val service = OrderService(paymentGateway)

    @Test
    fun `processOrder calls payment gateway`() {
        whenever(paymentGateway.charge(any(), any())).thenReturn(PaymentResult.Success)

        service.processOrder(Order(id = "1", amount = 99.99))

        verify(paymentGateway).charge(eq("1"), eq(99.99))
    }

    @Test
    fun `processOrder handles payment failure`() {
        whenever(paymentGateway.charge(any(), any())).thenReturn(PaymentResult.Declined)

        val result = service.processOrder(Order(id = "1", amount = 99.99))

        assertEquals(OrderStatus.FAILED, result.status)
        verify(paymentGateway, never()).confirmOrder(any())
    }
}
```

### Turbine: Flow Testing

```kotlin
@Test
fun `search emits loading then results`() = runTest {
    val repository = mockk<SearchRepository>()
    coEvery { repository.search("kotlin") } returns listOf("Result 1", "Result 2")
    val viewModel = SearchViewModel(repository)

    viewModel.searchResults.test {
        viewModel.search("kotlin")

        assertEquals(SearchState.Loading, awaitItem())
        assertEquals(SearchState.Success(listOf("Result 1", "Result 2")), awaitItem())

        cancelAndIgnoreRemainingEvents()
    }
}

@Test
fun `search emits error on failure`() = runTest {
    val repository = mockk<SearchRepository>()
    coEvery { repository.search(any()) } throws IOException("network error")
    val viewModel = SearchViewModel(repository)

    viewModel.searchResults.test {
        viewModel.search("kotlin")

        assertEquals(SearchState.Loading, awaitItem())
        val error = awaitItem()
        assertTrue(error is SearchState.Error)
        assertEquals("network error", (error as SearchState.Error).message)

        cancelAndIgnoreRemainingEvents()
    }
}
```

## iOS Target Patterns

### Step 1: Define Protocols for Dependencies

Every class you want to mock must have a protocol. This is the fundamental prerequisite.

```swift
// Production code: define protocol
protocol UserRepositoryProtocol {
    func getUser(id: String) async throws -> User
    func saveUser(_ user: User) async throws
    func deleteUser(id: String) async throws
}

// Production implementation
final class UserRepository: UserRepositoryProtocol {
    private let apiClient: APIClient
    private let cache: UserCache

    init(apiClient: APIClient, cache: UserCache) {
        self.apiClient = apiClient
        self.cache = cache
    }

    func getUser(id: String) async throws -> User {
        if let cached = cache.get(id: id) { return cached }
        let user = try await apiClient.fetch(endpoint: .user(id))
        cache.set(user, for: id)
        return user
    }

    func saveUser(_ user: User) async throws {
        try await apiClient.post(endpoint: .saveUser, body: user)
    }

    func deleteUser(id: String) async throws {
        try await apiClient.delete(endpoint: .user(id))
    }
}
```

### Step 2: Create Manual Mock (Fake)

```swift
// Test double: manual mock with call tracking
final class MockUserRepository: UserRepositoryProtocol {

    // --- getUser ---
    var getUserResult: Result<User, Error> = .failure(TestError.notConfigured)
    var getUserCallCount = 0
    var getUserCapturedIds: [String] = []

    func getUser(id: String) async throws -> User {
        getUserCallCount += 1
        getUserCapturedIds.append(id)
        return try getUserResult.get()
    }

    // --- saveUser ---
    var saveUserError: Error?
    var saveUserCallCount = 0
    var saveUserCapturedUsers: [User] = []

    func saveUser(_ user: User) async throws {
        saveUserCallCount += 1
        saveUserCapturedUsers.append(user)
        if let error = saveUserError { throw error }
    }

    // --- deleteUser ---
    var deleteUserError: Error?
    var deleteUserCallCount = 0
    var deleteUserCapturedIds: [String] = []

    func deleteUser(id: String) async throws {
        deleteUserCallCount += 1
        deleteUserCapturedIds.append(id)
        if let error = deleteUserError { throw error }
    }
}

enum TestError: Error {
    case notConfigured
    case simulated(String)
}
```

### Step 3: Use Mock in Tests (Equivalent to MockK Tests)

```swift
import XCTest
@testable import MyApp

final class UserViewModelTests: XCTestCase {

    private var mockRepository: MockUserRepository!
    private var viewModel: UserViewModel!

    override func setUp() {
        super.setUp()
        mockRepository = MockUserRepository()
        viewModel = UserViewModel(repository: mockRepository)
    }

    func testLoadUser_updatesStateWithUserData() async {
        let user = User(id: "1", name: "Alice")
        mockRepository.getUserResult = .success(user)

        await viewModel.loadUser(id: "1")

        XCTAssertEqual(viewModel.uiState.user, user)
        XCTAssertEqual(mockRepository.getUserCallCount, 1)       // verify(exactly = 1)
        XCTAssertEqual(mockRepository.getUserCapturedIds, ["1"])  // verify argument
    }

    func testLoadUser_setsErrorStateOnFailure() async {
        mockRepository.getUserResult = .failure(TestError.simulated("timeout"))

        await viewModel.loadUser(id: "1")

        XCTAssertNotNil(viewModel.uiState.error)
        XCTAssertEqual(viewModel.uiState.error, "timeout")
    }
}
```

### Swift Testing Version

```swift
import Testing
@testable import MyApp

@Suite("UserViewModel")
struct UserViewModelTests {

    @Test("loadUser updates state with user data")
    func loadUser() async {
        let mockRepository = MockUserRepository()
        let viewModel = UserViewModel(repository: mockRepository)
        let user = User(id: "1", name: "Alice")
        mockRepository.getUserResult = .success(user)

        await viewModel.loadUser(id: "1")

        #expect(viewModel.uiState.user == user)
        #expect(mockRepository.getUserCallCount == 1)
        #expect(mockRepository.getUserCapturedIds == ["1"])
    }

    @Test("loadUser sets error state on failure")
    func loadUserFailure() async {
        let mockRepository = MockUserRepository()
        let viewModel = UserViewModel(repository: mockRepository)
        mockRepository.getUserResult = .failure(TestError.simulated("timeout"))

        await viewModel.loadUser(id: "1")

        #expect(viewModel.uiState.error == "timeout")
    }
}
```

### Argument Capturing (Equivalent to MockK slot)

```swift
func testSaveUser_passesCorrectData() async throws {
    await viewModel.updateProfile(name: "Alice", email: "alice@example.com")

    XCTAssertEqual(mockRepository.saveUserCallCount, 1)

    let capturedUser = mockRepository.saveUserCapturedUsers[0]
    XCTAssertEqual(capturedUser.name, "Alice")
    XCTAssertEqual(capturedUser.email, "alice@example.com")
}
```

### Verification Order (Equivalent to MockK verifyOrder)

```swift
// Track call order across multiple mocks using a shared recorder
final class CallRecorder {
    var calls: [String] = []

    func record(_ call: String) {
        calls.append(call)
    }
}

final class MockCartService: CartServiceProtocol {
    let recorder: CallRecorder

    init(recorder: CallRecorder) { self.recorder = recorder }

    func validateCart(_ cartId: String) async throws {
        recorder.record("validateCart")
    }
}

final class MockPaymentService: PaymentServiceProtocol {
    let recorder: CallRecorder

    init(recorder: CallRecorder) { self.recorder = recorder }

    func processPayment(_ payment: Payment) async throws {
        recorder.record("processPayment")
    }
}

final class MockOrderService: OrderServiceProtocol {
    let recorder: CallRecorder

    init(recorder: CallRecorder) { self.recorder = recorder }

    func createOrder(_ order: Order) async throws {
        recorder.record("createOrder")
    }
}

// Test
func testCheckoutFlow_callsServicesInOrder() async throws {
    let recorder = CallRecorder()
    let cartService = MockCartService(recorder: recorder)
    let paymentService = MockPaymentService(recorder: recorder)
    let orderService = MockOrderService(recorder: recorder)
    let checkout = CheckoutManager(
        cart: cartService,
        payment: paymentService,
        order: orderService
    )

    try await checkout.processCheckout(cartId: "cart-1")

    XCTAssertEqual(recorder.calls, ["validateCart", "processPayment", "createOrder"])
}
```

### Mockolo: Code-Generated Mocks

For large codebases, manually writing mocks is tedious. Mockolo generates mock classes from protocols.

**Setup:** `brew install mockolo` or add via SPM build plugin.

```swift
// Annotate protocols for mock generation
/// @mockable
protocol UserRepositoryProtocol {
    func getUser(id: String) async throws -> User
    func saveUser(_ user: User) async throws
}

// Run: mockolo -s Sources -d Tests/GeneratedMocks.swift -i MyApp
// Generates a MockUserRepositoryProtocol class with:
// - Configurable return values
// - Call counts
// - Argument capture
```

**Generated mock usage:**

```swift
func testLoadUser_withMockolo() async {
    let mock = MockUserRepositoryProtocol()
    mock.getUserHandler = { id in
        return User(id: id, name: "Alice")
    }

    let viewModel = UserViewModel(repository: mock)
    await viewModel.loadUser(id: "1")

    XCTAssertEqual(mock.getUserCallCount, 1)
    XCTAssertEqual(viewModel.uiState.user?.name, "Alice")
}
```

### Closure-Based Dependency Injection (Alternative to Protocols)

For simple dependencies, closures avoid the ceremony of protocol + mock class:

```swift
// Production code
struct UserViewModel {
    private let fetchUser: (String) async throws -> User
    @Published var uiState = UserUiState()

    init(fetchUser: @escaping (String) async throws -> User) {
        self.fetchUser = fetchUser
    }

    func loadUser(id: String) async {
        do {
            let user = try await fetchUser(id)
            uiState = UserUiState(user: user)
        } catch {
            uiState = UserUiState(error: error.localizedDescription)
        }
    }
}

// Test: no mock class needed
func testLoadUser_withClosure() async {
    let viewModel = UserViewModel(fetchUser: { id in
        User(id: id, name: "Alice")
    })

    await viewModel.loadUser(id: "1")

    XCTAssertEqual(viewModel.uiState.user?.name, "Alice")
}

// Test failure path
func testLoadUser_failure_withClosure() async {
    let viewModel = UserViewModel(fetchUser: { _ in
        throw URLError(.notConnectedToInternet)
    })

    await viewModel.loadUser(id: "1")

    XCTAssertNotNil(viewModel.uiState.error)
}
```

## Fake vs Mock vs Stub: When to Use What

| Type | Definition | iOS Pattern | When to Use |
|---|---|---|---|
| **Stub** | Returns preconfigured values, no verification | Property with fixed return value | Simple dependencies, no need to verify calls |
| **Mock** | Records interactions for verification | Properties for call count + captured args | Need to verify a method was called with specific args |
| **Fake** | Working implementation with shortcuts | In-memory database, in-memory cache | Need realistic behavior without external systems |
| **Spy** | Wraps real object, records calls | Subclass override (class-only) | Rare in Swift; prefer protocol-based mocks |

### Fake Example: In-Memory Repository

```swift
// Fake: has real behavior, just uses in-memory storage
final class FakeUserRepository: UserRepositoryProtocol {
    private var users: [String: User] = [:]

    func getUser(id: String) async throws -> User {
        guard let user = users[id] else {
            throw UserNotFoundError(id: id)
        }
        return user
    }

    func saveUser(_ user: User) async throws {
        users[user.id] = user
    }

    func deleteUser(id: String) async throws {
        users.removeValue(forKey: id)
    }

    // Test helper
    func seed(_ users: [User]) {
        for user in users {
            self.users[user.id] = user
        }
    }
}
```

## Testing Async Code and Streams

### Combine Publisher Testing (Equivalent to Turbine)

```swift
import XCTest
import Combine
@testable import MyApp

final class SearchViewModelTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testSearch_emitsLoadingThenResults() {
        let mockRepository = MockSearchRepository()
        mockRepository.searchResult = .success(["Result 1", "Result 2"])
        let viewModel = SearchViewModel(repository: mockRepository)

        var states: [SearchState] = []
        let expectation = expectation(description: "States collected")
        expectation.expectedFulfillmentCount = 2

        viewModel.$searchState
            .dropFirst() // skip initial value
            .sink { state in
                states.append(state)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.search("swift")

        wait(for: [expectation], timeout: 2)

        XCTAssertEqual(states.count, 2)
        XCTAssertEqual(states[0], .loading)
        XCTAssertEqual(states[1], .success(["Result 1", "Result 2"]))
    }

    func testSearch_emitsErrorOnFailure() {
        let mockRepository = MockSearchRepository()
        mockRepository.searchResult = .failure(TestError.simulated("network error"))
        let viewModel = SearchViewModel(repository: mockRepository)

        var states: [SearchState] = []
        let expectation = expectation(description: "States collected")
        expectation.expectedFulfillmentCount = 2

        viewModel.$searchState
            .dropFirst()
            .sink { state in
                states.append(state)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.search("swift")

        wait(for: [expectation], timeout: 2)

        XCTAssertEqual(states[0], .loading)
        if case .error(let message) = states[1] {
            XCTAssertEqual(message, "network error")
        } else {
            XCTFail("Expected error state")
        }
    }
}
```

### AsyncSequence Testing (Modern Swift Equivalent to Turbine)

```swift
// Helper: collect values from an AsyncSequence with a timeout
func collect<S: AsyncSequence>(
    _ sequence: S,
    count: Int,
    timeout: TimeInterval = 2.0
) async throws -> [S.Element] {
    var values: [S.Element] = []

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            for try await value in sequence {
                values.append(value)
                if values.count >= count { return }
            }
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw TimeoutError()
        }

        try await group.next()
        group.cancelAll()
    }

    return values
}

// Usage in test
func testSearch_emitsStates() async throws {
    let mockRepository = MockSearchRepository()
    mockRepository.searchResult = .success(["Result 1"])
    let viewModel = SearchViewModel(repository: mockRepository)

    // Collect 2 state changes (loading + results)
    async let states = collect(viewModel.stateStream, count: 2)

    viewModel.search("swift")

    let collected = try await states
    XCTAssertEqual(collected[0], .loading)
    XCTAssertEqual(collected[1], .success(["Result 1"]))
}
```

### Testing @Observable (iOS 17+)

```swift
import XCTest
@testable import MyApp

@Observable
class CounterViewModel {
    var count = 0
    private let analytics: AnalyticsProtocol

    init(analytics: AnalyticsProtocol) {
        self.analytics = analytics
    }

    func increment() {
        count += 1
        analytics.track(event: "counter_incremented", value: count)
    }
}

final class CounterViewModelTests: XCTestCase {

    func testIncrement_updatesCount() {
        let mockAnalytics = MockAnalytics()
        let viewModel = CounterViewModel(analytics: mockAnalytics)

        viewModel.increment()

        XCTAssertEqual(viewModel.count, 1)
    }

    func testIncrement_tracksAnalytics() {
        let mockAnalytics = MockAnalytics()
        let viewModel = CounterViewModel(analytics: mockAnalytics)

        viewModel.increment()
        viewModel.increment()

        XCTAssertEqual(mockAnalytics.trackedEvents.count, 2)
        XCTAssertEqual(mockAnalytics.trackedEvents[0].name, "counter_incremented")
        XCTAssertEqual(mockAnalytics.trackedEvents[1].value, 2)
    }
}
```

## Protocol-Oriented Design Patterns for Testability

### Pattern: Protocol with Associated Type

```swift
// When you need generic protocols (e.g., generic repository)
protocol Repository {
    associatedtype Entity: Identifiable

    func get(id: Entity.ID) async throws -> Entity
    func save(_ entity: Entity) async throws
    func delete(id: Entity.ID) async throws
}

// Problem: can't use as a type directly. Solution: type erasure or constrain at use site.

// Option A: Constrain at use site
class UserViewModel<Repo: Repository> where Repo.Entity == User {
    private let repository: Repo
    init(repository: Repo) { self.repository = repository }
}

// Option B: Use a concrete protocol without associated types (preferred for testability)
protocol UserRepositoryProtocol {
    func getUser(id: String) async throws -> User
    func saveUser(_ user: User) async throws
}
```

### Pattern: Environment-Based DI for SwiftUI

```swift
// Define a dependency key
private struct UserRepositoryKey: EnvironmentKey {
    static let defaultValue: any UserRepositoryProtocol = UserRepository()
}

extension EnvironmentValues {
    var userRepository: any UserRepositoryProtocol {
        get { self[UserRepositoryKey.self] }
        set { self[UserRepositoryKey.self] = newValue }
    }
}

// In SwiftUI preview or test
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.userRepository, MockUserRepository())
    }
}
```

## Common Pitfalls

1. **Trying to use runtime mocking**: Libraries like OCMock or SwiftMock that attempt runtime method swizzling are fragile and limited to `@objc` classes. Do not rely on them for Swift code. Use protocol-based mocks.

2. **Forgetting to extract protocols**: If your production class is used directly without a protocol, you cannot mock it. Extract protocols early in the migration. A class `UserRepository` should implement `UserRepositoryProtocol`.

3. **Over-mocking**: Do not mock value types, simple data structures, or pure functions. Only mock boundaries (network, database, file system, analytics). Use real objects for domain logic.

4. **Mock maintenance burden**: Manual mocks grow stale when protocols change. Use Mockolo for large codebases, or keep protocols small (Interface Segregation Principle).

5. **Turbine has no direct iOS equivalent**: Combine publisher testing is more verbose. Consider writing a small helper (like the `collect()` function above) to reduce boilerplate. There is no 1:1 Turbine replacement.

6. **`@Published` emits on willSet**: Combine's `@Published` fires before the property changes. If you observe `$state`, you may see the old value first. Use `.receive(on: RunLoop.main)` or `dropFirst()` as needed.

7. **Async test methods need `async`**: XCTest supports `func testFoo() async throws` natively. Do not wrap in `Task { }` blocks -- use the async test method directly.

8. **Mocking static methods**: Kotlin allows `mockkStatic(...)`. Swift static methods cannot be mocked. Wrap them in a protocol or use a closure parameter.

9. **MockK's `relaxed = true` has no equivalent**: In Swift mocks, you must provide default return values. There is no auto-relaxation. Use optional return types or `fatalError("not configured")` for methods that should not be called in a particular test.

## Migration Checklist

- [ ] Identify all `mockk<T>()` and `mock<T>()` calls in Android tests
- [ ] For each mocked type, ensure an equivalent protocol exists in iOS production code
- [ ] Create manual mock classes implementing each protocol (or set up Mockolo)
- [ ] Add call count tracking (`var methodCallCount: Int`) to each mock method
- [ ] Add argument capture (`var methodCapturedArgs: [ArgType]`) where `verify` checks arguments
- [ ] Convert `every { mock.method() } returns value` to `mock.methodResult = value`
- [ ] Convert `coEvery { }` (coroutine) to the same pattern (async is transparent in Swift mocks)
- [ ] Convert `verify(exactly = N) { mock.method() }` to `XCTAssertEqual(mock.methodCallCount, N)`
- [ ] Convert `verify(never()) { }` to `XCTAssertEqual(mock.methodCallCount, 0)`
- [ ] Convert `slot<T>()` + `capture(slot)` to captured argument arrays on mock
- [ ] Convert `verifyOrder { }` to shared `CallRecorder` pattern
- [ ] Convert Turbine `test { awaitItem() }` to Combine publisher collection with expectations
- [ ] Replace `relaxed = true` mocks with explicit default values on mock properties
- [ ] Convert `mockkStatic` calls to protocol wrappers around static methods
- [ ] Evaluate closure-based DI for simple, single-method dependencies
- [ ] Set up Mockolo in build pipeline if project has more than 20 protocols to mock
- [ ] Ensure all ViewModel/Service classes accept protocols, not concrete types
