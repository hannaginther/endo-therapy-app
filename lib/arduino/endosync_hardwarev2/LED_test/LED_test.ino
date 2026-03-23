#define LED_PIN LED_BUILTIN // Built in pin arduino nanao ESP32

void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  delay(1000);
  Serial.println("===Endo Component Test===");

  // LED
  pinMode(LED_PIN, OUTPUT);
  Serial.println("LED pin ready.");
}

void loop() {
  // put your main code here, to run repeatedly:
  // Test 1: LED blink
  Serial.println("\n--- Test 1: LED blink ---");
  for (int i = 0; i < 5; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(300);
    digitalWrite(LED_PIN, LOW);
    delay(300);
  }
  Serial.println("LED blink done.");
  Serial.println("Repeating loop");
}
