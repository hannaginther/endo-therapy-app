#include <Wire.h>
#include <Adafruit_MCP9808.h>

Adafruit_MCP9808 tempsensor = Adafruit_MCP9808();

// MCP9808 Wiring:
// SDA → A4 (GPIO11)
// SCL → A5 (GPIO12)
// VDD → 3V3
// GND → GND
// A0, A1, A2 → GND (sets I2C address to 0x18)

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("=== Test 2: MCP9808 Temp Sensor ===");

  if (!tempsensor.begin(0x18)) {
    Serial.println("FAIL: MCP9808 not found. Check wiring!");
    while (1);
  }
  Serial.println("PASS: MCP9808 found!");
  tempsensor.setResolution(3);
}

void loop() {
  tempsensor.wake();
  float temp = tempsensor.readTempC();
  Serial.print("Temp: ");
  Serial.print(temp);
  Serial.println(" C");
  tempsensor.shutdown_wake(1);
  delay(1000);
}