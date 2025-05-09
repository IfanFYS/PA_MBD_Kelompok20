// NOIR - Noise and Air Quality Monitoring System
// Master Device

// Include necessary libraries
#include <Wire.h>                // For I2C communication

// Pin Definitions
#define RED_LED 3                // Red LED pin (danger)
#define YELLOW_LED 4             // Yellow LED pin (warning)
#define GREEN_LED 5              // Green LED pin (normal)
#define BUZZER_PIN 6             // Buzzer pin

// I2C Address
#define SLAVE_ADDR 0x08          // Slave Arduino address

// Thresholds for warnings
#define NOISE_WARNING_THRESHOLD 500    // Adjust based on calibration
#define NOISE_DANGER_THRESHOLD 700     // Adjust based on calibration
#define GAS_WARNING_THRESHOLD 500      // Adjust based on calibration
#define GAS_DANGER_THRESHOLD 700       // Adjust based on calibration
#define HUMIDITY_WARNING_THRESHOLD 70   // 70% humidity
#define HUMIDITY_DANGER_THRESHOLD 85    // 85% humidity
#define TEMP_WARNING_THRESHOLD 28      // 28°C
#define TEMP_DANGER_THRESHOLD 32       // 32°C

// Timing variables
unsigned long previousMillis = 0;
const long interval = 1000;           // Reading interval (1 second)
const long buzzerDuration = 1000;     // Buzzer sound duration (1 second)
unsigned long buzzerStartTime = 0;
bool buzzerActive = false;

// Variables to store sensor values received from slave
int noiseLevel = 0;
int gasLevel = 0;
float temperature = 0.0;
float humidity = 0.0;
bool urgentAlert = false;

// Structure to store data received from slave
struct SlaveData {
  byte noiseValue;
  byte gasValue;
  byte humidityValue;
  byte temperatureValue;
};

SlaveData slaveData;

void setup() {
  // Initialize serial communication
  Serial.begin(9600);
  Serial.println("NOIR Monitoring System - Master Initializing");
  
  // Initialize I2C as master
  Wire.begin();
  
  // Set pin modes
  pinMode(RED_LED, OUTPUT);
  pinMode(YELLOW_LED, OUTPUT);
  pinMode(GREEN_LED, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  
  // Initial LED state - all off
  digitalWrite(RED_LED, LOW);
  digitalWrite(YELLOW_LED, LOW);
  digitalWrite(GREEN_LED, LOW);
  digitalWrite(BUZZER_PIN, LOW);
  
  Serial.println("Master Initialization Complete");
}

void loop() {
  unsigned long currentMillis = millis();
  
  // Request data from slave at the specified interval
  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;
    
    // Request data from slave
    requestDataFromSlave();
    
    // Process data
    processData();
    
    // Display data on serial monitor
    displayData();
  }
  
  // Handle buzzer timing
  manageBuzzer(currentMillis);
  
  // Check for any urgent conditions that need immediate attention
  if (urgentAlert) {
    // If there's an urgent alert, we might want to do something special
    // like make the buzzer sound differently
  }
}

void requestDataFromSlave() {
  // Request 4 bytes from slave device
  Wire.requestFrom(SLAVE_ADDR, 4);
  
  // If data is available from the slave
  if (Wire.available() >= 4) {
    slaveData.noiseValue = Wire.read();
    slaveData.gasValue = Wire.read();
    slaveData.humidityValue = Wire.read();
    slaveData.temperatureValue = Wire.read();
    
    // Convert data from 0-255 range to actual values
    noiseLevel = map(slaveData.noiseValue, 0, 255, 0, 1023);
    gasLevel = map(slaveData.gasValue, 0, 255, 0, 1023);
    humidity = map(slaveData.humidityValue, 0, 255, 0, 100);    // 0-100%
    temperature = map(slaveData.temperatureValue, 0, 255, 0, 50); // 0-50°C
  } else {
    Serial.println("Failed to receive data from slave!");
  }
}

void processData() {
  // Reset alert status
  urgentAlert = false;
  
  // All LEDs off initially
  digitalWrite(RED_LED, LOW);
  digitalWrite(YELLOW_LED, LOW);
  digitalWrite(GREEN_LED, LOW);
  
  // Default to green LED on
  digitalWrite(GREEN_LED, HIGH);
  
  // Check noise level
  if (noiseLevel > NOISE_DANGER_THRESHOLD) {
    digitalWrite(RED_LED, HIGH);
    digitalWrite(GREEN_LED, LOW); // Turn off green
    activateBuzzer();
    urgentAlert = true;
  } else if (noiseLevel > NOISE_WARNING_THRESHOLD) {
    digitalWrite(YELLOW_LED, HIGH);
    digitalWrite(GREEN_LED, LOW); // Turn off green
  }
  
  // Check gas level (combines with the LED status)
  if (gasLevel > GAS_DANGER_THRESHOLD) {
    digitalWrite(RED_LED, HIGH);
    digitalWrite(GREEN_LED, LOW); // Turn off green
    activateBuzzer();
    urgentAlert = true;
  } else if (gasLevel > GAS_WARNING_THRESHOLD) {
    digitalWrite(YELLOW_LED, HIGH);
    digitalWrite(GREEN_LED, LOW); // Turn off green
  }
  
  // Check humidity
  if (humidity > HUMIDITY_DANGER_THRESHOLD) {
    digitalWrite(RED_LED, HIGH);
    digitalWrite(GREEN_LED, LOW); // Turn off green
    activateBuzzer();
    urgentAlert = true;
  } else if (humidity > HUMIDITY_WARNING_THRESHOLD) {
    digitalWrite(YELLOW_LED, HIGH);
    digitalWrite(GREEN_LED, LOW); // Turn off green
  }
  
  // Check temperature
  if (temperature > TEMP_DANGER_THRESHOLD) {
    digitalWrite(RED_LED, HIGH);
    digitalWrite(GREEN_LED, LOW); // Turn off green
    activateBuzzer();
    urgentAlert = true;
  } else if (temperature > TEMP_WARNING_THRESHOLD) {
    digitalWrite(YELLOW_LED, HIGH);
    digitalWrite(GREEN_LED, LOW); // Turn off green
  }
  
  // If all sensors are in normal range, green LED will remain on
}

void displayData() {
  // Display all sensor data on serial monitor
  Serial.println("\n===== NOIR Monitoring System Data =====");
  Serial.print("Noise Level: ");
  Serial.println(noiseLevel);
  Serial.print("Air Quality (MQ-2): ");
  Serial.println(gasLevel);
  Serial.print("Temperature: ");
  Serial.print(temperature);
  Serial.println(" °C");
  Serial.print("Humidity: ");
  Serial.print(humidity);
  Serial.println(" %");
  
  // Display raw data received from slave
  Serial.println("\nRaw data from Slave:");
  Serial.print("Noise (byte): ");
  Serial.println(slaveData.noiseValue);
  Serial.print("Gas (byte): ");
  Serial.println(slaveData.gasValue);
  Serial.print("Humidity (byte): ");
  Serial.println(slaveData.humidityValue);
  Serial.print("Temperature (byte): ");
  Serial.println(slaveData.temperatureValue);
  
  // Display status
  Serial.print("\nStatus: ");
  if (digitalRead(RED_LED) == HIGH) {
    Serial.println("DANGER - Levels exceeded safe thresholds!");
  } else if (digitalRead(YELLOW_LED) == HIGH) {
    Serial.println("WARNING - Levels approaching thresholds");
  } else {
    Serial.println("NORMAL - All levels within safe range");
  }
  Serial.println("======================================");
}

void activateBuzzer() {
  buzzerActive = true;
  buzzerStartTime = millis();
  digitalWrite(BUZZER_PIN, HIGH);
}

void manageBuzzer(unsigned long currentMillis) {
  // Check if buzzer should be turned off
  if (buzzerActive && (currentMillis - buzzerStartTime >= buzzerDuration)) {
    digitalWrite(BUZZER_PIN, LOW);
    buzzerActive = false;
  }
}