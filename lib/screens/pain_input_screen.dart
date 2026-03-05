/* 
  This screen allows the user to input their current pain level on a scale of 1-10. 
  The selected pain level is then passed to the ExerciseSelectionScreen to provide personalized exercise recommendations.
*/

import 'package:flutter/material.dart';
import 'exercise_selection_screen.dart';

class PainInputScreen extends StatefulWidget {
  const PainInputScreen({super.key});

  @override
  State<PainInputScreen> createState() => _PainInputScreenState();
}

class _PainInputScreenState extends State<PainInputScreen> {
  int _selectedPain = 1;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How is your pain right now?')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pain slider
              Slider(
                value: _selectedPain.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '$_selectedPain',
                onChanged: (value) {
                  setState(() {
                    _selectedPain = value.toInt();
                  });
                },
              ),
              const SizedBox(height: 32),

              // Pain label
              Text(
                '$_selectedPain - ${_painLabels[_selectedPain]!}',
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Continue button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExerciseSelectionScreen(
                        initialPain: _selectedPain,
                      ),
                    ),
                  );
                },
                child: const Text('Confirm and Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}