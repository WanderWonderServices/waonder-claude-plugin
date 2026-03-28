---
name: generic-android-to-ios-billing
description: Use when migrating Android in-app purchase patterns (Google Play Billing Library with BillingClient, ProductDetails, Purchase, acknowledgement, consumption) to iOS StoreKit 2 equivalents (Product, Transaction, async/await API, subscription management, offer codes) covering product types, purchase flow, receipt validation, subscription management, and sandbox testing
type: generic
---

# generic-android-to-ios-billing

## Context

Android's Google Play Billing Library uses a callback-based API centered on `BillingClient` with explicit purchase acknowledgement and consumption flows. iOS's StoreKit 2 (introduced iOS 15) provides a modern async/await API with `Product`, `Transaction`, and `Transaction.updates` for real-time purchase tracking. The fundamental differences are: Android requires explicit acknowledgement within 3 days or purchases are refunded, while iOS handles this implicitly; Android separates "consumed" vs "acknowledged" for consumables, while StoreKit 2 uses `Transaction.finish()`; and server-side receipt validation differs completely between platforms. This skill maps the complete purchase lifecycle from Android to iOS.

## Android Best Practices (Source Patterns)

### BillingClient Setup

```kotlin
class BillingRepository(private val context: Context) {

    private var billingClient: BillingClient? = null
    private val _purchaseState = MutableStateFlow<PurchaseState>(PurchaseState.Idle)
    val purchaseState: StateFlow<PurchaseState> = _purchaseState.asStateFlow()

    fun initialize() {
        billingClient = BillingClient.newBuilder(context)
            .setListener { billingResult, purchases ->
                handlePurchaseResult(billingResult, purchases)
            }
            .enablePendingPurchases()
            .build()

        billingClient?.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    // Ready to query products and make purchases
                }
            }

            override fun onBillingServiceDisconnected() {
                // Retry connection
            }
        })
    }
}
```

### Querying Products

```kotlin
suspend fun queryProducts(productIds: List<String>, type: String): List<ProductDetails> {
    val params = QueryProductDetailsParams.newBuilder()
        .setProductList(productIds.map { id ->
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(id)
                .setProductType(type) // BillingClient.ProductType.INAPP or SUBS
                .build()
        })
        .build()

    val result = billingClient?.queryProductDetails(params)
    return if (result?.billingResult?.responseCode == BillingClient.BillingResponseCode.OK) {
        result.productDetailsList ?: emptyList()
    } else {
        emptyList()
    }
}
```

### Launching Purchase Flow

```kotlin
fun launchPurchase(activity: Activity, productDetails: ProductDetails) {
    val flowParams = BillingFlowParams.newBuilder()
        .setProductDetailsParamsList(
            listOf(
                BillingFlowParams.ProductDetailsParams.newBuilder()
                    .setProductDetails(productDetails)
                    // For subscriptions, specify the offer
                    .setOfferToken(productDetails.subscriptionOfferDetails?.firstOrNull()?.offerToken ?: "")
                    .build()
            )
        )
        .build()

    billingClient?.launchBillingFlow(activity, flowParams)
}
```

### Handling Purchase Results

```kotlin
private fun handlePurchaseResult(billingResult: BillingResult, purchases: List<Purchase>?) {
    if (billingResult.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
        for (purchase in purchases) {
            when (purchase.purchaseState) {
                Purchase.PurchaseState.PURCHASED -> {
                    // Verify purchase on server, then acknowledge
                    verifyAndAcknowledge(purchase)
                }
                Purchase.PurchaseState.PENDING -> {
                    // Pending purchase (e.g., cash payment)
                    _purchaseState.value = PurchaseState.Pending
                }
            }
        }
    } else if (billingResult.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
        _purchaseState.value = PurchaseState.Cancelled
    }
}
```

### Acknowledgement and Consumption

```kotlin
// Non-consumable: acknowledge only
suspend fun acknowledgePurchase(purchase: Purchase) {
    if (!purchase.isAcknowledged) {
        val params = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken)
            .build()
        billingClient?.acknowledgePurchase(params)
    }
}

// Consumable: consume (which also acknowledges)
suspend fun consumePurchase(purchase: Purchase) {
    val params = ConsumeParams.newBuilder()
        .setPurchaseToken(purchase.purchaseToken)
        .build()
    billingClient?.consumeAsync(params) { billingResult, purchaseToken ->
        if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
            // Product consumed, can be purchased again
        }
    }
}
```

### Restoring Purchases

```kotlin
suspend fun restorePurchases() {
    // In-app products
    val inAppParams = QueryPurchasesParams.newBuilder()
        .setProductType(BillingClient.ProductType.INAPP)
        .build()
    val inAppResult = billingClient?.queryPurchasesAsync(inAppParams)

    // Subscriptions
    val subsParams = QueryPurchasesParams.newBuilder()
        .setProductType(BillingClient.ProductType.SUBS)
        .build()
    val subsResult = billingClient?.queryPurchasesAsync(subsParams)

    // Process and grant entitlements
}
```

### Key Android Patterns to Recognize

- `BillingClient.newBuilder` — creates and configures the billing client
- `PurchasesUpdatedListener` — callback for all purchase state changes
- `queryProductDetails` — fetches product metadata from Play Store
- `launchBillingFlow` — presents the purchase UI
- `acknowledgePurchase` — required within 3 days for non-consumables and subscriptions
- `consumeAsync` — marks consumable as re-purchasable
- `queryPurchasesAsync` — restores existing purchases
- `enablePendingPurchases` — required for delayed/pending payment methods

## iOS Best Practices (Target Patterns)

### StoreKit 2 Product Loading

```swift
import StoreKit

final class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var purchaseState: PurchaseState = .idle

    private var transactionListener: Task<Void, Error>?

    // Product IDs configured in App Store Connect
    private let productIDs: Set<String> = [
        "com.myapp.premium",           // Non-consumable
        "com.myapp.coins.100",          // Consumable
        "com.myapp.subscription.monthly", // Auto-renewable subscription
        "com.myapp.subscription.yearly"
    ]

    init() {
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
        Task { await updatePurchasedProducts() }
    }

    deinit {
        transactionListener?.cancel()
    }

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIDs)
            await MainActor.run {
                products = storeProducts.sorted { $0.price < $1.price }
            }
        } catch {
            print("Failed to load products: \(error)")
        }
    }
}
```

### Listening for Transactions

```swift
extension StoreManager {
    // Listen for transactions that happen outside the app
    // (renewals, family sharing, subscription offers, App Store refunds)
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                await self.handle(transactionResult: result)
            }
        }
    }

    @MainActor
    private func handle(transactionResult: VerificationResult<Transaction>) async {
        switch transactionResult {
        case .verified(let transaction):
            // Grant entitlement
            await updatePurchasedProducts()
            // Always finish the transaction
            await transaction.finish()

        case .unverified(let transaction, let error):
            // StoreKit verification failed — handle cautiously
            print("Unverified transaction: \(error)")
        }
    }
}
```

### Purchase Flow

```swift
extension StoreManager {
    func purchase(_ product: Product) async throws {
        purchaseState = .purchasing

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                // Purchase verified by StoreKit
                await updatePurchasedProducts()
                await transaction.finish()
                purchaseState = .purchased

            case .unverified(_, let error):
                purchaseState = .failed(error)
            }

        case .userCancelled:
            purchaseState = .cancelled

        case .pending:
            // Purchase requires approval (Ask to Buy, SCA)
            purchaseState = .pending

        @unknown default:
            purchaseState = .failed(StoreError.unknown)
        }
    }
}

enum PurchaseState: Equatable {
    case idle
    case purchasing
    case purchased
    case cancelled
    case pending
    case failed(Error)

    static func == (lhs: PurchaseState, rhs: PurchaseState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.purchasing, .purchasing), (.purchased, .purchased),
             (.cancelled, .cancelled), (.pending, .pending):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}
```

### Checking Entitlements and Restoring Purchases

```swift
extension StoreManager {
    @MainActor
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        // Check current entitlements (active non-consumables and subscriptions)
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchased.insert(transaction.productID)
            }
        }

        purchasedProductIDs = purchased
    }

    func isPurchased(_ productID: String) -> Bool {
        purchasedProductIDs.contains(productID)
    }

    // Explicit restore for user-initiated restore button
    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }
}
```

### Subscription Management

```swift
extension StoreManager {
    func subscriptionStatus() async -> [Product.SubscriptionInfo.Status] {
        guard let product = products.first(where: { $0.type == .autoRenewable }),
              let statuses = try? await product.subscription?.status else {
            return []
        }
        return statuses
    }

    func activeSubscription() async -> Transaction? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productType == .autoRenewable {
                return transaction
            }
        }
        return nil
    }

    // Check subscription renewal info
    func subscriptionRenewalInfo(for product: Product) async -> Product.SubscriptionInfo.RenewalInfo? {
        guard let statuses = try? await product.subscription?.status else { return nil }
        for status in statuses {
            if case .verified(let renewalInfo) = status.renewalInfo {
                return renewalInfo
            }
        }
        return nil
    }

    // Open subscription management (App Store subscription settings)
    func manageSubscriptions() async {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            try? await AppStore.showManageSubscriptions(in: windowScene)
        }
    }
}
```

### Subscription Offer Codes and Promotional Offers

```swift
extension StoreManager {
    // Open offer code redemption sheet
    func redeemOfferCode() async {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            try? await AppStore.presentOfferCodeRedeemSheet(in: windowScene)
        }
    }

    // Purchase with promotional offer (requires server-signed offer)
    func purchaseWithOffer(product: Product, offerID: String, signature: Data,
                           nonce: UUID, timestamp: Int, keyID: String) async throws {
        let offer = Product.PurchaseOption.promotionalOffer(
            offerID: offerID,
            keyID: keyID,
            nonce: nonce,
            signature: signature,
            timestamp: timestamp
        )
        let result = try await product.purchase(options: [offer])
        // Handle result same as regular purchase
    }
}
```

### SwiftUI Integration

```swift
struct StoreView: View {
    @StateObject private var storeManager = StoreManager()

    var body: some View {
        List {
            ForEach(storeManager.products) { product in
                ProductRow(product: product, isPurchased: storeManager.isPurchased(product.id))
            }
        }
        .task {
            await storeManager.loadProducts()
        }
    }
}

struct ProductRow: View {
    let product: Product
    let isPurchased: Bool
    @EnvironmentObject var storeManager: StoreManager

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(product.displayName)
                    .font(.headline)
                Text(product.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isPurchased {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(product.displayPrice) {
                    Task {
                        try? await storeManager.purchase(product)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// Built-in subscription store view (iOS 17+)
struct SubscriptionStoreExampleView: View {
    var body: some View {
        SubscriptionStoreView(groupID: "YOUR_GROUP_ID") {
            VStack {
                Text("Premium Features")
                    .font(.title)
                Text("Unlock everything with a subscription")
            }
        }
    }
}
```

### Server-Side Receipt Validation

```swift
// StoreKit 2 uses JWS (JSON Web Signature) for transaction verification
// The Transaction object is already verified by StoreKit on-device
// For server validation, send the transaction's JWS representation

extension StoreManager {
    func sendTransactionToServer(_ transaction: Transaction) async {
        // Get the JWS representation
        guard let jwsRepresentation = transaction.jsonRepresentation else { return }

        // Send to your server
        var request = URLRequest(url: URL(string: "https://api.myapp.com/verify-purchase")!)
        request.httpMethod = "POST"
        request.httpBody = jwsRepresentation
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            // Handle server response
        } catch {
            // Handle error
        }
    }
}

// Server-side: Use App Store Server API v2
// - Verify JWS token signature using Apple's public keys
// - Use App Store Server Notifications V2 for real-time subscription events
// - Use /inApps/v2/history endpoint for transaction history
// - Use /inApps/v1/subscriptions/{transactionId} for subscription status
```

### Testing with StoreKit Configuration

```swift
// For unit testing with StoreKit Test
import StoreKitTest

class PurchaseTests: XCTestCase {
    var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "StoreKitConfig")
        session.disableDialogs = true
        session.clearTransactions()
    }

    func testPurchaseProduct() async throws {
        let storeManager = StoreManager()
        await storeManager.loadProducts()

        guard let product = storeManager.products.first else {
            XCTFail("No products loaded")
            return
        }

        try await storeManager.purchase(product)
        XCTAssertTrue(storeManager.isPurchased(product.id))
    }

    func testSubscriptionRenewal() async throws {
        // Simulate subscription renewal
        try session.buyProduct(productIdentifier: "com.myapp.subscription.monthly")
        try await session.expireSubscription(productIdentifier: "com.myapp.subscription.monthly")
        // Verify renewal behavior
    }
}
```

## Migration Mapping Table

| Android (Play Billing) | iOS (StoreKit 2) |
|---|---|
| `BillingClient` | `Product` / `Transaction` static APIs |
| `BillingClient.startConnection` | No connection needed — StoreKit 2 is stateless |
| `queryProductDetails` | `Product.products(for:)` |
| `ProductDetails` | `Product` |
| `ProductDetails.oneTimePurchaseOfferDetails.formattedPrice` | `Product.displayPrice` |
| `ProductDetails.subscriptionOfferDetails` | `Product.subscription` |
| `launchBillingFlow` | `Product.purchase()` |
| `PurchasesUpdatedListener` | `Transaction.updates` async sequence |
| `Purchase` | `Transaction` |
| `Purchase.purchaseToken` | `Transaction.id` / `Transaction.originalID` |
| `acknowledgePurchase` | `Transaction.finish()` (always required) |
| `consumeAsync` | `Transaction.finish()` (same as acknowledge) |
| `queryPurchasesAsync` | `Transaction.currentEntitlements` |
| `BillingClient.ProductType.INAPP` | `Product.ProductType.consumable` / `.nonConsumable` |
| `BillingClient.ProductType.SUBS` | `Product.ProductType.autoRenewable` |
| Purchase verification (server-side) | JWS verification / `VerificationResult` |
| Google Play Developer API | App Store Server API v2 |
| Real-time Developer Notifications (RTDN) | App Store Server Notifications V2 |
| Promo codes | Offer codes (`AppStore.presentOfferCodeRedeemSheet`) |
| `Purchase.PurchaseState.PENDING` | `.pending` result from `product.purchase()` |
| Sandbox testing (license testers) | StoreKit Testing in Xcode / Sandbox environment |

## Product Type Differences

| Type | Android | iOS |
|---|---|---|
| Consumable | `INAPP` + `consumeAsync` | `.consumable` + `Transaction.finish()` |
| Non-consumable | `INAPP` + `acknowledgePurchase` | `.nonConsumable` + `Transaction.finish()` |
| Auto-renewable subscription | `SUBS` + `acknowledgePurchase` | `.autoRenewable` + `Transaction.finish()` |
| Non-renewing subscription | `SUBS` (manual renewal logic) | `.nonRenewable` |
| Prepaid subscription | `SUBS` with prepaid offer | Not available on iOS |

## Common Pitfalls

1. **Forgetting `Transaction.finish()`** — On Android, unacknowledged purchases are refunded after 3 days. On iOS, unfinished transactions keep appearing in `Transaction.updates`. Always call `finish()` after granting the entitlement, for ALL product types (consumable, non-consumable, and subscriptions).

2. **Not listening to `Transaction.updates`** — This async sequence delivers transactions that occur outside the purchase flow: subscription renewals, Family Sharing changes, refunds, offer code redemptions, and restored purchases. It must be started at app launch and run for the app's lifetime. This is the equivalent of Android's `PurchasesUpdatedListener`.

3. **Confusing StoreKit 1 and StoreKit 2** — StoreKit 2 (`Product`, `Transaction`) is completely separate from StoreKit 1 (`SKPayment`, `SKPaymentQueue`). Do not mix them. StoreKit 2 requires iOS 15+ minimum. If you need iOS 14 or earlier, you must use StoreKit 1 (the original API).

4. **No explicit connection setup** — Unlike Android's `BillingClient.startConnection`, StoreKit 2 does not require connection management. `Product.products(for:)` and `Transaction` APIs work directly. Do not try to replicate the connection/disconnection lifecycle.

5. **Consumable re-purchase** — On Android, you must call `consumeAsync` before a consumable can be purchased again. On iOS StoreKit 2, calling `Transaction.finish()` is all that is needed. The product becomes available for re-purchase immediately after finishing.

6. **Receipt validation architecture change** — Android uses server-side verification via the Google Play Developer API with purchase tokens. StoreKit 2 transactions are JWS-signed and verified on-device automatically. For server validation, send the JWS representation and verify the signature using Apple's public keys. The old `appStoreReceiptURL` approach (StoreKit 1) is deprecated.

7. **Subscription group differences** — Android subscriptions can have base plans and offers. iOS subscriptions are organized into subscription groups with their own upgrade/downgrade/crossgrade rules. Carefully map your Android subscription tiers to iOS subscription groups in App Store Connect.

8. **Testing environment differences** — Android uses license test accounts configured in the Play Console. iOS has two testing approaches: StoreKit Testing in Xcode (local, no server) and the Sandbox environment (connects to Apple's test servers). Use StoreKit Testing for development and Sandbox for integration testing.

9. **`AppStore.sync()` vs `queryPurchasesAsync`** — The iOS equivalent of restoring purchases is `AppStore.sync()`, which triggers a sign-in prompt. Only call this in response to an explicit user action (e.g., "Restore Purchases" button). For passive entitlement checking, use `Transaction.currentEntitlements` which does not prompt.

## Migration Checklist

- [ ] Configure products in App Store Connect (matching your Play Console product setup)
- [ ] Create StoreKit Configuration file in Xcode for local testing
- [ ] Replace `BillingClient` setup with `Product.products(for:)` for product loading
- [ ] Start `Transaction.updates` listener at app launch (equivalent to `PurchasesUpdatedListener`)
- [ ] Replace `launchBillingFlow` with `Product.purchase()`
- [ ] Handle all `PurchaseResult` cases: `.success`, `.userCancelled`, `.pending`
- [ ] Handle `VerificationResult`: `.verified` and `.unverified`
- [ ] Replace `acknowledgePurchase` and `consumeAsync` with `Transaction.finish()`
- [ ] Replace `queryPurchasesAsync` with `Transaction.currentEntitlements` for entitlement checking
- [ ] Add a "Restore Purchases" button that calls `AppStore.sync()`
- [ ] Implement subscription management UI or use `AppStore.showManageSubscriptions(in:)`
- [ ] Use `SubscriptionStoreView` for subscription UI if targeting iOS 17+
- [ ] Migrate server-side receipt validation from Google Play Developer API to App Store Server API v2
- [ ] Set up App Store Server Notifications V2 (equivalent to Google's RTDN)
- [ ] Replace promo code handling with `AppStore.presentOfferCodeRedeemSheet(in:)`
- [ ] Map subscription tiers to iOS subscription groups in App Store Connect
- [ ] Configure promotional offers with server-signed keys if applicable
- [ ] Write tests using `SKTestSession` for purchase flow verification
- [ ] Test in Sandbox environment with a Sandbox Apple ID before submission
- [ ] Ensure `Transaction.finish()` is called for every verified transaction, including renewals
