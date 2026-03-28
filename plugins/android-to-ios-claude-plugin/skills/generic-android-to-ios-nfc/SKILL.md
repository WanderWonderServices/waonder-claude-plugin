---
name: generic-android-to-ios-nfc
description: Use when migrating Android NFC patterns (NfcAdapter, NDEF, NdefMessage, Tag dispatch, Host Card Emulation, foreground dispatch) to iOS Core NFC equivalents (NFCNDEFReaderSession, NFCTagReaderSession) covering NDEF reading/writing, tag types, iOS limitations vs Android capabilities, and background tag reading
type: generic
---

# generic-android-to-ios-nfc

## Context

Android's NFC stack is comprehensive: it supports reading, writing, tag emulation (HCE), foreground dispatch, and intent-based tag delivery. iOS's Core NFC framework is significantly more limited — it supports NDEF reading on iPhone 7+ (iOS 11+), NDEF writing and native tag access on iPhone 7+ (iOS 13+), and background tag reading (iOS 12+), but does not support Host Card Emulation or peer-to-peer NFC. This skill maps the Android NFC patterns to their iOS equivalents and clearly documents what cannot be migrated due to platform limitations.

## Android Best Practices (Source Patterns)

### NFC Permissions and Setup

```kotlin
// AndroidManifest.xml
// <uses-permission android:name="android.permission.NFC" />
// <uses-feature android:name="android.hardware.nfc" android:required="true" />

// Intent filter for NDEF discovery
// <intent-filter>
//     <action android:name="android.nfc.action.NDEF_DISCOVERED" />
//     <category android:name="android.intent.category.DEFAULT" />
//     <data android:mimeType="text/plain" />
// </intent-filter>

class NfcRepository(private val context: Context) {

    private val nfcAdapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(context)

    fun isNfcSupported(): Boolean = nfcAdapter != null
    fun isNfcEnabled(): Boolean = nfcAdapter?.isEnabled == true
}
```

### Foreground Dispatch (NDEF Reading)

```kotlin
class NfcActivity : AppCompatActivity() {

    private var nfcAdapter: NfcAdapter? = null
    private lateinit var pendingIntent: PendingIntent

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_MUTABLE
        )
    }

    override fun onResume() {
        super.onResume()
        val techFilter = arrayOf(arrayOf(Ndef::class.java.name))
        nfcAdapter?.enableForegroundDispatch(this, pendingIntent, null, techFilter)
    }

    override fun onPause() {
        super.onPause()
        nfcAdapter?.disableForegroundDispatch(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == NfcAdapter.ACTION_NDEF_DISCOVERED ||
            intent.action == NfcAdapter.ACTION_TECH_DISCOVERED ||
            intent.action == NfcAdapter.ACTION_TAG_DISCOVERED
        ) {
            val tag = intent.getParcelableExtra<Tag>(NfcAdapter.EXTRA_TAG)
            val messages = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
            messages?.forEach { raw ->
                val ndefMessage = raw as NdefMessage
                ndefMessage.records.forEach { record ->
                    val payload = String(record.payload)
                    val type = String(record.type)
                    // Process NDEF record
                }
            }
        }
    }
}
```

### NDEF Writing

```kotlin
fun writeNdefTag(tag: Tag, text: String): Boolean {
    val ndef = Ndef.get(tag) ?: return false
    val record = NdefRecord.createTextRecord("en", text)
    val message = NdefMessage(arrayOf(record))

    return try {
        ndef.connect()
        if (!ndef.isWritable) return false
        if (ndef.maxSize < message.toByteArray().size) return false
        ndef.writeNdefMessage(message)
        true
    } catch (e: Exception) {
        false
    } finally {
        try { ndef.close() } catch (_: Exception) {}
    }
}

fun createUriRecord(uri: String): NdefRecord = NdefRecord.createUri(uri)
fun createMimeRecord(mimeType: String, data: ByteArray): NdefRecord =
    NdefRecord.createMime(mimeType, data)
```

### Host Card Emulation (HCE)

```kotlin
class MyHostApduService : HostApduService() {

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        // Process incoming APDU commands from NFC reader
        val selectAid = byteArrayOf(0x00, 0xA4.toByte(), 0x04, 0x00)
        return if (commandApdu.startsWith(selectAid)) {
            // Return response APDU
            byteArrayOf(0x90.toByte(), 0x00)
        } else {
            byteArrayOf(0x6F, 0x00)
        }
    }

    override fun onDeactivated(reason: Int) {
        // Handle deactivation
    }
}
```

### Key Android Patterns to Recognize

- `NfcAdapter.enableForegroundDispatch` — intercepts NFC tags while app is in foreground
- `ACTION_NDEF_DISCOVERED` / `ACTION_TECH_DISCOVERED` / `ACTION_TAG_DISCOVERED` — tag dispatch system priority
- `NdefMessage` / `NdefRecord` — NDEF data containers
- `Ndef.get(tag)` — obtains NDEF interface from a discovered tag
- `HostApduService` — card emulation service
- `NfcAdapter.enableReaderMode` — exclusive NFC reader mode

## iOS Best Practices (Target Patterns)

### NDEF Reading (iOS 11+)

```swift
import CoreNFC

// Info.plist required:
// NFCReaderUsageDescription — user-facing description
// com.apple.developer.nfc.readersession.iso7816.select-identifiers — for ISO 7816 tags
// com.apple.developer.nfc.readersession.felica.systemcodes — for FeliCa tags

// Entitlements required:
// com.apple.developer.nfc.readersession.formats — set to TAG or NDEF

final class NFCReaderManager: NSObject, ObservableObject {
    @Published var scannedMessage: String?
    @Published var isScanning = false

    private var ndefSession: NFCNDEFReaderSession?

    var isNFCAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    func beginScanning() {
        guard isNFCAvailable else { return }
        ndefSession = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: true
        )
        ndefSession?.alertMessage = "Hold your iPhone near the NFC tag."
        ndefSession?.begin()
        isScanning = true
    }
}

extension NFCReaderManager: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Called when invalidateAfterFirstRead is true
        for message in messages {
            for record in message.records {
                if let payloadString = String(data: record.payload, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.scannedMessage = payloadString
                    }
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false
        }
        if let nfcError = error as? NFCReaderError,
           nfcError.code != .readerSessionInvalidationErrorFirstNDEFTagRead,
           nfcError.code != .readerSessionInvalidationErrorUserCanceled {
            // Handle actual errors
        }
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        // Session is now active
    }
}
```

### NDEF Writing (iOS 13+)

```swift
final class NFCWriterManager: NSObject, ObservableObject {
    private var ndefSession: NFCNDEFReaderSession?
    private var messageToWrite: NFCNDEFMessage?

    func writeText(_ text: String) {
        guard NFCNDEFReaderSession.readingAvailable else { return }

        let payload = NFCNDEFPayload.wellKnownTypeTextPayload(
            string: text,
            locale: Locale.current
        )!
        messageToWrite = NFCNDEFMessage(records: [payload])

        // Use invalidateAfterFirstRead: false to get writable tag access
        ndefSession = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: false
        )
        ndefSession?.alertMessage = "Hold your iPhone near the NFC tag to write."
        ndefSession?.begin()
    }

    func writeURI(_ uri: URL) {
        let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: uri)!
        messageToWrite = NFCNDEFMessage(records: [payload])

        ndefSession = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: false
        )
        ndefSession?.alertMessage = "Hold your iPhone near the NFC tag to write."
        ndefSession?.begin()
    }
}

extension NFCWriterManager: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first, let message = messageToWrite else {
            session.invalidate(errorMessage: "No tag or message.")
            return
        }

        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }

            tag.queryNDEFStatus { status, capacity, error in
                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Tag is not NDEF compatible.")
                case .readOnly:
                    session.invalidate(errorMessage: "Tag is read-only.")
                case .readWrite:
                    let messageSize = message.length
                    if messageSize > capacity {
                        session.invalidate(errorMessage: "Tag capacity is too small.")
                        return
                    }
                    tag.writeNDEF(message) { error in
                        if let error = error {
                            session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                        } else {
                            session.alertMessage = "Write successful!"
                            session.invalidate()
                        }
                    }
                @unknown default:
                    session.invalidate(errorMessage: "Unknown tag status.")
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Not called when invalidateAfterFirstRead is false
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // Handle session end
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}
}
```

### Native Tag Access (ISO 7816, ISO 15693, FeliCa, MIFARE)

```swift
final class NativeTagReader: NSObject, ObservableObject {
    private var tagSession: NFCTagReaderSession?

    func beginNativeTagScan() {
        guard NFCTagReaderSession.readingAvailable else { return }
        tagSession = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693, .iso18092],
            delegate: self,
            queue: nil
        )
        tagSession?.alertMessage = "Hold your iPhone near the tag."
        tagSession?.begin()
    }
}

extension NativeTagReader: NFCTagReaderSessionDelegate {
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }

        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection failed.")
                return
            }

            switch tag {
            case .iso7816(let iso7816Tag):
                let apdu = NFCISO7816APDU(
                    instructionClass: 0x00,
                    instructionCode: 0xB0,
                    p1Parameter: 0x00,
                    p2Parameter: 0x00,
                    data: Data(),
                    expectedResponseLength: 256
                )
                iso7816Tag.sendCommand(apdu: apdu) { data, sw1, sw2, error in
                    // Process response
                }

            case .miFare(let mifareTag):
                let readCommand = Data([0x30, 0x04]) // READ page 4
                mifareTag.sendMiFareCommand(commandPacket: readCommand) { data, error in
                    // Process MIFARE response
                }

            case .iso15693(let iso15693Tag):
                iso15693Tag.readSingleBlock(requestFlags: .highDataRate, blockNumber: 0) { data, error in
                    // Process ISO 15693 response
                }

            case .feliCa(let felicaTag):
                // Process FeliCa tag
                break

            @unknown default:
                break
            }
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        // Handle session invalidation
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}
}
```

### Background Tag Reading (iOS 12+)

```swift
// Info.plist: Add Associated Domains or Universal Links for URL-based NDEF tags
// The system automatically reads NDEF tags containing URLs when the screen is on
// and presents a notification — no app code needed for this feature.

// To handle the launched URL in your app:
// In your App or SceneDelegate:
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else { return }
    // Handle the NFC-triggered URL
}

// SwiftUI equivalent:
struct ContentView: View {
    var body: some View {
        Text("NFC App")
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL {
                    // Handle NFC-triggered URL
                }
            }
    }
}
```

## Migration Mapping Table

| Android | iOS (Core NFC) | Notes |
|---|---|---|
| `NfcAdapter` | `NFCNDEFReaderSession` / `NFCTagReaderSession` | Session-based, not adapter-based |
| `enableForegroundDispatch` | `NFCNDEFReaderSession.begin()` | iOS requires user-initiated action |
| `NdefMessage` | `NFCNDEFMessage` | Direct equivalent |
| `NdefRecord` | `NFCNDEFPayload` | Direct equivalent |
| `NdefRecord.createTextRecord` | `NFCNDEFPayload.wellKnownTypeTextPayload` | Direct equivalent |
| `NdefRecord.createUri` | `NFCNDEFPayload.wellKnownTypeURIPayload` | Direct equivalent |
| `Ndef.writeNdefMessage` | `NFCNDEFTag.writeNDEF` | iOS 13+ only |
| `HostApduService` (HCE) | **Not available** | iOS does not support card emulation |
| `ACTION_NDEF_DISCOVERED` intent filter | Background tag reading (URL-based NDEF only) | Very limited on iOS |
| `ACTION_TECH_DISCOVERED` | `NFCTagReaderSession` with polling options | iOS 13+ |
| `NfcAdapter.enableReaderMode` | `NFCTagReaderSession` | Similar exclusive reader mode |
| `IsoDep` / `NfcA` / `NfcB` | `NFCISO7816Tag` / `NFCMiFareTag` | iOS 13+ |
| `NfcV` | `NFCISO15693Tag` | iOS 13+ |
| `NfcF` | `NFCFeliCaTag` | iOS 13+ |
| Tag dispatch system (3-level priority) | No equivalent — session-based scanning only | Different architecture |

## Platform Limitation Differences

### Features Android Has That iOS Does Not

| Feature | Android | iOS |
|---|---|---|
| Host Card Emulation (HCE) | Full support via `HostApduService` | Not available (Apple Pay only) |
| Peer-to-peer (Android Beam) | Deprecated but was available | Never available |
| Always-on tag dispatch | Yes, via intent filters | Background tag reading is URL-only |
| Card emulation (custom AID) | Full APDU-level HCE | Not available |
| NFC-A/B/F raw access | Full low-level access | Limited to ISO 7816/MIFARE/FeliCa wrappers |
| Automatic NDEF discovery without user action | Yes, via intent filters | Requires user to tap a scan button (foreground) |
| Format tags to NDEF | `NdefFormatable.format()` | Not available |

### iOS-Specific Constraints

- NFC scanning requires the app to be in the **foreground** and the user must initiate the scan
- Each `NFCReaderSession` presents a system UI sheet that cannot be customized
- Only one NFC session can be active at a time
- Sessions time out after ~60 seconds of inactivity
- Minimum device: iPhone 7 for reading, iPhone 7 for writing (iOS 13+)
- iPad does not support NFC at all

## Common Pitfalls

1. **Trying to implement HCE on iOS** — Apple reserves NFC card emulation exclusively for Apple Pay and Apple Wallet. If your Android app uses HCE for access cards, payment, or transit, you must use Apple Wallet passes or a completely different approach on iOS.

2. **Expecting automatic tag discovery** — Android can automatically dispatch NDEF tags to your app via intent filters. On iOS, the user must explicitly initiate an NFC scan session (except for URL-based background tag reading). Design your UX with a "Scan" button.

3. **Session lifecycle management** — iOS NFC sessions are single-use. After a session invalidates (success or error), you must create a new `NFCNDEFReaderSession` instance. Do not try to reuse or restart an invalidated session.

4. **Not checking `readingAvailable`** — Always check `NFCNDEFReaderSession.readingAvailable` before creating a session. iPads and older iPhones will return `false`.

5. **Background tag reading expectations** — iOS background tag reading only works with NDEF tags containing URL records. It does not work with arbitrary NDEF types, and you cannot process the tag data in the background — the system shows a notification that launches your app.

6. **Delegate method confusion for reading vs writing** — When `invalidateAfterFirstRead` is `true`, the system calls `didDetectNDEFs`. When `false` (needed for writing), the system calls `didDetect tags:` instead. Using the wrong configuration causes delegate methods to never fire.

7. **Missing entitlements** — NFC Tag reading requires the `com.apple.developer.nfc.readersession.formats` entitlement. Without it, `NFCTagReaderSession` will fail silently. Add this in your app's entitlements file and configure it in the Apple Developer portal.

## Migration Checklist

- [ ] Add `NFCReaderUsageDescription` to Info.plist
- [ ] Add NFC entitlements (`com.apple.developer.nfc.readersession.formats`)
- [ ] Configure AID identifiers in Info.plist if using ISO 7816 tag reading
- [ ] Check `NFCNDEFReaderSession.readingAvailable` before initiating scans
- [ ] Replace `NfcAdapter.enableForegroundDispatch` with `NFCNDEFReaderSession` for NDEF reading
- [ ] Replace `Ndef.writeNdefMessage` with `NFCNDEFTag.writeNDEF` (requires `invalidateAfterFirstRead: false`)
- [ ] Design UX with explicit "Scan NFC" button since iOS does not auto-dispatch tags
- [ ] Replace `NdefRecord` creation with `NFCNDEFPayload` factory methods
- [ ] Migrate native tag access to `NFCTagReaderSession` with appropriate polling options (iOS 13+)
- [ ] Remove or redesign any HCE functionality — it is not available on iOS
- [ ] Remove any peer-to-peer NFC code — it is not available on iOS
- [ ] Implement background tag reading via Universal Links if URL-based NDEF tags are used
- [ ] Handle session invalidation errors gracefully (user cancellation is not an error)
- [ ] Test on physical iPhone devices (NFC is not available in Simulator)
- [ ] Document feature gaps for stakeholders (HCE, tag formatting, automatic dispatch)
