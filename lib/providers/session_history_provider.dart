import 'package:flutter/foundation.dart';

import '../data/models/session_record.dart';
import '../data/session_repository.dart';

class SessionHistoryProvider extends ChangeNotifier {
  final _repository = SessionRepository();

  List<SessionRecord> _sessions = [];
  bool _isLoading = false;

  List<SessionRecord> get sessions => List.unmodifiable(_sessions);
  bool get isLoading => _isLoading;
  SessionRepository get repository => _repository;

  Future<void> init() async {
    await _repository.init();
    await loadSessions();
  }

  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();

    _sessions = await _repository.fetchAll();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveSession(SessionRecord record) async {
    await _repository.insert(record);
    await loadSessions();
  }

  Future<void> clearAll() async {
    await _repository.deleteAll();
    await loadSessions();
  }
}
