/*
 * NOIR System - Slave with SPI and Sensors
 * ---------------------------------------
 * This program reads analog values from sound and gas sensors
 * and sends them to the master via SPI when requested.
 */

#include <SPI.h>

// Pin definitions
#define SS_PIN 10
#define LED_PIN 13
#define SOUND_SENSOR_PIN A0
#define GAS_SENSOR_PIN A1

// Variables to store sensor values
volatile uint16_t sound_value = 0;
volatile uint16_t gas_value = 0;

// State variables for SPI transfers
volatile byte command = 0;

void setup() {
  // Initialize serial communication
  Serial.begin(9600);
  delay(500);
  
  Serial.println("NOIR System - Slave (SPI with Sensors)");
  Serial.println("-------------------------------------");
  
  // Configure pins
  pinMode(SS_PIN, INPUT);
  pinMode(MISO, OUTPUT);
  pinMode(LED_PIN, OUTPUT);
  pinMode(SOUND_SENSOR_PIN, INPUT);
  pinMode(GAS_SENSOR_PIN, INPUT);
  
  // Visual indicator
  digitalWrite(LED_PIN, HIGH);
  delay(200);
  digitalWrite(LED_PIN, LOW);
  delay(200);
  digitalWrite(LED_PIN, HIGH);
  delay(200);
  digitalWrite(LED_PIN, LOW);
  
  // Take a few initial readings to stabilize
  readSensors();
  
  // Initialize SPI in slave mode
  SPCR = (1 << SPE) | (1 << SPIE); // Enable SPI and interrupts
  SPI.attachInterrupt(); // Enable the interrupt
  
  Serial.println("Ready to send sensor values:");
  Serial.print("Sound: ");
  Serial.print(sound_value);
  Serial.print(", Gas: ");
  Serial.println(gas_value);
  
  Serial.println("Slave initialized");
  Serial.println("----------------------------------");
}

// SPI interrupt routine
ISR(SPI_STC_vect) {
  byte received = SPDR;
  static byte transfer_state = 0;
  
  if (digitalRead(SS_PIN) == LOW) { // If we're selected
    
    // First check if this is a command
    if (received == 0x01 && transfer_state == 0) {
      // Command for sound value
      command = 0x01;
      SPDR = sound_value & 0xFF; // Send low byte first
      transfer_state = 1;
      return;
    }
    else if (received == 0x02 && transfer_state == 0) {
      // Command for gas value
      command = 0x02;
      SPDR = gas_value & 0xFF; // Send low byte first
      transfer_state = 1;
      return;
    }
    
    // Handle second byte of transfer
    if (transfer_state == 1) {
      if (command == 0x01) {
        // Send high byte of sound value
        SPDR = (sound_value >> 8) & 0xFF;
      }
      else if (command == 0x02) {
        // Send high byte of gas value
        SPDR = (gas_value >> 8) & 0xFF;
      }
      transfer_state = 0;
    }
  }
}

void loop() {
  // Read sensors every 100ms
  static unsigned long last_reading_time = 0;
  unsigned long current_time = millis();
  
  if (current_time - last_reading_time >= 100) {
    last_reading_time = current_time;
    readSensors();
  }
  
  // Monitor SS pin for debug info
  static bool last_ss_state = HIGH;
  bool current_ss_state = digitalRead(SS_PIN);
  
  if (last_ss_state != current_ss_state) {
    last_ss_state = current_ss_state;
    
    if (current_ss_state == LOW) {
      // Selected - turn on LED
      digitalWrite(LED_PIN, HIGH);
      Serial.println("Selected by master (SS LOW)");
    } else {
      // Deselected - turn off LED
      digitalWrite(LED_PIN, LOW);
      Serial.println("Deselected by master (SS HIGH)");
      Serial.println("Transfer completed");
      
      // Print latest values
      Serial.print("Current values - Sound: ");
      Serial.print(sound_value);
      Serial.print(", Gas: ");
      Serial.println(gas_value);
    }
  }
  
  // Small delay
  delay(10);
}

void readSensors() {
  // Technique 3 from potentiometer test: Multiple readings with averaging
  
  int temp_sound = 0;
  int temp_gas = 0;
  
  // Toggle pins first (Proteus-specific technique)
  pinMode(SOUND_SENSOR_PIN, OUTPUT);
  pinMode(GAS_SENSOR_PIN, OUTPUT);
  delayMicroseconds(10);
  pinMode(SOUND_SENSOR_PIN, INPUT);
  pinMode(GAS_SENSOR_PIN, INPUT);
  
  // Take multiple readings
  for (int i = 0; i < 5; i++) {
    temp_sound += analogRead(SOUND_SENSOR_PIN);
    temp_gas += analogRead(GAS_SENSOR_PIN);
    delay(2);
  }
  
  // Average the readings
  temp_sound = temp_sound / 5;
  temp_gas = temp_gas / 5;
  
  // Process sound value
  if (temp_sound <= 100) {
    // If reading is 0-100, treat as percentage and map to full range
    sound_value = map(temp_sound, 0, 100, 0, 1023);
  } else {
    sound_value = temp_sound;
  }
  
  // Process gas value
  if (temp_gas <= 100) {
    // If reading is 0-100, treat as percentage and map to full range
    gas_value = map(temp_gas, 0, 100, 0, 1023);
  } else {
    gas_value = temp_gas;
  }
  
  // Constrain values
  sound_value = constrain(sound_value, 0, 1023);
  gas_value = constrain(gas_value, 0, 1023);
}
