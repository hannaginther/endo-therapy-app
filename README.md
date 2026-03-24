# EndoSync

A prototype wearable therapeutic system for pelvic pain relief associated with endometriosis. EndoSync pairs a Bluetooth Low Energy (BLE) wearable device — delivering heat and vibration therapy — with a Flutter mobile app that guides the user through pain assessment, exercise selection, and session management.

> **Status: Research prototype.** This project is under active development. Hardware and software interfaces may change between versions.

---

## System Overview

EndoSync has two components that work together over BLE:

**Wearable device (Arduino Nano ESP32)**
- Resistive heater controlled via MOSFET
- Vibration motor driven by an Adafruit DRV2605L haptic driver
- MCP9808 I2C temperature sensor for thermal safety monitoring
- BLE GATT server that receives commands from the app and sends back telemetry and safety alerts

**Flutter mobile app**
- Connects to the device automatically on launch
- Walks the user through pain rating → exercise selection → session
- Manages a 10-minute session countdown with in-app exercise guidance
- Monitors for safety alerts from the device and enforces session limits

---

## Hardware Components

| Component | Part | Notes |
|---|---|---|
| Microcontroller | Arduino Nano ESP32 (ABX00083) | Built-in BLE |
| Temperature sensor | MCP9808 (I2C, 0x18) | Safety monitoring, polled every 500 ms |
| Heater switch | MOSFET on GPIO D5 | Controls resistive heater |
| Haptic driver | Adafruit DRV2605L (I2C) | Internal-trigger mode, waveform library 1 |
| Vibration motor | Connected to DRV2605L | Waveform 14 (continuous buzz) |

---

## App — Getting Started

### Prerequisites

- Flutter SDK `>=3.0.0 <4.0.0`
- Dart SDK `>=3.0.0`
- Xcode 14+ (required for iOS deployment)
- An iPhone with BLE support (iOS 12+)

### Install dependencies

```bash
flutter pub get
```

### Run the app

Open the project in Xcode (`ios/Runner.xcworkspace`) and run on a connected iPhone, or use the Flutter CLI:

```bash
flutter run -d <your-device-id>
```

Use `flutter devices` to find your iPhone's device ID.

### Build for production

```bash
flutter build ios
```

### Code quality

```bash
flutter analyze          # Static analysis
flutter test             # Unit and widget tests
```

---

## Firmware — Getting Started

The firmware is in `lib/arduino/endosync_hardwarev2/endosync_hardwarev2.ino`.

### Prerequisites

- Arduino IDE 2.x
- Arduino Nano ESP32 board support package
- Libraries (install via Arduino Library Manager):
  - `ArduinoBLE`
  - `Adafruit MCP9808`
  - `Adafruit DRV2605 Library`
  - `Adafruit BusIO` (dependency of the above)

### Flash the firmware

1. Open `lib/arduino/endosync_hardwarev2/endosync_hardwarev2.ino` in the Arduino IDE.
2. Select board: **Arduino Nano ESP32**.
3. Upload to the device.
4. Open Serial Monitor at 115200 baud to verify startup output.

The device will advertise as `EndoSync` over BLE once setup completes.

---

## BLE Interface

The device exposes a single custom GATT service:

| Name | UUID |
|---|---|
| Service | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| TX Characteristic (notify, Device → App) | `beb5483e-36e1-4688-b7f5-ea07361b26a8` |
| RX Characteristic (write, App → Device) | `6c88fae1-9bfb-4a9e-8f30-1d5a7c8b9f0c` |

### Commands (App → Device)

| Command | Effect |
|---|---|
| `HEAT_ON` | Activates heater (MOSFET HIGH) |
| `HEAT_OFF` | Deactivates heater |
| `VIBRATE_ON` | Starts haptic motor (continuous buzz) |
| `VIBRATE_OFF` | Stops haptic motor |
| `BOTH_ON` | Activates heat and vibration simultaneously |
| `ALL_OFF` | Stops all outputs immediately |
| `READ_TEMP` | Requests current temperature from MCP9808 |

### Responses (Device → App)

Command echo strings (`HEAT_ON`, `BOTH_ON`, etc.) confirm execution. Temperature is returned as `TEMP:{value}` (e.g. `TEMP:39.5`). Safety events are prefixed with `SAFETY:` and trigger an in-app alert:

| Safety Event | Cause |
|---|---|
| `SAFETY:TEMP_HIGH` | Device temperature ≥ 42 °C |
| `SAFETY:BLE_TIMEOUT` | No command received for 11 minutes while outputs active |
| `SAFETY:BLE_LOST` | BLE central disconnected unexpectedly |

---

## Session Flow

1. App auto-scans for the device on launch (up to 3 attempts).
2. User rates pain on a scale of 1–10.
3. User selects an exercise mode: Guided Breathing, Guided Physical Exercise, Both, or No Exercise.
4. App sends `BOTH_ON` and starts a 10-minute countdown.
5. In-app exercise guidance is displayed throughout the session. A `READ_TEMP` ping is sent every 25 seconds to keep the BLE connection alive.
6. Session ends automatically at 10 minutes (or earlier if the user taps "End Session Early"). App sends `ALL_OFF`.
7. User re-rates pain. If pain decreased, the session is marked successful. If not, a repeat session is offered.
8. After 2 sessions, a mandatory 30-minute cooldown is enforced before another session can begin.

---

## Safety

| Constraint | Value | Enforced by |
|---|---|---|
| Max temperature | 42 °C | Firmware (MCP9808, every 500 ms) |
| BLE activity timeout | 11 minutes | Firmware |
| Session duration | 10 minutes | App (countdown timer) |
| Max sessions per use | 2 | App (BleManager) |
| Cooldown after limit | 30 minutes | App (BleManager) |

If the device temperature exceeds 42 °C, the firmware immediately cuts all outputs and sends a `SAFETY:TEMP_HIGH` notification. The app displays a non-dismissible alert and returns to the home screen. A failsafe `ALL_OFF` command is sent if the session screen is closed before the session ends normally.

---

## Project Structure

```
flutter_endosync_2/
  lib/
    main.dart                        # App entry point, Provider setup
    bluetooth/
      ble_constants.dart             # UUIDs, device name, session limits, commands
      ble_manager.dart               # BLE state, scan, connect, send, safety alerts
    screens/
      home_screen.dart               # Entry, connection status, cooldown display
      pain_input_screen.dart         # Pain slider (1–10)
      exercise_selection_screen.dart # Exercise mode selection
      session_screen.dart            # Active session, timer, BLE commands, guidance
      end_screen.dart                # Post-session re-rank, repeat / done logic
    arduino/
      endosync_hardwarev2/           # Current firmware
      endosync_hardwarev1/           # Previous firmware (reference only)
      endo_*/                        # Individual component test sketches (reference only)
  pubspec.yaml                       # Flutter dependencies
  Software_Architecture.docx         # Full software architecture document
```

---

## Key Dependencies

| Package | Version | Purpose |
|---|---|---|
| `flutter_blue_plus` | ^1.31.0 | BLE scan, connect, read/write |
| `provider` | ^6.1.0 | State management |
| `permission_handler` | ^11.0.0 | Included as a dependency; BLE permissions on iOS are handled via `Info.plist` (`NSBluetoothAlwaysUsageDescription`) and prompted by the system automatically |

---

## Debug Mode

A `kDebugSkipBle` flag in `lib/bluetooth/ble_constants.dart` can be set to `true` to enable UI-flow testing without a physical device. When active, a "Skip BLE" button appears on the home screen that bypasses the connection requirement.

---

## Future Work

- Adaptive intensity control (graduated heat/vibration levels responding to pain re-ranking)
- Session data logging and longitudinal tracking
- Cloud backend for data storage and optional healthcare provider access
- Battery monitoring via BLE
- Richer animated exercise guidance sequences
