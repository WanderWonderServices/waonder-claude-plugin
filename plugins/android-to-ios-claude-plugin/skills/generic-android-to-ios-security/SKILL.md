---
name: generic-android-to-ios-security
description: Use when migrating Android security (AndroidKeyStore, EncryptedSharedPreferences, BiometricPrompt, SafetyNet/Play Integrity, certificate pinning) to iOS equivalents (Keychain Services, CryptoKit, LAContext biometrics, App Attest/DeviceCheck, ATS, certificate pinning) with credential storage, encryption, biometric auth, device attestation, and network security
type: generic
---

# generic-android-to-ios-security

## Context

Android and iOS both provide comprehensive security frameworks, but they differ significantly in API design and architecture. Android uses `AndroidKeyStore` for hardware-backed key storage, `EncryptedSharedPreferences` for encrypted key-value storage, `BiometricPrompt` for biometric authentication, and `Play Integrity` for device attestation. iOS provides `Keychain Services` for secure credential storage, `CryptoKit` for modern cryptographic operations, `LocalAuthentication` (`LAContext`) for biometrics, `App Attest`/`DeviceCheck` for device integrity, and `App Transport Security` (ATS) for enforced HTTPS. This skill maps each Android security pattern to its idiomatic iOS equivalent with production-ready code.

## Android Best Practices (Source Patterns)

### AndroidKeyStore Key Generation

```kotlin
class KeyStoreManager {
    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    fun generateEncryptionKey(alias: String) {
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore"
        )
        keyGenerator.init(
            KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setUserAuthenticationRequired(true)
                .setUserAuthenticationParameters(300, KeyProperties.AUTH_BIOMETRIC_STRONG)
                .build()
        )
        keyGenerator.generateKey()
    }

    fun encrypt(alias: String, data: ByteArray): Pair<ByteArray, ByteArray> {
        val key = keyStore.getKey(alias, null) as SecretKey
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        return cipher.iv to cipher.doFinal(data)
    }

    fun decrypt(alias: String, iv: ByteArray, encryptedData: ByteArray): ByteArray {
        val key = keyStore.getKey(alias, null) as SecretKey
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, iv))
        return cipher.doFinal(encryptedData)
    }
}
```

### EncryptedSharedPreferences

```kotlin
class SecureStorage @Inject constructor(@ApplicationContext context: Context) {
    private val prefs = EncryptedSharedPreferences.create(
        context,
        "secure_prefs",
        MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun saveToken(token: String) = prefs.edit { putString("auth_token", token) }
    fun getToken(): String? = prefs.getString("auth_token", null)
    fun saveCredentials(username: String, password: String) {
        prefs.edit {
            putString("username", username)
            putString("password", password)
        }
    }
    fun clearAll() = prefs.edit { clear() }
}
```

### BiometricPrompt

```kotlin
class BiometricAuthManager(private val activity: FragmentActivity) {
    fun authenticate(
        title: String = "Authenticate",
        subtitle: String = "Verify your identity",
        onSuccess: (BiometricPrompt.AuthenticationResult) -> Unit,
        onError: (Int, String) -> Unit
    ) {
        val executor = ContextCompat.getMainExecutor(activity)

        val biometricPrompt = BiometricPrompt(activity, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    onSuccess(result)
                }
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    onError(errorCode, errString.toString())
                }
                override fun onAuthenticationFailed() {
                    // Individual attempt failed, not final
                }
            }
        )

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
            .build()

        biometricPrompt.authenticate(promptInfo)
    }

    fun canAuthenticate(): Boolean {
        val manager = BiometricManager.from(activity)
        return manager.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG
        ) == BiometricManager.BIOMETRIC_SUCCESS
    }

    // Biometric-bound crypto operation
    fun authenticateWithCrypto(
        cipher: Cipher,
        onSuccess: (Cipher) -> Unit,
        onError: (Int, String) -> Unit
    ) {
        val executor = ContextCompat.getMainExecutor(activity)
        val biometricPrompt = BiometricPrompt(activity, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    result.cryptoObject?.cipher?.let { onSuccess(it) }
                }
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    onError(errorCode, errString.toString())
                }
            }
        )
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Authenticate")
            .setNegativeButtonText("Cancel")
            .build()
        biometricPrompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(cipher))
    }
}
```

### Play Integrity API

```kotlin
class IntegrityChecker @Inject constructor(
    @ApplicationContext private val context: Context
) {
    suspend fun getIntegrityToken(): String {
        val manager = IntegrityManagerFactory.create(context)
        val request = IntegrityTokenRequest.builder()
            .setNonce(generateNonce())
            .build()
        val response = manager.requestIntegrityToken(request).await()
        return response.token()
    }

    private fun generateNonce(): String {
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        return Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP)
    }
}
```

### Certificate Pinning (OkHttp)

```kotlin
val client = OkHttpClient.Builder()
    .certificatePinner(
        CertificatePinner.Builder()
            .add("api.waonder.com", "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
            .add("api.waonder.com", "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=") // backup
            .build()
    )
    .build()
```

### Network Security Config

```xml
<!-- res/xml/network_security_config.xml -->
<network-security-config>
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">api.waonder.com</domain>
        <pin-set expiration="2025-12-31">
            <pin digest="SHA-256">AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</pin>
            <pin digest="SHA-256">BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

## iOS Equivalent Patterns

### Keychain Services (AndroidKeyStore + EncryptedSharedPreferences Equivalent)

```swift
import Security

actor KeychainManager {
    enum KeychainError: Error {
        case duplicateItem
        case itemNotFound
        case unexpectedStatus(OSStatus)
        case invalidData
    }

    // Save credentials
    func save(
        _ data: Data,
        forKey key: String,
        accessControl: SecAccessControl? = nil
    ) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        if let accessControl {
            query[kSecAttrAccessControl as String] = accessControl
            query.removeValue(forKey: kSecAttrAccessible as String)
        }

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // Update existing
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]
            let attributes: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(
                updateQuery as CFDictionary,
                attributes as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // Retrieve credentials
    func load(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
        return data
    }

    // Delete
    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // Save with biometric protection
    func saveBiometricProtected(_ data: Data, forKey key: String) throws {
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            [.biometryCurrentSet, .privateKeyUsage],
            nil
        ) else {
            throw KeychainError.unexpectedStatus(errSecParam)
        }

        try save(data, forKey: key, accessControl: accessControl)
    }
}

// High-level wrapper (equivalent to EncryptedSharedPreferences)
actor SecureStorage {
    private let keychain = KeychainManager()

    func saveToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else { return }
        try keychain.save(data, forKey: "auth_token")
    }

    func getToken() -> String? {
        guard let data = try? keychain.load(forKey: "auth_token") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveCredentials(username: String, password: String) throws {
        let credentials = ["username": username, "password": password]
        let data = try JSONEncoder().encode(credentials)
        try keychain.save(data, forKey: "credentials")
    }

    func clearAll() throws {
        try keychain.delete(forKey: "auth_token")
        try keychain.delete(forKey: "credentials")
    }
}
```

### CryptoKit (AndroidKeyStore Crypto Equivalent)

```swift
import CryptoKit

struct CryptoManager {
    // Symmetric encryption (AES-GCM, equivalent to AndroidKeyStore AES)
    static func generateSymmetricKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    static func encrypt(data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        return combined
    }

    static func decrypt(combinedData: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // Store key in Keychain
    static func storeKey(_ key: SymmetricKey, withTag tag: String) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw CryptoError.keyStoreFailed
        }
    }

    // Retrieve key from Keychain
    static func loadKey(withTag tag: String) throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let keyData = result as? Data else {
            throw CryptoError.keyNotFound
        }
        return SymmetricKey(data: keyData)
    }

    // Hashing
    static func sha256Hash(of data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // HMAC
    static func hmac(data: Data, key: SymmetricKey) -> Data {
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(signature)
    }

    enum CryptoError: Error {
        case encryptionFailed
        case keyStoreFailed
        case keyNotFound
    }
}

// Secure Enclave key (hardware-backed, equivalent to StrongBox)
struct SecureEnclaveManager {
    static func generatePrivateKey() throws -> SecKey {
        let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            nil
        )!

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: "com.waonder.app.securekey".data(using: .utf8)!,
                kSecAttrAccessControl as String: accessControl
            ] as [String: Any]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        return privateKey
    }

    static func sign(data: Data, with privateKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            &error
        ) else {
            throw error!.takeRetainedValue() as Error
        }
        return signature as Data
    }
}
```

### Biometric Authentication (BiometricPrompt Equivalent)

```swift
import LocalAuthentication

actor BiometricAuthManager {
    enum BiometricError: Error {
        case notAvailable
        case notEnrolled
        case authenticationFailed(String)
        case cancelled
    }

    enum BiometricType {
        case faceID
        case touchID
        case opticID
        case none
    }

    func biometricType() -> BiometricType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        case .none: return .none
        @unknown default: return .none
        }
    }

    func canAuthenticate() -> Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: nil
        )
    }

    // Biometric only
    func authenticateWithBiometrics(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "" // Hide "Enter Password" fallback

        var error: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) else {
            if let error {
                throw BiometricError.authenticationFailed(error.localizedDescription)
            }
            throw BiometricError.notAvailable
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                throw BiometricError.cancelled
            default:
                throw BiometricError.authenticationFailed(error.localizedDescription)
            }
        }
    }

    // Biometric + device passcode fallback
    // Equivalent to BIOMETRIC_STRONG | DEVICE_CREDENTIAL
    func authenticateWithBiometricsOrPasscode(reason: String) async throws -> Bool {
        let context = LAContext()

        return try await context.evaluatePolicy(
            .deviceOwnerAuthentication,  // Includes passcode fallback
            localizedReason: reason
        )
    }

    // Biometric-bound Keychain access (equivalent to BiometricPrompt + CryptoObject)
    func loadBiometricProtectedItem(forKey key: String) async throws -> Data {
        let context = LAContext()
        context.localizedReason = "Authenticate to access secure data"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            throw BiometricError.authenticationFailed("Keychain access failed: \(status)")
        }
        return data
    }
}

// SwiftUI integration
struct BiometricLoginView: View {
    @State private var isAuthenticated = false
    @State private var errorMessage: String?
    private let biometricManager = BiometricAuthManager()

    var body: some View {
        VStack(spacing: 20) {
            if isAuthenticated {
                Text("Authenticated!")
            } else {
                Button("Authenticate") {
                    Task {
                        do {
                            isAuthenticated = try await biometricManager
                                .authenticateWithBiometricsOrPasscode(
                                    reason: "Log in to your account"
                                )
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }
}
```

### App Attest and DeviceCheck (Play Integrity Equivalent)

```swift
import DeviceCheck

actor DeviceIntegrityManager {
    // App Attest - strong attestation (equivalent to Play Integrity)
    func generateAttestKey() async throws -> String {
        let service = DCAppAttestService.shared
        guard service.isSupported else {
            throw IntegrityError.notSupported
        }
        return try await service.generateKey()
    }

    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        let service = DCAppAttestService.shared
        return try await service.attestKey(keyId, clientDataHash: clientDataHash)
    }

    func generateAssertion(
        keyId: String,
        clientDataHash: Data
    ) async throws -> Data {
        let service = DCAppAttestService.shared
        return try await service.generateAssertion(keyId, clientDataHash: clientDataHash)
    }

    // DeviceCheck - simple two-bit device state
    func generateDeviceToken() async throws -> Data {
        let device = DCDevice.current
        guard device.isSupported else {
            throw IntegrityError.notSupported
        }
        return try await device.generateToken()
    }

    enum IntegrityError: Error {
        case notSupported
    }
}

// Full attestation flow
actor AppAttestManager {
    private var attestKeyId: String?

    func performAttestation(serverChallenge: Data) async throws -> Data {
        let service = DCAppAttestService.shared

        // 1. Generate key (do this once and store the keyId)
        let keyId: String
        if let existingKey = attestKeyId {
            keyId = existingKey
        } else {
            keyId = try await service.generateKey()
            attestKeyId = keyId
        }

        // 2. Create client data hash from server challenge
        let clientDataHash = SHA256.hash(data: serverChallenge)
        let hashData = Data(clientDataHash)

        // 3. Attest the key (first time only - sends to Apple for verification)
        let attestation = try await service.attestKey(keyId, clientDataHash: hashData)

        // 4. Send attestation to your server for verification
        return attestation
    }

    func generateAssertion(requestData: Data) async throws -> Data {
        guard let keyId = attestKeyId else {
            throw AppAttestError.noKey
        }

        let clientDataHash = Data(SHA256.hash(data: requestData))
        return try await DCAppAttestService.shared.generateAssertion(
            keyId,
            clientDataHash: clientDataHash
        )
    }

    enum AppAttestError: Error {
        case noKey
    }
}
```

### Certificate Pinning

```swift
// Option 1: URLSession delegate-based pinning
class PinnedURLSessionDelegate: NSObject, URLSessionDelegate {
    // Base64-encoded SHA-256 hashes of the public key
    private let pinnedHashes: Set<String> = [
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" // backup pin
    ]

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod ==
                NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              challenge.protectionSpace.host == "api.waonder.com" else {
            return (.cancelAuthenticationChallenge, nil)
        }

        // Evaluate the server certificate
        let policies = [SecPolicyCreateSSL(true, "api.waonder.com" as CFString)]
        SecTrustSetPolicies(serverTrust, policies as CFTypeRef)

        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            return (.cancelAuthenticationChallenge, nil)
        }

        // Check public key hash against pins
        guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0),
              let serverPublicKey = SecCertificateCopyKey(serverCertificate),
              let serverPublicKeyData = SecKeyCopyExternalRepresentation(
                  serverPublicKey, nil
              ) as? Data else {
            return (.cancelAuthenticationChallenge, nil)
        }

        let hash = SHA256.hash(data: serverPublicKeyData)
        let hashString = Data(hash).base64EncodedString()

        if pinnedHashes.contains(hashString) {
            return (.useCredential, URLCredential(trust: serverTrust))
        }

        return (.cancelAuthenticationChallenge, nil)
    }
}

// Option 2: Info.plist NSPinnedDomains (iOS 14+, declarative)
// Add to Info.plist:
// NSAppTransportSecurity > NSPinnedDomains > api.waonder.com >
//   NSIncludesSubdomains: true
//   NSPinnedCAIdentities or NSPinnedLeafIdentities:
//     - SPKI-SHA256-BASE64: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
```

### App Transport Security (ATS)

```swift
// ATS is enabled by default on iOS - enforces HTTPS
// No code needed for basic HTTPS enforcement

// Info.plist exceptions (avoid in production):
// NSAppTransportSecurity:
//   NSAllowsArbitraryLoads: false (default, leave this)
//   NSExceptionDomains:
//     legacy-api.example.com:
//       NSExceptionAllowsInsecureHTTPLoads: true
//       NSExceptionMinimumTLSVersion: TLSv1.2

// Programmatic TLS configuration
let config = URLSessionConfiguration.default
config.tlsMinimumSupportedProtocolVersion = .TLSv12
config.tlsMaximumSupportedProtocolVersion = .TLSv13
```

### Secure Data Wipe on Jailbreak Detection

```swift
struct JailbreakDetector {
    static func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // Check for common jailbreak indicators
        let paths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // Check if app can write outside sandbox
        let testPath = "/private/jailbreak_test_\(UUID().uuidString)"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
        #endif
    }
}
```

## Concept Mapping

| Android | iOS |
|---------|-----|
| `AndroidKeyStore` | Keychain Services + Secure Enclave |
| `KeyGenerator` (AES) | `CryptoKit.SymmetricKey` + `AES.GCM` |
| `EncryptedSharedPreferences` | Keychain Services (data encrypted at rest by OS) |
| `BiometricPrompt` | `LAContext.evaluatePolicy()` |
| `BIOMETRIC_STRONG` | `.deviceOwnerAuthenticationWithBiometrics` |
| `BIOMETRIC_STRONG \| DEVICE_CREDENTIAL` | `.deviceOwnerAuthentication` (includes passcode) |
| `BiometricPrompt.CryptoObject` | Keychain `kSecAttrAccessControl` with `.biometryCurrentSet` |
| `Play Integrity API` | `DCAppAttestService` (App Attest) |
| `SafetyNet Attestation` | `DCDevice` (DeviceCheck) |
| `CertificatePinner` (OkHttp) | `URLSessionDelegate` + `SecTrust` or `NSPinnedDomains` |
| `network_security_config.xml` | `NSAppTransportSecurity` in Info.plist |
| `StrongBox Keymaster` | Secure Enclave (`kSecAttrTokenIDSecureEnclave`) |
| `setUserAuthenticationRequired(true)` | `SecAccessControl` with `.biometryCurrentSet` |

## Common Pitfalls

1. **Not using kSecAttrAccessibleWhenUnlockedThisDeviceOnly** - The default Keychain accessibility allows items to be accessed when the device is locked and synced via iCloud Keychain. For sensitive data, always use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` to prevent iCloud sync and lock-screen access.

2. **Forgetting the Info.plist entry for Face ID** - `NSFaceIDUsageDescription` must be present in Info.plist or the app will crash when requesting Face ID. There is no equivalent requirement for Touch ID.

3. **Not handling biometric enrollment changes** - Using `.biometryCurrentSet` in access control invalidates the Keychain item when biometrics change (finger added/removed). This is the correct security behavior but must be handled in UX (prompt re-authentication).

4. **Using SecItemAdd without checking for duplicates** - `SecItemAdd` returns `errSecDuplicateItem` if the key already exists. Always handle this by calling `SecItemUpdate` for existing items.

5. **Assuming App Attest is available everywhere** - `DCAppAttestService.shared.isSupported` returns false on simulators and some older devices. Always provide a fallback.

6. **Relying solely on jailbreak detection** - Jailbreak detection is a cat-and-mouse game. It should be one layer of defense, not the only one. Combine with App Attest, certificate pinning, and server-side validation.

7. **Storing encryption keys in UserDefaults** - UserDefaults is not encrypted and is included in device backups. Always store keys and credentials in Keychain.

8. **Not pinning backup certificates** - Always include at least one backup pin. If the primary certificate rotates and you only pinned one key, all users are locked out until an app update is shipped.

## Migration Checklist

- [ ] Replace `EncryptedSharedPreferences` with Keychain Services using `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- [ ] Create a `KeychainManager` wrapper for save/load/delete operations
- [ ] Replace `AndroidKeyStore` AES encryption with `CryptoKit` `AES.GCM` for symmetric encryption
- [ ] Migrate hardware-backed signing keys to Secure Enclave (`kSecAttrTokenIDSecureEnclave`)
- [ ] Replace `BiometricPrompt` with `LAContext.evaluatePolicy()` for biometric authentication
- [ ] Add `NSFaceIDUsageDescription` to Info.plist
- [ ] Implement biometric-protected Keychain items using `SecAccessControl` with `.biometryCurrentSet`
- [ ] Replace `Play Integrity` with `DCAppAttestService` for device attestation
- [ ] Implement App Attest key generation, attestation, and assertion flow
- [ ] Replace OkHttp `CertificatePinner` with `URLSessionDelegate` certificate validation or `NSPinnedDomains` in Info.plist
- [ ] Verify `NSAppTransportSecurity` settings enforce HTTPS (ATS is on by default)
- [ ] Remove any `NSAllowsArbitraryLoads = true` exceptions in production builds
- [ ] Implement jailbreak detection as an additional security layer
- [ ] Store all sensitive tokens and credentials in Keychain, never in UserDefaults or files
- [ ] Test Keychain behavior across app reinstalls (items persist) and device lock states
- [ ] Verify biometric auth works with Face ID, Touch ID, and passcode fallback
- [ ] Test certificate pinning with proxy tools (Charles, mitmproxy) to confirm pins are enforced
