# EndoSync — Claude Context

## Project
Research prototype wearable therapeutic system for endometriosis-related pelvic pain.
Two-component system: Arduino Nano ESP32 firmware (BLE GATT server) + Flutter iOS app.

## Firmware
- **Source:** `lib/arduino/endosync_hardware_v3/endosync_hardware_v3.ino`
- **Toolchain:** Arduino IDE (not PlatformIO)
- **Board:** Arduino Nano ESP32 (ABX00083)
- **Serial monitor:** Arduino IDE Serial Monitor, 115200 baud
- **Flash:** Arduino IDE Upload button
- **No CI** — build and flash manually
- **Switch behaviour:** BLE advertising only starts when the physical switch on pin D6 is pulled LOW (switch ON). The device is not discoverable until the switch is turned on.

## Flutter App
- iOS only (iPhone, BLE required)
- State management: Provider
- BLE: `flutter_blue_plus ^1.31.0`
- Debug flag `kDebugSkipBle` in `lib/bluetooth/ble_constants.dart` bypasses BLE for UI testing

## BLE Interface
- Device advertises as `EndoSync`
- Service UUID: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- RX (App → Device, write): `6c88fae1-9bfb-4a9e-8f30-1d5a7c8b9f0c`
- TX (Device → App, notify): `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- Commands: `HEAT_ON`, `HEAT_OFF`, `VIBRATE_ON`, `VIBRATE_OFF`, `BOTH_ON`, `ALL_OFF`, `READ_TEMP`
- Safety notifications prefixed `SAFETY:` (e.g. `SAFETY:TEMP_HIGH`)

## Safety Constraints (never relax without deliberate review)
- Max temperature: 42 °C — enforced in firmware every 500 ms via MCP9808
- BLE activity timeout: 11 minutes — firmware cuts all outputs if no command received
- Session duration: 10 minutes — enforced by app timer
- Max sessions per use: 2 — enforced by BleManager
- Cooldown after limit: 30 minutes

## Operating the Device — Step by Step

### 1. Flash the firmware (first time or after code changes)
1. Open **Arduino IDE** and install board support for **Arduino Nano ESP32** if not already installed.
2. Open `lib/arduino/endosync_hardware_v3/endosync_hardware_v3.ino`.
3. Connect the Arduino Nano ESP32 to your Mac via USB-C.
4. Select the correct board and port, then click the **Upload** button (→).
5. Open the **Serial Monitor** (115200 baud). You should see:
   ```
   Endosync booting...
   MCP9808 ready.
   DRV2605L ready.
   BLE ready. Waiting for switch...
   ```
   If a sensor line is missing, check its I2C wiring or power rail.
6. Flip the D6 switch ON. You should then see:
   ```
   Device ON — BLE advertising.
   ```

### 2. Verify hardware before a session
| Check | Expected |
|---|---|
| Power LED on Nano ESP32 | On |
| Serial monitor output | All three "ready" lines present |
| MOSFET gate (D5 / GPIO8) | LOW at startup (heater off) |
| I2C bus (SDA/SCL) | Both sensors respond (address 0x18 for MCP9808, 0x5A for DRV2605L) |

### 3. Run a session via the app
1. Power the device (USB or battery).
2. Launch the **EndoSync** iOS app and tap **Scan for Device**.
3. **Flip the D6 switch ON** — the LED on D9 turns on and the device starts BLE advertising.
4. Once connected, the home screen shows the device as connected.
5. **Rate pain** (1–10 slider) → tap Continue.
6. **Select exercise mode**: Guided Breathing, Guided Physical Exercise, Both, or No Exercise → tap Start Session.
7. The app sends `BOTH_ON`; the heater and vibration motor activate. A 10-minute countdown begins.
8. Follow in-app exercise guidance. The app pings `READ_TEMP` every 25 seconds to keep BLE alive.
9. Session ends automatically at 10 minutes (or tap **End Session Early**). App sends `ALL_OFF`.
10. **Re-rate pain**. If pain decreased → session marked successful. If not → option to repeat (up to 2 sessions total).
11. After 2 sessions a **30-minute cooldown** is enforced before another session can begin.

### 4. Manual BLE testing (without the app)
Use a BLE scanner app (e.g. nRF Connect) to connect and write commands directly to the RX characteristic:
- Write `HEAT_ON` → heater activates; device notifies `HEAT_ON`
- Write `READ_TEMP` → device notifies `TEMP:xx.x`
- Write `ALL_OFF` → all outputs stop

### 5. Safety events
| Event | Cause | What happens |
|---|---|---|
| `SAFETY:TEMP_HIGH` | Sensor reads ≥ 42 °C | Firmware cuts all outputs immediately; app shows non-dismissible alert |
| `SAFETY:BLE_TIMEOUT` | No command for 11 min while outputs active | Firmware cuts all outputs |
| `SAFETY:BLE_LOST` | BLE central disconnected unexpectedly | Firmware cuts all outputs; resumes advertising |

After any safety event, all outputs are off. Reconnect and restart a session from the app.

### 6. Shutdown
- Send `ALL_OFF` from the app or serial monitor before cutting power.
- Disconnect USB / remove battery only after confirming heater is cold and motor is silent.

---

## Key Files
| File | Purpose |
|---|---|
| `lib/bluetooth/ble_constants.dart` | UUIDs, device name, `kDebugSkipBle` flag |
| `lib/bluetooth/ble_manager.dart` | BLE state, scan, connect, send, safety alerts |
| `lib/arduino/endosync_hardware_v3/endosync_hardware_v3.ino` | Firmware source (source of truth) |
