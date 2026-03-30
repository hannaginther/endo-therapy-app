# EndoSync — Timing Test Prompts

Four prompts covering all timing test recommendations. Run them in order — each builds on the last.

---

## Prompt 1 — Add `kDebugShortTimers` Flag (Compressed Manual Testing)

```
In the EndoSync Flutter app, add a debug flag that compresses all timer durations so
I can manually verify session and cooldown behaviour without waiting 10–30 minutes.

In `lib/bluetooth/ble_constants.dart`, inside the `BleSessionLimits` class:

1. Add this constant near the top of the class:
   static const bool kDebugShortTimers = true;
   // Set to false before any real-use testing or submission

2. Convert the three time constants from plain `static const int` values into
   static getters that return compressed values when kDebugShortTimers is true:

   static int get sessionDurationSeconds     => kDebugShortTimers ? 30  : 600;
   static int get cooldownDurationSeconds    => kDebugShortTimers ? 60  : 1800;
   static int get minSessionDurationForCount => kDebugShortTimers ? 5   : 300;

   Remove the old `static const int` declarations for these three fields if they exist.

3. Anywhere in the codebase that reads these as `BleSessionLimits.sessionDurationSeconds`
   (or the other two) will automatically pick up the getter — no other changes needed.
   Verify by searching for usages of all three constant names across the project and
   confirming none of them use `const` in a context that would break with a getter.

4. Add a prominent comment block above kDebugShortTimers:
   // ─────────────────────────────────────────────
   // DEBUG: shorten all timers for manual testing.
   // 30 s session | 60 s cooldown | 5 s min-count
   // SET TO FALSE BEFORE REAL-USE TESTING.
   // ─────────────────────────────────────────────

After making the changes, show me the final state of BleSessionLimits in full.
```

---

## Prompt 2 — Flutter Widget Tests with Fake Timers (Automated, No Hardware)

```
In the EndoSync Flutter app, create a widget test file that verifies all timer-dependent
behaviour without any real waiting and without requiring BLE hardware.

The app uses kDebugSkipBle (in lib/bluetooth/ble_constants.dart) to bypass BLE,
and BleSessionLimits for timer durations. The relevant screens are:
  - SessionScreen  (10-minute countdown, early-end button, safety handling)
  - EndScreen      (pain re-rating, session save)
  - HomeScreen     (entry point, shows cooldown state when active)

State is managed via Provider: BleManager and SessionHistoryProvider.

Create the file `test/timing_test.dart` with the following test cases. Use
`flutter_test` (already in dev_dependencies). Do not add any new packages.

Test 1 — Session timer expires and navigates to EndScreen:
  - Build the app with kDebugSkipBle = true
  - Navigate through to SessionScreen (simulate pain rating + exercise selection)
  // The session timer fires on the tick AFTER _secondsRemaining reaches 0,
  // so we need sessionDurationSeconds + 1 ticks to trigger _endSession().
  - Call tester.pump(Duration(seconds: BleSessionLimits.sessionDurationSeconds + 1))
  - Call tester.pumpAndSettle()
  - Assert that EndScreen is present in the widget tree

Test 2 — Early-end button navigates to EndScreen immediately:
  - Navigate to SessionScreen
  - Find and tap the "End Session Early" button
  - Call tester.pumpAndSettle()
  - Assert EndScreen is present

Test 3 — Short session (under minSessionDurationForCount) does not consume a session slot:
  - Navigate to SessionScreen
  - Pump only 4 seconds (below the 5 s threshold with kDebugShortTimers)
  - Tap End Session Early
  - Complete the EndScreen flow (submit a final pain rating)
  - Navigate back to HomeScreen
  - Assert sessionCount on BleManager is still 0 (slot was not consumed)

Test 4 — Two full sessions trigger cooldown:
  // Same off-by-one as Test 1: need sessionDurationSeconds + 1 ticks per session.
  - Complete session 1: pump full sessionDurationSeconds + 1, submit EndScreen
  - Complete session 2: same
  - Assert HomeScreen shows a cooldown message or the start button is disabled
  - Assert BleManager.inCooldown == true

Test 5 — Cooldown expires and start button re-enables:
  - Reach cooldown state (from Test 4 setup)
  // The cooldown timer clears on the tick AFTER remaining hits 0, same
  // off-by-one as the session timer.
  - pump(Duration(seconds: BleSessionLimits.cooldownDurationSeconds + 1))
  // One extra pump to flush the notifyListeners() rebuild
  - pump()
  // Do NOT use pumpAndSettle here — the cooldown timer is still active during
  // the pump and would prevent settlement for the full cooldown duration.
  - Assert BleManager.inCooldown == false
  - Assert the start/scan button on HomeScreen is enabled

For each test, provide clear comments explaining what timing behaviour is being verified.
Use setUp() to reset BleManager state between tests.
Show me the complete test file when done.
```

---

## Prompt 3 — In-App Timestamp Event Log (Integration Run Logging)

```
In the EndoSync Flutter app, add a lightweight timestamp event logger so that during
a manual test run I can see a precise log of every key event without needing a stopwatch.

1. Create `lib/utils/event_log.dart` with a simple singleton:

   class EventLog {
     EventLog._();
     static final EventLog instance = EventLog._();

     final List<String> _entries = [];
     List<String> get entries => List.unmodifiable(_entries);

     void log(String event) {
       final entry = '${DateTime.now().toIso8601String()} — $event';
       _entries.add(entry);
       debugPrint('[ENDOSYNC] $entry');
     }

     void clear() => _entries.clear();

     String dump() => _entries.join('\n');
   }

2. Add EventLog.instance.log(...) calls at these exact points:
   - session_screen.dart  → _startSession()           : 'Session started. Exercise: $exerciseType'
   - session_screen.dart  → _endSession()             : 'Session ended. Duration: ${actualDurationSeconds}s. Early: $endedEarly'
   - session_screen.dart  → _sendReadTemp()           : 'READ_TEMP ping sent'
   - session_screen.dart  → _handleSafetyShutoff()   : 'Safety shutoff triggered: ${_ble.safetyAlert}'
   - ble_manager.dart     → incrementSessionCount()   : 'Session count incremented to $_sessionCount'
   - ble_manager.dart     → startCooldown()           : 'Cooldown started. ${BleSessionLimits.cooldownDurationSeconds}s'
   - ble_manager.dart     → resetSessionCount()       : 'Session count reset. Cooldown cleared.'
   - end_screen.dart      → _submitFinalPain()        : 'Final pain submitted: $finalPain. Saved: ${record.wasSuccessful}'

3. In HomeScreen (or wherever a debug floating action button would be unobtrusive),
   add a floating action button visible only when kDebugSkipBle == true:
   - Tapping it shows a dialog with a scrollable view of EventLog.instance.dump()
   - The dialog has a "Clear Log" button and a "Copy to Clipboard" button
     (use Clipboard.setData from flutter/services.dart)

4. In main.dart initState or wherever sessions are first initialised, call
   EventLog.instance.log('App launched. kDebugSkipBle=${BleConstants.kDebugSkipBle}. ShortTimers=${BleSessionLimits.kDebugShortTimers}')

Show me every file you create or modify, with the final full content.
```

---

## Prompt 4 — Arduino Serial Timestamps for Firmware Timing

```
In the EndoSync Arduino firmware at
lib/arduino/endosync_hardware_v3/endosync_hardware_v3.ino,
add millisecond timestamps to every Serial.println() call so I can measure all
timing intervals precisely from the Serial Monitor output without a stopwatch.

1. Create a helper at the top of the file (before setup()), after the global
   variable declarations:

   void logEvent(const char* msg) {
     Serial.print("[");
     Serial.print(millis());
     Serial.print(" ms] ");
     Serial.println(msg);
   }

   Also add an overload for String:
   void logEvent(const String& msg) {
     Serial.print("[");
     Serial.print(millis());
     Serial.print(" ms] ");
     Serial.println(msg);
   }

2. Replace every existing Serial.println() call in the file with logEvent().
   Do NOT change Serial.print() calls that are part of building up a message
   across multiple prints — only replace the final Serial.println() that
   terminates each message. If a block uses Serial.print() + Serial.println()
   together to form one message, consolidate them into a single String variable
   and pass that to logEvent().

3. Make sure the following events all produce a timestamped logEvent() output:
   - Device boot ("Endosync booting...")
   - Each sensor ready ("MCP9808 ready", "DRV2605L ready", "BLE ready")
   - Switch detected ON / OFF
   - BLE central connected / disconnected
   - Each command received (HEAT_ON, HEAT_OFF, VIBRATE_ON, VIBRATE_OFF,
     BOTH_ON, ALL_OFF, READ_TEMP)
   - Temperature reading (the value itself)
   - Each safety event (SAFETY:TEMP_HIGH, SAFETY:BLE_TIMEOUT, SAFETY:BLE_LOST)
   - BLE timeout countdown warnings if any exist

4. Do not change any logic, timing constants, BLE behaviour, or safety thresholds.
   Only add or modify Serial output statements.

After making all changes, show me the complete modified .ino file.
```

---

## Usage Notes

**Order to run these prompts:**
1. Prompt 1 first — sets up compressed timers needed by Prompt 2 tests
2. Prompt 2 — automated widget tests (run with `flutter test test/timing_test.dart`)
3. Prompt 3 — event log for manual integration runs in the simulator
4. Prompt 4 — firmware timestamps (run independently in Arduino IDE)

**To run the widget tests:**
```bash
flutter test test/timing_test.dart --verbose
```

**To read the event log during a simulator run:**
- Build with `kDebugSkipBle = true` and `kDebugShortTimers = true`
- Tap the debug FAB (bottom-right, only visible in debug mode) after any test flow
- Copy the log and paste into a spreadsheet — subtract ISO timestamps to get exact intervals

**To read firmware timestamps:**
- Open Serial Monitor in Arduino IDE at 115200 baud
- All output is prefixed with `[XXXXXX ms]` — subtract any two values to get the interval in milliseconds
- E.g. `[25043 ms] READ_TEMP` followed by `[50089 ms] READ_TEMP` = 25046 ms ≈ 25 s between pings ✓

**Before submitting or real-use testing:**
- Set `kDebugShortTimers = false` in `ble_constants.dart`
- Set `kDebugSkipBle = false` in `ble_constants.dart`
