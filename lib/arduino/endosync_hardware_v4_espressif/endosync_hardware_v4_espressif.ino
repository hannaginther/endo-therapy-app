// Libraries
#include <Wire.h>
#include <Adafruit_MCP9808.h>
#include <Adafruit_DRV2605.h>

// ESP32 BLE
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Pin assignments
#define HEAT_PIN    D5
#define SWITCH_PIN  D6
#define LED_PIN     D9
#define MAX_TEMP    42.0

// BLE UUIDs
#define SERVICE_UUID      "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define TX_CHARACTERISTIC "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define RX_CHARACTERISTIC "6c88fae1-9bfb-4a9e-8f30-1d5a7c8b9f0c"

// BLE objects
BLEServer* pServer = nullptr;
BLECharacteristic* txCharacteristic;
BLECharacteristic* rxCharacteristic;
BLEAdvertising* pAdvertising;

bool deviceConnected = false;

// Hardware objects
Adafruit_MCP9808 tempSensor;
Adafruit_DRV2605 hapticDriver;

// State variables
bool heatActive     = false;
bool vibrateActive  = false;
bool tempSensorOk   = false;
bool hapticDriverOk = false;
bool deviceActive   = false;

unsigned long lastCommandTime = 0;
const unsigned long BLE_TIMEOUT_MS = 660000UL;

// Forward declaration so RXCallbacks can call it
void handleCommand(String command);

// ── BLE Callbacks ─────────────────────────────────────────

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;
    Serial.println("BLE connected.");
  }

  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;
    Serial.println("BLE disconnected.");

    // Only restart advertising if the physical switch still allows the device to be active.
    if (deviceActive && pAdvertising != nullptr) {
      pAdvertising->start();
    }
  }
};

class RXCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    String command = characteristic->getValue();  // FIX: use String, not std::string

    if (command.length() > 0) {
      Serial.print("Received: ");
      Serial.println(command);

      handleCommand(command);
      lastCommandTime = millis();
    }
  }
};


// ── Setup ─────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  delay(1500);
  Serial.println("Endosync booting...");

  pinMode(HEAT_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);
  pinMode(SWITCH_PIN, INPUT_PULLUP);

  digitalWrite(HEAT_PIN, LOW);
  digitalWrite(LED_PIN, LOW);

  Wire.begin();

  // Temperature sensor
  if (!tempSensor.begin(0x18)) {
    Serial.println("WARNING: MCP9808 not found.");
  } else {
    tempSensor.setResolution(3);
    tempSensorOk = true;
  }

  // Haptic driver
  if (!hapticDriver.begin()) {
    Serial.println("WARNING: DRV2605 not found.");
  } else {
    hapticDriver.selectLibrary(1);
    hapticDriver.setMode(DRV2605_MODE_INTTRIG);
    hapticDriverOk = true;
  }

  // BLE setup
  BLEDevice::init("EndoSync");

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  txCharacteristic = pService->createCharacteristic(
    TX_CHARACTERISTIC,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  txCharacteristic->addDescriptor(new BLE2902());

  rxCharacteristic = pService->createCharacteristic(
    RX_CHARACTERISTIC,
    BLECharacteristic::PROPERTY_WRITE
  );
  rxCharacteristic->setCallbacks(new RXCallbacks());

  pService->start();

  pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);

  Serial.println("BLE ready. Waiting for switch...");
}


// ── Safety ────────────────────────────────────────────────

void safetyShutoff(String reason) {
  digitalWrite(HEAT_PIN, LOW);
  digitalWrite(LED_PIN, LOW);

  if (hapticDriverOk) hapticDriver.stop();

  heatActive = false;
  vibrateActive = false;

  if (deviceConnected) {
    txCharacteristic->setValue(("SAFETY:" + reason).c_str());
    txCharacteristic->notify();
  }

  Serial.print("SAFETY SHUTOFF: ");
  Serial.println(reason);
}


// ── Command Handler ───────────────────────────────────────

void handleCommand(String command) {

  if (!deviceActive && command != "READ_TEMP") return;

  if (command == "HEAT_ON") {
    digitalWrite(HEAT_PIN, HIGH);
    heatActive = true;

  } else if (command == "HEAT_OFF") {
    digitalWrite(HEAT_PIN, LOW);
    heatActive = false;

  } else if (command == "VIBRATE_ON") {
    if (hapticDriverOk) {
      hapticDriver.setWaveform(0, 14);
      hapticDriver.setWaveform(1, 0);
      hapticDriver.go();
      vibrateActive = true;
    }

  } else if (command == "VIBRATE_OFF") {
    if (hapticDriverOk) hapticDriver.stop();
    vibrateActive = false;

  } else if (command == "BOTH_ON") {
    digitalWrite(HEAT_PIN, HIGH);
    heatActive = true;

    if (hapticDriverOk) {
      hapticDriver.setWaveform(0, 14);
      hapticDriver.setWaveform(1, 0);
      hapticDriver.go();
      vibrateActive = true;
    }

  } else if (command == "ALL_OFF") {
    digitalWrite(HEAT_PIN, LOW);
    if (hapticDriverOk) hapticDriver.stop();
    heatActive = false;
    vibrateActive = false;

  } else if (command == "READ_TEMP") {
    if (tempSensorOk) {
      float temp = tempSensor.readTempC();
      String response = "TEMP:" + String(temp, 1);
      if (deviceConnected) {
        txCharacteristic->setValue(response.c_str());
        txCharacteristic->notify();
      }
    } else {
      if (deviceConnected) {
        txCharacteristic->setValue("TEMP:ERROR");
        txCharacteristic->notify();
      }
    }
    return; // prevent the echo below from sending READ_TEMP back
  } else {
    Serial.println("Unknown command.");
  }

  if (deviceConnected) {
    txCharacteristic->setValue(command.c_str());
    txCharacteristic->notify();
  }
}


// ── Loop ──────────────────────────────────────────────────

void loop() {

  bool switchOn = (digitalRead(SWITCH_PIN) == LOW);

  // Switch ON
  if (switchOn && !deviceActive) {
    deviceActive = true;
    digitalWrite(LED_PIN, HIGH);
    pAdvertising->start();
    Serial.println("Device ON — BLE advertising.");
  }

  // Switch OFF
  if (!switchOn && deviceActive) {
    deviceActive = false;

    digitalWrite(LED_PIN, LOW);
    digitalWrite(HEAT_PIN, LOW);
    if (hapticDriverOk) hapticDriver.stop();

    heatActive = false;
    vibrateActive = false;

    pAdvertising->stop();
    Serial.println("Device OFF.");
  }

  if (!deviceActive) {
    delay(50);
    return;
  }

  static unsigned long lastTempCheck = 0;

  if (millis() - lastTempCheck >= 500) {
    lastTempCheck = millis();

    if (tempSensorOk) {
      float temp = tempSensor.readTempC();

      if (temp >= MAX_TEMP && heatActive) {
        safetyShutoff("TEMP_HIGH");
      }
    }

    if (vibrateActive && hapticDriverOk) {
      hapticDriver.go();
    }
  }

  if ((heatActive || vibrateActive) &&
      (millis() - lastCommandTime >= BLE_TIMEOUT_MS)) {
    safetyShutoff("BLE_TIMEOUT");
  }
}