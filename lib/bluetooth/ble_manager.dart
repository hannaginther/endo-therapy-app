import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_constants.dart';

class BleManager extends ChangeNotifier {
// State variables
  bool _isScanning = false;
  bool _isConnected = false;
  String _lastReceivedData = '';
  final List<ScanResult> _scanResults = [];
  int _retryCount = 0;
  static const int maxRetries = 3;
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

// Getters
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  String get lastReceivedData => _lastReceivedData;
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);
  BluetoothDevice? get connectedDevice => _connectedDevice;
  BluetoothCharacteristic? get txCharacteristic => _txCharacteristic;
  bool get deviceUnavailable => ! _isConnected && !isScanning && _retryCount >= maxRetries;
  String? get safetyAlert => _safetyAlert;
  int get sessionCount => _sessionCount;
  bool get inCooldown => _inCooldown;
  int get cooldownSecondsRemaining => _cooldownSecondsRemaining;


// Start scanning for devices
  Future<void> startScan() async {
    _scanResults.clear();
    _isScanning = true;
    notifyListeners();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.advertisementData.serviceUuids
        .any((uuid) => uuid.toString() == BleConstants.serviceUuid)) {
          stopScan();
          connectTo(r.device);
          return;
        }
      }
    });

    // Stop scanning after timeout
    Future.delayed(const Duration(seconds: 10), () {
      if (!_isConnected) {
        _retryCount++;
        if(_retryCount < maxRetries) {
          debugPrint('BleManager: Device not found, retrying ($_retryCount/$maxRetries)');
          startScan(); // Retry scanning
        } else {
          debugPrint('BleManager: Device not found after $maxRetries attempts, prompt user. ');
            _isScanning = false;
            notifyListeners();
        }
      }
    });
  }

// Stop scanning for devices
  Future<void> stopScan() async {
     await FlutterBluePlus.stopScan();
     await _scanSubscription?.cancel();
    _isScanning = false;
    notifyListeners();
   }

// Connect to a device
  Future<void> connectTo(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;
      _isConnected = true;
      notifyListeners();

      await _discoverServices(device);

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });
  } catch (e) {
    debugPrint('BleManager: Connection error - $e');
     _isConnected = false;
     notifyListeners();
  }
 }


 Future<void> _discoverServices(BluetoothDevice device) async{
  final services = await device.discoverServices();
  for (final service in services) {
    if (service.uuid.toString() == BleConstants.serviceUuid) {
      for (final char in service.characteristics) {
        final uuid = char.uuid.toString();
        if (uuid == BleConstants.txCharacteristicUuid) {
          _txCharacteristic = char;
          await _subscribeToData(char);
        } else if (uuid == BleConstants.rxCharacteristicUuid) {
          _rxCharacteristic = char;
        }
      }
    }
  }
  notifyListeners();
 }

  Future<void> _subscribeToData(BluetoothCharacteristic char) async {
    await char.setNotifyValue(true);
    _dataSubscription = char.lastValueStream.listen((value) {
      if (value.isNotEmpty) {
        final message = utf8.decode(value);

        // Check if it's a safety alert        if (message.startsWith('SAFETY:'))
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
  

  Future<void> sendCommand (String command) async {
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
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _dataSubscription?.cancel();
    _connectedDevice = null;
    _txCharacteristic = null;
    _rxCharacteristic = null;
    _isConnected = false;
    _lastReceivedData = '';
    _safetyAlert = 'SAFETY:BLE_LOST';
    notifyListeners();
  }

  Future<void> resetAndScan() async {
    _retryCount = 0;
    await startScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _dataSubscription?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void incrementSessionCount() {
    _sessionCount++;
    notifyListeners();
  }

  void resetSessionCount() {
    _sessionCount = 0;
    notifyListeners();
  }

  void startCooldown() {
    _inCooldown = true;
    _cooldownSecondsRemaining = BleSessionLimits.cooldownDurationSeconds;
    notifyListeners();

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSecondsRemaining <= 0) {
        _cooldownTimer?.cancel();
        _inCooldown = false;
        _sessionCount = 0; // Reset session count after cooldown
        notifyListeners();
      } else {
        _cooldownSecondsRemaining--;
        notifyListeners();
      }
    });
  }

}
