import 'package:flutter/foundation.dart';

/// Lightweight singleton timestamp logger for manual test runs.
/// Every call to [log] appends an ISO-8601-prefixed entry to the in-memory
/// list and prints it to the debug console via [debugPrint].
/// Access the dialog via the HomeScreen FAB (visible when kDebugSkipBle=true).
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
