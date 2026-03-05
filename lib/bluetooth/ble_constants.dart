/* Constants for Bluetooth
*/

// Debug mode for testing
const bool kDebugSkipBle = true;


class BleConstants {
  static const String deviceName = 'EndoSync';
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String txCharacteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String rxCharacteristicUuid = '6c88fae1-9bfb-4a9e-8f30-1d5a7c8b9f0c';
}

class BleSessionLimits{
  static const int sessionDurationSeconds = 600; // 10 minutes
  static const int maxSessionsPerUse = 2; // Max sessions before recommending a break or consultation
  static const int cooldownDurationSeconds = 1800; // 30 minutes cooldown after max sessions reached
}

class BleCommands {
  // Heat control (MOSFET on/off)
  static const String heatOn = 'HEAT_ON';
  static const String heatOff = 'HEAT_OFF';

  // Vibration control (DRV2605L haptic driver)
  static const String vibrateOn = 'VIBRATE_ON';
  static const String vibrateOff = 'VIBRATE_OFF';

  // Both together
  static const String bothOn = 'BOTH_ON';
  static const String allOff = 'ALL_OFF';

  // Request current temperature from MCP9808
  static const String readTemp = 'READ_TEMP';
}