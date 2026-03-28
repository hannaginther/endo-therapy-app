import 'package:path/path.dart';
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

  Future<void> deleteAll() async {
    await _db!.delete(_tableName);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
