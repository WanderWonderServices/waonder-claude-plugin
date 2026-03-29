---
name: mobile-android-emulator-manager
description: Use when an Android emulator is needed for local automation testing — checks, creates, and launches emulators, never uses real devices.
type: mobile
platform: android
---

# mobile-android-emulator-manager

## Context

This skill manages Android emulators for local automation testing. It checks if a suitable emulator AVD exists, creates one if needed, and launches it. It is designed to be invoked before running automation tests to ensure an emulator is available and running.

The real physical device is reserved for development and must **never** be used for automation.

## Instructions

When invoked, perform the following steps in order. Stop and report if any step fails with an unrecoverable error.

### SDK Paths

All Android SDK tools are accessed via `$ANDROID_HOME` (defaults to `~/Library/Android/sdk` on macOS):

```
ANDROID_HOME=/Users/gabrielfernandez/Library/Android/sdk
EMULATOR=$ANDROID_HOME/emulator/emulator
AVDMANAGER=$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager
SDKMANAGER=$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager
ADB=$ANDROID_HOME/platform-tools/adb
```

## Steps

### 1. Check if an emulator is already running

```bash
adb devices | grep emulator
```

- If an `emulator-XXXX` device is listed and status is `device` → the emulator is already running. Report it and skip to Step 5.
- If no emulator is running → continue to Step 2.

### 2. List available AVDs

```bash
$ANDROID_HOME/emulator/emulator -list-avds
```

- If one or more AVDs exist → pick the best candidate (prefer API level >= 29, prefer Google Play images, prefer arm64 on Apple Silicon).
- If no AVDs exist → continue to Step 3 to create one.

### 3. Create an AVD (only if none exist)

**3a. Check installed system images:**

```bash
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --list_installed 2>&1 | grep "system-images"
```

**3b. If no suitable image is installed, download one:**

```bash
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "system-images;android-35;google_apis_playstore;arm64-v8a"
```

Use the highest available API level with Google Play for arm64-v8a (Apple Silicon Mac).

**3c. Create the AVD:**

```bash
echo "no" | $ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd \
  --name "Waonder_Test_API35" \
  --package "system-images;android-35;google_apis_playstore;arm64-v8a" \
  --device "pixel_6"
```

Naming convention: `Waonder_Test_API{level}` (e.g., `Waonder_Test_API35`).

**3d. Verify creation:**

```bash
$ANDROID_HOME/emulator/emulator -list-avds
```

### 4. Launch the emulator

```bash
$ANDROID_HOME/emulator/emulator -avd <AVD_NAME> -no-snapshot-load -no-audio -no-boot-anim &
```

Flags explained:
- `-no-snapshot-load` — cold boot for clean state
- `-no-audio` — no audio (headless-friendly)
- `-no-boot-anim` — skip boot animation (faster startup)

**4a. Wait for the emulator to fully boot:**

```bash
adb wait-for-device
adb shell getprop sys.boot_completed
```

Poll `sys.boot_completed` until it returns `1` (check every 3 seconds, timeout after 120 seconds).

**4b. Verify emulator is ready:**

```bash
adb devices
```

Confirm `emulator-XXXX device` is listed.

### 5. Verify the Waonder app is installed

```bash
adb -s emulator-5554 shell pm list packages | grep com.app.waonder
```

- If installed → report ready.
- If not installed → inform the user to run `./gradlew installDebug` or offer to run it.

### 6. Report status

Output a summary:

```
## Emulator Status

- **AVD**: <name>
- **Device**: emulator-XXXX
- **API Level**: <level>
- **Status**: Running / Booting / Created & Launched
- **App installed**: Yes / No
- **Ready for testing**: Yes / No
```

## Constraints

- **NEVER use a real/physical device** — only emulators. If `adb devices` shows a physical device alongside the emulator, always target the emulator explicitly with `-s emulator-XXXX`.
- **NEVER delete existing AVDs** — only create new ones if none exist or none are suitable.
- **NEVER modify Android SDK installation or global settings** beyond downloading a system image and creating an AVD.
- **NEVER launch multiple emulators simultaneously** — one is sufficient for testing.
- **ALWAYS use cold boot** (`-no-snapshot-load`) to ensure clean state for testing.
- **ALWAYS wait for full boot** before reporting ready — poll `sys.boot_completed`.
- **ALWAYS prefer Google Play system images** (needed for apps that depend on Play Services).
- **ALWAYS prefer arm64-v8a images** on Apple Silicon Macs for native performance.
- **ALWAYS use API level >= 29** (the app's minSdk) when creating AVDs.
- If the emulator fails to start, report the error clearly — do not retry in a loop.
