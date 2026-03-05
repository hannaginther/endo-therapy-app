/* After session ends
  * Show EndScreen to allow user to re-rank pain and provide feedback on session
  * Compare new score to initial pain to track improvement
  * Either complete the session or send the user back for another round
  */

import 'package:flutter/material.dart';
import 'package:prototype_app/bluetooth/ble_constants.dart';

class EndScreen extends StatefulWidget {
  final int initialPain;
  final int sessionNumber;

  const EndScreen({
    super.key,
    required this.initialPain,
    required this.sessionNumber,
    });

  @override
  State<EndScreen> createState() => _EndScreenState();
}

class _EndScreenState extends State<EndScreen> {
  int _finalPain = 1;

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

  void _submitFinalPain(BuildContext context) {
    final bool canRepeat = widget.sessionNumber < BleSessionLimits.maxSessionsPerUse;

    if (_finalPain<widget.initialPain) {
      // Pain decreased - session successful
      _showResultDialog(
        context,
        success: true,
        canRepeat: false, // No need to repeat if successful, but could offer if we want to encourage more sessions
        message: 'Your pain has decreased from ${widget.initialPain} to $_finalPain! Great progress!',
      );
    } else if (!canRepeat) {
      // Max sessions reached - end program
      _showResultDialog(
        context,
        success: false,
        canRepeat: false,
        message: 'Your pain hasn\'t decreased, but you\'ve reached the maximum safe usage of 20 minutes. Please rest.',
      );
    } else {
      // Pain unchanged or increased - offer another session
      _showResultDialog(
        context,
        success: false,
        canRepeat: true,
        message: 'Your pain hasn\'t decreased. Would you like to try another session?',
      );
    }
  }
  
  void _showResultDialog(
    BuildContext context, {
    required bool success,
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
              success ? Icons.check_circle : (canRepeat ? Icons.refresh : Icons.warning),
              color: success ? Colors.green : (canRepeat ? Colors.orange : Colors.red),
            ),
            const SizedBox(width: 8),
            Text(success ? 'Session Complete!' : (canRepeat ? 'Try Again?' : 'Session Limit Reached')),
          ],
        ),
        content: Text(message),
        actions: [
          if (canRepeat)
            TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                // Note - home screen will restart flow with sessionNumber incremented
              },
              child: const Text('Try Again'),
            ),
          TextButton(
            onPressed: () {
              // Pop all screens back to home to start fresh
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Try Again'),
          ),
        TextButton(
           onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: Text(success ? 'Done' : 'End Session'),
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
               onPressed: () => _submitFinalPain(context),
              child: const Text('Submit'),
             ),
            ],
          ),
        ),
      ),
    );
  }
}