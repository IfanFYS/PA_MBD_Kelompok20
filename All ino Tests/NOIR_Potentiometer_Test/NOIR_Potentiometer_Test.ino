/*
 * NOIR System - Potentiometer Test Script
 * ---------------------------------------
 * This simple script tests potentiometer reading techniques in Proteus
 * Use this to verify that your potentiometer readings are working correctly
 * before trying to integrate with SPI communication.
 */

// Pin definitions
#define SOUND_SENSOR_PIN A0
#define GAS_SENSOR_PIN A1

// Variables to store sensor values
int sound_value = 0;
int gas_value = 0;

// Variables for showing value changes
int prev_sound_value = 0;
int prev_gas_value = 0;

// Timing variables
unsigned long last_reading_time = 0;
unsigned long last_print_time = 0;
unsigned long last_toggle_time = 0;

// Counter for testing different techniques
int test_technique = 0;
const int NUM_TECHNIQUES = 3;

void setup() {
  // Initialize serial communication
  Serial.begin(9600);
  delay(100);
  Serial.println("NOIR System - Potentiometer Test Script");
  Serial.println("--------------------------------------");
  
  // Configure analog pins as inputs
  pinMode(SOUND_SENSOR_PIN, INPUT);
  pinMode(GAS_SENSOR_PIN, INPUT);
  
  Serial.println("This script will test 3 different potentiometer reading techniques");
  Serial.println("1. Basic analogRead");
  Serial.println("2. Pin toggling before reading");
  Serial.println("3. Multiple readings with averaging");
  Serial.println();
  Serial.println("Press RESET to cycle through techniques");
  Serial.println("Starting with Technique 1...");
}

void loop() {
  unsigned long current_time = millis();
  
  // Read potentiometers every 100ms
  if (current_time - last_reading_time >= 100) {
    last_reading_time = current_time;
    
    // Use different techniques based on the current test
    switch(test_technique) {
      case 0:
        // Technique 1: Basic analogRead
        sound_value = analogRead(SOUND_SENSOR_PIN);
        gas_value = analogRead(GAS_SENSOR_PIN);
        break;
        
      case 1:
        // Technique 2: Pin toggling before reading
        pinMode(SOUND_SENSOR_PIN, OUTPUT);
        pinMode(GAS_SENSOR_PIN, OUTPUT);
        delayMicroseconds(10);
        pinMode(SOUND_SENSOR_PIN, INPUT);
        pinMode(GAS_SENSOR_PIN, INPUT);
        delay(5);
        
        sound_value = analogRead(SOUND_SENSOR_PIN);
        gas_value = analogRead(GAS_SENSOR_PIN);
        break;
        
      case 2:
        // Technique 3: Multiple readings with averaging
        int temp_sound = 0;
        int temp_gas = 0;
        
        // Toggle pins first
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
        sound_value = temp_sound / 5;
        gas_value = temp_gas / 5;
        break;
    }
    
    // Auto-scale if reading is percentage (0-100)
    if (sound_value <= 100) {
      sound_value = map(sound_value, 0, 100, 0, 1023);
    }
    
    if (gas_value <= 100) {
      gas_value = map(gas_value, 0, 100, 0, 1023);
    }
    
    // Detect value changes
    if (sound_value != prev_sound_value || gas_value != prev_gas_value) {
      Serial.println("*** Values changed! ***");
      prev_sound_value = sound_value;
      prev_gas_value = gas_value;
    }
  }
  
  // Display readings every 500ms
  if (current_time - last_print_time >= 500) {
    last_print_time = current_time;
    
    Serial.print("[Technique ");
    Serial.print(test_technique + 1);
    Serial.print("] Sound: ");
    Serial.print(sound_value);
    Serial.print(" | Gas: ");
    Serial.println(gas_value);
  }
  
  // Toggle pins every 30ms regardless of technique
  // to see if this improves reading in all cases
  if (current_time - last_toggle_time >= 30) {
    last_toggle_time = current_time;
    
    if (test_technique == 0) {
      // Only perform this extra toggling for technique 1
      // to see if continuous toggling helps
      pinMode(SOUND_SENSOR_PIN, OUTPUT);
      pinMode(GAS_SENSOR_PIN, OUTPUT);
      delayMicroseconds(5);
      pinMode(SOUND_SENSOR_PIN, INPUT);
      pinMode(GAS_SENSOR_PIN, INPUT);
    }
  }
  
  // Small delay
  delay(10);
}
