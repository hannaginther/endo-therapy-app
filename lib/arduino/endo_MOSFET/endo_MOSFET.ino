// MOSFET Wiring:
// Gate  → D5 (GPIO8)
// Source → GND
// Drain  → Heater negative
// Connect an LED + resistor across drain/source to test safely first

#define MOSFET_PIN D5  // GPIO8

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("=== Test 3: MOSFET ===");
  pinMode(MOSFET_PIN, OUTPUT);
}

void loop() {
  Serial.println("MOSFET ON");
  digitalWrite(MOSFET_PIN, HIGH);
  delay(2000);

  Serial.println("MOSFET OFF");
  digitalWrite(MOSFET_PIN, LOW);
  delay(2000);
}