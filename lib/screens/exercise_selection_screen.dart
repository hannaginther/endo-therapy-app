/*
  ExerciseSelectionScreen: Allows user to choose between guided breathing, physical exercise, both, or no exercise before starting the session.
*/

import 'package:flutter/material.dart';
import 'session_screen.dart';
import '../utils/event_log.dart';

class ExerciseSelectionScreen extends StatefulWidget {
  final int initialPain;
  final int sessionNumber;

  const ExerciseSelectionScreen({
    super.key,
    required this.initialPain,
    this.sessionNumber = 0,
  });

  @override
  State<ExerciseSelectionScreen> createState() => _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState extends State<ExerciseSelectionScreen> {
  String? _selectedExercise; // null until user selects
  bool _timingLogged = false;

  @override
  void initState() {
    super.initState();
    if (!_timingLogged) { _timingLogged = true; EventLog.instance.log('TIMING: ExerciseSelectionScreen appeared'); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Exercise Type')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Choose what to do during your session:',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Exercise options
              _ExerciseOption(
                label: 'Guided Breathing',
                description: 'Relax with a calming breathing exercise.',
                value: 'breathing',
                groupValue: _selectedExercise,
                onChanged: (val) => setState(() => _selectedExercise = val),
              ),
              const SizedBox(height: 12),

              _ExerciseOption(
                label: 'Guided Physical Exercise',
                description: 'Follow gentle physical movements to ease tension.',
                value: 'physical',
                groupValue: _selectedExercise,
                onChanged: (val) => setState(() => _selectedExercise = val),
              ),
              const SizedBox(height: 12),

              _ExerciseOption(
                label: 'Breathing + Physical',
                description: 'Combine breathing and movement for deeper relaxation.',
                value: 'both',
                groupValue: _selectedExercise,
                onChanged: (val) => setState(() => _selectedExercise = val),
              ),
              const SizedBox(height: 12),

              _ExerciseOption(
                label: 'No Exercise',
                description: 'Device therapy only, no guided exercises.',
                value: 'none',
                groupValue: _selectedExercise,
                onChanged: (val) => setState(() => _selectedExercise = val),
              ),

              const SizedBox(height: 48),

              // Continue button
              ElevatedButton(
                onPressed: _selectedExercise == null
                    ? null
                    : () {
                        EventLog.instance.log('TIMING: StartSessionTapped');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SessionScreen(
                              initialPain: widget.initialPain,
                              exerciseType: _selectedExercise!,
                              sessionNumber: widget.sessionNumber,
                            ),
                          ),
                        );
                      },
                child: const Text('Start Session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable widget for each option row
class _ExerciseOption extends StatelessWidget {
  final String label;
  final String description;
  final String value;
  final String? groupValue;
  final ValueChanged<String?> onChanged;

  const _ExerciseOption({
    required this.label,
    required this.description,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(description),
      leading: Radio<String>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
      ),
      onTap: () => onChanged(value),
    );
  } 
}
            