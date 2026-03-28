// EndoSync Hardware Test Sketch
// Board: Arduino Nano ESP32 (ABX00083)
// Baud:  115200 — set Serial Monitor line ending to "Newline"
//
// Purpose: test all hardware components (heater, vibration,
// temperature sensor) via Serial Monitor commands, with no
// BLE stack or app required.
//
// WARNING: This sketch bypasses the BLE activity timeout.
// Flash endosync_hardware_v3.ino before any user-facing use.

#include <Wire.h>
#include <Adafruit_MCP9808.h>
#include <Adafruit_DRV2605.h>

// ── Pin assignments (must match main firmware) ───────────────────────────────
#define HEAT_PIN    D5   // MOSFET gate — heater
#define LED_PIN     D9   // Status LED
#define SWITCH_PIN  D6   // Physical switch (readable but not gating here)
#define MAX_TEMP    42.0 // Safety cutoff in °C

// ── Hardware objects ─────────────────────────────────────────────────────────
Adafruit_MCP9808 tempSensor;
Adafruit_DRV2605 hapticDriver;

// ── State ────────────────────────────────────────────────────────────────────
bool heatActive      = false;
bool vibrateActive   = false;
bool tempStreamOn    = false;
bool safetyTriggered = false;
bool tempSensorOk    = false;
bool hapticDriverOk  = false;

// ── Timing (all non-blocking, millis-based) ──────────────────────────────────
unsigned long lastTempStream   = 0;  // TEMP_STREAM output (1000 ms)
unsigned long lastHapticRetrig = 0;  // DRV2605L re-trigger (500 ms)
unsigned long lastSafetyCheck  = 0;  // Thermal safety poll (500 ms)


// ── Helpers ──────────────────────────────────────────────────────────────────

void printMenu() {
  Serial.println();
  Serial.println("Commands (type and press Enter):");
  Serial.println("  HEAT_ON      — Turn heater on");
  Serial.println("  HEAT_OFF     — Turn heater off");
  Serial.println("  VIBRATE_ON   — Start vibration");
  Serial.println("  VIBRATE_OFF  — Stop vibration");
  Serial.println("  BOTH_ON      — Heater + vibration on");
  Serial.println("  ALL_OFF      — Everything off");
  Serial.println("  READ_TEMP    — Read MCP9808 once and print");
  Serial.println("  TEMP_STREAM  — Toggle continuous temp printing every 1 s (default: off)");
  Serial.println("  STATUS       — Print current state of all outputs");
  Serial.println("  HELP         — Reprint this menu");
}

void printStatus() {
  Serial.print("Status: heat=");
  Serial.print(heatActive   ? "ON" : "OFF");
  Serial.print(" vibration=");
  Serial.print(vibrateActive ? "ON" : "OFF");
  Serial.print(" temp_stream=");
  Serial.println(tempStreamOn ? "ON" : "OFF");
}

// Cut all outputs immediately and set the safety flag.
void safetyCutoff() {
  digitalWrite(HEAT_PIN, LOW);
  digitalWrite(LED_PIN,  LOW);
  if (hapticDriverOk) hapticDriver.stop();
  heatActive      = false;
  vibrateActive   = false;
  safetyTriggered = true;
  Serial.println("SAFETY CUTOFF: temp >= 42C");
}


// ── Command handler ──────────────────────────────────────────────────────────

void handleCommand(String cmd) {
  cmd.trim();

  if (cmd == "HEAT_ON") {
    if (safetyTriggered) {
      Serial.println("Blocked — safety cutoff active. Send ALL_OFF to reset.");
      return;
    }
    if (!tempSensorOk) {
      Serial.println("WARNING: MCP9808 unavailable — running without thermal safety.");
    }
    digitalWrite(HEAT_PIN, HIGH);
    digitalWrite(LED_PIN,  HIGH);
    heatActive = true;
    Serial.println("HEAT ON — D5 HIGH");

  } else if (cmd == "HEAT_OFF") {
    digitalWrite(HEAT_PIN, LOW);
    heatActive = false;
    if (!vibrateActive) digitalWrite(LED_PIN, LOW);
    Serial.println("HEAT OFF — D5 LOW");

  } else if (cmd == "VIBRATE_ON") {
    if (safetyTriggered) {
      Serial.println("Blocked — safety cutoff active. Send ALL_OFF to reset.");
      return;
    }
    if (!hapticDriverOk) {
      Serial.println("DRV2605L not available — vibration disabled.");
      return;
    }
    hapticDriver.setWaveform(0, 14); // waveform 14 = continuous buzz
    hapticDriver.setWaveform(1, 0);  // end of sequence
    hapticDriver.go();
    vibrateActive = true;
    digitalWrite(LED_PIN, HIGH);
    lastHapticRetrig = millis();
    Serial.println("VIBRATE ON");

  } else if (cmd == "VIBRATE_OFF") {
    if (hapticDriverOk) hapticDriver.stop();
    vibrateActive = false;
    if (!heatActive) digitalWrite(LED_PIN, LOW);
    Serial.println("VIBRATE OFF");

  } else if (cmd == "BOTH_ON") {
    if (safetyTriggered) {
      Serial.println("Blocked — safety cutoff active. Send ALL_OFF to reset.");
      return;
    }
    if (!tempSensorOk) {
      Serial.println("WARNING: MCP9808 unavailable — running without thermal safety.");
    }
    digitalWrite(HEAT_PIN, HIGH);
    digitalWrite(LED_PIN,  HIGH);
    heatActive = true;
    if (hapticDriverOk) {
      hapticDriver.setWaveform(0, 14);
      hapticDriver.setWaveform(1, 0);
      hapticDriver.go();
      vibrateActive = true;
      lastHapticRetrig = millis();
    } else {
      Serial.println("  (DRV2605L not available — vibration skipped)");
    }
    Serial.println("BOTH ON — heater + vibration on");

  } else if (cmd == "ALL_OFF") {
    digitalWrite(HEAT_PIN, LOW);
    digitalWrite(LED_PIN,  LOW);
    if (hapticDriverOk) hapticDriver.stop();
    heatActive      = false;
    vibrateActive   = false;
    safetyTriggered = false; // Reset for continued testing
    Serial.println("ALL OFF — safety flag cleared");

  } else if (cmd == "READ_TEMP") {
    if (!tempSensorOk) {
      Serial.println("TEMP: ERROR — MCP9808 not available");
      return;
    }
    float temp = tempSensor.readTempC();
    Serial.print("Temp: ");
    Serial.print(temp, 1);
    Serial.println(" C");
    if (temp >= MAX_TEMP) {
      safetyCutoff();
    }

  } else if (cmd == "TEMP_STREAM") {
    tempStreamOn = !tempStreamOn;
    Serial.print("TEMP_STREAM ");
    Serial.println(tempStreamOn ? "ON" : "OFF");

  } else if (cmd == "STATUS") {
    printStatus();

  } else if (cmd == "HELP") {
    printMenu();

  } else if (cmd.length() > 0) {
    Serial.print("Unknown command: ");
    Serial.println(cmd);
    Serial.println("Type HELP for command list.");
  }
}


// ── Setup ─────────────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  delay(1500); // Wait for USB-CDC to enumerate on Nano ESP32

  Serial.println("=== EndoSync Hardware Test ===");
  Serial.println("Checking hardware...");

  pinMode(HEAT_PIN,   OUTPUT);
  pinMode(LED_PIN,    OUTPUT);
  pinMode(SWITCH_PIN, INPUT_PULLUP);
  digitalWrite(HEAT_PIN, LOW);
  digitalWrite(LED_PIN,  LOW);

  Wire.begin();

  // MCP9808 temperature sensor (address 0x18)
  if (!tempSensor.begin(0x18)) {
    Serial.println("MCP9808: NOT FOUND — temp features disabled");
    tempSensorOk = false;
  } else {
    tempSensor.setResolution(3);
    tempSensorOk = true;
    Serial.println("MCP9808: OK");
  }

  // DRV2605L haptic driver (address 0x5A)
  if (!hapticDriver.begin()) {
    Serial.println("DRV2605L: NOT FOUND — vibration features disabled");
    hapticDriverOk = false;
  } else {
    hapticDriver.selectLibrary(1);
    hapticDriver.setMode(DRV2605_MODE_INTTRIG);
    hapticDriverOk = true;
    Serial.println("DRV2605L: OK");
  }

  Serial.println("All checks done. Ready for commands.");
  printMenu();
}


// ── Main loop ─────────────────────────────────────────────────────────────────

void loop() {
  unsigned long now = millis();

  // ── Read Serial commands ──
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    handleCommand(cmd);
  }

  // ── Thermal safety check every 500 ms (when outputs are active) ──
  if (tempSensorOk && (heatActive || vibrateActive) &&
      (now - lastSafetyCheck >= 500)) {
    lastSafetyCheck = now;
    float temp = tempSensor.readTempC();
    if (temp >= MAX_TEMP) {
      safetyCutoff();
    }
  }

  // ── TEMP_STREAM: continuous print every 1000 ms ──
  if (tempStreamOn && tempSensorOk && (now - lastTempStream >= 1000)) {
    lastTempStream = now;
    float temp = tempSensor.readTempC();
    Serial.print("Temp: ");
    Serial.print(temp, 1);
    Serial.println(" C");
    if (temp >= MAX_TEMP) {
      safetyCutoff();
    }
  }

  // ── DRV2605L re-trigger every 500 ms ──
  // Waveform 14 is a one-shot effect — must be re-fired to sustain vibration.
  if (vibrateActive && hapticDriverOk && (now - lastHapticRetrig >= 500)) {
    lastHapticRetrig = now;
    hapticDriver.go();
  }
}
