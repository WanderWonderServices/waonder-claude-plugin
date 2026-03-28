---
name: generic-android-to-ios-unit-testing
description: Use when migrating Android unit testing patterns (JUnit 4/5, @Test, @Before/@After, assertions, parameterized tests, test rules) to iOS equivalents (XCTest with XCTestCase, setUp/tearDown, XCTAssert*) and Swift Testing (@Test, #expect, @Suite, Xcode 16+), covering test structure, assertion mapping, async testing, fixtures, parameterized tests, and test filtering
type: generic
---

# generic-android-to-ios-unit-testing

## Context

Android unit testing is built on JUnit (4 and 5), which provides annotations, lifecycle callbacks, assertions, and parameterized test support. iOS has two frameworks: the mature XCTest (class-based, integrated since Xcode 5) and the newer Swift Testing (macro-based, available from Xcode 16 / Swift 6). This skill maps every JUnit concept to both iOS frameworks so you can choose the right target based on your minimum Xcode version.

## Quick Reference: Annotation / Macro Mapping

| Android (JUnit 4) | Android (JUnit 5) | iOS (XCTest) | iOS (Swift Testing) |
|---|---|---|---|
| `@Test` | `@Test` | `func test*()` prefix | `@Test` |
| `@Before` | `@BeforeEach` | `setUp()` / `setUpWithError()` | `init()` on `@Suite` struct |
| `@After` | `@AfterEach` | `tearDown()` / `tearDownWithError()` | `deinit` on `@Suite` class |
| `@BeforeClass` | `@BeforeAll` | `override class func setUp()` | Static property in `@Suite` |
| `@AfterClass` | `@AfterAll` | `override class func tearDown()` | No direct equivalent |
| `@Ignore` | `@Disabled` | `func DISABLED_testFoo()` | `@Test(.disabled("reason"))` |
| `@Tag` | `@Tag` | No built-in (use schemes) | `@Tag(.myTag)` |
| `@ParameterizedTest` | `@ParameterizedTest` | Not built-in (loop manually) | `@Test(arguments:)` |
| `@RunWith` | `@ExtendWith` | N/A | N/A |
| `@Rule` / `@ClassRule` | `@RegisterExtension` | No equivalent (use setUp) | No equivalent |

## Android Source Patterns

### JUnit 4 Basic Test

```kotlin
class UserRepositoryTest {

    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()

    private lateinit var repository: UserRepository
    private lateinit var fakeApi: FakeUserApi
    private lateinit var fakeDao: FakeUserDao

    @Before
    fun setUp() {
        fakeApi = FakeUserApi()
        fakeDao = FakeUserDao()
        repository = UserRepository(fakeApi, fakeDao)
    }

    @After
    fun tearDown() {
        fakeDao.clear()
    }

    @Test
    fun `getUser returns cached user when available`() {
        fakeDao.insert(User(id = "1", name = "Alice"))

        val result = repository.getUser("1")

        assertEquals(User(id = "1", name = "Alice"), result)
    }

    @Test(expected = UserNotFoundException::class)
    fun `getUser throws when user not found`() {
        repository.getUser("unknown")
    }

    @Test
    fun `getUser fetches from api when not cached`() {
        fakeApi.addUser(User(id = "2", name = "Bob"))

        val result = repository.getUser("2")

        assertEquals("Bob", result.name)
        assertTrue(fakeDao.contains("2"))
    }
}
```

### JUnit 5 with Extensions and Lifecycle

```kotlin
@ExtendWith(CoroutineTestExtension::class)
class OrderServiceTest {

    private lateinit var service: OrderService
    private lateinit var fakePayment: FakePaymentGateway

    @BeforeEach
    fun setUp() {
        fakePayment = FakePaymentGateway()
        service = OrderService(fakePayment)
    }

    @Test
    fun `processOrder succeeds with valid payment`() {
        fakePayment.willSucceed = true
        val order = Order(id = "1", amount = 99.99)

        val result = service.processOrder(order)

        assertEquals(OrderStatus.CONFIRMED, result.status)
    }

    @Nested
    inner class WhenPaymentFails {
        @BeforeEach
        fun setUp() {
            fakePayment.willSucceed = false
        }

        @Test
        fun `processOrder returns failed status`() {
            val result = service.processOrder(Order(id = "1", amount = 50.0))
            assertEquals(OrderStatus.FAILED, result.status)
        }

        @Test
        fun `processOrder does not deduct inventory`() {
            service.processOrder(Order(id = "1", amount = 50.0))
            assertEquals(0, service.deductionCount)
        }
    }
}
```

### JUnit 5 Parameterized Tests

```kotlin
class EmailValidatorTest {

    @ParameterizedTest(name = "{0} should be valid={1}")
    @CsvSource(
        "user@example.com, true",
        "invalid-email, false",
        "user@.com, false",
        "user+tag@example.com, true",
        "'', false"
    )
    fun `validates email addresses`(email: String, expected: Boolean) {
        assertEquals(expected, EmailValidator.isValid(email))
    }

    @ParameterizedTest
    @MethodSource("provideUsers")
    fun `formats display name correctly`(user: User, expectedName: String) {
        assertEquals(expectedName, user.displayName)
    }

    companion object {
        @JvmStatic
        fun provideUsers() = listOf(
            Arguments.of(User("Alice", "Smith"), "Alice Smith"),
            Arguments.of(User("Bob", null), "Bob"),
        )
    }
}
```

### Coroutine Testing (runTest)

```kotlin
class SyncManagerTest {

    @Test
    fun `sync uploads pending changes`() = runTest {
        val fakeRemote = FakeRemoteDataSource()
        val manager = SyncManager(fakeRemote, testScheduler)

        manager.addPendingChange(Change("update", "record-1"))
        manager.sync()

        assertEquals(1, fakeRemote.uploadedChanges.size)
        assertEquals("record-1", fakeRemote.uploadedChanges[0].recordId)
    }

    @Test
    fun `sync retries on transient failure`() = runTest {
        val fakeRemote = FakeRemoteDataSource()
        fakeRemote.failNextNTimes(2)
        val manager = SyncManager(fakeRemote, testScheduler)

        manager.addPendingChange(Change("update", "record-1"))
        manager.sync()

        assertEquals(3, fakeRemote.attemptCount) // 1 initial + 2 retries
        assertEquals(1, fakeRemote.uploadedChanges.size)
    }
}
```

## iOS Target Patterns

### XCTest: Basic Test (Equivalent to JUnit 4)

```swift
import XCTest
@testable import MyApp

final class UserRepositoryTests: XCTestCase {

    private var repository: UserRepository!
    private var fakeApi: FakeUserApi!
    private var fakeDao: FakeUserDao!

    override func setUp() {
        super.setUp()
        fakeApi = FakeUserApi()
        fakeDao = FakeUserDao()
        repository = UserRepository(api: fakeApi, dao: fakeDao)
    }

    override func tearDown() {
        fakeDao.clear()
        repository = nil
        fakeApi = nil
        fakeDao = nil
        super.tearDown()
    }

    func testGetUser_returnsCachedUser_whenAvailable() {
        fakeDao.insert(User(id: "1", name: "Alice"))

        let result = repository.getUser(id: "1")

        XCTAssertEqual(result, User(id: "1", name: "Alice"))
    }

    func testGetUser_throws_whenUserNotFound() {
        XCTAssertThrowsError(try repository.getUser(id: "unknown")) { error in
            XCTAssertTrue(error is UserNotFoundError)
        }
    }

    func testGetUser_fetchesFromApi_whenNotCached() {
        fakeApi.addUser(User(id: "2", name: "Bob"))

        let result = repository.getUser(id: "2")

        XCTAssertEqual(result?.name, "Bob")
        XCTAssertTrue(fakeDao.contains(id: "2"))
    }
}
```

### Swift Testing: Basic Test (Equivalent to JUnit 5)

```swift
import Testing
@testable import MyApp

@Suite("UserRepository Tests")
struct UserRepositoryTests {

    let repository: UserRepository
    let fakeApi: FakeUserApi
    let fakeDao: FakeUserDao

    init() {
        fakeApi = FakeUserApi()
        fakeDao = FakeUserDao()
        repository = UserRepository(api: fakeApi, dao: fakeDao)
    }

    @Test("Returns cached user when available")
    func getCachedUser() {
        fakeDao.insert(User(id: "1", name: "Alice"))

        let result = repository.getUser(id: "1")

        #expect(result == User(id: "1", name: "Alice"))
    }

    @Test("Throws when user not found")
    func getUserNotFound() {
        #expect(throws: UserNotFoundError.self) {
            try repository.getUser(id: "unknown")
        }
    }

    @Test("Fetches from API when not cached")
    func fetchFromApi() {
        fakeApi.addUser(User(id: "2", name: "Bob"))

        let result = repository.getUser(id: "2")

        #expect(result?.name == "Bob")
        #expect(fakeDao.contains(id: "2"))
    }
}
```

### Swift Testing: Nested Suites (Equivalent to JUnit 5 @Nested)

```swift
import Testing
@testable import MyApp

@Suite("OrderService")
struct OrderServiceTests {

    let service: OrderService
    let fakePayment: FakePaymentGateway

    init() {
        fakePayment = FakePaymentGateway()
        service = OrderService(payment: fakePayment)
    }

    @Test("Processes order with valid payment")
    func processValidOrder() {
        fakePayment.willSucceed = true
        let order = Order(id: "1", amount: 99.99)

        let result = service.processOrder(order)

        #expect(result.status == .confirmed)
    }

    @Suite("When Payment Fails")
    struct WhenPaymentFails {
        let service: OrderService
        let fakePayment: FakePaymentGateway

        init() {
            fakePayment = FakePaymentGateway()
            fakePayment.willSucceed = false
            service = OrderService(payment: fakePayment)
        }

        @Test("Returns failed status")
        func failedStatus() {
            let result = service.processOrder(Order(id: "1", amount: 50.0))
            #expect(result.status == .failed)
        }

        @Test("Does not deduct inventory")
        func noInventoryDeduction() {
            service.processOrder(Order(id: "1", amount: 50.0))
            #expect(service.deductionCount == 0)
        }
    }
}
```

### Swift Testing: Parameterized Tests (Equivalent to @ParameterizedTest)

```swift
import Testing
@testable import MyApp

@Suite("EmailValidator")
struct EmailValidatorTests {

    @Test("Validates email addresses", arguments: [
        ("user@example.com", true),
        ("invalid-email", false),
        ("user@.com", false),
        ("user+tag@example.com", true),
        ("", false)
    ])
    func validatesEmail(email: String, expected: Bool) {
        #expect(EmailValidator.isValid(email) == expected)
    }

    // For complex arguments, use a static property or zip
    static let users: [(User, String)] = [
        (User(first: "Alice", last: "Smith"), "Alice Smith"),
        (User(first: "Bob", last: nil), "Bob"),
    ]

    @Test("Formats display name correctly", arguments: users)
    func formatsDisplayName(user: User, expectedName: String) {
        #expect(user.displayName == expectedName)
    }
}
```

### XCTest: Parameterized Tests (Manual Loop Pattern)

```swift
import XCTest
@testable import MyApp

final class EmailValidatorTests: XCTestCase {

    func testValidatesEmailAddresses() {
        let cases: [(email: String, expected: Bool)] = [
            ("user@example.com", true),
            ("invalid-email", false),
            ("user@.com", false),
            ("user+tag@example.com", true),
            ("", false)
        ]

        for testCase in cases {
            XCTAssertEqual(
                EmailValidator.isValid(testCase.email),
                testCase.expected,
                "Expected \(testCase.email) to be valid=\(testCase.expected)"
            )
        }
    }
}
```

### Async Testing

#### XCTest Async

```swift
final class SyncManagerTests: XCTestCase {

    func testSyncUploadsPendingChanges() async throws {
        let fakeRemote = FakeRemoteDataSource()
        let manager = SyncManager(remote: fakeRemote)

        manager.addPendingChange(Change(type: .update, recordId: "record-1"))
        try await manager.sync()

        XCTAssertEqual(fakeRemote.uploadedChanges.count, 1)
        XCTAssertEqual(fakeRemote.uploadedChanges[0].recordId, "record-1")
    }

    func testSyncRetriesOnTransientFailure() async throws {
        let fakeRemote = FakeRemoteDataSource()
        fakeRemote.failNextNTimes(2)
        let manager = SyncManager(remote: fakeRemote)

        manager.addPendingChange(Change(type: .update, recordId: "record-1"))
        try await manager.sync()

        XCTAssertEqual(fakeRemote.attemptCount, 3)
        XCTAssertEqual(fakeRemote.uploadedChanges.count, 1)
    }
}
```

#### Swift Testing Async

```swift
@Suite("SyncManager")
struct SyncManagerTests {

    @Test("Uploads pending changes")
    func syncUploads() async throws {
        let fakeRemote = FakeRemoteDataSource()
        let manager = SyncManager(remote: fakeRemote)

        manager.addPendingChange(Change(type: .update, recordId: "record-1"))
        try await manager.sync()

        #expect(fakeRemote.uploadedChanges.count == 1)
        #expect(fakeRemote.uploadedChanges[0].recordId == "record-1")
    }

    @Test("Retries on transient failure")
    func syncRetries() async throws {
        let fakeRemote = FakeRemoteDataSource()
        fakeRemote.failNextNTimes(2)
        let manager = SyncManager(remote: fakeRemote)

        manager.addPendingChange(Change(type: .update, recordId: "record-1"))
        try await manager.sync()

        #expect(fakeRemote.attemptCount == 3)
        #expect(fakeRemote.uploadedChanges.count == 1)
    }
}
```

## Assertion Mapping

| JUnit | XCTest | Swift Testing |
|---|---|---|
| `assertEquals(a, b)` | `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `assertNotEquals(a, b)` | `XCTAssertNotEqual(a, b)` | `#expect(a != b)` |
| `assertTrue(x)` | `XCTAssertTrue(x)` | `#expect(x)` |
| `assertFalse(x)` | `XCTAssertFalse(x)` | `#expect(!x)` |
| `assertNull(x)` | `XCTAssertNil(x)` | `#expect(x == nil)` |
| `assertNotNull(x)` | `XCTAssertNotNil(x)` | `#expect(x != nil)` |
| `assertThrows { }` | `XCTAssertThrowsError(try expr)` | `#expect(throws: E.self) { }` |
| `assertDoesNotThrow { }` | `XCTAssertNoThrow(try expr)` | `#expect(throws: Never.self) { }` |
| `assertThat(x, matcher)` | No built-in (use Nimble) | `#expect(x.property == val)` |
| `assertEquals(a, b, delta)` | `XCTAssertEqual(a, b, accuracy:)` | `#expect(abs(a - b) < delta)` |
| `assertArrayEquals(a, b)` | `XCTAssertEqual(a, b)` (works on arrays) | `#expect(a == b)` |
| `fail("msg")` | `XCTFail("msg")` | `Issue.record("msg")` |

## Test Lifecycle Mapping

### JUnit Rule to XCTest setUp

JUnit Rules have no direct iOS equivalent. Translate them into setUp/tearDown logic:

```kotlin
// Android: TemporaryFolder Rule
@get:Rule
val tempFolder = TemporaryFolder()

@Test
fun `writes to temp directory`() {
    val file = tempFolder.newFile("data.json")
    // ...
}
```

```swift
// iOS: Manual temp directory management
final class FileTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testWritesToTempDirectory() {
        let fileURL = tempDir.appendingPathComponent("data.json")
        // ...
    }
}
```

## Test Filtering and Organization

| Concept | Android | iOS (XCTest) | iOS (Swift Testing) |
|---|---|---|---|
| Run single test | `./gradlew test --tests "*.methodName"` | `xcodebuild -only-testing TestTarget/Class/method` | Same xcodebuild command |
| Run test class | `./gradlew test --tests "com.app.MyTest"` | `xcodebuild -only-testing TestTarget/Class` | Same xcodebuild command |
| Skip test | `@Ignore` / `@Disabled` | Prefix with `DISABLED_` or `XCTSkipIf` | `@Test(.disabled("reason"))` |
| Conditional skip | `assumeTrue(condition)` | `try XCTSkipIf(!condition)` | `@Test(.enabled(if: condition))` |
| Tag / category | `@Tag("slow")` | Test plans with schemes | `@Tag(.slow)` |
| Test timeout | `@Timeout(5, SECONDS)` | `executionTimeAllowance` in test plan | `@Test(.timeLimit(.minutes(1)))` |

## Common Pitfalls

1. **XCTest requires `test` prefix**: Methods must start with `test` or they will not run. Swift Testing uses `@Test` macro instead -- no prefix needed.

2. **XCTest class vs Swift Testing struct**: XCTest uses classes inheriting `XCTestCase`. Swift Testing uses structs annotated with `@Suite`. Do not mix them in the same file -- the runner can get confused.

3. **setUp is called per-test in XCTest**: `setUp()` runs before every test method, same as JUnit's `@Before`. Do not confuse with `class func setUp()` which runs once per class (like `@BeforeClass`).

4. **No `@Rule` equivalent**: Android test rules (InstantTaskExecutorRule, CoroutineTestRule) must be translated into manual setUp/tearDown. There is no automatic lifecycle extension mechanism in XCTest.

5. **Async tests in XCTest**: Mark the test method `async throws`. Do not use `waitForExpectations` for structured concurrency -- that pattern is for callback-based code only.

6. **Swift Testing requires Xcode 16+**: If your project must support Xcode 15, use XCTest exclusively. You can mix both frameworks in a project, but not in the same file.

7. **Floating point comparisons**: JUnit's `assertEquals(expected, actual, delta)` maps to `XCTAssertEqual(a, b, accuracy: delta)`. In Swift Testing, use `#expect(abs(a - b) < delta)`.

8. **Test execution order**: Both JUnit and XCTest do not guarantee test execution order by default. Do not rely on test ordering. Each test must be independent.

## Migration Checklist

- [ ] Decide framework: XCTest (Xcode 15+) or Swift Testing (Xcode 16+) or both
- [ ] Create test target in Xcode if it does not exist (File > New > Target > Unit Testing Bundle)
- [ ] Map `@Before` / `@BeforeEach` to `setUp()` (XCTest) or `init()` (Swift Testing)
- [ ] Map `@After` / `@AfterEach` to `tearDown()` (XCTest) or `deinit` (Swift Testing)
- [ ] Convert all assertions using the mapping table above
- [ ] Replace JUnit Rules with setUp/tearDown logic
- [ ] Convert `@Nested` classes to nested `@Suite` structs (Swift Testing) or separate test classes (XCTest)
- [ ] Convert `@ParameterizedTest` to `@Test(arguments:)` (Swift Testing) or manual loop (XCTest)
- [ ] Convert `runTest { }` coroutine tests to `async throws` test methods
- [ ] Convert `@Ignore` / `@Disabled` to `@Test(.disabled())` or `XCTSkipIf`
- [ ] Replace Kotlin backtick method names with camelCase (Swift does not allow backtick test names in XCTest)
- [ ] Ensure all test methods start with `test` prefix (XCTest only)
- [ ] Add `@testable import ModuleName` at the top of each test file
- [ ] Verify tests run in both Xcode and `xcodebuild` CLI
- [ ] Set up test plans for filtering/grouping if needed
