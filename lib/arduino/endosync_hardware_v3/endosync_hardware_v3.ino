// Libraries
#include <ArduinoBLE.h>
#include <Wire.h>
#include <Adafruit_MCP9808.h>
#include <Adafruit_DRV2605.h>

// Pin assignments
#define HEAT_PIN    D5   // GPIO8  - MOSFET gate (heater)
#define SWITCH_PIN  D6   // Switch input (internal pull-up, connect other side to GND)
#define LED_PIN     D9   // LED output (on when device is active)
#define MAX_TEMP    42.0 // Safety cutoff temperature in Celsius

// BLE UUIDs (must match ble_constants.dart exactly)
#define SERVICE_UUID      "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define TX_CHARACTERISTIC "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define RX_CHARACTERISTIC "6c88fae1-9bfb-4a9e-8f30-1d5a7c8b9f0c"

// BLE objects
BLEService endosyncService(SERVICE_UUID);
BLEStringCharacteristic rxCharacteristic(RX_CHARACTERISTIC, BLEWrite,  20);
BLEStringCharacteristic txCharacteristic(TX_CHARACTERISTIC, BLENotify, 20);

// Hardware objects
Adafruit_MCP9808 tempSensor;
Adafruit_DRV2605 hapticDriver;

// State variables
bool heatActive     = false;
bool vibrateActive  = false;
bool tempSensorOk   = false;
bool hapticDriverOk = false;
bool deviceActive   = false;  // true when switch is ON

unsigned long lastCommandTime = 0;
const unsigned long BLE_TIMEOUT_MS = 660000UL; // 11 minutes


// ── Timestamp logger ───────────────────────────────────────────────────────
// Prefixes every message with the Arduino uptime in milliseconds so timing
// intervals can be read directly from the Serial Monitor without a stopwatch.

void logEvent(const char* msg) {
  Serial.print("[");
  Serial.print(millis());
  Serial.print(" ms] ");
  Serial.println(msg);
}

void logEvent(const String& msg) {
  Serial.print("[");
  Serial.print(millis());
  Serial.print(" ms] ");
  Serial.println(msg);
}


// ── Setup ──────────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  delay(1500); // Wait for native USB-CDC to enumerate on Nano ESP32
  logEvent("Endosync booting...");

  // Pin modes
  pinMode(HEAT_PIN,   OUTPUT);
  pinMode(LED_PIN,    OUTPUT);
  pinMode(SWITCH_PIN, INPUT_PULLUP); // Internal pull-up — no external resistor needed

  digitalWrite(HEAT_PIN, LOW);
  digitalWrite(LED_PIN,  LOW); // LED off at boot

  Wire.begin();

  // MCP9808 temperature sensor
  if (!tempSensor.begin(0x18)) {
    logEvent("WARNING: MCP9808 not found. Temperature safety disabled.");
    tempSensorOk = false;
  } else {
    tempSensor.setResolution(3);
    tempSensorOk = true;
    logEvent("MCP9808 ready.");
  }

  // DRV2605L haptic driver
  if (!hapticDriver.begin()) {
    logEvent("WARNING: DRV2605 not found. Vibration disabled.");
    hapticDriverOk = false;
  } else {
    hapticDriver.selectLibrary(1);
    hapticDriver.setMode(DRV2605_MODE_INTTRIG);
    hapticDriverOk = true;
    logEvent("DRV2605L ready.");
  }

  // Initialise BLE stack but do NOT advertise yet —
  // advertising starts only when the switch is turned ON.
  if (!BLE.begin()) {
    logEvent("ERROR: BLE failed to start.");
    while (1);
  }

  BLE.setLocalName("EndoSync");
  BLE.setAdvertisedService(endosyncService);
  endosyncService.addCharacteristic(rxCharacteristic);
  endosyncService.addCharacteristic(txCharacteristic);
  BLE.addService(endosyncService);
  // BLE.advertise() is NOT called here

  logEvent("BLE ready. Waiting for switch...");
}


// ── Safety shutoff ─────────────────────────────────────────────────────────

void safetyShutoff(String reason) {
  digitalWrite(HEAT_PIN, LOW);
  digitalWrite(LED_PIN,  LOW); // LED off on safety event
  if (hapticDriverOk) hapticDriver.stop();
  heatActive    = false;
  vibrateActive = false;
  deviceActive  = false;

  String alert = "SAFETY:" + reason;
  txCharacteristic.writeValue(alert);

  logEvent("SAFETY SHUTOFF: " + reason);
}


// ── Command handler ────────────────────────────────────────────────────────

void handleCommand(String command) {
  // Always allow READ_TEMP so BLE keepalive pings work.
  // Block all other therapy commands if switch is off.
  if (!deviceActive && command != "READ_TEMP") {
    logEvent("Command ignored — device inactive (switch off).");
    return;
  }

  logEvent("Received: " + command);

  if (command == "HEAT_ON") {
    digitalWrite(HEAT_PIN, HIGH);
    heatActive = true;
    txCharacteristic.writeValue("HEAT_ON");

  } else if (command == "HEAT_OFF") {
    digitalWrite(HEAT_PIN, LOW);
    heatActive = false;
    txCharacteristic.writeValue("HEAT_OFF");

  } else if (command == "VIBRATE_ON") {
    if (hapticDriverOk) {
      hapticDriver.setWaveform(0, 14); // waveform 14 = continuous buzz
      hapticDriver.setWaveform(1, 0);  // end of sequence
      hapticDriver.go();
      vibrateActive = true;
    }
    txCharacteristic.writeValue("VIBRATE_ON");

  } else if (command == "VIBRATE_OFF") {
    if (hapticDriverOk) hapticDriver.stop();
    vibrateActive = false;
    txCharacteristic.writeValue("VIBRATE_OFF");

  } else if (command == "BOTH_ON") {
    digitalWrite(HEAT_PIN, HIGH);
    heatActive = true;
    if (hapticDriverOk) {
      hapticDriver.setWaveform(0, 14);
      hapticDriver.setWaveform(1, 0);
      hapticDriver.go();
      vibrateActive = true;
    }
    txCharacteristic.writeValue("BOTH_ON");

  } else if (command == "ALL_OFF") {
    digitalWrite(HEAT_PIN, LOW);
    if (hapticDriverOk) hapticDriver.stop();
    heatActive    = false;
    vibrateActive = false;
    txCharacteristic.writeValue("ALL_OFF");

  } else if (command == "READ_TEMP") {
    if (tempSensorOk) {
      float temp = tempSensor.readTempC();
      String response = "TEMP:" + String(temp, 1);
      txCharacteristic.writeValue(response);
      logEvent(response);
    } else {
      txCharacteristic.writeValue("TEMP:ERROR");
      logEvent("TEMP:ERROR");
    }

  } else {
    logEvent("Unknown command.");
  }
}


// ── Main loop ──────────────────────────────────────────────────────────────

void loop() {

  // ── Switch state check ────────────────────────────────────────────────
  bool switchOn = (digitalRead(SWITCH_PIN) == LOW);

  if (switchOn && !deviceActive) {
    // Switch just turned ON — enable device and start BLE advertising
    deviceActive = true;
    digitalWrite(LED_PIN, HIGH);
    BLE.advertise();
    logEvent("Device ON — BLE advertising.");
  }

  if (!switchOn && deviceActive) {
    // Switch just turned OFF — cut all outputs and stop BLE advertising
    deviceActive = false;
    digitalWrite(LED_PIN,  LOW);
    digitalWrite(HEAT_PIN, LOW);
    if (hapticDriverOk) hapticDriver.stop();
    heatActive    = false;
    vibrateActive = false;
    BLE.stopAdvertise();
    logEvent("Device OFF — BLE stopped.");
  }

  // If device is off, nothing else to do
  if (!deviceActive) {
    delay(50);
    return;
  }

  // ── Standalone temperature print (no BLE connection) ─────────────────
  static unsigned long lastStandaloneTemp = 0;
  if (tempSensorOk && millis() - lastStandaloneTemp >= 2000) {
    lastStandaloneTemp = millis();
    float temp = tempSensor.readTempC();
    logEvent("Temp: " + String(temp, 1));
  }

  // ── BLE central connection ────────────────────────────────────────────
  BLEDevice central = BLE.central();

  if (central) {
    logEvent(String("Connected to: ") + central.address());
    lastCommandTime = millis();

    while (central.connected()) {

      // ── Check switch inside connected loop ──
      // If user turns switch off mid-session, cut everything immediately
      switchOn = (digitalRead(SWITCH_PIN) == LOW);
      if (!switchOn && deviceActive) {
        deviceActive = false;
        digitalWrite(LED_PIN,  LOW);
        digitalWrite(HEAT_PIN, LOW);
        if (hapticDriverOk) hapticDriver.stop();
        heatActive    = false;
        vibrateActive = false;
        txCharacteristic.writeValue("DEVICE_OFF");
        logEvent("Device OFF mid-session — outputs cut.");
        break; // Exit connected loop
      }

      // ── Handle incoming BLE commands ──
      if (rxCharacteristic.written()) {
        String command = rxCharacteristic.value();
        handleCommand(command);
        lastCommandTime = millis();
      }

      // ── Temperature safety check + vibration re-trigger every 500 ms ──
      static unsigned long lastTempCheck = 0;
      bool safetyTriggered = false;

      if (millis() - lastTempCheck >= 500) {
        lastTempCheck = millis();

        if (tempSensorOk) {
          float temp = tempSensor.readTempC();
          logEvent("Temp: " + String(temp, 1));

          if (temp >= MAX_TEMP && heatActive) {
            safetyShutoff("TEMP_HIGH");
            safetyTriggered = true;
          }
        }

        // Re-trigger haptic every 500 ms to keep vibration continuous.
        // Waveform 14 is a one-shot effect — without this it cuts out after ~1 s.
        if (!safetyTriggered && vibrateActive && hapticDriverOk) {
          hapticDriver.go();
        }
      }

      // ── BLE activity timeout ──
      if (!safetyTriggered &&
          (heatActive || vibrateActive) &&
          (millis() - lastCommandTime >= BLE_TIMEOUT_MS)) {
        safetyShutoff("BLE_TIMEOUT");
        safetyTriggered = true;
      }

      // Break out of connected loop immediately after any safety event
      if (safetyTriggered) break;
    }

    // ── Central disconnected ──
    logEvent("Disconnected.");
    safetyShutoff("BLE_LOST");

    // Only resume advertising if switch is still on
    if (deviceActive) {
      BLE.advertise();
      logEvent("Resuming BLE advertising...");
    } else {
      logEvent("Switch off — not resuming advertising.");
    }
  }
}
