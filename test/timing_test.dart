// test/timing_test.dart
//
// Timer-behaviour widget tests for SessionScreen, EndScreen, and HomeScreen.
//
// These tests run entirely in the flutter_test FakeAsync environment — no real
// time elapses and no BLE hardware is required.  testWidgets() wraps every test
// in FakeAsync, so tester.pump(Duration(seconds: N)) advances the Dart timer
// queue by exactly N seconds without wall-clock delay.
//
// Pre-requisites
//   • kDebugShortTimers = true  (set in BleSessionLimits, ble_constants.dart)
//     Compressed durations used throughout:
//       sessionDurationSeconds     = 30  s
//       cooldownDurationSeconds    = 60  s
//       minSessionDurationForCount =  5  s
//   • kDebugSkipBle not required — screens are pumped directly, bypassing the
//     HomeScreen BLE scanner entirely.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:prototype_app/bluetooth/ble_manager.dart';
import 'package:prototype_app/bluetooth/ble_constants.dart';
import 'package:prototype_app/providers/session_history_provider.dart';
import 'package:prototype_app/screens/session_screen.dart';
import 'package:prototype_app/screens/home_screen.dart';
import 'package:prototype_app/data/models/session_record.dart';


// ── Fake provider ─────────────────────────────────────────────────────────────
//
// SessionHistoryProvider uses sqflite, which is not available in the flutter_test
// host environment.  This subclass overrides every method that touches the
// database so the tests never open a real DB file.

class _FakeSessionHistoryProvider extends SessionHistoryProvider {
  @override
  Future<void> init() async {} // skip DB open + loadSessions

  @override
  Future<void> saveSession(SessionRecord record) async {} // skip insert + reload
}


// ── Widget builders ───────────────────────────────────────────────────────────

/// Minimal app rooted at SessionScreen, sharing the given providers.
Widget _sessionApp(
  BleManager ble,
  _FakeSessionHistoryProvider history, {
  int initialPain = 5,
  String exerciseType = 'none',
  int sessionNumber = 0,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<BleManager>.value(value: ble),
      ChangeNotifierProvider<SessionHistoryProvider>.value(value: history),
    ],
    child: MaterialApp(
      home: SessionScreen(
        initialPain: initialPain,
        exerciseType: exerciseType,
        sessionNumber: sessionNumber,
      ),
    ),
  );
}

/// Minimal app rooted at HomeScreen, sharing the given providers.
Widget _homeApp(BleManager ble, _FakeSessionHistoryProvider history) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<BleManager>.value(value: ble),
      ChangeNotifierProvider<SessionHistoryProvider>.value(value: history),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}


// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late BleManager ble;
  late _FakeSessionHistoryProvider history;

  setUp(() {
    ble = BleManager();
    history = _FakeSessionHistoryProvider();
  });

  tearDown(() {
    ble.dispose();
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Test 1 — Session timer expires and navigates to EndScreen
  //
  // Timing contract being verified:
  //   SessionScreen._timer ticks every 1 s, decrementing _secondsRemaining.
  //   When a tick fires and _secondsRemaining is already 0, _endSession() is
  //   called.  Starting from sessionDurationSeconds (30), the first 30 ticks
  //   decrement to 0; the 31st tick triggers navigation.
  //   We therefore need to pump sessionDurationSeconds + 1 seconds.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets(
    'Test 1: session timer fires after sessionDurationSeconds and navigates to EndScreen',
    (tester) async {
      await tester.pumpWidget(_sessionApp(ble, history));
      await tester.pump(); // initial render

      // Start the countdown
      await tester.tap(find.text('Start Session'));
      await tester.pump(); // process tap; timer starts here

      // Advance past the session end.
      // Tick 30 decrements _secondsRemaining to 0; tick 31 calls _endSession().
      await tester.pump(Duration(seconds: BleSessionLimits.sessionDurationSeconds + 1));
      // Allow the page-transition animation (300 ms default) to complete.
      // No active periodic timers remain at this point — _timer and _keepaliveTimer
      // are cancelled inside _endSession(), so pumpAndSettle is safe here.
      await tester.pumpAndSettle();

      // EndScreen is identified by its AppBar title
      expect(find.text('How is your pain now?'), findsOneWidget);
    },
  );


  // ────────────────────────────────────────────────────────────────────────────
  // Test 2 — Early-end button navigates to EndScreen immediately
  //
  // Timing contract being verified:
  //   Tapping "End Session Early" calls _endSession(endedEarly: true) at any
  //   point during the countdown without waiting for the timer to reach zero.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets(
    'Test 2: tapping End Session Early navigates to EndScreen without waiting for the timer',
    (tester) async {
      await tester.pumpWidget(_sessionApp(ble, history));
      await tester.pump();

      await tester.tap(find.text('Start Session'));
      await tester.pump(); // renders the End Session Early button

      expect(find.text('End Session Early'), findsOneWidget);

      // Tap early — no time pump needed
      await tester.tap(find.text('End Session Early'));
      // One small pump to complete the page transition
      await tester.pumpAndSettle();

      expect(find.text('How is your pain now?'), findsOneWidget);
    },
  );


  // ────────────────────────────────────────────────────────────────────────────
  // Test 3 — Short session does not consume a session slot
  //
  // Timing contract being verified:
  //   _endSession() computes actualDurationSeconds = sessionDurationSeconds -
  //   _secondsRemaining and only calls incrementSessionCount() when that value
  //   is >= minSessionDurationForCount (5 s with kDebugShortTimers).
  //   A 4-second session (4 < 5) must leave sessionCount unchanged at 0.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets(
    'Test 3: session shorter than minSessionDurationForCount does not increment sessionCount',
    (tester) async {
      await tester.pumpWidget(_sessionApp(ble, history));
      await tester.pump();

      await tester.tap(find.text('Start Session'));
      await tester.pump();

      // Advance 4 seconds — below the 5 s minimum-count threshold.
      // After 4 ticks: _secondsRemaining = 30 - 4 = 26.
      // actualDurationSeconds will be 30 - 26 = 4 when End is tapped.
      await tester.pump(const Duration(seconds: 4));

      await tester.tap(find.text('End Session Early'));
      await tester.pumpAndSettle();

      // Navigation to EndScreen confirms _endSession() ran
      expect(find.text('How is your pain now?'), findsOneWidget);

      // The session was too short — sessionCount must still be 0
      expect(
        ble.sessionCount,
        0,
        reason: 'A 4 s session is below minSessionDurationForCount (5 s) '
            'and must not consume a session slot.',
      );
    },
  );


  // ────────────────────────────────────────────────────────────────────────────
  // Test 4 — Two full sessions trigger cooldown
  //
  // Timing contract being verified:
  //   Each full session (sessionDurationSeconds = 30 s) increments sessionCount.
  //   After the second session, sessionCount reaches maxSessionsPerUse (2) and
  //   _endSession() calls startCooldown(), setting BleManager.inCooldown = true.
  //
  // Two separate pumpWidget calls share the same BleManager instance so that
  // sessionCount from session 1 carries over into session 2.
  //
  // IMPORTANT: pumpAndSettle() is NOT used after session 2 ends because
  // startCooldown() creates a Timer.periodic that notifyListeners() every
  // second, which would prevent the tree from ever settling for 60 s.
  // A single 500 ms pump is enough to complete the page transition.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets(
    'Test 4: two full sessions increment sessionCount to maxSessionsPerUse and trigger cooldown',
    (tester) async {
      // ── Session 1 ──
      // initialPain = 1 so the default EndScreen slider value (1) equals
      // initialPain, meaning no pain improvement.  This causes EndScreen to
      // show a dialog rather than navigate to SessionCompleteScreen, which
      // lets us keep the navigation stack simple for a two-session test.
      await tester.pumpWidget(_sessionApp(ble, history, initialPain: 1));
      await tester.pump();

      await tester.tap(find.text('Start Session'));
      await tester.pump();

      await tester.pump(Duration(seconds: BleSessionLimits.sessionDurationSeconds + 1));
      // pumpAndSettle is safe here: no cooldown timer yet (count=1 < max=2)
      await tester.pumpAndSettle();

      // Verify session 1 was counted
      expect(ble.sessionCount, 1);
      expect(find.text('How is your pain now?'), findsOneWidget);

      // Flush the old NavigatorState (which still has EndScreen on the stack)
      // so the next pumpWidget starts with a clean navigation history.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // ── Session 2 ──
      // Replace the widget tree with a fresh SessionScreen that shares the same
      // BleManager so sessionCount = 1 carries over.
      await tester.pumpWidget(
        _sessionApp(ble, history, initialPain: 1, sessionNumber: 1),
      );
      await tester.pump();

      await tester.tap(find.text('Start Session'));
      await tester.pump();

      await tester.pump(Duration(seconds: BleSessionLimits.sessionDurationSeconds + 1));
      // Use a fixed pump instead of pumpAndSettle — startCooldown() has now
      // started a periodic timer that would prevent settlement for 60 s.
      await tester.pump(const Duration(milliseconds: 500));

      // Session 2 complete: cooldown must have been triggered
      expect(ble.sessionCount, 2);
      expect(
        ble.inCooldown,
        isTrue,
        reason: 'After two full sessions sessionCount reaches maxSessionsPerUse, '
            'which triggers startCooldown().',
      );

      // ── HomeScreen reflects cooldown state ──
      // Flush Navigator state (still has Session 2's EndScreen on the stack)
      // so HomeScreen is rendered as the fresh root, not hidden behind EndScreen.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await tester.pumpWidget(_homeApp(ble, history));
      await tester.pump();

      expect(find.text('Cooldown Period'), findsOneWidget);

      // Drain the cooldown timer so no periodic timers remain when the test
      // exits. Flutter's test framework fails if timers are still pending.
      // Pumping cooldownDurationSeconds + 1 fires the timer's self-cancelling
      // clearing tick, leaving nothing pending.
      await tester.pump(Duration(seconds: BleSessionLimits.cooldownDurationSeconds + 1));
    },
  );


  // ────────────────────────────────────────────────────────────────────────────
  // Test 5 — Cooldown expires and scan button re-enables
  //
  // Timing contract being verified:
  //   startCooldown() creates a Timer.periodic(1 s) that decrements
  //   _cooldownSecondsRemaining.  When it reaches 0, the timer cancels itself,
  //   sets inCooldown = false, and resets sessionCount to 0.
  //   The tick that CLEARS the cooldown fires after the remaining counter hits 0,
  //   so we need cooldownDurationSeconds + 1 ticks (same off-by-one as the
  //   session timer above).
  //
  // BleManager state is set up directly (two increments + startCooldown) to
  // avoid duplicating the full two-session flow from Test 4.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets(
    'Test 5: cooldown expires after cooldownDurationSeconds and HomeScreen returns to scanner',
    (tester) async {
      // Set up cooldown state — equivalent outcome to completing two full sessions
      ble.incrementSessionCount();
      ble.incrementSessionCount();
      ble.startCooldown();

      expect(ble.inCooldown, isTrue);

      await tester.pumpWidget(_homeApp(ble, history));
      await tester.pump();

      // Cooldown UI must be visible before the timer expires
      expect(find.text('Cooldown Period'), findsOneWidget);

      // Advance past the cooldown.
      // Tick 60 decrements remaining to 0; tick 61 clears inCooldown and calls
      // notifyListeners(), which rebuilds HomeScreen to show the scanner.
      await tester.pump(Duration(seconds: BleSessionLimits.cooldownDurationSeconds + 1));
      await tester.pump(); // process the final notifyListeners() → widget rebuild

      // Cooldown must have cleared
      expect(
        ble.inCooldown,
        isFalse,
        reason: 'inCooldown should be false after cooldownDurationSeconds have elapsed.',
      );
      expect(
        ble.sessionCount,
        0,
        reason: 'startCooldown() resets sessionCount to 0 when the timer expires.',
      );

      // HomeScreen should now show the scanner, not the cooldown view
      expect(find.text('Cooldown Period'), findsNothing);
      // The scan button is present and enabled (onPressed is non-null when not scanning)
      expect(
        find.text('Device is turned ON. Scan for device'),
        findsOneWidget,
      );
    },
  );
}
