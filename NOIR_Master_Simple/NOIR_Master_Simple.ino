// NOIR - Simple Master Test for Proteus
// This is a simplified version to test basic functionality

#include <Wire.h>

// Pin definitions
#define RED_LED 3
#define YELLOW_LED 4
#define GREEN_LED 5
#define BUZZER_PIN 6

// Timing variables
unsigned long previousMillis = 0;
const long interval = 1000;  // 1 second interval

void setup() {
  // Initialize serial communication
  Serial.begin(9600);
  Serial.println("NOIR Simple Master Test");
  
  // Initialize I2C as master
  Wire.begin();
  
  // Set pin modes
  pinMode(RED_LED, OUTPUT);
  pinMode(YELLOW_LED, OUTPUT);
  pinMode(GREEN_LED, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  
  // Test all outputs
  testOutputs();
}

void loop() {
  unsigned long currentMillis = millis();
  
  // Simple LED pattern every interval
  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;
    
    // Cycle through LEDs
    static int ledState = 0;
    turnOffAllLEDs();
    
    switch (ledState) {
      case 0:
        digitalWrite(GREEN_LED, HIGH);
        break;
      case 1:
        digitalWrite(YELLOW_LED, HIGH);
        break;
      case 2:
        digitalWrite(RED_LED, HIGH);
        digitalWrite(BUZZER_PIN, HIGH);
        delay(100);
        digitalWrite(BUZZER_PIN, LOW);
        break;
    }
    
    ledState = (ledState + 1) % 3;
    
    // Print something to serial
    Serial.print("Current state: ");
    Serial.println(ledState);
  }
}

void testOutputs() {
  // Test all outputs in sequence
  Serial.println("Testing outputs...");
  
  // Green LED
  digitalWrite(GREEN_LED, HIGH);
  delay(300);
  digitalWrite(GREEN_LED, LOW);
  
  // Yellow LED
  digitalWrite(YELLOW_LED, HIGH);
  delay(300);
  digitalWrite(YELLOW_LED, LOW);
  
  // Red LED
  digitalWrite(RED_LED, HIGH);
  delay(300);
  digitalWrite(RED_LED, LOW);
  
  // Buzzer
  digitalWrite(BUZZER_PIN, HIGH);
  delay(100);
  digitalWrite(BUZZER_PIN, LOW);
  
  Serial.println("Test complete!");
}

void turnOffAllLEDs() {
  digitalWrite(RED_LED, LOW);
  digitalWrite(YELLOW_LED, LOW);
  digitalWrite(GREEN_LED, LOW);
}
