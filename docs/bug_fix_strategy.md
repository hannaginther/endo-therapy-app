# EndoSync — Test Bug Fix Strategy

This document catalogues every bug found across the test suite and source code,
explains the root cause of each one, and gives a paste-ready prompt your
groupmate can use to fix it.

Bugs are grouped by severity: **Test-breaking** (will cause `flutter test` to
fail or hang), **Logic** (code runs but produces wrong behaviour), and
**Consistency** (minor inconsistencies that won't break tests but should be
fixed before submission).

---

## Bug 1 — LOGIC BUG: `_endSession` has no re-entry guard

**File:** `lib/screens/session_screen.dart`

**Root cause:**
`_endSession()` is called by two independent code paths:
- The periodic `_timer` (fires every second)
- The "End Session Early" button (direct tap)
- `_handleSafetyShutoff()` (listener callback)

`_endSession` cancels `_timer` as its first action, but in Dart's event loop a
timer callback that is already executing cannot be cancelled mid-flight. If the
user taps the button at the exact moment a tick fires, both paths execute in the
same event loop turn. The `_sessionEnded` flag is set to `true` via `setState()`
**after** the increment logic, so the guard is too late to stop a second call.

**Effect:**
- `ble.incrementSessionCount()` is called twice → `sessionCount` jumps by 2
  instead of 1
- `ble.startCooldown()` may be called twice, creating two overlapping periodic
  cooldown timers, causing the cooldown countdown to race
- `Navigator.pushReplacement` is called twice, which throws a navigation error

**The fix:**

```
In lib/screens/session_screen.dart, add a re-entry guard to _endSession so it
can never execute its body more than once per session.

At the very top of _endSession (before _timer?.cancel()), add:
  if (_sessionEnded) return;
  _sessionEnded = true;

Then remove the later `setState(() => _sessionEnded = true);` call (since
_sessionEnded is now set synchronously at the start of the method) and keep the
setState call only if there are other state mutations that still need it (there
are none in the current code — the navigation makes the widget unreachable
anyway).

Show me the complete updated _endSession method when done.
```

---

## Bug 2 — CONSISTENCY BUG: `startCooldown()` bypasses `resetSessionCount()`

**File:** `lib/bluetooth/ble_manager.dart`

**Root cause:**
When the cooldown timer expires, the timer callback directly mutates
`_sessionCount = 0` instead of calling the existing `resetSessionCount()` method.
`resetSessionCount()` writes an EventLog entry (`'Session count reset. Cooldown
cleared.'`), which is important for the manual integration testing workflow
described in `docs/timing_test_prompts.md` (Prompt 3). The direct mutation silently
skips that log entry.

**Relevant code (lines 246–252):**
```dart
_cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
  if (_cooldownSecondsRemaining <= 0) {
    _cooldownTimer?.cancel();
    _inCooldown = false;
    _sessionCount = 0;   // ← BUG: bypasses resetSessionCount()
    notifyListeners();
  } else {
    _cooldownSecondsRemaining--;
    notifyListeners();
  }
});
```

**Effect:**
- EventLog never records that the cooldown cleared
- Manual test logs (via the debug FAB) will appear to show the cooldown starting
  but never ending, making post-session analysis confusing

**The fix:**

```
In lib/bluetooth/ble_manager.dart, inside the startCooldown() method, fix the
timer callback so it calls resetSessionCount() instead of directly setting
_sessionCount = 0.

The corrected block inside Timer.periodic should read:
  if (_cooldownSecondsRemaining <= 0) {
    _cooldownTimer?.cancel();
    _inCooldown = false;
    resetSessionCount();   // logs 'Session count reset. Cooldown cleared.'
    notifyListeners();
  } else {
    _cooldownSecondsRemaining--;
    notifyListeners();
  }

Show me the complete updated startCooldown() method when done.
```

---

## Bug 3 — FRAGILE PATTERN: `static final sessionDuration` caches a getter

**File:** `lib/screens/session_screen.dart` (line 35)

**Root cause:**
```dart
static final int sessionDuration = BleSessionLimits.sessionDurationSeconds;
int _secondsRemaining = sessionDuration;
```

`static final` fields in Dart are initialised exactly once — the first time the
class is loaded — and the computed value is cached forever. `sessionDurationSeconds`
is a getter backed by the `kDebugShortTimers` constant, which is `const bool`, so
the value is always the same within a single compilation. This means the cached
value is **currently** correct.

However:
1. If `kDebugShortTimers` is ever changed to a non-`const` runtime flag (e.g.,
   read from shared preferences), the cached `static final` would return the
   wrong value for every session after the first.
2. The `static final` lives on the `_SessionScreenState` **class**, not the
   instance, so it persists across all widget rebuilds and test runs in the same
   process — meaning a test that changes the flag after the class is loaded would
   silently use the stale cached value.

**Effect:** Currently no runtime error, but it's a trap that will cause subtle
timer bugs if the timer constants are ever made dynamic.

**The fix:**

```
In lib/screens/session_screen.dart, remove the static field sessionDuration and
replace the instance field initialiser so it reads the getter directly at widget
creation time.

Change:
  static final int sessionDuration = BleSessionLimits.sessionDurationSeconds;
  int _secondsRemaining = sessionDuration;

To:
  late int _secondsRemaining;

And in initState(), add:
  _secondsRemaining = BleSessionLimits.sessionDurationSeconds;

(Move this line before the WidgetsBinding.instance.addPostFrameCallback call so
the countdown is ready before the first render.)

Show me the updated _SessionScreenState fields and initState() when done.
```

---

## Bug 4 — TEST GUIDE BUG: Prompt 2 specifies wrong pump duration for Test 1

**File:** `docs/timing_test_prompts.md` (Prompt 2, Test 1)

**Root cause:**
The guide says:
> `tester.pump(Duration(seconds: BleSessionLimits.sessionDurationSeconds))`

But the actual timer logic in `session_screen.dart` requires **one extra tick**:
- Ticks 1–30 decrement `_secondsRemaining` from 30 down to 0
- Only tick **31** finds `_secondsRemaining <= 0` and calls `_endSession()`

Pumping exactly `sessionDurationSeconds` (30 s) leaves the timer sitting at
`_secondsRemaining == 0` with `_endSession()` not yet called. The test would
remain on SessionScreen and the `find.text('How is your pain now?')` assertion
would fail.

The implemented test file (`test/timing_test.dart`) already uses `+1` correctly
on line 119, but if someone regenerates the test from the guide (e.g., to add a
new test case) they would reproduce the bug.

**Effect:** Test 1 would fail with a "widget not found" error, misleadingly
suggesting the navigation never happened.

**The fix:**

```
In docs/timing_test_prompts.md, find the Prompt 2 section and fix the pump
duration in Test 1.

Change:
  Call tester.pump(Duration(seconds: BleSessionLimits.sessionDurationSeconds))

To:
  // The session timer fires on the tick AFTER _secondsRemaining reaches 0,
  // so we need sessionDurationSeconds + 1 ticks to trigger _endSession().
  Call tester.pump(Duration(seconds: BleSessionLimits.sessionDurationSeconds + 1))

Apply the same +1 correction to Test 4's instructions (which describe the same
two-session flow). Leave Test 5's cooldown pump at cooldownDurationSeconds + 1
(already correct in the implementation).

Show me the updated Prompt 2 section when done.
```

---

## Bug 5 — TEST GUIDE BUG: Prompt 2 Test 5 says to use `pumpAndSettle()` after cooldown — this can hang

**File:** `docs/timing_test_prompts.md` (Prompt 2, Test 5)

**Root cause:**
The guide says:
> Pump `cooldownDurationSeconds`, then `pumpAndSettle()`

`pumpAndSettle()` advances fake time in 100 ms increments until the widget tree
is fully settled. If the cooldown timer is **still running** when `pumpAndSettle`
is called (which it will be — 60 ticks have fired but the 61st, which cancels the
timer, has not), `pumpAndSettle` must keep pumping until 1 more second elapses to
fire the 61st tick. This usually works but risks a `pumpAndSettle` timeout
exception if the test runner's deadline is shorter than 1 second (unlikely but
possible in CI environments with tight timeouts).

More importantly, it is fundamentally fragile: if the cooldown duration were
changed to a value that makes `pumpAndSettle`'s 100 ms-per-pump strategy take
longer than the framework timeout (default 10 s), the test would hang.

The correct approach (already used in the implementation on line 304) is:
```dart
await tester.pump(Duration(seconds: BleSessionLimits.cooldownDurationSeconds + 1));
await tester.pump(); // process the final notifyListeners() → widget rebuild
```

**Effect:** Under normal conditions the test passes; under tight CI timeouts or
with longer cooldown values it hangs or times out.

**The fix:**

```
In docs/timing_test_prompts.md, find the Prompt 2 / Test 5 section and fix the
pump instructions.

Replace:
  - Pump cooldownDurationSeconds
  - pumpAndSettle()

With:
  // The cooldown timer clears on the tick AFTER remaining hits 0, same
  // off-by-one as the session timer.
  - pump(Duration(seconds: BleSessionLimits.cooldownDurationSeconds + 1))
  // One extra pump to flush the notifyListeners() rebuild
  - pump()
  // Do NOT use pumpAndSettle here — the cooldown timer is still active during
  // the pump and would prevent settlement for the full cooldown duration.

Show me the updated Test 5 instructions when done.
```

---

## How to run the tests after fixes

```bash
cd /path/to/flutter_endosync_2
flutter test test/timing_test.dart --verbose
```

All 5 tests should pass in under a few seconds (no real time elapses — FakeAsync
is used throughout).

## Flags to verify before running tests

In `lib/bluetooth/ble_constants.dart`:
- `kDebugSkipBle = true` — not required by the tests (they pump widgets directly)
  but leave it as-is
- `BleSessionLimits.kDebugShortTimers = true` — **required**: tests depend on the
  30 s / 60 s / 5 s compressed durations

## Recommended fix order

1. Bug 1 (`_endSession` guard) — highest risk, fix first
2. Bug 3 (`static final` → `late int` / initState) — do alongside Bug 1 since
   it's in the same file
3. Bug 2 (`resetSessionCount()` in cooldown timer) — one-line fix
4. Bug 4 & 5 (guide doc corrections) — update the markdown last
