/* SessionCompleteScreen
 * Shown after a successful session where final pain < initial pain.
 * Displays both scores and a positive message, then lets the user return home.
 */

import 'package:flutter/material.dart';

class SessionCompleteScreen extends StatelessWidget {
  final int initialPain;
  final int finalPain;

  const SessionCompleteScreen({
    super.key,
    required this.initialPain,
    required this.finalPain,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Complete'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 72, color: Colors.green),
                const SizedBox(height: 24),
                const Text(
                  'Great progress!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your pain went from $initialPain to $finalPain.',
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
