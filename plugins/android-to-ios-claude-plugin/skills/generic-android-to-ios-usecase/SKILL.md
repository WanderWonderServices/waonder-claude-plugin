---
name: generic-android-to-ios-usecase
description: Guides migration of Android Use Case / Interactor patterns (operator() convention, coroutine-based, single-responsibility) to iOS equivalents (Swift protocols, async/await, Combine pipelines) with composability and testability strategies
type: generic
---

# generic-android-to-ios-usecase

## Context

Use Cases (also called Interactors) encapsulate a single business operation in Clean Architecture. On Android, they follow a convention of overriding `operator fun invoke()` so they can be called like functions, run on coroutine dispatchers, and compose together. On iOS, the same pattern maps to Swift protocols with an `execute` method (or `callAsFunction` for the Kotlin `invoke` feel), using `async/await` for suspension and `AsyncSequence` for streaming results. This skill provides the complete mapping for migrating Android Use Cases to idiomatic Swift.

## Android Best Practices (Source Patterns)

### Simple Use Case (One-Shot)

```kotlin
class GetUserUseCase @Inject constructor(
    private val userRepository: UserRepository,
    private val dispatchers: DispatcherProvider
) {
    suspend operator fun invoke(userId: String): Result<User> {
        return withContext(dispatchers.io) {
            userRepository.getUser(userId)
        }
    }
}
```

### Streaming Use Case (Flow-Based)

```kotlin
class ObserveUserUseCase @Inject constructor(
    private val userRepository: UserRepository
) {
    operator fun invoke(userId: String): Flow<User> {
        return userRepository.observeUser(userId)
    }
}
```

### Parameterized Use Case with Validation

```kotlin
class CreateOrderUseCase @Inject constructor(
    private val orderRepository: OrderRepository,
    private val inventoryRepository: InventoryRepository,
    private val dispatchers: DispatcherProvider
) {
    suspend operator fun invoke(params: Params): Result<Order> {
        return withContext(dispatchers.io) {
            runCatching {
                require(params.items.isNotEmpty()) { "Order must contain items" }
                require(params.items.all { it.quantity > 0 }) { "Quantities must be positive" }

                // Check inventory availability
                params.items.forEach { item ->
                    val available = inventoryRepository.checkStock(item.productId)
                    if (available < item.quantity) {
                        throw InsufficientStockException(item.productId, available, item.quantity)
                    }
                }

                orderRepository.createOrder(params.toOrder())
            }
        }
    }

    data class Params(
        val items: List<OrderItem>,
        val shippingAddress: Address,
        val paymentMethod: PaymentMethod
    )
}
```

### Composing Use Cases

```kotlin
class PlaceOrderUseCase @Inject constructor(
    private val validateCartUseCase: ValidateCartUseCase,
    private val createOrderUseCase: CreateOrderUseCase,
    private val sendOrderConfirmationUseCase: SendOrderConfirmationUseCase
) {
    suspend operator fun invoke(cart: Cart, payment: PaymentMethod): Result<OrderConfirmation> {
        return runCatching {
            validateCartUseCase(cart).getOrThrow()
            val order = createOrderUseCase(
                CreateOrderUseCase.Params(cart.items, cart.shippingAddress, payment)
            ).getOrThrow()
            sendOrderConfirmationUseCase(order).getOrThrow()
        }
    }
}
```

### Abstract Base Use Case Pattern

```kotlin
abstract class UseCase<in P, out R> {
    suspend operator fun invoke(params: P): Result<R> {
        return runCatching { execute(params) }
    }
    protected abstract suspend fun execute(params: P): R
}

abstract class FlowUseCase<in P, out R> {
    operator fun invoke(params: P): Flow<R> = execute(params)
    protected abstract fun execute(params: P): Flow<R>
}
```

### Key Android Patterns to Recognize

- `operator fun invoke()` — makes use case callable as a function
- `@Inject constructor` — Hilt/Dagger DI
- `suspend` — coroutine-based suspension
- `withContext(dispatchers.io)` — thread confinement
- `Result<T>` / `runCatching` — error wrapping
- `Flow<T>` return type — for streaming/observable use cases
- Single public method convention — one class, one operation

## iOS Best Practices (Target Patterns)

### Simple Use Case (One-Shot)

```swift
// Protocol-based approach (recommended for testability)
protocol GetUserUseCaseProtocol: Sendable {
    func execute(userId: String) async throws -> User
}

struct GetUserUseCase: GetUserUseCaseProtocol {
    private let userRepository: UserRepositoryProtocol

    init(userRepository: UserRepositoryProtocol) {
        self.userRepository = userRepository
    }

    func execute(userId: String) async throws -> User {
        try await userRepository.getUser(userId: userId)
    }
}
```

### Using callAsFunction (Kotlin invoke() Equivalent)

```swift
// If you prefer the Kotlin `invoke()` feel
struct GetUserUseCase: GetUserUseCaseProtocol {
    private let userRepository: UserRepositoryProtocol

    init(userRepository: UserRepositoryProtocol) {
        self.userRepository = userRepository
    }

    func callAsFunction(userId: String) async throws -> User {
        try await userRepository.getUser(userId: userId)
    }

    // Also conform to protocol
    func execute(userId: String) async throws -> User {
        try await callAsFunction(userId: userId)
    }
}

// Usage — looks like Kotlin:
// let user = try await getUserUseCase(userId: "123")
```

### Streaming Use Case (AsyncSequence-Based)

```swift
protocol ObserveUserUseCaseProtocol: Sendable {
    func execute(userId: String) -> AsyncThrowingStream<User, Error>
}

struct ObserveUserUseCase: ObserveUserUseCaseProtocol {
    private let userRepository: UserRepositoryProtocol

    init(userRepository: UserRepositoryProtocol) {
        self.userRepository = userRepository
    }

    func execute(userId: String) -> AsyncThrowingStream<User, Error> {
        userRepository.observeUser(userId: userId)
    }
}
```

### Parameterized Use Case with Validation

```swift
protocol CreateOrderUseCaseProtocol: Sendable {
    func execute(params: CreateOrderParams) async throws -> Order
}

struct CreateOrderParams: Sendable {
    let items: [OrderItem]
    let shippingAddress: Address
    let paymentMethod: PaymentMethod
}

enum CreateOrderError: Error, LocalizedError {
    case emptyOrder
    case invalidQuantity(itemId: String)
    case insufficientStock(productId: String, available: Int, requested: Int)

    var errorDescription: String? {
        switch self {
        case .emptyOrder:
            "Order must contain at least one item"
        case .invalidQuantity(let itemId):
            "Invalid quantity for item \(itemId)"
        case .insufficientStock(let productId, let available, let requested):
            "Insufficient stock for \(productId): \(available) available, \(requested) requested"
        }
    }
}

struct CreateOrderUseCase: CreateOrderUseCaseProtocol {
    private let orderRepository: OrderRepositoryProtocol
    private let inventoryRepository: InventoryRepositoryProtocol

    init(
        orderRepository: OrderRepositoryProtocol,
        inventoryRepository: InventoryRepositoryProtocol
    ) {
        self.orderRepository = orderRepository
        self.inventoryRepository = inventoryRepository
    }

    func execute(params: CreateOrderParams) async throws -> Order {
        guard !params.items.isEmpty else {
            throw CreateOrderError.emptyOrder
        }

        for item in params.items {
            guard item.quantity > 0 else {
                throw CreateOrderError.invalidQuantity(itemId: item.productId)
            }

            let available = try await inventoryRepository.checkStock(productId: item.productId)
            if available < item.quantity {
                throw CreateOrderError.insufficientStock(
                    productId: item.productId,
                    available: available,
                    requested: item.quantity
                )
            }
        }

        return try await orderRepository.createOrder(from: params)
    }
}
```

### Composing Use Cases

```swift
protocol PlaceOrderUseCaseProtocol: Sendable {
    func execute(cart: Cart, payment: PaymentMethod) async throws -> OrderConfirmation
}

struct PlaceOrderUseCase: PlaceOrderUseCaseProtocol {
    private let validateCart: ValidateCartUseCaseProtocol
    private let createOrder: CreateOrderUseCaseProtocol
    private let sendConfirmation: SendOrderConfirmationUseCaseProtocol

    init(
        validateCart: ValidateCartUseCaseProtocol,
        createOrder: CreateOrderUseCaseProtocol,
        sendConfirmation: SendOrderConfirmationUseCaseProtocol
    ) {
        self.validateCart = validateCart
        self.createOrder = createOrder
        self.sendConfirmation = sendConfirmation
    }

    func execute(cart: Cart, payment: PaymentMethod) async throws -> OrderConfirmation {
        try await validateCart.execute(cart: cart)

        let params = CreateOrderParams(
            items: cart.items,
            shippingAddress: cart.shippingAddress,
            paymentMethod: payment
        )
        let order = try await createOrder.execute(params: params)

        return try await sendConfirmation.execute(order: order)
    }
}
```

### Combine-Based Use Case (Alternative for iOS 15+)

```swift
import Combine

protocol ObserveUserUseCaseCombine {
    func execute(userId: String) -> AnyPublisher<User, Error>
}

struct ObserveUserUseCaseCombineImpl: ObserveUserUseCaseCombine {
    private let userRepository: UserRepositoryProtocol

    func execute(userId: String) -> AnyPublisher<User, Error> {
        // Bridge from AsyncSequence to Combine if needed
        let subject = PassthroughSubject<User, Error>()
        let task = Task {
            do {
                for try await user in userRepository.observeUser(userId: userId) {
                    subject.send(user)
                }
                subject.send(completion: .finished)
            } catch {
                subject.send(completion: .failure(error))
            }
        }
        return subject
            .handleEvents(receiveCancel: { task.cancel() })
            .eraseToAnyPublisher()
    }
}
```

### Generic Use Case Protocol (Optional)

```swift
// If you want a base protocol similar to Android's abstract UseCase
protocol UseCase: Sendable {
    associatedtype Params: Sendable
    associatedtype Result: Sendable
    func execute(params: Params) async throws -> Result
}

protocol StreamUseCase: Sendable {
    associatedtype Params: Sendable
    associatedtype Element: Sendable
    func execute(params: Params) -> AsyncThrowingStream<Element, Error>
}

// Note: Generic protocols with associated types are harder to mock.
// Prefer concrete protocols (GetUserUseCaseProtocol) in most codebases.
```

## Migration Mapping Table

| Android | iOS |
|---|---|
| `operator fun invoke()` | `func execute()` or `func callAsFunction()` |
| `suspend operator fun invoke()` | `func execute() async throws` |
| `Flow<T>` return | `AsyncThrowingStream<T, Error>` |
| `Result<T>` wrapping | `throws` (caller uses `do/catch`) |
| `runCatching { }` | `do { try } catch { }` |
| `withContext(dispatchers.io)` | Not needed (Swift concurrency manages threads) |
| `@Inject constructor` | `init` with protocol parameters |
| `require()` / `check()` | `guard` + `throw` custom error |
| Abstract `UseCase<P, R>` base class | `UseCase` protocol with associated types (or concrete protocols) |
| Abstract `FlowUseCase<P, R>` | `StreamUseCase` protocol (or concrete protocols) |
| Use Case composing via constructor injection | Same — inject use case protocols |

## Single Responsibility Patterns

### Android Anti-Pattern to Avoid on iOS

```kotlin
// BAD: Use case doing too many things
class UserProfileUseCase @Inject constructor(...) {
    suspend fun getUser(id: String): Result<User> { ... }
    suspend fun updateUser(user: User): Result<Unit> { ... }
    suspend fun deleteUser(id: String): Result<Unit> { ... }
    fun observeUser(id: String): Flow<User> { ... }
}
```

### Correct iOS Pattern

```swift
// GOOD: One use case per operation
struct GetUserUseCase: GetUserUseCaseProtocol { ... }
struct UpdateUserUseCase: UpdateUserUseCaseProtocol { ... }
struct DeleteUserUseCase: DeleteUserUseCaseProtocol { ... }
struct ObserveUserUseCase: ObserveUserUseCaseProtocol { ... }
```

## Testing

```swift
// Mock via protocol conformance
struct MockGetUserUseCase: GetUserUseCaseProtocol {
    var result: User?
    var error: Error?

    func execute(userId: String) async throws -> User {
        if let error { throw error }
        guard let result else { throw TestError.noMockData }
        return result
    }
}

// Test
@Test func placeOrder_validatesCartFirst() async throws {
    var validateCalled = false
    let mockValidate = MockValidateCartUseCase(onExecute: { _ in
        validateCalled = true
    })
    let mockCreate = MockCreateOrderUseCase(result: .mock)
    let mockConfirm = MockSendConfirmationUseCase(result: .mock)

    let useCase = PlaceOrderUseCase(
        validateCart: mockValidate,
        createOrder: mockCreate,
        sendConfirmation: mockConfirm
    )

    _ = try await useCase.execute(cart: .mock, payment: .creditCard)
    #expect(validateCalled)
}

@Test func createOrder_throwsOnEmptyItems() async {
    let useCase = CreateOrderUseCase(
        orderRepository: MockOrderRepository(),
        inventoryRepository: MockInventoryRepository()
    )

    await #expect(throws: CreateOrderError.emptyOrder) {
        try await useCase.execute(params: CreateOrderParams(
            items: [],
            shippingAddress: .mock,
            paymentMethod: .creditCard
        ))
    }
}
```

## Common Pitfalls

1. **Mixing concerns** — A use case should not contain UI logic, formatting, or navigation decisions. If you see a Kotlin use case doing formatting, split that out during migration.

2. **Skipping the protocol** — Always define a protocol for each use case. Concrete structs alone make testing the ViewModel harder because you cannot substitute mocks.

3. **Using `Result<T, Error>` instead of throws** — Swift's `async throws` is idiomatic. Do not wrap in `Result` unless you specifically need to store or pass around the result object. This differs from Kotlin where `Result<T>` is conventional.

4. **Thread management** — Do not add `DispatchQueue` calls or manual thread management. Swift structured concurrency handles suspension points automatically. Remove all `withContext(dispatchers.io)` calls — there is no iOS equivalent needed.

5. **Overusing generic base protocols** — `UseCase<Params, Result>` with associated types makes mocking difficult (you cannot use `any UseCase` easily). Prefer concrete protocols like `GetUserUseCaseProtocol`.

6. **Forgetting Sendable** — Use case types must be `Sendable` since they are typically shared across concurrency domains. Use `struct` (value types) for use cases when possible, which are implicitly `Sendable`.

7. **callAsFunction and protocols** — `callAsFunction` does not satisfy protocol requirements automatically. If your protocol defines `execute()`, you need both `callAsFunction` and `execute` (the latter delegating to the former), or just use `execute` consistently.

## Migration Checklist

- [ ] Identify all Use Case classes in the Android codebase
- [ ] Create a Swift protocol for each Use Case with `execute` method
- [ ] Create a concrete `struct` implementation for each Use Case
- [ ] Convert `suspend operator fun invoke()` to `func execute() async throws`
- [ ] Convert `Flow<T>` returning use cases to `AsyncThrowingStream<T, Error>`
- [ ] Replace `Result<T>` / `runCatching` with `throws` and custom error enums
- [ ] Remove `withContext(dispatchers)` calls — not needed in Swift
- [ ] Map DI constructor parameters to `init` with protocol types
- [ ] Convert `require()` / `check()` to `guard` + `throw`
- [ ] Ensure all use case types are `Sendable` (prefer `struct`)
- [ ] Verify single responsibility — one operation per use case
- [ ] Create mock implementations of each use case protocol for testing
- [ ] Write unit tests for validation logic, composition, and error paths
- [ ] If using Combine downstream, add `AnyPublisher` bridge methods where needed
