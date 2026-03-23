#include <Wire.h>
#include <Adafruit_MCP9808.h>
#include <Adafruit_DRV2605.h>

// Pin assignments
#define HEAT_PIN 9
#define LED_PIN LED_BUILTIN // Built in pin arduino nanao ESP32

// Hardware objects
Adafruit_MCP9808 tempSensor;
Adafruit_DRV2605 hapticDriver;

void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  delay(1000);
  Serial.println("===Endo Component Test===");

  // LED
  pinMode(LED_PIN, OUTPUT);
  Serial.println("LED pin ready.");

  // Heat pin
  pinMode(HEAT_PIN, OUTPUT);
  digitalWrite(HEAT_PIN, LOW);
  Serial.println("Heat pin ready. Heat is OFF.");

  // I2C
  Wire.begin();

  // MCP9808
  if (!tempSensor.begin()) {
    Serial.println("FAIL: MCP9808 not found. Check wiring.");
  } else {
    tempSensor.setResolution(3);
    Serial.println("PASS: MCP9808 temperature sensor found.");
  }

  // Haptic driver (to be tested)
  if (!hapticDriver.begin()) {
    Serial.println("FAIL: DRV2605L not found. Check wiring.");
  } else {
    hapticDriver.selectLibrary(1);
    hapticDriver.setMode(DRV2605_MODE_INTTRIG);
    Serial.println("PASS: DRV2605L haptic driver found.");
  }

  Serial.println("=== Starting component test loop ===");
}

void loop() {
  // Test 1: LED blink
  Serial.println("\n--- Test 1: LED blink ---");
  for (int i = 0; i < 5; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(300);
    digitalWrite(LED_PIN, LOW);
    delay(300);
  }
  Serial.println("LED blink done.");

  // Test 2: Temperature reading
  Serial.println("\n--- Test 2: Temp reading ---");
  for (int i = 0; i <5; i++) {
    float temp = tempSensor.readTempC();
    Serial.print("Temperature: ");
    Serial.print(temp);
    Serial.println(" C");
    delay(1000);
  }

  // Test heat pad
  Serial.println("\n--- Test 3: Head pad ON for 60 seconds ---");
  digitalWrite(HEAT_PIN, HIGH);
  Serial.println("Heat ON");

  // Monitor temp while heat is on
  for (int i = 0; i < 120; i++) {
    float temp = tempSensor.readTempC();
    Serial.print("Temp while heating: ");
    Serial.print(temp);
    Serial.println(" C");

    // Safety check during test
    if (temp >= 42.0) {
      Serial.println("SAFETY: Max temp reached. Turning off heat.");
      digitalWrite(HEAT_PIN, LOW);
      break;
    }
    delay(500);
  }

  digitalWrite(HEAT_PIN, LOW);
  Serial.println("Heat OFF");
  delay(2000);


  // Test 4: Vibration
  Serial.println("\n--- Test 4: Vibration for 5 seconds ---");
  hapticDriver.setWaveform(0, 14); // waveform 14 = continuous buzz
  hapticDriver.setWaveform(1, 0); // end of sequence
  hapticDriver.go();
  Serial.println("Vibration ON");
  delay(5000);
  hapticDriver.stop();
  Serial.println("Vibration OFF");
  delay(2000);

  Serial.println("\n=== Cycle complete. Repeating... ===");

}
