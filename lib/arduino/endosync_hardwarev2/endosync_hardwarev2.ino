// Libraries
#include <ArduinoBLE.h>
#include <Wire.h>
#include <Adafruit_MCP9808.h>
#include <Adafruit_DRV2605.h>

// pin assignments:
#define HEAT_PIN D5   // GPIO8 - MOSFET gate (matches working test wiring)
#define MAX_TEMP 42.0 // safety cutoff temperature in celsius

// BLE UUIDs (must match ble_constants.dart exactly)
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define TX_CHARACTERISTIC   "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define RX_CHARACTERISTIC   "6c88fae1-9bfb-4a9e-8f30-1d5a7c8b9f0c"

// BLE objects
BLEService endosyncService (SERVICE_UUID);
BLEStringCharacteristic rxCharacteristic(RX_CHARACTERISTIC, BLEWrite, 20);
BLEStringCharacteristic txCharacteristic(TX_CHARACTERISTIC, BLENotify, 20);

// Hardware objects
Adafruit_MCP9808 tempSensor;
Adafruit_DRV2605 hapticDriver;

// State variables
bool heatActive = false;
bool vibrateActive = false;
bool tempSensorOk = false;
bool hapticDriverOk = false;
unsigned long lastCommandTime = 0;
const unsigned long BLE_TIMEOUT_MS = 660000; // 11 minutes (covers full 10-min session)

void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  Serial.println("Endosync booting...");

  pinMode(HEAT_PIN, OUTPUT);
  digitalWrite(HEAT_PIN, LOW);

  Wire.begin();

  if (!tempSensor.begin(0x18)) {
    Serial.println("WARNING: MCP9808 not found. Temperature safety disabled.");
    tempSensorOk = false;
  } else {
    tempSensor.setResolution(3);
    tempSensorOk = true;
    Serial.println("MCP9808 ready.");
  }

  if(!hapticDriver.begin()) {
    Serial.println("WARNING: DRV2605 not found. Vibration disabled.");
    hapticDriverOk = false;
  } else {
    hapticDriver.selectLibrary(1);
    hapticDriver.setMode(DRV2605_MODE_INTTRIG);
    hapticDriverOk = true;
    Serial.println("DRV2605L ready.");
  }

  if(!BLE.begin()) {
    Serial.println("ERROR: BLE failed to start.");
    while (1);
  }

  BLE.setLocalName("EndoSync");
  BLE.setAdvertisedService(endosyncService);
  endosyncService.addCharacteristic(rxCharacteristic);
  endosyncService.addCharacteristic(txCharacteristic);
  BLE.addService(endosyncService);
  BLE.advertise();

  Serial.println("BLE advertising as 'EndoSync'.");
  Serial.println("Setup complete. Waiting for connection...");

}

// Safety shutoff
void safetyShutoff(String reason) {
  digitalWrite(HEAT_PIN, LOW);
  if (hapticDriverOk) hapticDriver.stop();
  heatActive = false;
  vibrateActive = false;

  String alert = "SAFETY:" + reason;
  txCharacteristic.writeValue(alert);

  Serial.print("SAFETY SHUTOFF: ");
  Serial.println(reason);
}

// Command handler
void handleCommand (String command) {
  Serial.print("Received: ");
  Serial.println(command);

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
    heatActive = false;
    vibrateActive = false;
    txCharacteristic.writeValue("ALL_OFF");

  } else if (command == "READ_TEMP") {
    if (tempSensorOk) {
      float temp = tempSensor.readTempC();
      String response = "TEMP:" + String(temp, 1);
      txCharacteristic.writeValue(response);
    } else {
      txCharacteristic.writeValue("TEMP:ERROR");
    }

  } else {
    Serial.println("Unknown command.");
  }
}

void loop() {
  // put your main code here, to run repeatedly:
  BLEDevice central = BLE.central();

  if (central) {
    Serial.print("Connected to: ");
    Serial.println(central.address());
    lastCommandTime = millis(); // reset timeout on each command

    while (central.connected()) {
      // handle incoming commands
      if (rxCharacteristic.written()) {
        String command = rxCharacteristic.value();
        handleCommand(command);
        lastCommandTime = millis();
      }

      // temperature safety check every 500 ms
      static unsigned long lastTempCheck = 0;
      if (tempSensorOk && (millis() - lastTempCheck >= 500)) {
        lastTempCheck = millis();
        float temp = tempSensor.readTempC();
        Serial.print("Temp: ");
        Serial.println(temp);

        if (temp >= MAX_TEMP && heatActive) {
          safetyShutoff("TEMP_HIGH");
        }
      }

      // BLE timeout check
      if ((heatActive || vibrateActive) &&
          (millis() - lastCommandTime >= BLE_TIMEOUT_MS)) {
            safetyShutoff("BLE_TIMEOUT");
          }
    }

    Serial.println("Disconnected.");
    safetyShutoff("BLE_LOST");
  }
}
