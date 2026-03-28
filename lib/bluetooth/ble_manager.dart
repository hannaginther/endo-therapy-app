import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_constants.dart';
import '../utils/event_log.dart';

class BleManager extends ChangeNotifier {
// State variables
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  String _lastReceivedData = '';
  final List<ScanResult> _scanResults = [];
  String? _connectionError;
  String? _safetyAlert;
  int _sessionCount = 0;
  bool _inCooldown = false;
  int _cooldownSecondsRemaining = 0;
  Timer? _cooldownTimer;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;

  StreamSubscription? _scanSubscription;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _connectionStateSubscription;

// Getters
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  String get lastReceivedData => _lastReceivedData;
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);
  BluetoothDevice? get connectedDevice => _connectedDevice;
  BluetoothCharacteristic? get txCharacteristic => _txCharacteristic;
  String? get connectionError => _connectionError;
  String? get safetyAlert => _safetyAlert;
  int get sessionCount => _sessionCount;
  bool get inCooldown => _inCooldown;
  int get cooldownSecondsRemaining => _cooldownSecondsRemaining;


// Start scanning — collects all nearby devices for the user to pick from.
// Does NOT auto-connect; the UI calls connectTo() on user selection.
  Future<void> startScan() async {
    await _scanSubscription?.cancel();
    _scanResults.clear();
    _connectionError = null;
    _isScanning = true;
    _isConnecting = false;
    notifyListeners();

    // On iOS, CoreBluetooth initialises asynchronously and starts in
    // CBManagerStateUnknown. Wait up to 3 s for a known state before scanning.
    final adapterState = await FlutterBluePlus.adapterState
        .where((s) => s != BluetoothAdapterState.unknown)
        .first
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => BluetoothAdapterState.unknown,
        );

    if (adapterState != BluetoothAdapterState.on) {
      _connectionError = 'Bluetooth is not available. Please enable Bluetooth in Settings and try again.';
      _isScanning = false;
      notifyListeners();
      return;
    }

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults.clear();
      _scanResults.addAll(results);
      notifyListeners();
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(BleConstants.serviceUuid)],
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      _connectionError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

// Stop scanning early (e.g. user taps "Stop" or we start connecting)
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _isScanning = false;
    notifyListeners();
  }

// Connect to a specific device chosen by the user
  Future<void> connectTo(BluetoothDevice device) async {
    _isConnecting = true;
    _connectionError = null;
    _safetyAlert = null; // Clear any stale safety alert from a previous session
    notifyListeners();

    // Stop scanning before connecting
    if (_isScanning) await stopScan();

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      // Subscribe to connection state BEFORE service discovery so we catch
      // an unexpected disconnect that happens during discovery.
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });

      await _discoverServices(device);

      _isConnected = true;
      _isConnecting = false;
      notifyListeners();
    } catch (e) {
      // Surface the raw error so the UI can show it
      _connectionError = e.toString().replaceFirst('Exception: ', '');
      _isConnected = false;
      _isConnecting = false;
      notifyListeners();
    }
  }


  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid.toString().toLowerCase() == BleConstants.serviceUuid.toLowerCase()) {
        for (final char in service.characteristics) {
          final uuid = char.uuid.toString().toLowerCase();
          if (uuid == BleConstants.txCharacteristicUuid.toLowerCase()) {
            _txCharacteristic = char;
            await _subscribeToData(char);
            debugPrint('BleManager: TX characteristic found and subscribed.');
          } else if (uuid == BleConstants.rxCharacteristicUuid.toLowerCase()) {
            _rxCharacteristic = char;
            debugPrint('BleManager: RX characteristic found.');
          }
        }
      }
    }
    if (_txCharacteristic == null || _rxCharacteristic == null) {
      debugPrint('BleManager: WARNING - characteristics not found after service discovery.');
    }
  }

  Future<void> _subscribeToData(BluetoothCharacteristic char) async {
    await char.setNotifyValue(true);
    _dataSubscription = char.lastValueStream.listen((value) {
      if (value.isNotEmpty) {
        final message = utf8.decode(value);
        if (message.startsWith('SAFETY:')) {
          _safetyAlert = message;
          debugPrint('BleManager: Received safety alert - $message');
        } else {
          _lastReceivedData = message;
        }
        notifyListeners();
      }
    });
  }

  void clearSafetyAlert() {
    _safetyAlert = null;
    notifyListeners();
  }

  Future<void> sendCommand(String command) async {
    if (_rxCharacteristic == null || !_isConnected) return;
    try {
      final bytes = utf8.encode(command);
      await _rxCharacteristic!.write(bytes, withoutResponse: false);
    } catch (e) {
      debugPrint('BleManager: Error sending command - $e');
    }
  }

  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    // _handleDisconnect() is called by the connectionState listener — not here
  }

  void _handleDisconnect() {
    final wasConnected = _isConnected;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _dataSubscription?.cancel();
    _isConnecting = false;
    _connectedDevice = null;
    _txCharacteristic = null;
    _rxCharacteristic = null;
    _isConnected = false;
    _lastReceivedData = '';
    // Only raise BLE_LOST when we had an established connection.
    // Avoids a stale alert showing up at the start of the next session.
    if (wasConnected) {
      _safetyAlert = 'SAFETY:BLE_LOST';
    }
    notifyListeners();
  }

  Future<void> resetAndScan() async {
    await startScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _dataSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void incrementSessionCount() {
    _sessionCount++;
    EventLog.instance.log('Session count incremented to $_sessionCount');
    notifyListeners();
  }

  void resetSessionCount() {
    _sessionCount = 0;
    EventLog.instance.log('Session count reset. Cooldown cleared.');
    notifyListeners();
  }

  void startCooldown() {
    _inCooldown = true;
    _cooldownSecondsRemaining = BleSessionLimits.cooldownDurationSeconds;
    EventLog.instance.log('Cooldown started. ${BleSessionLimits.cooldownDurationSeconds}s');
    notifyListeners();

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSecondsRemaining <= 0) {
        _cooldownTimer?.cancel();
        _inCooldown = false;
        _sessionCount = 0;
        notifyListeners();
      } else {
        _cooldownSecondsRemaining--;
        notifyListeners();
      }
    });
  }
}
