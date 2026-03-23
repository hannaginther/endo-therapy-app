#include <Wire.h>
#include <Adafruit_MCP9808.h>
#include <Adafruit_DRV2605.h>

// ==========================================
// PIN DEFINITIONS
// ==========================================
#define MOSFET_PIN D5  // GPIO8 - controls heater

// ==========================================
// COMPONENT OBJECTS
// ==========================================
Adafruit_MCP9808 tempsensor = Adafruit_MCP9808();
Adafruit_DRV2605 drv;

// ==========================================
// SETUP
// ==========================================
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("==========================================");
  Serial.println("     ENDO SIMULTANEOUS COMPONENT TEST    ");
  Serial.println("==========================================\n");

  pinMode(MOSFET_PIN, OUTPUT);

  // Init temp sensor
  Serial.println("Initializing MCP9808...");
  if (!tempsensor.begin(0x18)) {
    Serial.println("FAIL: MCP9808 not found. Check wiring!");
    while (1);
  }
  tempsensor.setResolution(3);
  Serial.println("PASS: MCP9808 ready.");

  // Init vibration driver
  Serial.println("Initializing DRV2605L...");
  if (!drv.begin()) {
    Serial.println("FAIL: DRV2605L not found. Check wiring!");
    while (1);
  }
  drv.selectLibrary(1);
  drv.setMode(DRV2605_MODE_INTTRIG);
  Serial.println("PASS: DRV2605L ready.");

  Serial.println("\nAll components initialized. Starting simultaneous test...\n");
  delay(1000);
}

// ==========================================
// LOOP - All 3 running together
// ==========================================
void loop() {
  Serial.println("--- Cycle Start ---");

  // Turn heater ON
  digitalWrite(MOSFET_PIN, HIGH);
  Serial.println("Heater: ON");

  // Play vibration effect
  drv.setWaveform(0, 14);  // Strong Buzz 100%
  drv.setWaveform(1, 0);
  drv.go();
  Serial.println("Vibration: Buzzing");

  // Read temp 60 times over 60 seconds while heater and vibration are running
  for (int i = 0; i < 60; i++) {
    tempsensor.wake();
    float temp = tempsensor.readTempC();
    tempsensor.shutdown_wake(1);
    Serial.print("Temp: ");
    Serial.print(temp);
    Serial.println(" C");
    delay(1000);
  }

  // Turn heater OFF
  digitalWrite(MOSFET_PIN, LOW);
  Serial.println("Heater: OFF");

  // Play a different vibration effect to confirm motor still running
  drv.setWaveform(0, 52);  // Pulsing Strong 100%
  drv.setWaveform(1, 0);
  drv.go();
  Serial.println("Vibration: Pulsing");

  // Read temp 15 times to confirm it drops after heater off
  for (int i = 0; i < 15; i++) {
    tempsensor.wake();
    float temp = tempsensor.readTempC();
    tempsensor.shutdown_wake(1);
    Serial.print("Temp (cooling): ");
    Serial.print(temp);
    Serial.println(" C");
    delay(1000);
  }