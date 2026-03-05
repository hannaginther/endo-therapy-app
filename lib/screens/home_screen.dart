/* 
  HomeScreen: Main landing page of the app. Displays connection status and allows navigation to pain input screen.
  Shows a retry prompt if BLE device is not found after multiple attempts.
*/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bluetooth/ble_manager.dart';
import '../bluetooth/ble_constants.dart';
import 'pain_input_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleManager>();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Main app content goes here
            _buildMainContent(context, ble),

            // Status indicator (BLE) always floats in top-right corner
            Positioned(
              top: 16,
              right: 16,
              child: _buildStatusIndicator(ble),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, BleManager ble) {
    // Device unavailable - show retry prompt
    if (ble.deviceUnavailable) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Device not found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Make sure your device is powered on and nearby.',
              textAlign: TextAlign.center,
            ),  
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ble.resetAndScan(),
              child: const Text('Try Connecting Again'),
            ),

            // Debug Only
            if (kDebugSkipBle) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'DEBUG MODE',
                style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 2),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PainInputScreen()),
                  );
                },
                child: const Text('Skip BLE — Test UI Flow'),
              ),
            ],
          ],
        ),
      );
    }

    if (ble.inCooldown) {
      final mins = (ble.cooldownSecondsRemaining ~/ 60).toString().padLeft(2, '0');
      final secs = (ble.cooldownSecondsRemaining % 60).toString().padLeft(2, '0');

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text ('Cooldown Period',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Please wait before starting another session.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Text('$mins:$secs',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('until next session available',
              style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    // Connected - show main app content
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children:[
          const Text(
            'EndoSync',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PainInputScreen()),
                );
            },
            child: const Text('Log your pain to begin a session'),
          ),

          // Debug only - skip BLE requirement for UI testing
          if (kDebugSkipBle) ...[
            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'DEBUG MODE',
              style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PainInputScreen()),
                );
              },
              child: const Text('Skip BLE - Test UI Flow'),
            )
          ]
        ],
      ),
    );
  }
    Widget _buildStatusIndicator(BleManager ble) {
      Color color;
      String tooltip;

      if (ble.isConnected) {
        color = Colors.green;
        tooltip = 'Connected';
      } else if (ble.isScanning) {
        color = Colors.amber;
        tooltip = 'Searching...';
      } else {
        color = Colors.red;
        tooltip = 'Disconnected';
      }

      return Tooltip(
        message: tooltip,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
}