/*
  HomeScreen: Main landing page of the app.
  States (in priority order):
    1. Cooldown      — mandatory rest between sessions
    2. Connected     — ready to start a session
    3. Connecting    — connection attempt in progress
    4. Scanning      — showing live list of discovered devices
    5. Idle          — waiting for user to tap "Scan"
*/

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../bluetooth/ble_manager.dart';
import '../bluetooth/ble_constants.dart';
import 'history_screen.dart';
import 'pain_input_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleManager>();

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _buildBody(context, ble),
            Positioned(
              top: 16,
              right: 16,
              child: _buildStatusDot(ble),
            ),
          ],
        ),
      ),
    );
  }

  // ── State router ──────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, BleManager ble) {
    if (ble.inCooldown) return _buildCooldown(ble);
    if (ble.isConnected) return _buildConnected(context, ble);
    if (ble.isConnecting) return _buildConnecting(ble);
    return _buildScanner(context, ble);
  }

  // ── 1. Cooldown ───────────────────────────────────────────────────────────

  Widget _buildCooldown(BleManager ble) {
    final mins = (ble.cooldownSecondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secs = (ble.cooldownSecondsRemaining % 60).toString().padLeft(2, '0');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer, size: 48, color: Colors.orange),
          const SizedBox(height: 16),
          const Text('Cooldown Period',
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

  // ── 2. Connected ──────────────────────────────────────────────────────────

  Widget _buildConnected(BuildContext context, BleManager ble) {
    final deviceName = ble.connectedDevice?.platformName ?? BleConstants.deviceName;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('EndoSync',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Connected to $deviceName',
              style: const TextStyle(color: Colors.green)),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PainInputScreen()),
            ),
            child: const Text('Log your pain to begin a session'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => ble.disconnect(),
            child: const Text('Disconnect', style: TextStyle(color: Colors.grey)),
          ),

          // Debug only
          if (kDebugSkipBle) ...[
            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 8),
            const Text('DEBUG MODE',
                style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 2)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PainInputScreen()),
              ),
              child: const Text('Skip BLE — Test UI Flow'),
            ),
          ],
        ],
      ),
    );
  }

  // ── 3. Connecting ─────────────────────────────────────────────────────────

  Widget _buildConnecting(BleManager ble) {
    final name = ble.connectedDevice?.platformName ?? 'device';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text('Connecting to $name…',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          const Text('This may take a few seconds.',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ── 4 & 5. Scanner (idle + scanning + results) ────────────────────────────

  Widget _buildScanner(BuildContext context, BleManager ble) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('EndoSync',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Select your device below to connect.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.power_settings_new, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Make sure your EndoSync device is turned on before scanning.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Connection error banner
          if (ble.connectionError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(ble.connectionError!,
                        style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Device list
          Expanded(child: _buildDeviceList(ble)),

          const SizedBox(height: 16),

          // Scan button
          ElevatedButton.icon(
            onPressed: ble.isScanning ? null : () => ble.startScan(),
            icon: ble.isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.bluetooth_searching),
            label: Text(ble.isScanning ? 'Scanning…' : 'Device is turned ON. Scan for device'),
          ),

          // Debug only
          if (kDebugSkipBle) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text('DEBUG MODE',
                style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 2),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PainInputScreen()),
              ),
              child: const Text('Skip BLE — Test UI Flow'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceList(BleManager ble) {
    // Pre-filter to only EndoSync devices so the empty-state message is shown
    // correctly even when other BLE devices are nearby.
    final endosyncResults = ble.scanResults.where((r) {
      final name = r.advertisementData.advName.isNotEmpty
          ? r.advertisementData.advName
          : r.device.platformName;
      return name.contains(BleConstants.deviceName);
    }).toList();

    if (endosyncResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              ble.isScanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              ble.isScanning ? 'Looking for devices…' : 'No devices found.\nTap Scan to search.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: endosyncResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) => _DeviceTile(
        result: endosyncResults[i],
        onConnect: () => ble.connectTo(endosyncResults[i].device),
      ),
    );
  }

  // ── Status dot (top-right) ─────────────────────────────────────────────────

  Widget _buildStatusDot(BleManager ble) {
    final Color color;
    final String tooltip;

    if (ble.isConnected) {
      color = Colors.green;
      tooltip = 'Connected';
    } else if (ble.isConnecting || ble.isScanning) {
      color = Colors.amber;
      tooltip = ble.isConnecting ? 'Connecting…' : 'Scanning…';
    } else {
      color = Colors.red;
      tooltip = 'Disconnected';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

// ── Device list tile ──────────────────────────────────────────────────────────
//
// Displays one discovered BLE device. Called for every entry in scanResults.
// The ScanResult gives you:
//   result.advertisementData.advName  — name broadcast in the BLE advertisement
//   result.device.platformName        — name cached by the OS (may differ)
//   result.rssi                       — signal strength in dBm (~-40 strong, ~-90 weak)
//
// BleConstants.deviceName == 'EndoSync' — use this to identify the target device.

class _DeviceTile extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onConnect;

  const _DeviceTile({required this.result, required this.onConnect});

  /// Maps RSSI to 0-3 bars: 0 = no signal, 3 = strong.
  int _signalBars(int rssi) {
    if (rssi >= -60) return 3;
    if (rssi >= -75) return 2;
    if (rssi >= -85) return 1;
    return 0;
  }

  Widget _buildSignalIcon(int rssi) {
    final bars = _signalBars(rssi);
    final IconData icon;
    switch (bars) {
      case 3:
        icon = Icons.signal_cellular_alt;
      case 2:
        icon = Icons.signal_cellular_alt_2_bar;
      case 1:
        icon = Icons.signal_cellular_alt_1_bar;
      default:
        icon = Icons.signal_cellular_0_bar;
    }
    final color = bars >= 2 ? Colors.green : (bars == 1 ? Colors.orange : Colors.red);
    return Tooltip(
      message: '$rssi dBm',
      child: Icon(icon, size: 20, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = result.advertisementData.advName.isNotEmpty
        ? result.advertisementData.advName
        : result.device.platformName;

    // Only show EndoSync devices
    if (name != BleConstants.deviceName) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.bluetooth, color: Colors.blue, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(result.device.remoteId.str,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            _buildSignalIcon(result.rssi),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onConnect,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}
