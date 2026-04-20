# How to Run the EndoSync Tests

## ❓ Do I need to plug in the device or open the app?

**No.** The tests are fully automated and run entirely on your laptop.
- No Arduino hardware needed
- No iPhone or simulator needed
- No Bluetooth needed
- The app does not need to be open

The tests simulate time passing (a 30-second session, a 60-second cooldown) in milliseconds using a "fake clock" built into Flutter's test framework. Everything runs invisibly in the terminal.

---

## 🧪 What do the tests actually check?

There are 5 tests. Each one verifies a specific rule about how the app manages sessions:

| Test | What it checks | Why it matters |
|------|---------------|----------------|
| **Test 1** | After 30 seconds the session ends automatically and the "How is your pain now?" screen appears | The countdown timer must actually stop the session |
| **Test 2** | Tapping "End Session Early" goes straight to the pain screen | The early-end button must work at any point |
| **Test 3** | A session under 5 seconds doesn't count as a real session | Very short/accidental sessions shouldn't use up one of the 2 allowed sessions |
| **Test 4** | After 2 full sessions, the app enters a cooldown and shows "Cooldown Period" | The 2-session safety limit must be enforced |
| **Test 5** | After 60 seconds the cooldown clears and the scan button comes back | The cooldown must actually expire and let the user start again |

---

## 🛠️ One-time setup (do this once, then never again)

### Step 1 — Install Flutter

If you haven't already, install Flutter by following the guide for your operating system:
https://docs.flutter.dev/get-started/install

To check it worked, open a terminal and type:
```
flutter --version
```
You should see a version number printed. If you see "command not found", Flutter is not installed yet.

### Step 2 — Get the project dependencies

Open a terminal, navigate to the project folder, and run:
```
flutter pub get
```
This downloads all the packages the app needs. You only need to do this once (or after pulling new code from your teammate).

### Step 3 — Check the two debug flags are ON

Open this file in any text editor:
```
lib/bluetooth/ble_constants.dart
```

Make sure these two lines look exactly like this (both say `true`):
```dart
const bool kDebugSkipBle = true;
static const bool kDebugShortTimers = true;
```

If either one says `false`, change it to `true` and save the file before running tests.

> ⚠️ **Important:** These flags compress the timers so tests run in seconds instead of 30 minutes. Without them, the tests will time out.

---

## ▶️ Running the tests

### Option A — One command (recommended)

In the terminal, from the project root folder, run:
```
./run_tests.sh
```

You'll see each test run and a final result at the bottom:
- **✅ ALL TESTS PASSED** — everything is working correctly
- **❌ SOME TESTS FAILED** — the script will tell you exactly what to check

### Option B — Flutter command directly

If the script doesn't work on your system, run this instead:
```
flutter test test/timing_test.dart --reporter expanded
```

---

## 🔍 Reading the output

When tests pass it looks like this:
```
✓ Test 1: session timer fires after sessionDurationSeconds and navigates to EndScreen
✓ Test 2: tapping End Session Early navigates to EndScreen without waiting for the timer
✓ Test 3: session shorter than minSessionDurationForCount does not increment sessionCount
✓ Test 4: two full sessions increment sessionCount to maxSessionsPerUse and trigger cooldown
✓ Test 5: cooldown expires after cooldownDurationSeconds and HomeScreen returns to scanner

All tests passed!
```

When a test fails it looks like this:
```
✗ Test 1: session timer fires after sessionDurationSeconds...
  Expected: exactly one matching node in the widget tree
  Actual: found no matching nodes
```
The name of the failing test tells you which feature is broken.

---

## ❗ Common problems

**"command not found: flutter"**
Flutter is not installed or not on your PATH. Reinstall from https://docs.flutter.dev/get-started/install and restart your terminal.

**"permission denied: ./run_tests.sh"**
Run this once to fix it:
```
chmod +x run_tests.sh
```

**"Could not find package..."**
Run `flutter pub get` first, then try again.

**Tests time out or take forever**
Check that `kDebugShortTimers = true` in `lib/bluetooth/ble_constants.dart`. If it is set to `false`, the fake session timer runs for 600 seconds and the cooldown for 1800 seconds.

**A test was passing before and now fails**
Check `docs/bug_fix_strategy.md` — it has a ready-made fix for each known bug.

---

## 📋 Summary in one sentence

**No hardware. Open terminal → run `./run_tests.sh` → all 5 should say ✓.**
