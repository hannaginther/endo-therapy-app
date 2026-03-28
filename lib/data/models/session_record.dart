import 'package:uuid/uuid.dart';

class SessionRecord {
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int initialPain;
  final int finalPain;
  final int painDelta;
  final String exerciseType;
  final int actualDurationSeconds;
  final bool endedEarly;
  final bool wasSuccessful;
  final String? safetyEvent;
  final int sessionNumberInCycle;

  const SessionRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.initialPain,
    required this.finalPain,
    required this.painDelta,
    required this.exerciseType,
    required this.actualDurationSeconds,
    required this.endedEarly,
    required this.wasSuccessful,
    this.safetyEvent,
    required this.sessionNumberInCycle,
  });

  factory SessionRecord.create({
    required DateTime startedAt,
    required DateTime endedAt,
    required int initialPain,
    required int finalPain,
    required String exerciseType,
    required int actualDurationSeconds,
    required bool endedEarly,
    String? safetyEvent,
    required int sessionNumberInCycle,
  }) {
    return SessionRecord(
      id: const Uuid().v4(),
      startedAt: startedAt,
      endedAt: endedAt,
      initialPain: initialPain,
      finalPain: finalPain,
      painDelta: initialPain - finalPain,
      exerciseType: exerciseType,
      actualDurationSeconds: actualDurationSeconds,
      endedEarly: endedEarly,
      wasSuccessful: finalPain < initialPain,
      safetyEvent: safetyEvent,
      sessionNumberInCycle: sessionNumberInCycle,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ended_at': endedAt.millisecondsSinceEpoch,
      'initial_pain': initialPain,
      'final_pain': finalPain,
      'pain_delta': painDelta,
      'exercise_type': exerciseType,
      'actual_duration_secs': actualDurationSeconds,
      'ended_early': endedEarly ? 1 : 0,
      'was_successful': wasSuccessful ? 1 : 0,
      'safety_event': safetyEvent,
      'session_num_in_cycle': sessionNumberInCycle,
    };
  }

  factory SessionRecord.fromMap(Map<String, dynamic> map) {
    return SessionRecord(
      id: map['id'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
      endedAt: DateTime.fromMillisecondsSinceEpoch(map['ended_at'] as int),
      initialPain: map['initial_pain'] as int,
      finalPain: map['final_pain'] as int,
      painDelta: map['pain_delta'] as int,
      exerciseType: map['exercise_type'] as String,
      actualDurationSeconds: map['actual_duration_secs'] as int,
      endedEarly: (map['ended_early'] as int) == 1,
      wasSuccessful: (map['was_successful'] as int) == 1,
      safetyEvent: map['safety_event'] as String?,
      sessionNumberInCycle: map['session_num_in_cycle'] as int,
    );
  }

  SessionRecord copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? endedAt,
    int? initialPain,
    int? finalPain,
    int? painDelta,
    String? exerciseType,
    int? actualDurationSeconds,
    bool? endedEarly,
    bool? wasSuccessful,
    String? safetyEvent,
    int? sessionNumberInCycle,
  }) {
    return SessionRecord(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      initialPain: initialPain ?? this.initialPain,
      finalPain: finalPain ?? this.finalPain,
      painDelta: painDelta ?? this.painDelta,
      exerciseType: exerciseType ?? this.exerciseType,
      actualDurationSeconds: actualDurationSeconds ?? this.actualDurationSeconds,
      endedEarly: endedEarly ?? this.endedEarly,
      wasSuccessful: wasSuccessful ?? this.wasSuccessful,
      safetyEvent: safetyEvent ?? this.safetyEvent,
      sessionNumberInCycle: sessionNumberInCycle ?? this.sessionNumberInCycle,
    );
  }

  @override
  String toString() {
    return 'SessionRecord(id: $id, startedAt: $startedAt, endedAt: $endedAt, '
        'initialPain: $initialPain, finalPain: $finalPain, painDelta: $painDelta, '
        'exerciseType: $exerciseType, actualDurationSeconds: $actualDurationSeconds, '
        'endedEarly: $endedEarly, wasSuccessful: $wasSuccessful, '
        'safetyEvent: $safetyEvent, sessionNumberInCycle: $sessionNumberInCycle)';
  }
}
