---
name: generic-android-to-ios-compose-testing
description: Guides migration of Android Compose UI testing patterns (composeTestRule, onNodeWithText, performClick, semantic trees, test tags) to iOS SwiftUI testing equivalents (ViewInspector for unit tests, XCUITest for integration, swift-snapshot-testing), covering semantic-based testing, snapshot testing, interaction testing, accessibility testing, and test architecture
type: generic
---

# generic-android-to-ios-compose-testing

## Context

Android Jetpack Compose has first-class testing support through the `compose-ui-test` library, which uses the semantic tree to find, interact with, and assert on composable nodes. SwiftUI has no equivalent first-party testing API. The iOS ecosystem relies on three approaches: (1) XCUITest for integration/end-to-end tests via the accessibility tree, (2) ViewInspector (third-party) for unit-level view introspection, and (3) swift-snapshot-testing for visual regression. This skill maps Compose testing patterns to the best available iOS equivalents.

## Quick Reference: API Mapping

| Compose Test | iOS Equivalent | Approach |
|---|---|---|
| `composeTestRule.setContent { }` | ViewInspector: `let view = MyView(); try view.inspect()` | Unit test |
| `onNodeWithText("Hello")` | ViewInspector: `view.find(text: "Hello")` | Unit test |
| `onNodeWithTag("myTag")` | XCUITest: `app.otherElements["myTag"]` | Integration test |
| `onNodeWithContentDescription("Close")` | XCUITest: `app.buttons["Close"]` | Integration test |
| `.performClick()` | ViewInspector: `try button.tap()` / XCUITest: `.tap()` | Depends on level |
| `.performTextInput("text")` | XCUITest: `.typeText("text")` | Integration test |
| `.performScrollTo()` | XCUITest: `.swipeUp()` | Integration test |
| `.assertIsDisplayed()` | ViewInspector: element exists / XCUITest: `.exists` | Depends |
| `.assertTextEquals("text")` | ViewInspector: `try text.string()` | Unit test |
| `.assertIsEnabled()` | XCUITest: `.isEnabled` | Integration test |
| `.assertHasClickAction()` | ViewInspector: check for Button type | Unit test |
| `onAllNodesWithText(...)` | ViewInspector: `view.findAll(text: ...)` | Unit test |
| `printToLog("TAG")` | ViewInspector: `print(try view.inspect())` | Unit test |
| Snapshot comparison | swift-snapshot-testing: `assertSnapshot(of:)` | Snapshot test |

## Android Source Patterns

### Basic Compose Test

```kotlin
@get:Rule
val composeTestRule = createComposeRule()

@Test
fun greeting_displaysUserName() {
    composeTestRule.setContent {
        GreetingCard(userName = "Alice")
    }

    composeTestRule
        .onNodeWithText("Hello, Alice!")
        .assertIsDisplayed()
}

@Test
fun loginForm_buttonDisabled_whenEmailEmpty() {
    composeTestRule.setContent {
        LoginForm(onLogin = {})
    }

    composeTestRule
        .onNodeWithTag("loginButton")
        .assertIsNotEnabled()
}

@Test
fun loginForm_callsOnLogin_withCredentials() {
    var capturedEmail = ""
    composeTestRule.setContent {
        LoginForm(onLogin = { email, _ -> capturedEmail = email })
    }

    composeTestRule
        .onNodeWithTag("emailField")
        .performTextInput("user@example.com")

    composeTestRule
        .onNodeWithTag("passwordField")
        .performTextInput("password")

    composeTestRule
        .onNodeWithTag("loginButton")
        .performClick()

    assertEquals("user@example.com", capturedEmail)
}
```

### Compose Test with State and Interactions

```kotlin
@Test
fun counter_incrementsOnClick() {
    composeTestRule.setContent {
        CounterScreen()
    }

    composeTestRule
        .onNodeWithText("Count: 0")
        .assertIsDisplayed()

    composeTestRule
        .onNodeWithTag("incrementButton")
        .performClick()

    composeTestRule
        .onNodeWithText("Count: 1")
        .assertIsDisplayed()
}

@Test
fun todoList_addsItem() {
    composeTestRule.setContent {
        TodoListScreen()
    }

    composeTestRule
        .onNodeWithTag("todoInput")
        .performTextInput("Buy groceries")

    composeTestRule
        .onNodeWithTag("addButton")
        .performClick()

    composeTestRule
        .onNodeWithText("Buy groceries")
        .assertIsDisplayed()

    composeTestRule
        .onAllNodesWithTag("todoItem")
        .assertCountEquals(1)
}
```

### Compose Test Tags and Semantics

```kotlin
// In production code
@Composable
fun ProfileCard(user: User) {
    Column(modifier = Modifier.testTag("profileCard")) {
        Text(
            text = user.name,
            modifier = Modifier.testTag("userName")
        )
        Text(
            text = user.email,
            modifier = Modifier.semantics { contentDescription = "User email: ${user.email}" }
        )
        if (user.isVerified) {
            Icon(
                imageVector = Icons.Default.Verified,
                contentDescription = "Verified badge",
                modifier = Modifier.testTag("verifiedBadge")
            )
        }
    }
}

// In test
@Test
fun profileCard_showsVerifiedBadge_forVerifiedUser() {
    composeTestRule.setContent {
        ProfileCard(user = User("Alice", "alice@example.com", isVerified = true))
    }

    composeTestRule.onNodeWithTag("verifiedBadge").assertIsDisplayed()
    composeTestRule.onNodeWithTag("userName").assertTextEquals("Alice")
}

@Test
fun profileCard_hidesVerifiedBadge_forUnverifiedUser() {
    composeTestRule.setContent {
        ProfileCard(user = User("Bob", "bob@example.com", isVerified = false))
    }

    composeTestRule.onNodeWithTag("verifiedBadge").assertDoesNotExist()
}
```

### Compose LazyList Testing

```kotlin
@Test
fun lazyColumn_displaysAllItems() {
    val items = (1..50).map { "Item $it" }

    composeTestRule.setContent {
        ItemList(items = items)
    }

    // First item visible
    composeTestRule
        .onNodeWithText("Item 1")
        .assertIsDisplayed()

    // Scroll to last item
    composeTestRule
        .onNodeWithTag("itemList")
        .performScrollToIndex(49)

    composeTestRule
        .onNodeWithText("Item 50")
        .assertIsDisplayed()
}
```

### Compose Async and Animation Testing

```kotlin
@Test
fun loadingScreen_showsContent_afterDelay() {
    composeTestRule.setContent {
        DataScreen(viewModel = FakeViewModel())
    }

    composeTestRule
        .onNodeWithTag("loadingIndicator")
        .assertIsDisplayed()

    // Advance time for coroutines
    composeTestRule.mainClock.advanceTimeBy(2000)

    composeTestRule
        .onNodeWithTag("loadingIndicator")
        .assertDoesNotExist()

    composeTestRule
        .onNodeWithTag("dataContent")
        .assertIsDisplayed()
}
```

## iOS Target Patterns

### Approach 1: ViewInspector for Unit-Level Testing

ViewInspector is a third-party library that allows inspecting SwiftUI view hierarchies in unit tests, similar to Compose's semantic tree testing.

**Setup:** Add `ViewInspector` via SPM: `https://github.com/nicklama/ViewInspector`

```swift
import XCTest
import ViewInspector
@testable import MyApp

final class GreetingCardTests: XCTestCase {

    func testGreeting_displaysUserName() throws {
        let view = GreetingCard(userName: "Alice")
        let text = try view.inspect().find(text: "Hello, Alice!")
        XCTAssertEqual(try text.string(), "Hello, Alice!")
    }
}
```

### ViewInspector: Form Testing (Equivalent to Compose Form Test)

```swift
import XCTest
import ViewInspector
@testable import MyApp

final class LoginFormTests: XCTestCase {

    func testLoginForm_callsOnLogin_withCredentials() throws {
        var capturedEmail = ""
        let view = LoginForm(onLogin: { email, _ in capturedEmail = email })

        // ViewInspector requires async inspection for @State changes
        let exp = view.on(\.didAppear) { view in
            let emailField = try view.find(viewWithAccessibilityIdentifier: "emailField")
            try emailField.setInput("user@example.com")

            let loginButton = try view.find(button: "Log In")
            try loginButton.tap()

            XCTAssertEqual(capturedEmail, "user@example.com")
        }
        ViewHosting.host(view: view)
        wait(for: [exp], timeout: 1)
    }
}
```

### ViewInspector: Conditional Rendering (Equivalent to Compose assertDoesNotExist)

```swift
final class ProfileCardTests: XCTestCase {

    func testProfileCard_showsVerifiedBadge_forVerifiedUser() throws {
        let user = User(name: "Alice", email: "alice@example.com", isVerified: true)
        let view = ProfileCard(user: user)

        XCTAssertNoThrow(try view.inspect().find(viewWithAccessibilityIdentifier: "verifiedBadge"))
    }

    func testProfileCard_hidesVerifiedBadge_forUnverifiedUser() throws {
        let user = User(name: "Bob", email: "bob@example.com", isVerified: false)
        let view = ProfileCard(user: user)

        XCTAssertThrowsError(try view.inspect().find(viewWithAccessibilityIdentifier: "verifiedBadge"))
    }

    func testProfileCard_displaysUserName() throws {
        let user = User(name: "Alice", email: "alice@example.com", isVerified: false)
        let view = ProfileCard(user: user)

        let nameText = try view.inspect().find(text: "Alice")
        XCTAssertEqual(try nameText.string(), "Alice")
    }
}
```

### Approach 2: XCUITest for Integration Testing

Use XCUITest when you need to test full user flows, navigation, and system integration -- similar to using Compose testing with `createAndroidComposeRule<Activity>()`.

```swift
import XCTest

final class CounterScreenUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launch()
    }

    func testCounter_incrementsOnClick() {
        XCTAssertTrue(app.staticTexts["Count: 0"].exists)

        app.buttons["incrementButton"].tap()

        XCTAssertTrue(app.staticTexts["Count: 1"].exists)
    }
}

final class TodoListUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launchArguments = ["--reset-state"]
        app.launch()
    }

    func testTodoList_addsItem() {
        let input = app.textFields["todoInput"]
        input.tap()
        input.typeText("Buy groceries")

        app.buttons["addButton"].tap()

        XCTAssertTrue(app.staticTexts["Buy groceries"].waitForExistence(timeout: 2))
    }
}
```

### Setting Test Identifiers in SwiftUI (Equivalent to Modifier.testTag)

```swift
// SwiftUI production code
struct ProfileCard: View {
    let user: User

    var body: some View {
        VStack {
            Text(user.name)
                .accessibilityIdentifier("userName")

            Text(user.email)
                .accessibilityLabel("User email: \(user.email)")

            if user.isVerified {
                Image(systemName: "checkmark.seal.fill")
                    .accessibilityIdentifier("verifiedBadge")
                    .accessibilityLabel("Verified badge")
            }
        }
        .accessibilityIdentifier("profileCard")
    }
}

struct TodoListScreen: View {
    @State private var items: [String] = []
    @State private var newItem = ""

    var body: some View {
        VStack {
            HStack {
                TextField("New todo", text: $newItem)
                    .accessibilityIdentifier("todoInput")

                Button("Add") {
                    items.append(newItem)
                    newItem = ""
                }
                .accessibilityIdentifier("addButton")
            }

            List(items, id: \.self) { item in
                Text(item)
                    .accessibilityIdentifier("todoItem")
            }
        }
    }
}
```

### Approach 3: Snapshot Testing (Visual Regression)

swift-snapshot-testing provides pixel-perfect comparison, which complements semantic testing.

**Setup:** Add `swift-snapshot-testing` via SPM: `https://github.com/pointfreeco/swift-snapshot-testing`

```swift
import XCTest
import SnapshotTesting
@testable import MyApp

final class ProfileCardSnapshotTests: XCTestCase {

    func testProfileCard_verifiedUser() {
        let view = ProfileCard(user: User(name: "Alice", email: "alice@example.com", isVerified: true))

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 375, height: 200))
        )
    }

    func testProfileCard_unverifiedUser() {
        let view = ProfileCard(user: User(name: "Bob", email: "bob@example.com", isVerified: false))

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 375, height: 200))
        )
    }

    // Test dark mode
    func testProfileCard_darkMode() {
        let view = ProfileCard(user: User(name: "Alice", email: "alice@example.com", isVerified: true))
            .environment(\.colorScheme, .dark)

        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 375, height: 200)),
            named: "dark"
        )
    }

    // Test multiple device sizes
    func testProfileCard_iPhone_SE() {
        let view = ProfileCard(user: User(name: "Alice", email: "alice@example.com", isVerified: true))

        assertSnapshot(
            of: view,
            as: .image(layout: .device(config: .iPhoneSe)),
            named: "iPhone_SE"
        )
    }

    func testProfileCard_iPadPro() {
        let view = ProfileCard(user: User(name: "Alice", email: "alice@example.com", isVerified: true))

        assertSnapshot(
            of: view,
            as: .image(layout: .device(config: .iPadPro12_9)),
            named: "iPad_Pro"
        )
    }
}
```

### Snapshot Testing: Recording and Updating

```swift
// First run: record reference snapshots
// Set this to true, run tests, then set back to false
// isRecording = true  // in setUp or per-test

override func setUp() {
    super.setUp()
    // Uncomment to re-record all snapshots in this class:
    // isRecording = true
}

// Or record a single test:
func testNewComponent_snapshot() {
    let view = NewComponent()
    assertSnapshot(of: view, as: .image(layout: .fixed(width: 375, height: 100)), record: true)
}
```

## Accessibility Testing

### Compose Accessibility Testing

```kotlin
@Test
fun profileCard_hasCorrectSemantics() {
    composeTestRule.setContent {
        ProfileCard(user = User("Alice", "alice@example.com", isVerified = true))
    }

    composeTestRule
        .onNodeWithContentDescription("Verified badge")
        .assertIsDisplayed()

    composeTestRule
        .onNodeWithContentDescription("User email: alice@example.com")
        .assertIsDisplayed()
}
```

### iOS Accessibility Testing (XCUITest)

```swift
func testProfileCard_hasCorrectAccessibility() {
    let verifiedBadge = app.images["Verified badge"]
    XCTAssertTrue(verifiedBadge.exists)

    let emailElement = app.staticTexts.matching(
        NSPredicate(format: "label CONTAINS 'User email'")
    ).firstMatch
    XCTAssertTrue(emailElement.exists)
}

// Accessibility audit (Xcode 15+)
func testProfileCard_passesAccessibilityAudit() throws {
    try app.performAccessibilityAudit()
}

// Targeted audit
func testProfileCard_passesContrastAudit() throws {
    try app.performAccessibilityAudit(for: [.contrast])
}
```

## Test Architecture Comparison

| Compose | iOS | When to Use |
|---|---|---|
| `createComposeRule()` + setContent | ViewInspector `inspect()` | Unit-test individual views in isolation |
| `createAndroidComposeRule<Activity>()` | XCUITest `XCUIApplication` | Full integration tests with navigation |
| Screenshot testing libraries | swift-snapshot-testing | Visual regression, multi-device checks |
| Semantic tree assertions | ViewInspector tree queries | Testing view structure and content |
| `composeTestRule.mainClock` | Manual async waits | Testing time-dependent behavior |

## Recommended iOS Testing Strategy

```
Test Pyramid for SwiftUI:

                  /\
                 /  \     XCUITest (E2E flows)
                /    \    - Critical user journeys
               /------\   - Navigation flows
              /        \
             /          \  Snapshot Tests
            /            \ - Visual regression
           /   Unit Tests  \ - Device/theme variants
          /                 \
         /  ViewInspector    \  - View logic
        /  ViewModel Tests    \ - State management
       /  Domain Logic Tests   \- Business rules
      /__________________________\
```

## Common Pitfalls

1. **No first-party SwiftUI view testing API**: Apple does not provide a Compose-test equivalent. ViewInspector is community-maintained and may lag behind new SwiftUI features. Always have XCUITest as a fallback.

2. **ViewInspector limitations**: It cannot test animations, gesture recognizers, or complex view modifiers. Use it for structure and content assertions, not visual behavior.

3. **Compose testTag vs accessibilityIdentifier**: Compose's `testTag` is specifically for testing and does not affect accessibility. SwiftUI's `accessibilityIdentifier` serves both purposes. Be mindful that identifiers you add for testing are visible to accessibility tools.

4. **No mainClock equivalent**: Compose tests can advance virtual time with `mainClock.advanceTimeBy()`. In iOS, you must either use dependency injection to control time (injecting a `Clock` protocol) or use real async waits.

5. **Snapshot test brittleness**: Snapshot tests are sensitive to OS version, simulator type, and font rendering. Pin your CI to a specific Xcode version and simulator. Store reference images in version control.

6. **ViewInspector requires `Inspectable` conformance for custom views**: If you use `@ViewBuilder` heavily or complex generic views, ViewInspector may need explicit type annotations to traverse the hierarchy.

7. **SwiftUI previews are not tests**: Xcode Previews are useful for development but do not replace automated tests. They do not run assertions and are not executed in CI.

8. **State changes in ViewInspector need async inspection**: You cannot test `@State` mutations synchronously in ViewInspector. Use the `on(\.didAppear)` or `on(\.didDisappear)` pattern with `ViewHosting.host(view:)`.

## Migration Checklist

- [ ] Audit Compose tests and categorize: unit (semantic), integration (activity-based), screenshot
- [ ] Add `ViewInspector` via SPM for unit-level view testing
- [ ] Add `swift-snapshot-testing` via SPM for visual regression testing
- [ ] Map `Modifier.testTag("x")` to `.accessibilityIdentifier("x")` in SwiftUI views
- [ ] Convert `composeTestRule.setContent { }` tests to ViewInspector `inspect()` tests
- [ ] Convert `onNodeWithText/Tag` to ViewInspector `find(text:)` / `find(viewWithAccessibilityIdentifier:)`
- [ ] Convert `performClick()` to ViewInspector `tap()` or XCUITest `.tap()`
- [ ] Convert `assertIsDisplayed()` / `assertDoesNotExist()` to appropriate existence checks
- [ ] Convert `assertTextEquals()` to ViewInspector `string()` comparison
- [ ] Convert activity-based Compose tests to XCUITest integration tests
- [ ] Set up snapshot reference images for key screens (light mode, dark mode, device sizes)
- [ ] Replace `mainClock.advanceTimeBy()` with injectable time dependencies or async waits
- [ ] Add `accessibilityIdentifier` to all testable SwiftUI elements
- [ ] Implement `performAccessibilityAudit()` tests (Xcode 15+)
- [ ] Pin CI to specific Xcode version and simulator for snapshot stability
- [ ] Decide on ViewInspector vs XCUITest boundary: use ViewInspector for view logic, XCUITest for user flows
