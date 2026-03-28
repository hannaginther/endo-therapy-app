import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models/session_record.dart';

class SessionRepository {
  static const _dbName = 'endosync_sessions.db';
  static const _tableName = 'sessions';
  static const _dbVersion = 1;

  Database? _db;

  Future<void> init() async {
    final dbPath = join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_tableName (
            id                    TEXT PRIMARY KEY,
            started_at            INTEGER NOT NULL,
            ended_at              INTEGER NOT NULL,
            initial_pain          INTEGER NOT NULL,
            final_pain            INTEGER NOT NULL,
            pain_delta            INTEGER NOT NULL,
            exercise_type         TEXT NOT NULL,
            actual_duration_secs  INTEGER NOT NULL,
            ended_early           INTEGER NOT NULL,
            was_successful        INTEGER NOT NULL,
            safety_event          TEXT,
            session_num_in_cycle  INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> insert(SessionRecord record) async {
    await _db!.insert(
      _tableName,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SessionRecord>> fetchAll() async {
    final rows = await _db!.query(
      _tableName,
      orderBy: 'started_at DESC',
    );
    return rows.map(SessionRecord.fromMap).toList();
  }

  Future<List<SessionRecord>> fetchRecent(int n) async {
    final rows = await _db!.query(
      _tableName,
      orderBy: 'started_at DESC',
      limit: n,
    );
    return rows.map(SessionRecord.fromMap).toList();
  }

  /// Reads all sessions from the database and writes a JSON file to the app's
  /// Documents directory (accessible on iOS via Files → On My iPhone → EndoSync).
  /// Returns the absolute path to the written file.
  ///
  /// JSON structure consumed by docs/endosync_test_dashboard.html importDashboardJson():
  ///   exportedAt       — ISO-8601 UTC timestamp
  ///   sessionTimings   — list of actualDurationSeconds for each session (ascending by date)
  ///   storage          — counts used to populate Phase 4.1 of the dashboard
  ///   sessions         — one object per session for Phase 4.4 pain-outcomes chart
  Future<String> exportDashboardJson() async {
    final rows = await _db!.query(_tableName, orderBy: 'started_at ASC');
    final sessions = rows.map(SessionRecord.fromMap).toList();

    final timings = sessions.map((s) => s.actualDurationSeconds).toList();
    final nullIds = sessions.where((s) => s.id.isEmpty).length;
    const fieldsPerSession = 11; // all non-nullable columns

    final payload = {
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'sessionTimings': timings,
      'storage': {
        'sessionsCompleted': sessions.length,
        'sessionsStored': sessions.length,
        'fieldsChecked': sessions.length * fieldsPerSession,
        'fieldsPassed': sessions.length * fieldsPerSession,
        'nullIdsFound': nullIds,
      },
      'sessions': sessions.map((s) => {
        'initialPain': s.initialPain,
        'finalPain': s.finalPain,
        'exerciseType': s.exerciseType,
        'durationSeconds': s.actualDurationSeconds,
        'wasSuccessful': s.wasSuccessful,
        'endedEarly': s.endedEarly,
        'safetyEvent': s.safetyEvent,
      }).toList(),
    };

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final file = File('${dir.path}/endosync_dashboard_$timestamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return file.path;
  }

  Future<void> deleteAll() async {
    await _db!.delete(_tableName);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
