/* SessionScreen.dart
 * This screen manages the active session
 * Sends correct BLE command to turn on heat/vibration when the session startes
 * Run a countdown timer
 * Show exercises guidance if selected
 * Send ALL_OFF when session ends
 * Navigate to EndScreen when session is complete for pain re-rank
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bluetooth/ble_manager.dart';
import '../bluetooth/ble_constants.dart';
import 'end_screen.dart';
import '../utils/event_log.dart';

class SessionScreen extends StatefulWidget {
  final int initialPain;
  final String exerciseType;
  final int sessionNumber;

  const SessionScreen({
    super.key,
    required this.initialPain,
    required this.exerciseType,
    required this.sessionNumber
  });

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late int _secondsRemaining;
  bool _sessionStarted = false;
  bool _sessionEnded = false;
  Timer? _timer;
  Timer? _keepaliveTimer;
  late BleManager _ble;
  DateTime? _startedAt;


  void _startSession() {
    final ble = _ble;
    _startedAt = DateTime.now();
    EventLog.instance.log('Session started. Exercise: ${widget.exerciseType}');

    // Send command to hardware to start session
    ble.sendCommand(BleCommands.bothOn); // For prototype, just turn on both

    setState(() {
      _sessionStarted = true;
    });

    // Keepalive: send READ_TEMP every 25 seconds so the Arduino's BLE timeout doesn't fire
    _keepaliveTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _sendReadTemp();
    });

    // Tick every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        _endSession(endedEarly: false);
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  void _sendReadTemp() {
    _ble.sendCommand(BleCommands.readTemp);
    EventLog.instance.log('READ_TEMP ping sent');
  }

  void _endSession({bool endedEarly = false}) {
    if (_sessionEnded) return;
    _sessionEnded = true;
    _timer?.cancel();
    _keepaliveTimer?.cancel();
    if (!mounted) return;

    final ble = _ble;
    ble.sendCommand(BleCommands.allOff); // Turn off hardware at end of session

    final actualDurationSeconds = BleSessionLimits.sessionDurationSeconds - _secondsRemaining;
    EventLog.instance.log('Session ended. Duration: ${actualDurationSeconds}s. Early: $endedEarly');
    if (actualDurationSeconds >= BleSessionLimits.minSessionDurationForCount) {
      _ble.incrementSessionCount(); // Only count sessions >= 5 min
    }

    if (ble.sessionCount >= BleSessionLimits.maxSessionsPerUse) {
      ble.startCooldown();
    }

    final safetyEvent = _ble.safetyAlert;

    // Navigate to EndScreen after short delay to show session ended state
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EndScreen(
          initialPain: widget.initialPain,
          sessionNumber: widget.sessionNumber,
          exerciseType: widget.exerciseType,
          startedAt: _startedAt ?? DateTime.now(),
          actualDurationSeconds: actualDurationSeconds,
          endedEarly: endedEarly,
          safetyEvent: safetyEvent,
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session'),
        automaticallyImplyLeading: false, // Disable back button
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Timer display
                Text(
                  _formatTime(_secondsRemaining),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 64, 
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()], // Monospaced digits,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('remaining', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 48),

                // Exercise guidance (placeholder)
                if (_sessionStarted) _buildExerciseGuidance(),

                const SizedBox(height: 48),


                // Start / Stop button
                if (!_sessionStarted)
                  ElevatedButton(
                    onPressed: _startSession,
                    child: const Text('Start Session'),
                  )
                else
                  OutlinedButton(
                    onPressed: () => _endSession(endedEarly: true),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('End Session Early'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
            
  Widget _buildExerciseGuidance() {
    switch (widget.exerciseType) {
      case 'breathing':
        return const Column(
          children: [
            Icon(Icons.air, size: 40, color: Colors.blue),
            SizedBox(height: 8),
            Text('Breathe in for 4 seconds...\nHold for 4 seconds...\nBreathe out for 4 seconds...', 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        );
      case 'physical':
        return const Column(
          children: [
            Icon(Icons.self_improvement, size: 40, color: Colors.green),
            SizedBox(height: 8),
            Text('Follow the guided physical exercise on your device screen.', 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        );
      case 'both':
        return const Column(
          children: [
            Icon(Icons.favorite, size: 40, color: Colors.purple),
            SizedBox(height: 8),
            Text('Combine breathing and physical exercises as guided on your device.', 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        );
        default:
          return const Text(
            'Device active. \nRest and relax.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          );
    }
  }
  
    void _handleSafetyShutoff(String alert) {
      EventLog.instance.log('Safety shutoff triggered: ${_ble.safetyAlert}');
      _endSession(endedEarly: false);
      if (!mounted) return;
      // Show alert dialog to user

      String message;
      if (alert.contains('TEMP_HIGH')) {
        message = 'Device temperature exceeded safe limit (42°C). Session ended automatically for your safety.';
      } else if (alert.contains('BLE_LOST')) {
        message = 'Bluetooth connection lost. Session ended and device shut off.';
      } else if (alert.contains('BLE_TIMEOUT')) {
        message = 'No activity was detected for 11 minutes. Session ended automatically for your safety.';
      } else if (alert.contains('COMPONENT_FAIL')) {
        message = 'A hardware fault was detected. Session ended automatically for your safety.';
      } else {
        message = 'A safety issue was detected. Session ended automatically for your safety.';
      }
      
      showDialog(
        context: context,
        barrierDismissible: false, // User must tap button to dismiss
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Session Ended'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                _ble.clearSafetyAlert();
                Navigator.of(context).pop(); // Dismiss dialog; user proceeds to EndScreen to save record
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

  @override
  void initState() {
    super.initState();
    _secondsRemaining = BleSessionLimits.sessionDurationSeconds;
    _ble = context.read<BleManager>();
    // Listen for safety alerts from BleManager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ble.addListener(_checkSafetyAlert);
    });
  }

  void _checkSafetyAlert() {
    if (!mounted) return;
    final alert = _ble.safetyAlert;
    if (alert != null && _sessionStarted && !_sessionEnded) {
      setState(() => _sessionEnded = true); // Prevent multiple dialogs if multiple alerts come in
      _handleSafetyShutoff(alert);
    }
  }

  @override
  void dispose() {
    _ble.removeListener(_checkSafetyAlert);
    _timer?.cancel();
    _keepaliveTimer?.cancel();
    if (!_sessionEnded) {
      _ble.sendCommand(BleCommands.allOff);
    }
    super.dispose();  
  }
}

