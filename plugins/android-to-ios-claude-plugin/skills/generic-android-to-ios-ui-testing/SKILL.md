---
name: generic-android-to-ios-ui-testing
description: Guides migration of Android UI testing patterns (Espresso with onView, ViewMatchers, ViewActions, ViewAssertions, IdlingResource) to iOS equivalents (XCUITest with XCUIApplication, XCUIElement, queries, actions, expectations, waitForExistence), covering element finding, actions, assertions, synchronization, test recording, and accessibility-based testing
type: generic
---

# generic-android-to-ios-ui-testing

## Context

Android UI testing relies on Espresso, which runs in-process and automatically synchronizes with the UI thread. iOS UI testing uses XCUITest, which runs as a separate process and communicates with the app via accessibility. This architectural difference means migration is not a 1:1 translation -- you must understand how XCUITest discovers elements, waits for state, and interacts with the app from the outside.

## Quick Reference: API Mapping

| Espresso | XCUITest |
|---|---|
| `onView(withId(R.id.button))` | `app.buttons["buttonIdentifier"]` |
| `onView(withText("Submit"))` | `app.buttons["Submit"]` or `app.staticTexts["Submit"]` |
| `onView(withContentDescription("Close"))` | `app.buttons["Close"]` (accessibility label) |
| `.perform(click())` | `.tap()` |
| `.perform(typeText("hello"))` | `.typeText("hello")` |
| `.perform(replaceText("new"))` | `.tap()` then `.typeText("new")` (clear first) |
| `.perform(scrollTo())` | `.swipeUp()` or element is auto-scrolled |
| `.perform(swipeLeft())` | `.swipeLeft()` |
| `.perform(longClick())` | `.press(forDuration: 1.0)` |
| `.check(matches(isDisplayed()))` | `XCTAssertTrue(element.exists)` |
| `.check(matches(withText("OK")))` | `XCTAssertEqual(element.label, "OK")` |
| `.check(matches(isEnabled()))` | `XCTAssertTrue(element.isEnabled)` |
| `.check(matches(isChecked()))` | `XCTAssertEqual(element.value as? String, "1")` |
| `.check(doesNotExist())` | `XCTAssertFalse(element.exists)` |
| `onData(...)` (AdapterView) | No equivalent (flat element tree) |
| `IdlingResource` | `waitForExistence(timeout:)` / `XCTNSPredicateExpectation` |
| `intended(hasComponent(...))` | Verify element on next screen |
| `Intents.init()` / `Intents.release()` | N/A |

## Android Source Patterns

### Basic Espresso Test

```kotlin
@RunWith(AndroidJUnit4::class)
class LoginScreenTest {

    @get:Rule
    val activityRule = ActivityScenarioRule(LoginActivity::class.java)

    @Test
    fun loginWithValidCredentials_navigatesToHome() {
        onView(withId(R.id.emailInput))
            .perform(typeText("user@example.com"), closeSoftKeyboard())

        onView(withId(R.id.passwordInput))
            .perform(typeText("password123"), closeSoftKeyboard())

        onView(withId(R.id.loginButton))
            .perform(click())

        onView(withId(R.id.welcomeText))
            .check(matches(withText("Welcome back!")))
    }

    @Test
    fun loginWithEmptyEmail_showsError() {
        onView(withId(R.id.loginButton))
            .perform(click())

        onView(withId(R.id.emailError))
            .check(matches(isDisplayed()))
            .check(matches(withText("Email is required")))
    }

    @Test
    fun loginButton_isDisabledInitially() {
        onView(withId(R.id.loginButton))
            .check(matches(not(isEnabled())))
    }
}
```

### Espresso with RecyclerView

```kotlin
@Test
fun recyclerView_displaysItems() {
    onView(withId(R.id.recyclerView))
        .check(matches(isDisplayed()))

    onView(withId(R.id.recyclerView))
        .perform(
            RecyclerViewActions.actionOnItemAtPosition<ViewHolder>(
                0, click()
            )
        )

    onView(withId(R.id.detailTitle))
        .check(matches(isDisplayed()))
}

@Test
fun recyclerView_scrollsToItem() {
    onView(withId(R.id.recyclerView))
        .perform(
            RecyclerViewActions.scrollTo<ViewHolder>(
                hasDescendant(withText("Item 50"))
            )
        )
}
```

### Espresso with IdlingResource

```kotlin
class NetworkIdlingResource : IdlingResource {
    private var callback: IdlingResource.ResourceCallback? = null
    private var isIdle = true

    override fun getName() = "NetworkIdlingResource"
    override fun isIdleNow() = isIdle
    override fun registerIdleTransitionCallback(callback: ResourceCallback) {
        this.callback = callback
    }

    fun setIdle(idle: Boolean) {
        isIdle = idle
        if (idle) callback?.onTransitionToIdle()
    }
}

@RunWith(AndroidJUnit4::class)
class SearchScreenTest {
    private val idlingResource = NetworkIdlingResource()

    @Before
    fun setUp() {
        IdlingRegistry.getInstance().register(idlingResource)
    }

    @After
    fun tearDown() {
        IdlingRegistry.getInstance().unregister(idlingResource)
    }

    @Test
    fun search_displaysResults() {
        onView(withId(R.id.searchInput))
            .perform(typeText("kotlin"), closeSoftKeyboard())

        onView(withId(R.id.searchButton))
            .perform(click())

        // Espresso waits for idling resource automatically
        onView(withId(R.id.resultsList))
            .check(matches(isDisplayed()))
    }
}
```

### Espresso Intents

```kotlin
@RunWith(AndroidJUnit4::class)
class ShareTest {
    @get:Rule
    val intentsRule = IntentsTestRule(DetailActivity::class.java)

    @Test
    fun shareButton_launchesShareIntent() {
        onView(withId(R.id.shareButton))
            .perform(click())

        intended(allOf(
            hasAction(Intent.ACTION_SEND),
            hasType("text/plain"),
            hasExtra(Intent.EXTRA_TEXT, containsString("Check this out"))
        ))
    }
}
```

## iOS Target Patterns

### XCUITest: Basic Test (Equivalent to Espresso Login)

```swift
import XCTest

final class LoginScreenTests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launch()
    }

    func testLoginWithValidCredentials_navigatesToHome() {
        let emailField = app.textFields["emailInput"]
        emailField.tap()
        emailField.typeText("user@example.com")

        let passwordField = app.secureTextFields["passwordInput"]
        passwordField.tap()
        passwordField.typeText("password123")

        app.buttons["loginButton"].tap()

        let welcomeText = app.staticTexts["Welcome back!"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 5))
    }

    func testLoginWithEmptyEmail_showsError() {
        app.buttons["loginButton"].tap()

        let errorLabel = app.staticTexts["Email is required"]
        XCTAssertTrue(errorLabel.waitForExistence(timeout: 2))
    }

    func testLoginButton_isDisabledInitially() {
        let loginButton = app.buttons["loginButton"]
        XCTAssertFalse(loginButton.isEnabled)
    }
}
```

### XCUITest: Lists and Scrolling (Equivalent to RecyclerView)

```swift
func testList_displaysItems() {
    let table = app.tables["itemsList"]  // or app.collectionViews["itemsList"]
    XCTAssertTrue(table.waitForExistence(timeout: 5))

    let firstCell = table.cells.element(boundBy: 0)
    XCTAssertTrue(firstCell.exists)
    firstCell.tap()

    let detailTitle = app.staticTexts["detailTitle"]
    XCTAssertTrue(detailTitle.waitForExistence(timeout: 3))
}

func testList_scrollsToItem() {
    let table = app.tables["itemsList"]

    // Scroll until the element is found
    let targetCell = table.cells.staticTexts["Item 50"]
    while !targetCell.exists {
        table.swipeUp()
    }

    XCTAssertTrue(targetCell.exists)
}

// More robust scrolling with a limit
func scrollToElement(_ element: XCUIElement, in scrollView: XCUIElement, maxSwipes: Int = 10) {
    var swipeCount = 0
    while !element.isHittable && swipeCount < maxSwipes {
        scrollView.swipeUp()
        swipeCount += 1
    }
}
```

### XCUITest: Waiting and Synchronization (Equivalent to IdlingResource)

```swift
final class SearchScreenTests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launch()
    }

    // Simple wait: waitForExistence
    func testSearch_displaysResults() {
        let searchField = app.searchFields["searchInput"]
        searchField.tap()
        searchField.typeText("swift")

        app.buttons["searchButton"].tap()

        // Wait for results to appear (replaces IdlingResource)
        let resultsList = app.tables["resultsList"]
        XCTAssertTrue(resultsList.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(resultsList.cells.count, 0)
    }

    // Predicate-based wait for complex conditions
    func testLoadingIndicator_disappearsAfterLoad() {
        app.buttons["loadButton"].tap()

        let spinner = app.activityIndicators["loadingSpinner"]
        XCTAssertTrue(spinner.waitForExistence(timeout: 2))

        // Wait for spinner to disappear
        let notExistsPredicate = NSPredicate(format: "exists == false")
        let expectation = expectation(for: notExistsPredicate, evaluatedWith: spinner)
        wait(for: [expectation], timeout: 10)
    }

    // Wait for element property to change
    func testButton_becomesEnabledAfterInput() {
        let emailField = app.textFields["emailInput"]
        emailField.tap()
        emailField.typeText("user@example.com")

        let submitButton = app.buttons["submitButton"]
        let enabledPredicate = NSPredicate(format: "isEnabled == true")
        let expectation = expectation(for: enabledPredicate, evaluatedWith: submitButton)
        wait(for: [expectation], timeout: 5)
    }
}
```

### XCUITest: Element Queries Deep Dive

```swift
// Finding elements by accessibility identifier (preferred)
let button = app.buttons["myButtonId"]

// Finding by label text
let label = app.staticTexts["Hello World"]

// Finding by index
let firstCell = app.tables.cells.element(boundBy: 0)

// Finding descendants
let cellLabel = app.tables.cells.element(boundBy: 0).staticTexts["itemTitle"]

// Finding by predicate
let matchingButtons = app.buttons.matching(
    NSPredicate(format: "label CONTAINS 'Delete'")
)

// Counting elements
XCTAssertEqual(app.tables.cells.count, 5)

// Checking element properties
let element = app.buttons["submit"]
XCTAssertTrue(element.exists)
XCTAssertTrue(element.isHittable) // visible and tappable
XCTAssertTrue(element.isEnabled)
XCTAssertEqual(element.label, "Submit")
XCTAssertEqual(element.value as? String, "selected") // for switches, sliders
```

### XCUITest: Common Interactions

```swift
// Text input
let textField = app.textFields["nameInput"]
textField.tap()
textField.typeText("John Doe")

// Clear and retype
textField.tap()
textField.press(forDuration: 1.2)  // long press to select all
app.menuItems["Select All"].tap()
textField.typeText("") // or use delete key
textField.typeText("Jane Doe")

// Clear text field helper
func clearAndType(_ element: XCUIElement, text: String) {
    element.tap()
    guard let currentValue = element.value as? String, !currentValue.isEmpty else {
        element.typeText(text)
        return
    }
    let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
    element.typeText(deleteString)
    element.typeText(text)
}

// Switches
let toggle = app.switches["notificationsToggle"]
toggle.tap() // toggles state

// Pickers
let picker = app.pickers["datePicker"]
picker.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "March")

// Alerts
let alert = app.alerts["Error"]
XCTAssertTrue(alert.waitForExistence(timeout: 3))
alert.buttons["OK"].tap()

// Sheets / Action sheets
let sheet = app.sheets.firstMatch
sheet.buttons["Delete"].tap()

// Pull to refresh
app.tables.firstMatch.swipeDown()

// Navigation back
app.navigationBars.buttons.element(boundBy: 0).tap()

// Tab bar
app.tabBars.buttons["Profile"].tap()
```

### Setting Accessibility Identifiers in SwiftUI

XCUITest finds elements through the accessibility tree. Set identifiers in your production code:

```swift
// SwiftUI
struct LoginView: View {
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack {
            TextField("Email", text: $email)
                .accessibilityIdentifier("emailInput")

            SecureField("Password", text: $password)
                .accessibilityIdentifier("passwordInput")

            Button("Log In") { /* ... */ }
                .accessibilityIdentifier("loginButton")
        }
    }
}

// UIKit
emailTextField.accessibilityIdentifier = "emailInput"
passwordTextField.accessibilityIdentifier = "passwordInput"
loginButton.accessibilityIdentifier = "loginButton"
```

### XCUITest: Launch Arguments and Environment

```swift
// Pass flags to the app for test configuration (like Android test instrumentation args)
override func setUp() {
    super.setUp()
    app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-state"]
    app.launchEnvironment = [
        "API_BASE_URL": "http://localhost:8080",
        "DISABLE_ANIMATIONS": "1"
    ]
    app.launch()
}

// In the app, check for test mode
// AppDelegate or @main
if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
    // Use mock services
}

if ProcessInfo.processInfo.environment["DISABLE_ANIMATIONS"] == "1" {
    UIView.setAnimationsEnabled(false)
}
```

### XCUITest: Screenshots and Attachments

```swift
func testCheckout_completesSuccessfully() {
    // Take screenshot at a point in time
    let screenshot = app.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = "Checkout Screen"
    attachment.lifetime = .keepAlways
    add(attachment)

    app.buttons["checkoutButton"].tap()

    // Automatic screenshot on failure is built in
}
```

## Synchronization: Espresso vs XCUITest

Espresso automatically waits for the UI thread and registered IdlingResources. XCUITest does NOT auto-wait -- you must explicitly handle timing.

**Pattern: Replace IdlingResource with waitForExistence**

```swift
// Instead of registering an IdlingResource, wait for the expected outcome:
let element = app.staticTexts["resultsLoaded"]
let appeared = element.waitForExistence(timeout: 10)
XCTAssertTrue(appeared, "Results did not load within 10 seconds")
```

**Pattern: Polling wait for complex conditions**

```swift
func waitForCondition(timeout: TimeInterval = 10, condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    XCTAssertTrue(condition(), "Condition not met within \(timeout)s")
}

// Usage
waitForCondition {
    app.tables.cells.count >= 5
}
```

## Common Pitfalls

1. **XCUITest runs out-of-process**: Unlike Espresso, XCUITest cannot access app internals (databases, view models, dependency containers). You interact only through the accessibility tree. Design test hooks via launch arguments / environment variables.

2. **No automatic synchronization**: Espresso waits for the main thread and registered IdlingResources. XCUITest does not. Always use `waitForExistence(timeout:)` or predicate expectations after actions that trigger async work.

3. **Accessibility identifiers are required**: Espresso can find views by resource ID (`R.id.xxx`). XCUITest finds elements by accessibility identifier, label, or type. Set `.accessibilityIdentifier()` on all testable elements.

4. **Element queries are evaluated lazily**: `app.buttons["foo"]` creates a query, not a resolved element. It is evaluated when you access `.exists`, `.tap()`, etc. This means the query can match a different element if the UI changes.

5. **Keyboard handling**: XCUITest sometimes needs the software keyboard. In the simulator, ensure Hardware > Keyboard > Connect Hardware Keyboard is unchecked for `typeText()` to work reliably.

6. **Flaky tests from animation**: Disable animations in UI tests via launch environment or `UIView.setAnimationsEnabled(false)` in the app's test setup.

7. **No equivalent to Espresso Intents**: XCUITest cannot intercept or verify system intents. Verify navigation results (the destination screen appeared) rather than the intent itself.

8. **Test data reset**: Unlike Android where you can clear app data easily, iOS simulators persist state. Use launch arguments to trigger a reset in the app, or call `springboardApp.terminate()` patterns.

## Migration Checklist

- [ ] Create UI Test target in Xcode (File > New > Target > UI Testing Bundle)
- [ ] Add accessibility identifiers to all interactive elements in production code
- [ ] Replace `ActivityScenarioRule` with `XCUIApplication().launch()` in setUp
- [ ] Convert `onView(withId(...))` to `app.elementType["identifier"]` queries
- [ ] Convert `onView(withText(...))` to `app.staticTexts["text"]` or label-based queries
- [ ] Replace `.perform(click())` with `.tap()`
- [ ] Replace `.perform(typeText(...))` with `.typeText(...)`
- [ ] Replace `.check(matches(isDisplayed()))` with `XCTAssertTrue(element.exists)`
- [ ] Replace IdlingResource with `waitForExistence(timeout:)` or predicate expectations
- [ ] Replace RecyclerViewActions with table/collection cell queries and swipe-to-scroll
- [ ] Replace Espresso Intents verification with destination screen assertions
- [ ] Add launch arguments for test configuration (mock services, disable animations)
- [ ] Set `continueAfterFailure = false` in setUp for fail-fast behavior
- [ ] Test on multiple simulator sizes to catch layout issues
- [ ] Set up CI with `xcodebuild test` pointing to the UI test target
