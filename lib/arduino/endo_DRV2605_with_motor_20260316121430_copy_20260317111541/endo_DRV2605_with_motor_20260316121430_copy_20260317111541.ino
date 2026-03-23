#include <Wire.h>
#include "Adafruit_DRV2605.h"

// DRV2605L Wiring:
// SDA  → A4 (GPIO11)
// SCL  → A5 (GPIO12)  
// VIN  → 3V3
// GND  → GND
// Motor+ → OUT+
// Motor- → OUT-

Adafruit_DRV2605 drv;

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("=== Test 5: DRV2605L + Vibration Motor ===");

  if (!drv.begin()) {
    Serial.println("FAIL: DRV2605L not found. Check wiring!");
    while (1) delay(10);
  }
  Serial.println("PASS: DRV2605L found!");

  drv.selectLibrary(1);
  drv.setMode(DRV2605_MODE_INTTRIG);
}

void loop() {
  // Test 3 different effects to confirm motor is working
  Serial.println("Effect: Strong Click 100%");
  drv.setWaveform(0, 1);
  drv.setWaveform(1, 0);
  drv.go();
  delay(1000);

  Serial.println("Effect: Buzz 100%");
  drv.setWaveform(0, 14);
  drv.setWaveform(1, 0);
  drv.go();
  delay(1000);

  Serial.println("Effect: Pulsing Strong 100%");
  drv.setWaveform(0, 52);
  drv.setWaveform(1, 0);
  drv.go();
  delay(1000);
}