# EndoSync — Session Data Storage: Technical Specification

**Date:** 2026-03-27
**Status:** Design / Pre-implementation
**Scope:** Persistent session history for the EndoSync Flutter iOS app

---

## 1. Why Add Session Storage

EndoSync is a research prototype. Right now, every session's pain ratings, exercise choice, and outcome disappear the moment the user navigates away. Persisting completed sessions enables:

- Longitudinal pain tracking across days and weeks
- Research analysis of exercise type efficacy
- A session history view for the user to see their progress
- Future CSV/JSON export for clinical or academic use

---

## 2. Recommended Storage Package: `sqflite`

| Option | Verdict | Reason |
|---|---|---|
| `sqflite` | **Recommended** | Mature, iOS-native SQLite, easy SQL queries for research analysis, straightforward CSV export |
| `hive` | Good alternative | Faster for simple key-value, but less suited to relational queries across sessions |
| `shared_preferences` | Not suitable | Designed for small config values, not structured history |
| Firebase | Overkill | Adds network dependency to a local-first prototype |

Add to `pubspec.yaml`:
```yaml
sqflite: ^2.3.0
path: ^1.9.0
uuid: ^4.3.3
```

---

## 3. Session Data Model

### `SessionRecord`

All fields that are knowable at the point of session save:

| Field | Type | Source | Notes |
|---|---|---|---|
| `id` | `String` | Generated | UUID v4 at record creation |
| `startedAt` | `DateTime` | `SessionScreen` | Captured when user taps "Start Session" |
| `endedAt` | `DateTime` | `EndScreen` | Captured when user taps "Submit" on final pain |
| `initialPain` | `int` | `PainInputScreen` | 1–10, already passed through nav |
| `finalPain` | `int` | `EndScreen` | 1–10, slider value at submit |
| `exerciseType` | `String` | `ExerciseSelectionScreen` | `'breathing'`, `'physical'`, `'both'`, `'none'` |
| `actualDurationSeconds` | `int` | `SessionScreen` | Seconds elapsed; may be < 600 if ended early |
| `endedEarly` | `bool` | `SessionScreen` | `true` if user tapped "End Session Early" |
| `wasSuccessful` | `bool` | Computed | `finalPain < initialPain` |
| `painDelta` | `int` | Computed | `initialPain - finalPain` (positive = improvement) |
| `safetyEvent` | `String?` | `SessionScreen` | `null`, or `'TEMP_HIGH'`, `'BLE_LOST'`, `'BLE_TIMEOUT'`, `'COMPONENT_FAIL'` |
| `sessionNumberInCycle` | `int` | `SessionScreen` | `1` or `2` within the current use cycle |

### SQLite Schema

```sql
CREATE TABLE sessions (
  id                    TEXT PRIMARY KEY,
  started_at            INTEGER NOT NULL,  -- Unix timestamp (ms)
  ended_at              INTEGER NOT NULL,  -- Unix timestamp (ms)
  initial_pain          INTEGER NOT NULL,
  final_pain            INTEGER NOT NULL,
  pain_delta            INTEGER NOT NULL,
  exercise_type         TEXT NOT NULL,
  actual_duration_secs  INTEGER NOT NULL,
  ended_early           INTEGER NOT NULL,  -- 0 or 1 (SQLite has no BOOLEAN)
  was_successful        INTEGER NOT NULL,  -- 0 or 1
  safety_event          TEXT,              -- NULL if no safety event occurred
  session_num_in_cycle  INTEGER NOT NULL
);
```

---

## 4. Architecture

### New Files to Create

```
lib/
  data/
    models/
      session_record.dart          ← Dart model + toMap/fromMap
    session_repository.dart        ← SQLite open/insert/query/delete
  providers/
    session_history_provider.dart  ← ChangeNotifier wrapping the repository
  screens/
    history_screen.dart            ← Session history list UI
```

### Files to Modify

| File | Change |
|---|---|
| `pubspec.yaml` | Add `sqflite`, `path`, `uuid` |
| `lib/main.dart` | Switch to `MultiProvider`, add `SessionHistoryProvider` |
| `lib/screens/session_screen.dart` | Capture `_startedAt` timestamp; pass extra fields to `EndScreen` |
| `lib/screens/end_screen.dart` | Accept new constructor params; call `saveSession()` on submit |
| `lib/screens/home_screen.dart` | Add "History" navigation button |

### No Changes Needed

`BleManager`, `BleConstants`, `PainInputScreen`, `ExerciseSelectionScreen`, `SessionCompleteScreen` — no storage logic belongs here.

---

## 5. Data Flow

```
PainInputScreen
  └─ initialPain ──────────────────────────────────────────────┐
                                                                │
ExerciseSelectionScreen                                         │
  └─ exerciseType ─────────────────────────────────────────────┤
                                                                │
SessionScreen                                                   │
  ├─ captures: _startedAt (DateTime.now() on Start tapped)      │
  ├─ captures: actualDurationSeconds (600 - _secondsRemaining)  │
  ├─ captures: endedEarly (bool)                                │
  ├─ captures: safetyEvent (from BleManager if triggered)       │
  └─ passes ALL of the above ──────────────────────────────────┤
                                                                ▼
                                                          EndScreen
                                                            ├─ collects: finalPain (slider)
                                                            ├─ on Submit: creates SessionRecord
                                                            ├─ calls: SessionHistoryProvider.saveSession(record)
                                                            └─ navigates: SessionCompleteScreen / dialog
```

---

## 6. Constructor Parameter Changes

### `EndScreen` — new signature

```dart
class EndScreen extends StatefulWidget {
  final int initialPain;
  final int sessionNumber;          // existing
  // NEW:
  final String exerciseType;
  final DateTime startedAt;
  final int actualDurationSeconds;
  final bool endedEarly;
  final String? safetyEvent;
}
```

### `SessionScreen._endSession()` — changes

Compute `actualDurationSeconds` as `BleSessionLimits.sessionDurationSeconds - _secondsRemaining` before navigating. Pass `endedEarly` as a named bool. If a safety event ended the session, capture `_ble.safetyAlert` as the `safetyEvent` string.

---

## 7. `SessionRepository` API

```dart
class SessionRepository {
  Future<void> init();                           // Open/create DB
  Future<void> insert(SessionRecord record);     // Save a completed session
  Future<List<SessionRecord>> fetchAll();        // Newest first
  Future<List<SessionRecord>> fetchRecent(int n); // Last n sessions
  Future<void> deleteAll();                      // Research reset / data wipe
  Future<void> close();                          // Clean shutdown
}
```

The database file is opened with `openDatabase(join(await getDatabasesPath(), 'endosync_sessions.db'), ...)`. Run `CREATE TABLE IF NOT EXISTS ...` in `onCreate`.

---

## 8. `SessionHistoryProvider` API

```dart
class SessionHistoryProvider extends ChangeNotifier {
  List<SessionRecord> get sessions;   // Ordered newest-first
  bool get isLoading;

  Future<void> loadSessions();        // Called on app init
  Future<void> saveSession(SessionRecord record);   // Called from EndScreen
  Future<void> clearAll();            // Research data wipe
}
```

Wrap in `MultiProvider` alongside `BleManager` in `main.dart`. Call `loadSessions()` at app startup via `WidgetsBinding.instance.addPostFrameCallback`.

---

## 9. History Screen (UI)

A simple read-only list, accessible from `HomeScreen` via an AppBar button. Shows:

- Date and time of each session
- Pain: before → after with colour coding (green = improved, red = unchanged/worsened)
- Exercise type label
- Duration (or "Ended early" badge if `endedEarly == true`)
- Safety event badge if `safetyEvent != null`

Empty state: "No sessions recorded yet."
Sort: newest first.

No delete-individual functionality in v1 (research simplicity). "Clear all data" is accessible from a settings option or long-press, protected by a confirmation dialog.

---

## 10. Safety Constraints — No Changes

Adding session storage does **not** alter any safety-critical logic. The heat/vibration cutoff, BLE timeout, temperature limit, and session count are all unchanged. The storage layer is write-only from the session flow's perspective — it never delays or gates BLE commands.

---

## 11. Implementation Order

Follow this sequence to avoid breaking the build at intermediate steps:

1. Add packages to `pubspec.yaml` and run `flutter pub get`
2. Create `SessionRecord` model
3. Create `SessionRepository`
4. Create `SessionHistoryProvider`
5. Update `main.dart` to `MultiProvider`
6. Update `SessionScreen` to capture and pass new fields
7. Update `EndScreen` to accept new fields and call `saveSession()`
8. Add `HistoryScreen`
9. Add history navigation to `HomeScreen`

Each step compiles independently. Steps 6 and 7 must be done together (constructor change).

---

## 12. Future Considerations (Out of Scope for v1)

- JSON/CSV export button in `HistoryScreen` for research data collection
- Aggregate stats: average pain delta, best exercise type, total sessions
- Charts: pain trend over time using `fl_chart` or `syncfusion_flutter_charts`
- Cloud backup (iCloud or Firebase) for multi-device or researcher access
- Per-session notes field
