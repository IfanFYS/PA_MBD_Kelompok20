// NOIR - Simple Slave Test for Proteus
// This is a simplified version to test basic functionality

#include <Wire.h>

// I2C address
#define SLAVE_ADDR 0x08

// Timing variables
unsigned long previousMillis = 0;
const long interval = 500;  // 0.5 second interval

// Simple test values
byte testValue = 0;

void setup() {
  // Initialize serial communication
  Serial.begin(9600);
  Serial.println("NOIR Simple Slave Test");
  
  // Initialize I2C as slave
  Wire.begin(SLAVE_ADDR);
  
  // Define callbacks for I2C communication
  Wire.onRequest(requestEvent);
  Wire.onReceive(receiveEvent);
  
  Serial.println("Slave ready");
}

void loop() {
  unsigned long currentMillis = millis();
  
  // Update test value periodically
  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;
    
    // Just increment test value (0-255 and wraps around)
    testValue++;
    
    // Print current value
    Serial.print("Current test value: ");
    Serial.println(testValue);
  }
}

// Function executed when data is requested by master
void requestEvent() {
  // Just send the test value
  Wire.write(testValue);
  Serial.println("Master requested data");
}

// Function executed when data is received from master
void receiveEvent(int byteCount) {
  while (Wire.available()) {
    byte command = Wire.read();
    Serial.print("Received command: ");
    Serial.println(command);
  }
}
