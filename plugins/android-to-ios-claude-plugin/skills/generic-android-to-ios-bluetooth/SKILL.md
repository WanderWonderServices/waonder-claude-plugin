---
name: generic-android-to-ios-bluetooth
description: Use when migrating Android Bluetooth/BLE patterns (BluetoothAdapter, BluetoothLeScanner, BluetoothGatt, central/peripheral roles) to iOS Core Bluetooth equivalents (CBCentralManager, CBPeripheralManager, CBPeripheral, CBUUID, delegate-based API) with scanning, GATT operations, permissions, background BLE, and state restoration
type: generic
---

# generic-android-to-ios-bluetooth

## Context

Android's `android.bluetooth` package provides a comprehensive Bluetooth API with both Classic Bluetooth and BLE support, using a mix of synchronous calls and callbacks. iOS's Core Bluetooth framework is exclusively BLE-focused and uses a delegate-based pattern throughout. The fundamental architectural difference is that Android uses a request-callback model on `BluetoothGatt`, while iOS requires implementing `CBCentralManagerDelegate` and `CBPeripheralDelegate` protocols. This skill maps Android BLE patterns to their idiomatic iOS equivalents, covering scanning, connecting, GATT operations, permissions, background execution, and state restoration.

## Android Best Practices (Source Patterns)

### Bluetooth Permissions and Adapter Setup

```kotlin
// AndroidManifest.xml permissions
// <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
// <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
// <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" /> <!-- peripheral role -->
// <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" /> <!-- required pre-API 31 -->
// <uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />

class BluetoothRepository(private val context: Context) {

    private val bluetoothManager = context.getSystemService(BluetoothManager::class.java)
    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager?.adapter

    fun isBluetoothSupported(): Boolean = bluetoothAdapter != null
    fun isBluetoothEnabled(): Boolean = bluetoothAdapter?.isEnabled == true
}
```

### BLE Scanning (Central Role)

```kotlin
class BleScanner(private val context: Context) {

    private val bluetoothAdapter = context.getSystemService(BluetoothManager::class.java)?.adapter
    private val scanner: BluetoothLeScanner? = bluetoothAdapter?.bluetoothLeScanner

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device
            val rssi = result.rssi
            val serviceUuids = result.scanRecord?.serviceUuids
            // Process discovered device
        }

        override fun onScanFailed(errorCode: Int) {
            // Handle scan failure
        }
    }

    fun startScan(serviceUuid: UUID) {
        val filter = ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(serviceUuid))
            .build()
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setReportDelay(0)
            .build()
        scanner?.startScan(listOf(filter), settings, scanCallback)
    }

    fun stopScan() {
        scanner?.stopScan(scanCallback)
    }
}
```

### GATT Connection and Operations

```kotlin
class GattManager(private val context: Context) {

    private var bluetoothGatt: BluetoothGatt? = null

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> gatt.discoverServices()
                BluetoothProfile.STATE_DISCONNECTED -> cleanup()
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val service = gatt.getService(SERVICE_UUID)
                val characteristic = service?.getCharacteristic(CHARACTERISTIC_UUID)
                // Read, write, or enable notifications
            }
        }

        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
            status: Int
        ) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                // Process read value
            }
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            // Handle write confirmation
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            // Handle notification/indication data
        }
    }

    fun connect(device: BluetoothDevice) {
        bluetoothGatt = device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
    }

    fun readCharacteristic(characteristic: BluetoothGattCharacteristic) {
        bluetoothGatt?.readCharacteristic(characteristic)
    }

    fun writeCharacteristic(characteristic: BluetoothGattCharacteristic, value: ByteArray) {
        bluetoothGatt?.writeCharacteristic(
            characteristic,
            value,
            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        )
    }

    fun enableNotifications(characteristic: BluetoothGattCharacteristic) {
        bluetoothGatt?.setCharacteristicNotification(characteristic, true)
        val descriptor = characteristic.getDescriptor(CCCD_UUID)
        bluetoothGatt?.writeDescriptor(descriptor, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
    }

    fun disconnect() {
        bluetoothGatt?.disconnect()
        bluetoothGatt?.close()
        bluetoothGatt = null
    }
}
```

### BLE Peripheral Role (Advertising)

```kotlin
class BleAdvertiser(private val context: Context) {

    private val bluetoothAdapter = context.getSystemService(BluetoothManager::class.java)?.adapter
    private val advertiser: BluetoothLeAdvertiser? = bluetoothAdapter?.bluetoothLeAdvertiser
    private var gattServer: BluetoothGattServer? = null

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) { /* Advertising started */ }
        override fun onStartFailure(errorCode: Int) { /* Handle failure */ }
    }

    fun startAdvertising(serviceUuid: UUID) {
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setConnectable(true)
            .build()
        val data = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(serviceUuid))
            .setIncludeDeviceName(true)
            .build()
        advertiser?.startAdvertising(settings, data, advertiseCallback)
    }
}
```

### Key Android Patterns to Recognize

- `BluetoothLeScanner.startScan` — begins BLE scan with filters and settings
- `BluetoothGattCallback` — single callback interface for all GATT events
- `BluetoothGatt.discoverServices()` — must be called after connection before any GATT operations
- `setCharacteristicNotification` + CCCD descriptor write — enables notifications
- `BluetoothDevice.TRANSPORT_LE` — forces BLE transport on dual-mode devices
- `ScanSettings.SCAN_MODE_*` — controls scan power/frequency tradeoff

## iOS Best Practices (Target Patterns)

### Central Manager Setup and Permissions

```swift
import CoreBluetooth

// Info.plist required keys:
// NSBluetoothAlwaysUsageDescription — required for all BLE usage
// NSBluetoothPeripheralUsageDescription — iOS 12 and earlier
// UIBackgroundModes: bluetooth-central — for background scanning/connections
// UIBackgroundModes: bluetooth-peripheral — for background advertising

final class BluetoothManager: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    @Published var isBluetoothReady = false
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            isBluetoothReady = true
        case .poweredOff:
            isBluetoothReady = false
        case .unauthorized:
            // Handle permission denied
            break
        case .unsupported:
            // BLE not available on this device
            break
        default:
            break
        }
    }
}
```

### BLE Scanning

```swift
extension BluetoothManager {
    static let serviceUUID = CBUUID(string: "YOUR-SERVICE-UUID")
    static let characteristicUUID = CBUUID(string: "YOUR-CHARACTERISTIC-UUID")

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        centralManager.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() {
        centralManager.stopScan()
    }
}

extension BluetoothManager {
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
        }
    }
}
```

### GATT Connection and Operations

```swift
extension BluetoothManager {
    func connect(to peripheral: CBPeripheral) {
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect(from peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
        // Optionally reconnect
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Handle connection failure
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([Self.characteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == Self.characteristicUUID {
                // Read
                peripheral.readValue(for: characteristic)
                // Subscribe to notifications
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        // Process received data — covers both reads and notifications
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // Write confirmation
    }
}
```

### Writing Characteristics

```swift
extension BluetoothManager {
    func write(data: Data, to characteristic: CBCharacteristic, on peripheral: CBPeripheral) {
        let writeType: CBCharacteristicWriteType =
            characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(data, for: characteristic, type: writeType)
    }
}
```

### Peripheral Role (Advertising)

```swift
final class PeripheralManager: NSObject, ObservableObject {
    private var peripheralManager: CBPeripheralManager!

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func startAdvertising() {
        let service = CBMutableService(type: BluetoothManager.serviceUUID, primary: true)
        let characteristic = CBMutableCharacteristic(
            type: BluetoothManager.characteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        service.characteristics = [characteristic]
        peripheralManager.add(service)

        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [BluetoothManager.serviceUUID],
            CBAdvertisementDataLocalNameKey: "MyDevice"
        ])
    }
}

extension PeripheralManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            startAdvertising()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        request.value = Data([0x01, 0x02])
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let data = request.value {
                // Process written data
            }
        }
        peripheral.respond(to: requests.first!, withResult: .success)
    }
}
```

### Background BLE and State Restoration

```swift
// Initialize with restoration identifier for background support
centralManager = CBCentralManager(
    delegate: self,
    queue: nil,
    options: [CBCentralManagerOptionRestoreStateIdentifierKey: "com.myapp.central"]
)

// Implement restoration delegate method
func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
    if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
        for peripheral in peripherals {
            peripheral.delegate = self
            connectedPeripheral = peripheral
        }
    }
}
```

## Migration Mapping Table

| Android | iOS (Core Bluetooth) |
|---|---|
| `BluetoothAdapter` | `CBCentralManager` |
| `BluetoothLeScanner` | `CBCentralManager.scanForPeripherals(withServices:options:)` |
| `ScanCallback` | `CBCentralManagerDelegate.centralManager(_:didDiscover:advertisementData:rssi:)` |
| `ScanFilter` (service UUID) | `withServices:` parameter on `scanForPeripherals` |
| `ScanSettings.SCAN_MODE_*` | No direct equivalent; iOS manages scan power internally |
| `BluetoothDevice` | `CBPeripheral` |
| `BluetoothGatt` | `CBPeripheral` (GATT operations are methods on `CBPeripheral`) |
| `BluetoothGattCallback` | `CBPeripheralDelegate` |
| `connectGatt()` | `CBCentralManager.connect(_:options:)` |
| `discoverServices()` | `CBPeripheral.discoverServices(_:)` |
| `getService()` / `getCharacteristic()` | `CBPeripheral.discoverCharacteristics(_:for:)` via delegate |
| `readCharacteristic()` | `CBPeripheral.readValue(for:)` |
| `writeCharacteristic()` | `CBPeripheral.writeValue(_:for:type:)` |
| `setCharacteristicNotification()` + CCCD | `CBPeripheral.setNotifyValue(true, for:)` (handles CCCD automatically) |
| `onCharacteristicChanged` | `peripheral(_:didUpdateValueFor:error:)` |
| `BluetoothGattServer` | `CBPeripheralManager` |
| `BluetoothLeAdvertiser` | `CBPeripheralManager.startAdvertising(_:)` |
| `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` permissions | `NSBluetoothAlwaysUsageDescription` in Info.plist |
| `ACCESS_FINE_LOCATION` (for BLE scan) | Not required on iOS for BLE scanning |

## Common Pitfalls

1. **Not retaining peripheral references** — iOS will garbage-collect `CBPeripheral` objects if you do not maintain a strong reference to them. After discovery, store the peripheral in a property before calling `connect`.

2. **Forgetting service/characteristic discovery** — On iOS, you cannot access characteristics directly after connecting. You must call `discoverServices`, wait for the delegate callback, then call `discoverCharacteristics`, and wait again. Android has the same requirement but developers sometimes try to skip it on iOS.

3. **CCCD descriptor management** — On Android you must manually write the CCCD descriptor to enable notifications. On iOS, `setNotifyValue(true, for:)` handles this automatically. Do not try to write the CCCD descriptor manually on iOS.

4. **Scan filter differences** — Android allows filtering by manufacturer data, service data, device name, etc. iOS only allows filtering by service UUIDs in the `scanForPeripherals(withServices:)` call. Additional filtering must be done in the delegate callback.

5. **Background scanning limitations** — On iOS, background BLE scanning only works if you specify service UUIDs (no wildcard scans). You must also add `bluetooth-central` to `UIBackgroundModes` in Info.plist. The scan rate is significantly reduced in background.

6. **No scan mode control** — Android offers `SCAN_MODE_LOW_LATENCY`, `SCAN_MODE_LOW_POWER`, etc. iOS manages scan power automatically and does not expose this control. Do not try to replicate scan mode settings.

7. **Classic Bluetooth not available** — Core Bluetooth is BLE-only. If the Android app uses Classic Bluetooth (SPP, RFCOMM), you must use `ExternalAccessory` framework with MFi certification or redesign around BLE.

8. **MTU negotiation** — On Android you explicitly call `requestMtu()`. On iOS the MTU is negotiated automatically during connection. Use `peripheral.maximumWriteValueLength(for:)` to determine the available payload size.

9. **State restoration pitfalls** — When using state restoration for background BLE, you must re-set the `delegate` on restored peripherals in `willRestoreState`. The system recreates peripherals without delegates.

## Migration Checklist

- [ ] Add `NSBluetoothAlwaysUsageDescription` to Info.plist with a user-facing description
- [ ] Add `bluetooth-central` and/or `bluetooth-peripheral` to `UIBackgroundModes` if background BLE is needed
- [ ] Replace `BluetoothAdapter` / `BluetoothManager` with `CBCentralManager`
- [ ] Implement `CBCentralManagerDelegate` and handle `centralManagerDidUpdateState` for all states
- [ ] Replace `BluetoothLeScanner` + `ScanCallback` with `scanForPeripherals(withServices:options:)` + delegate methods
- [ ] Store strong references to discovered `CBPeripheral` objects
- [ ] Replace `BluetoothGattCallback` with `CBPeripheralDelegate`
- [ ] Convert `connectGatt()` to `CBCentralManager.connect(_:options:)`
- [ ] Implement the full discovery chain: `discoverServices` -> `didDiscoverServices` -> `discoverCharacteristics` -> `didDiscoverCharacteristics`
- [ ] Replace manual CCCD descriptor writes with `setNotifyValue(true, for:)`
- [ ] Convert `readCharacteristic` / `writeCharacteristic` to `readValue(for:)` / `writeValue(_:for:type:)`
- [ ] Replace `BluetoothLeAdvertiser` with `CBPeripheralManager` if using peripheral role
- [ ] Add state restoration if background connectivity is required
- [ ] Remove Classic Bluetooth code and redesign for BLE-only or ExternalAccessory framework
- [ ] Handle MTU differences — use `maximumWriteValueLength(for:)` instead of `requestMtu()`
- [ ] Test on real devices (BLE does not work in iOS Simulator)
