/*
 * NOIR System - Master with SPI and Sensor Data
 * --------------------------------------------
 * This program receives sensor data from the slave via SPI,
 * displays it on the serial monitor, and provides visual and audio alerts.
 */

#include <SPI.h>

// Pin definitions
#define SS_PIN 10
#define LED_PIN 13      // Built-in LED for SPI activity
#define RED_LED_PIN 2   // Red LED for sound warning
#define YELLOW_LED_PIN 3 // Yellow LED for gas warning
#define GREEN_LED_PIN 4  // Green LED for normal status
#define BUZZER_PIN 5     // Buzzer for audio alerts
#define BUTTON_PIN 6     // Button to silence buzzer

// Variables for sensor data
uint16_t sound_value = 0;
uint16_t gas_value = 0;

// Threshold values
#define SOUND_THRESHOLD 600  // Threshold for sound warning (~60%)
#define GAS_THRESHOLD 700    // Threshold for gas warning (~70%)

// Variables for timing
unsigned long last_transfer_time = 0;
unsigned long last_led_toggle_time = 0;
unsigned long buzzer_start_time = 0;
unsigned long buzzer_silence_time = 0;
const unsigned long BUZZER_SILENCE_TIMEOUT = 30000; // Auto-reset silence after 30 seconds

// LED states
bool red_led_state = false;
bool yellow_led_state = false;
bool buzzer_active = false;
bool buzzer_silenced = false;

// Buffer for receiving data
byte buffer[4] = {0, 0, 0, 0};

void setup() {
  // Initialize serial communication
  Serial.begin(9600);
  while (!Serial) {} // Wait for serial to connect
  delay(500);
  
  Serial.println("NOIR System - Master (SPI with Sensors)");
  Serial.println("--------------------------------------");
    // Configure pins
  pinMode(SS_PIN, OUTPUT);
  digitalWrite(SS_PIN, HIGH);  // Start with slave deselected
  pinMode(LED_PIN, OUTPUT);
  pinMode(RED_LED_PIN, OUTPUT);
  pinMode(YELLOW_LED_PIN, OUTPUT);
  pinMode(GREEN_LED_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);  // Use internal pull-up resistor
  
  // Test buzzer at startup
  digitalWrite(BUZZER_PIN, HIGH);
  delay(200);
  digitalWrite(BUZZER_PIN, LOW);
  
  // Initialize SPI
  SPI.begin();
  SPI.setDataMode(SPI_MODE0);      // Mode 0 (CPOL=0, CPHA=0)
  SPI.setBitOrder(MSBFIRST);       // Most significant bit first
  SPI.setClockDivider(SPI_CLOCK_DIV64);  // Slow clock for reliability
  
  // Startup animation with LEDs
  for (int i = 0; i < 2; i++) {
    digitalWrite(RED_LED_PIN, HIGH);
    delay(100);
    digitalWrite(RED_LED_PIN, LOW);
    digitalWrite(YELLOW_LED_PIN, HIGH);
    delay(100);
    digitalWrite(YELLOW_LED_PIN, LOW);
    digitalWrite(GREEN_LED_PIN, HIGH);
    delay(100);
    digitalWrite(GREEN_LED_PIN, LOW);
  }
  
  // Set green LED on to indicate normal status at startup
  digitalWrite(GREEN_LED_PIN, HIGH);
  
  Serial.println("Master initialized");
  Serial.println("----------------------------------");
}

void loop() {
  unsigned long current_time = millis();
  
  // Request data from slave every 500ms
  if (current_time - last_transfer_time >= 500) {
    last_transfer_time = current_time;
    
    // Request and read sensor data
    requestSensorData();
    
    // Display sensor values
    printSensorValues();
  }
  
  // Toggle warning LEDs every 250ms if active
  if (current_time - last_led_toggle_time >= 250) {
    last_led_toggle_time = current_time;
      // Toggle yellow LED if sound warning is active
    if (sound_value > SOUND_THRESHOLD) {
      yellow_led_state = !yellow_led_state;
      digitalWrite(YELLOW_LED_PIN, yellow_led_state);
    }
    
    // Toggle red LED if gas warning is active
    if (gas_value > GAS_THRESHOLD) {
      red_led_state = !red_led_state;
      digitalWrite(RED_LED_PIN, red_led_state);
    }
  }
    // Check button press to silence buzzer
  if (digitalRead(BUTTON_PIN) == LOW) {  // Button pressed (active LOW)
    buzzer_silenced = true;
    buzzer_silence_time = current_time; // Record when buzzer was silenced
    digitalWrite(BUZZER_PIN, LOW);  // Turn off buzzer immediately
    buzzer_active = false;
    
    // Visual acknowledgment of button press
    for (int i = 0; i < 3; i++) {
      digitalWrite(GREEN_LED_PIN, LOW);
      delay(50);
      digitalWrite(GREEN_LED_PIN, HIGH);
      delay(50);
    }
    
    Serial.println("Buzzer silenced by button press");
  }
  
  // Auto-reset buzzer silence after timeout
  if (buzzer_silenced && (current_time - buzzer_silence_time >= BUZZER_SILENCE_TIMEOUT)) {
    buzzer_silenced = false;
    Serial.println("Buzzer silence timeout - Reset");
  }
    // Control buzzer if warnings are active and not silenced
  if ((sound_value > SOUND_THRESHOLD || gas_value > GAS_THRESHOLD) && !buzzer_silenced) {
    // Make buzzer beep every 1 second if not already active
    if (!buzzer_active) {
      // Use stronger signal for Proteus buzzer simulation
      // First make sure pin is output mode
      pinMode(BUZZER_PIN, OUTPUT);
      
      // Drive the buzzer with stronger signal
      digitalWrite(BUZZER_PIN, HIGH);
      
      // For Proteus, try toggling a few times to make sure the simulation registers it
      for (int i = 0; i < 3; i++) {
        digitalWrite(BUZZER_PIN, LOW);
        delayMicroseconds(500);
        digitalWrite(BUZZER_PIN, HIGH);
        delayMicroseconds(500);
      }
      
      buzzer_active = true;
      buzzer_start_time = current_time;
    }
    // Turn off buzzer after 400ms (longer on time) for a beeping pattern
    else if (current_time - buzzer_start_time >= 400 && buzzer_active) {
      digitalWrite(BUZZER_PIN, LOW);
      buzzer_active = false;
    }
  }
  else {
    // Make sure buzzer is off if no warnings
    digitalWrite(BUZZER_PIN, LOW);
    buzzer_active = false;
  }
  
  // Small delay
  delay(10);
}

void requestSensorData() {
  digitalWrite(LED_PIN, HIGH);  // Visual indicator
  
  // Request sound sensor data
  digitalWrite(SS_PIN, LOW);
  delay(5);  
  
  SPI.transfer(0x01);  // Command for sound sensor value
  delay(5);
  
  buffer[0] = SPI.transfer(0);  // Low byte
  delay(5);
  buffer[1] = SPI.transfer(0);  // High byte
  delay(5);
  
  digitalWrite(SS_PIN, HIGH);  // Deselect slave between requests
  delay(10);
  
  // Request gas sensor data
  digitalWrite(SS_PIN, LOW);
  delay(5);
  
  SPI.transfer(0x02);  // Command for gas sensor value
  delay(5);
  
  buffer[2] = SPI.transfer(0);  // Low byte
  delay(5);
  buffer[3] = SPI.transfer(0);  // High byte
  delay(5);
  
  digitalWrite(SS_PIN, HIGH);  // Deselect slave
  digitalWrite(LED_PIN, LOW);  // Turn off LED
  
  // Process the received data
  sound_value = buffer[0] | (buffer[1] << 8);  // Construct 16-bit value
  gas_value = buffer[2] | (buffer[3] << 8);    // Construct 16-bit value
}

void printSensorValues() {
  Serial.println("----------------------------------");
  Serial.print("Sound Sensor: ");
  Serial.print(sound_value);
  Serial.print(" (");
  Serial.print(map(sound_value, 0, 1023, 0, 100));  // Map to percentage
  Serial.println("%)");
  
  Serial.print("Gas Sensor: ");
  Serial.print(gas_value);
  Serial.print(" (");
  Serial.print(map(gas_value, 0, 1023, 0, 100));  // Map to percentage
  Serial.println("%)");
  
  // Evaluate conditions
  evaluateSensorConditions();
}

void evaluateSensorConditions() {
  // Check sound level
  if (sound_value > SOUND_THRESHOLD) {
    Serial.println("WARNING: High noise level detected!");
    // Yellow LED control handled in the main loop for blinking effect
  } else {
    // Turn off yellow LED if sound level is normal
    digitalWrite(YELLOW_LED_PIN, LOW);
  }
  
  // Check gas level
  if (gas_value > GAS_THRESHOLD) {
    Serial.println("WARNING: Poor air quality detected!");
    // Red LED control handled in the main loop for blinking effect
  } else {
    // Turn off red LED if gas level is normal
    digitalWrite(RED_LED_PIN, LOW);
  }
  
  // Overall status
  if (sound_value <= SOUND_THRESHOLD && gas_value <= GAS_THRESHOLD) {
    Serial.println("Status: Normal conditions");
    digitalWrite(GREEN_LED_PIN, HIGH); // Green LED on for normal status
    buzzer_silenced = false; // Reset buzzer silencing when conditions return to normal
  } else {
    Serial.println("Status: WARNING - Environmental conditions require attention");
    digitalWrite(GREEN_LED_PIN, LOW); // Turn off green LED during warnings
  }
}
