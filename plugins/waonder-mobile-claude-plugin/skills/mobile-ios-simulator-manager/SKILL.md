---
name: mobile-ios-simulator-manager
description: Use when an iOS Simulator is needed for local automation testing — checks, creates, and boots simulators, never uses real devices.
type: mobile
platform: ios
---

# mobile-ios-simulator-manager

## Context

This skill manages iOS Simulators for local automation testing. It checks if a suitable simulator is booted, creates one if needed, and boots it. It is designed to be invoked before running XCUITest automation tests to ensure a simulator is available and running.

The real physical device is reserved for development and must **never** be used for automation.

## Instructions

When invoked, perform the following steps in order. Stop and report if any step fails with an unrecoverable error.

## Steps

### 1. Check if a simulator is already booted

```bash
xcrun simctl list devices booted
```

- If a simulator is listed as `Booted` → report it and skip to Step 5.
- If no simulator is booted → continue to Step 2.

### 2. List available simulators

```bash
xcrun simctl list devices available
```

- If suitable simulators exist (iPhone 16, iPhone 15 Pro, etc.) → pick the best candidate (prefer iPhone 16, prefer latest iOS runtime).
- If no suitable simulators exist → continue to Step 3 to create one.

### 3. Create a simulator (only if none are suitable)

**3a. List available runtimes:**

```bash
xcrun simctl list runtimes
```

Pick the latest iOS runtime available (e.g., `com.apple.CoreSimulator.SimRuntime.iOS-18-2`).

**3b. List available device types:**

```bash
xcrun simctl list devicetypes | grep iPhone
```

Prefer `iPhone 16` device type.

**3c. Create the simulator:**

```bash
xcrun simctl create "Waonder_Test_iPhone16" \
  "com.apple.CoreSimulator.SimDeviceType.iPhone-16" \
  "com.apple.CoreSimulator.SimRuntime.iOS-18-2"
```

Naming convention: `Waonder_Test_iPhone16` (or similar descriptive name).

**3d. Verify creation:**

```bash
xcrun simctl list devices | grep "Waonder_Test"
```

### 4. Boot the simulator

```bash
xcrun simctl boot "<SIMULATOR_NAME_OR_UDID>"
```

**4a. Wait for the simulator to fully boot:**

```bash
xcrun simctl bootstatus "<SIMULATOR_UDID>" -b
```

This blocks until the simulator reports ready. Timeout after 120 seconds.

**4b. Optionally open Simulator.app for visual feedback:**

```bash
open -a Simulator
```

**4c. Verify simulator is booted:**

```bash
xcrun simctl list devices booted
```

Confirm the simulator is listed as `Booted`.

### 5. Verify the Waonder app can be built for this simulator

```bash
cd ~/Documents/WaonderApps/waonder-ios
xcodebuild -scheme Waonder -destination "platform=iOS Simulator,name=$(xcrun simctl list devices booted -j | python3 -c "import sys,json; devs=[d for r in json.load(sys.stdin)['devices'].values() for d in r if d['state']=='Booted']; print(devs[0]['name'] if devs else 'iPhone 16')")" -showBuildSettings 2>&1 | head -5
```

- If the scheme resolves → report ready.
- If it fails → report the error (likely missing scheme or workspace issue).

### 6. Report status

Output a summary:

```
## Simulator Status

- **Name**: <name>
- **UDID**: <udid>
- **Runtime**: iOS <version>
- **Device Type**: <type>
- **Status**: Booted / Created & Booted
- **Ready for testing**: Yes / No
```

## Constraints

- **NEVER use a real/physical device** — only simulators. If `xcodebuild -destination` could match a physical device, always specify `platform=iOS Simulator` explicitly.
- **NEVER delete existing simulators** — only create new ones if none exist or none are suitable.
- **NEVER modify Xcode installation or global settings** beyond creating a simulator.
- **NEVER boot multiple simulators simultaneously** — one is sufficient for testing.
- **ALWAYS wait for full boot** before reporting ready — use `xcrun simctl bootstatus`.
- **ALWAYS prefer iPhone 16** device type when creating new simulators.
- **ALWAYS prefer the latest iOS runtime** available on the system.
- **ALWAYS use `platform=iOS Simulator`** in xcodebuild destinations — never omit the platform qualifier.
- If the simulator fails to boot, report the error clearly — do not retry in a loop.
