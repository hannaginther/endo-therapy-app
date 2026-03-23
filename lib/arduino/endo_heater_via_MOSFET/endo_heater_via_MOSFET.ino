// Heater Wiring:
// Heater positive → VIN (5V from USB)
// Heater negative → MOSFET Drain
// MOSFET Gate     → D5 (GPIO8)
// MOSFET Source   → GND

#define MOSFET_PIN D5  // GPIO8

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("=== Test 4: Heater ===");
  pinMode(MOSFET_PIN, OUTPUT);
}

void loop() {
  Serial.println("Heater ON - touch to confirm warmth");
  digitalWrite(MOSFET_PIN, HIGH);
  delay(600000);

  Serial.println("Heater OFF");
  digitalWrite(MOSFET_PIN, LOW);
  delay(5000);
}