# EndoSync — Session Storage: Implementation Prompts for Claude

Use these prompts sequentially in a Cowork or Claude Code session. Each prompt is self-contained and compiles independently. Complete them in order — steps 6 and 7 must be done in the same conversation turn since they involve a linked constructor change.

Read `docs/session_storage_spec.md` first for the full architecture rationale.

---

## Prompt 1 — Add Packages

```
I'm adding persistent session storage to the EndoSync Flutter app.
Read pubspec.yaml first, then add these three packages under `dependencies`:

  sqflite: ^2.3.0
  path: ^1.9.0
  uuid: ^4.3.3

After editing the file, run:
  flutter pub get

Confirm the packages resolved successfully.
```

---

## Prompt 2 — Create the SessionRecord Model

```
I'm adding persistent session storage to the EndoSync Flutter app.
Read docs/session_storage_spec.md (section 3) for the full field list.

Create lib/data/models/session_record.dart with a `SessionRecord` class that has:

Fields (all final):
  String id
  DateTime startedAt
  DateTime endedAt
  int initialPain
  int finalPain
  int painDelta           (computed: initialPain - finalPain)
  String exerciseType     ('breathing' | 'physical' | 'both' | 'none')
  int actualDurationSeconds
  bool endedEarly
  bool wasSuccessful      (computed: finalPain < initialPain)
  String? safetyEvent     (nullable)
  int sessionNumberInCycle

Requirements:
- A named constructor `SessionRecord({...})` with all fields required except safetyEvent.
- A factory constructor `SessionRecord.create({...})` that auto-generates id (using the uuid package), computes painDelta and wasSuccessful, and sets all other fields from parameters.
- `Map<String, dynamic> toMap()` serialising to the SQLite column names in the spec (use millisecondsSinceEpoch for DateTime, 0/1 for bool).
- `factory SessionRecord.fromMap(Map<String, dynamic> map)` deserialising from those same column names.
- A `copyWith` method.
- Override `toString` for debug convenience.

Do not create any other files yet.
```

---

## Prompt 3 — Create the SessionRepository

```
I'm adding persistent session storage to the EndoSync Flutter app.
Read docs/session_storage_spec.md (sections 3 and 7) and
read lib/data/models/session_record.dart before writing any code.

Create lib/data/session_repository.dart with a `SessionRepository` class.

Use the `sqflite` and `path` packages. The DB file should be named
`endosync_sessions.db`. The table name is `sessions`.

The SQLite schema (from the spec) is:
  id                    TEXT PRIMARY KEY
  started_at            INTEGER NOT NULL
  ended_at              INTEGER NOT NULL
  initial_pain          INTEGER NOT NULL
  final_pain            INTEGER NOT NULL
  pain_delta            INTEGER NOT NULL
  exercise_type         TEXT NOT NULL
  actual_duration_secs  INTEGER NOT NULL
  ended_early           INTEGER NOT NULL
  was_successful        INTEGER NOT NULL
  safety_event          TEXT
  session_num_in_cycle  INTEGER NOT NULL

Public API:
  Future<void> init()                              — open/create DB
  Future<void> insert(SessionRecord record)        — save a session
  Future<List<SessionRecord>> fetchAll()           — all sessions, newest first (ORDER BY started_at DESC)
  Future<List<SessionRecord>> fetchRecent(int n)   — last n sessions, newest first
  Future<void> deleteAll()                         — clear all rows (research reset)
  Future<void> close()                             — close the DB

Keep the class simple — no singleton pattern needed.
Do not modify any existing files.
```

---

## Prompt 4 — Create the SessionHistoryProvider

```
I'm adding persistent session storage to the EndoSync Flutter app.
Read docs/session_storage_spec.md (section 8) and
read lib/data/session_repository.dart and
read lib/data/models/session_record.dart before writing any code.

Create lib/providers/session_history_provider.dart with a
`SessionHistoryProvider extends ChangeNotifier` class.

It should:
- Own a `SessionRepository` instance internally.
- Expose: `List<SessionRecord> get sessions` (unmodifiable, newest first), `bool get isLoading`.
- `Future<void> init()` — calls `_repository.init()` then `loadSessions()`. Call this once at startup.
- `Future<void> loadSessions()` — loads all sessions from repo into the internal list, sets isLoading appropriately, calls notifyListeners().
- `Future<void> saveSession(SessionRecord record)` — inserts to repo, then reloads the list.
- `Future<void> clearAll()` — calls `_repository.deleteAll()` then reloads.

Do not modify any existing files.
```

---

## Prompt 5 — Update main.dart to MultiProvider

```
I'm adding persistent session storage to the EndoSync Flutter app.
Read lib/main.dart and lib/providers/session_history_provider.dart before writing any code.

Update lib/main.dart to:
1. Replace the single `ChangeNotifierProvider` with `MultiProvider`.
2. Add `SessionHistoryProvider` as a second provider (alongside the existing `BleManager`).
3. After the widget tree is built, call `sessionHistoryProvider.init()` using
   `WidgetsBinding.instance.addPostFrameCallback` in a stateful wrapper or by
   calling it inside the `MultiProvider`'s `create` callback after construction.

The cleanest approach: make `MyApp` stateful, call
`context.read<SessionHistoryProvider>().init()` in `initState` using
`WidgetsBinding.instance.addPostFrameCallback`.

Do not change anything else in main.dart.
```

---

## Prompt 6 — Update SessionScreen + EndScreen (do these together)

```
I'm adding persistent session storage to the EndoSync Flutter app.
Read docs/session_storage_spec.md (sections 5 and 6),
read lib/screens/session_screen.dart, and
read lib/screens/end_screen.dart before writing any code.

Make these two coordinated changes:

### SessionScreen changes (lib/screens/session_screen.dart):
1. Add `DateTime? _startedAt` state variable.
2. In `_startSession()`, set `_startedAt = DateTime.now()` before starting the timer.
3. In `_endSession(endedEarly: bool)`:
   - Compute `actualDurationSeconds` as
     `BleSessionLimits.sessionDurationSeconds - _secondsRemaining`.
   - Capture `safetyEvent` as `_ble.safetyAlert` (nullable String).
   - Add these as new named parameters when navigating to `EndScreen`:
       exerciseType: widget.exerciseType
       startedAt: _startedAt ?? DateTime.now()
       actualDurationSeconds: actualDurationSeconds
       endedEarly: endedEarly
       safetyEvent: safetyEvent
4. The existing early-end button should call `_endSession(endedEarly: true)`.
   The timer-triggered end should call `_endSession(endedEarly: false)`.
5. Safety events also end the session — in `_handleSafetyShutoff`, call
   `_endSession(endedEarly: false)` (or a dedicated safety path) to ensure
   the session is still recorded even when cut short by a safety event.

### EndScreen changes (lib/screens/end_screen.dart):
1. Add these new required constructor parameters:
     String exerciseType
     DateTime startedAt
     int actualDurationSeconds
     bool endedEarly
     String? safetyEvent
2. In `_submitFinalPain`, after computing the outcome but before navigating,
   call `context.read<SessionHistoryProvider>().saveSession(record)` where
   `record` is a `SessionRecord.create(...)` built from all available fields.
3. Make `_submitFinalPain` async (use `await` for saveSession).
4. Add the required import for `SessionHistoryProvider` and `SessionRecord`.

Do not change any other files.
```

---

## Prompt 7 — Create the History Screen

```
I'm adding persistent session storage to the EndoSync Flutter app.
Read lib/providers/session_history_provider.dart and
read lib/data/models/session_record.dart before writing any code.

Create lib/screens/history_screen.dart with a `HistoryScreen` widget.

Requirements:
- AppBar title: "Session History"
- Watch `SessionHistoryProvider` via `context.watch`.
- Show a `CircularProgressIndicator` centred while `isLoading` is true.
- Show a centred "No sessions recorded yet." `Text` when the list is empty.
- Otherwise show a `ListView.separated` of session cards, newest first.

Each session card (use a `Card` with `ListTile` or a custom layout) should show:
- Date and time: formatted as e.g. "Mon 24 Mar · 14:32"
- Pain: "Pain: 7 → 4" with the delta coloured green if painDelta > 0, red if ≤ 0
- Exercise type: display as "Breathing", "Physical", "Both", or "No exercise"
- Duration: "10:00" or, if endedEarly is true, "Ended early (MM:SS)"
- A small red "⚠ Safety event" label if safetyEvent is not null
- A green tick icon if wasSuccessful, otherwise a neutral icon

At the bottom of the screen, add a "Clear all data" TextButton that shows a
confirmation AlertDialog before calling `SessionHistoryProvider.clearAll()`.

Do not modify any existing files.
```

---

## Prompt 8 — Add History Navigation to HomeScreen

```
I'm adding persistent session storage to the EndoSync Flutter app.
Read lib/screens/home_screen.dart before writing any code.

Add a history navigation button to HomeScreen:
- Add an `actions` list to the existing AppBar with a single `IconButton`
  using `Icons.history` as the icon.
- On press, navigate to `HistoryScreen` using `Navigator.push`.
- Import `HistoryScreen`.

That's the only change to this file.
```

---

## Prompt 9 — Verification Checklist

```
I've just implemented session data storage in the EndoSync Flutter app.
Please verify the implementation is correct and complete.

Read all of these files:
  pubspec.yaml
  lib/data/models/session_record.dart
  lib/data/session_repository.dart
  lib/providers/session_history_provider.dart
  lib/main.dart
  lib/screens/session_screen.dart
  lib/screens/end_screen.dart
  lib/screens/history_screen.dart
  lib/screens/home_screen.dart
  docs/session_storage_spec.md

Then check:
1. Does SessionRecord.create() correctly compute painDelta and wasSuccessful?
2. Does toMap/fromMap round-trip correctly for all field types (DateTime ms, bool as 0/1)?
3. Does the DB schema in SessionRepository match the spec exactly?
4. Does EndScreen receive all fields it needs from SessionScreen?
5. Is saveSession() called after the pain rating is submitted (not before)?
6. Does the history screen handle loading, empty, and populated states?
7. Are there any missing imports?
8. Are there any async/await issues (unawaited futures)?
9. Does the MultiProvider in main.dart correctly initialise SessionHistoryProvider?
10. Does the safety event path in SessionScreen still record the session?

Report any issues found and fix them.
```
