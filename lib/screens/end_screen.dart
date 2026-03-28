/* After session ends
  * Show EndScreen to allow user to re-rank pain and provide feedback on session
  * Compare new score to initial pain to track improvement
  * Either complete the session or send the user back for another round
  */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bluetooth/ble_manager.dart';
import '../bluetooth/ble_constants.dart';
import '../data/models/session_record.dart';
import '../providers/session_history_provider.dart';
import 'exercise_selection_screen.dart';
import 'session_complete_screen.dart';
import '../utils/event_log.dart';

class EndScreen extends StatefulWidget {
  final int initialPain;
  final int sessionNumber;
  final String exerciseType;
  final DateTime startedAt;
  final int actualDurationSeconds;
  final bool endedEarly;
  final String? safetyEvent;

  const EndScreen({
    super.key,
    required this.initialPain,
    required this.sessionNumber,
    required this.exerciseType,
    required this.startedAt,
    required this.actualDurationSeconds,
    required this.endedEarly,
    this.safetyEvent,
  });

  @override
  State<EndScreen> createState() => _EndScreenState();
}

class _EndScreenState extends State<EndScreen> {
  int _finalPain = 1;
  bool _isSubmitting = false;

  final Map<int, String> _painLabels = {
    1: 'Minimal pain',
    2: 'Mild pain',
    3: 'Mild pain',
    4: 'Moderate pain',
    5: 'Moderate pain',
    6: 'Severe pain',
    7: 'Severe pain',
    8: 'Very severe pain',
    9: 'Very severe pain',
    10: 'Worst possible pain',
  };

  Future<void> _submitFinalPain(BuildContext context) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final ble = context.read<BleManager>();
    // Check against current session count (already incremented by _endSession)
    final bool canRepeat = ble.sessionCount < BleSessionLimits.maxSessionsPerUse;

    final record = SessionRecord.create(
      startedAt: widget.startedAt,
      endedAt: DateTime.now(),
      initialPain: widget.initialPain,
      finalPain: _finalPain,
      exerciseType: widget.exerciseType,
      actualDurationSeconds: widget.actualDurationSeconds,
      endedEarly: widget.endedEarly,
      safetyEvent: widget.safetyEvent,
      sessionNumberInCycle: widget.sessionNumber,
    );
    await context.read<SessionHistoryProvider>().saveSession(record);
    EventLog.instance.log('Final pain submitted: $_finalPain. Saved: ${record.wasSuccessful}');

    if (!context.mounted) return;

    if (_finalPain < widget.initialPain) {
      // Pain decreased — navigate directly to success screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SessionCompleteScreen(
            initialPain: widget.initialPain,
            finalPain: _finalPain,
          ),
        ),
      );
    } else if (!canRepeat) {
      // Max sessions reached with no improvement
      _showResultDialog(
        context,
        canRepeat: false,
        message: 'Your pain hasn\'t decreased, but you\'ve reached the maximum safe usage of 20 minutes. Please rest.',
      );
    } else {
      // Pain unchanged or increased — offer another session
      _showResultDialog(
        context,
        canRepeat: true,
        message: 'Your pain hasn\'t decreased. Would you like to try another session?',
      );
    }
  }

  void _showResultDialog(
    BuildContext context, {
    required bool canRepeat,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              canRepeat ? Icons.refresh : Icons.warning,
              color: canRepeat ? Colors.orange : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(canRepeat ? 'Try Again?' : 'Session Limit Reached'),
          ],
        ),
        content: Text(message),
        actions: [
          if (canRepeat)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // dismiss dialog
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ExerciseSelectionScreen(
                      initialPain: widget.initialPain,
                      sessionNumber: context.read<BleManager>().sessionCount,
                    ),
                  ),
                );
              },
              child: const Text('Try Again'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How is your pain now?'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Show initial pain score for reference
              Text(
                'Your pain before: ${widget.initialPain}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Pain slider
              Slider(
                value: _finalPain.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '$_finalPain',
                onChanged: (value) {
                  setState(() {
                    _finalPain = value.toInt();
                  });
                },
              ),
              const SizedBox(height: 16),

              // Pain label
              Text(
                '$_finalPain - ${_painLabels[_finalPain]!}',
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              ElevatedButton(
                onPressed: _isSubmitting ? null : () => _submitFinalPain(context),
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
