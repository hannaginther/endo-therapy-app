# EndoSync — Bug Fix Prompts

Three targeted prompts, one per issue. Use them in order — each is self-contained.

---

## Fix 1 — Firmware: Temperature Sensor Not Printing to Serial

**Root cause:** In the `READ_TEMP` command handler, the temperature value is sent via BLE notification (`txCharacteristic.writeValue(response)`) but never printed to `Serial`. The `Serial.print("Temp: ...")` line on the 500 ms safety-check loop only runs when a BLE central is actively connected. Without an app connected, `READ_TEMP` produces no Serial output.

```
Read the firmware file at:
  lib/arduino/endosync_hardware_v3/endosync_hardware_v3.ino

Make exactly two changes — nothing else:

1. In the READ_TEMP branch of handleCommand() (around line 167):
   After the line `txCharacteristic.writeValue(response);`
   add:  `Serial.println(response);`
   And in the else branch (TEMP:ERROR), add: `Serial.println("TEMP:ERROR");`

2. In the main loop(), in the section that runs when deviceActive is true
   but BEFORE the `BLEDevice central = BLE.central();` call,
   add a periodic temperature print that runs every 2000 ms when NOT
   connected (so the temperature is visible in Serial Monitor during
   standalone testing, without needing BLE).
   Use a static unsigned long variable (e.g. lastStandaloneTemp) to track timing.
   Only print if tempSensorOk is true.
   Format: Serial.print("Temp: "); Serial.println(temp, 1);

Do not change any BLE logic, safety logic, pin assignments, or UUIDs.
Do not change the 500 ms connected-loop temperature check — leave it as-is.
Show me the full modified sections (handleCommand READ_TEMP block and the
new standalone temp print block) before saving.
```

---

## Fix 2 — Flutter App: Cooldown Triggers After Short/Early-Ended Sessions

**Root cause:** `incrementSessionCount()` is called in `_endSession()` on every call, regardless of how long the session actually ran. A session ended after 2 minutes counts identically to a full 10-minute session.

**Intended behaviour:** A session should only count toward the use-cycle limit if it ran for a clinically meaningful duration (≥ 5 minutes / 300 seconds). Sessions ended very early — whether by the user or by a safety event — should not consume one of the two allowed slots.

```
Read these two files before making any changes:
  lib/bluetooth/ble_constants.dart
  lib/screens/session_screen.dart

Make the following changes:

STEP 1 — lib/bluetooth/ble_constants.dart
In the BleSessionLimits class, add one new constant after sessionDurationSeconds:
  static const int minSessionDurationForCount = 300; // 5 min minimum to count toward session limit

STEP 2 — lib/screens/session_screen.dart
In _endSession(), find this line:
  _ble.incrementSessionCount();

Wrap it in a condition so it only runs when the session lasted long enough:
  final actualDurationSeconds = BleSessionLimits.sessionDurationSeconds - _secondsRemaining;
  if (actualDurationSeconds >= BleSessionLimits.minSessionDurationForCount) {
    _ble.incrementSessionCount();
  }

Note: actualDurationSeconds is already computed a few lines later in the same
method for the EndScreen navigation. Move or reuse it — do not compute it twice.
Keep the cooldown logic exactly as-is: startCooldown() is already gated on
ble.sessionCount >= maxSessionsPerUse, so it will only trigger if count was
actually incremented.

STEP 3 — Verify the logic is correct:
- Session lasting 2 min (120 s) → 120 < 300 → NOT counted → sessionCount unchanged
- Session lasting 5 min exactly (300 s) → 300 >= 300 → counted
- Session lasting full 10 min → always counted
- Safety event ending at any time → same threshold applies (endedEarly=false but
  duration may be short — this is intentional; a safety cutoff at 1 min should not
  penalise the user)

Do not change BleManager, the cooldown timer, or any other session logic.
Show me the final _endSession() method in full before saving.
```

---

## Fix 3 — Standalone Arduino Hardware Test Sketch

**Context:** A second groupmate needs to run hardware tests (heater, vibration, temperature) without the EndoSync app. The existing firmware requires a BLE connection. A separate sketch is needed that works purely via Serial Monitor — no BLE stack, no app required.

```
Create a new Arduino sketch at:
  lib/arduino/endosync_hardware_test/endosync_hardware_test.ino

The sketch must:

HARDWARE
- Use the same pin assignments as the main firmware:
    HEAT_PIN = D5 (MOSFET gate — heater)
    LED_PIN  = D9
    SWITCH_PIN = D6 (not used for BLE gating here, but can be read)
- Use the same I2C sensors:
    MCP9808 at address 0x18 (temperature)
    DRV2605L haptic driver (vibration)
- Do NOT include ArduinoBLE or any BLE library

SERIAL INTERFACE (115200 baud)
On startup, print a clear menu:
  === EndoSync Hardware Test ===
  Commands (type and press Enter):
    HEAT_ON      — Turn heater on
    HEAT_OFF     — Turn heater off
    VIBRATE_ON   — Start vibration
    VIBRATE_OFF  — Stop vibration
    BOTH_ON      — Heater + vibration on
    ALL_OFF      — Everything off
    READ_TEMP    — Read MCP9808 once and print
    TEMP_STREAM  — Toggle continuous temp printing every 1 s (default: off)
    STATUS       — Print current state of all outputs
    HELP         — Reprint this menu

BEHAVIOUR
- Read Serial input line-by-line (use Serial.readStringUntil('\n'), trim whitespace)
- Respond to each command with a confirmation message, e.g.:
    "HEAT ON — D5 HIGH"
    "Temp: 39.4 C"
    "Status: heat=ON vibration=OFF temp_stream=ON"
- TEMP_STREAM toggles a boolean; when true, print temp every 1000 ms in loop()
  using a non-blocking millis() timer (never use delay() in loop)
- Safety: if MCP9808 reads >= 42.0 C at any time (in loop or on READ_TEMP),
  immediately set HEAT_PIN LOW, stop vibration, print "SAFETY CUTOFF: temp >= 42C",
  and set a safetyTriggered flag that blocks HEAT_ON and VIBRATE_ON until the
  device is power-cycled (or the user sends ALL_OFF to reset the flag for testing)
- If a sensor is not found at startup, print a warning and disable that feature
  (do not crash)
- DRV2605L re-trigger: same as main firmware — call hapticDriver.go() every 500 ms
  in loop() while vibrateActive is true (waveform 14, one-shot, needs periodic retriggering)

STARTUP SEQUENCE
Print:
  === EndoSync Hardware Test ===
  Checking hardware...
  MCP9808: [OK / NOT FOUND — temp features disabled]
  DRV2605L: [OK / NOT FOUND — vibration features disabled]
  All checks done. Ready for commands.
  [print the command menu]

Do not use delay() anywhere in loop(). Use millis() for all timing.
Do not include any BLE code.
The sketch should be self-contained — no external header files beyond the
Adafruit libraries already used in the main firmware.
```

---

## Notes on Running the Test Sketch

- Flash `endosync_hardware_test.ino` to the board using Arduino IDE exactly as you would the main firmware (same board: Arduino Nano ESP32 / ABX00083, same port).
- Open Serial Monitor at **115200 baud** with **line ending set to "Newline"** (the dropdown in the bottom right of Serial Monitor — this is important for `Serial.readStringUntil('\n')` to work).
- The switch on D6 is not used for gating in the test sketch — the device responds to commands immediately on power-up.
- To return to normal operation, simply flash `endosync_hardware_v3.ino` again.
- **Never leave the test sketch flashed when handing the device to a user** — it bypasses the BLE activity timeout safety.
