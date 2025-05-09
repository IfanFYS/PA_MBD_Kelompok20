// NOIR - Noise and Air Quality Monitoring System
// Slave Device

// Include Wire library for I2C communication
#include <Wire.h>

// Define slave I2C address
#define SLAVE_ADDR 0x08

// Pin Definitions for sensors
#define SOUND_SENSOR_PIN A0  // Sound sensor on A0
#define MQ2_SENSOR_PIN A1    // MQ2 gas sensor on A1
#define DHT11_PIN 2          // DHT11 data pin to D2

// Variables to store sensor values
byte noiseDataByte = 0;      // Noise level data to send to master
byte gasDataByte = 0;        // Gas level data to send to master
byte humidityDataByte = 0;   // Humidity data to send to master
byte temperatureDataByte = 0; // Temperature data to send to master

int soundLevel = 0;          // Raw sound level from sensor
int gasLevel = 0;            // Raw gas level from sensor
float humidity = 0.0;        // Raw humidity from DHT11
float temperature = 0.0;     // Raw temperature from DHT11

// Timing variables
unsigned long previousMillis = 0;
const long interval = 500;  // Reading interval (0.5 second)
unsigned long dhtReadMillis = 0;
const long dhtInterval = 2000;  // DHT11 read interval (2 seconds)

void setup() {
  // Initialize serial communication for debugging
  Serial.begin(9600);
  Serial.println("NOIR Monitoring System - Slave Initializing");
  
  // Initialize I2C communications as slave
  Wire.begin(SLAVE_ADDR);
  
  // Define callbacks for I2C communication
  Wire.onRequest(requestEvent);  // Data requested from master
  Wire.onReceive(receiveEvent);  // Data received from master
  
  // Set sensor pin modes
  pinMode(SOUND_SENSOR_PIN, INPUT);
  pinMode(MQ2_SENSOR_PIN, INPUT);
  pinMode(DHT11_PIN, INPUT);
  
  // Initial temperature and humidity values (room temperature as default)
  temperature = 25.0;  // 25°C
  humidity = 50.0;     // 50%
  
  Serial.println("Slave Initialization Complete");
}

void loop() {
  unsigned long currentMillis = millis();
  
  // Read analog sensors at the specified interval
  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;
    
    // Read sound and gas sensors
    readAnalogSensors();
    
    // Process data if needed
    processData();
    
    // Display data on serial monitor for debugging
    displayData();
  }
  
  // Read DHT11 at a slower interval (DHT11 needs at least 2s between readings)
  if (currentMillis - dhtReadMillis >= dhtInterval) {
    dhtReadMillis = currentMillis;
    
    // Read DHT11 temperature and humidity
    readDHT11();
  }
}

void readAnalogSensors() {
  // Read sound sensor value
  soundLevel = analogRead(SOUND_SENSOR_PIN);
  
  // Read gas sensor value
  gasLevel = analogRead(MQ2_SENSOR_PIN);
  
  // Process sensor data into bytes for I2C transmission
  noiseDataByte = map(soundLevel, 0, 1023, 0, 255);  // Map analog reading to byte range
  gasDataByte = map(gasLevel, 0, 1023, 0, 255);      // Map analog reading to byte range
}

// Read DHT11 sensor without library
void readDHT11() {
  // Variables for the DHT11 reading process
  byte data[5] = {0, 0, 0, 0, 0};  // DHT11 sends 5 bytes of data
  
  // Step 1: Send start signal to DHT11
  pinMode(DHT11_PIN, OUTPUT);
  digitalWrite(DHT11_PIN, LOW);
  delay(18);  // At least 18ms low signal to wake up DHT11
  
  // Step 2: Switch to input and wait for DHT11 response
  pinMode(DHT11_PIN, INPUT);
  
  // In Proteus simulation environment, we'll use analog values to simulate the DHT11
  // We'll use the values from A2 and A3 pins if available, otherwise use default values
  
  // Read analog values as simulated temperature and humidity (for Proteus)
  int rawTemp = analogRead(A2);  // Use A2 for temperature simulation
  int rawHumid = analogRead(A3); // Use A3 for humidity simulation
  
  if (rawTemp > 0) {
    // Map from 0-1023 to 0-50°C (typical temperature range)
    temperature = map(rawTemp, 0, 1023, 0, 50);
  } else {
    temperature = 25.0; // Default room temperature if no simulation input
  }
  
  if (rawHumid > 0) {
    // Map from 0-1023 to 0-100% (humidity range)
    humidity = map(rawHumid, 0, 1023, 0, 100);
  } else {
    humidity = 50.0; // Default humidity if no simulation input
  }
  
  // Map humidity (0-100%) and temperature (0-50°C) to byte range (0-255)
  humidityDataByte = map(humidity * 10, 0, 1000, 0, 255);  // Multiply by 10 to preserve decimal
  temperatureDataByte = map(temperature * 10, 0, 500, 0, 255);  // Multiply by 10 to preserve decimal
  
  // For debugging
  Serial.print("DHT11 Reading - Temp: ");
  Serial.print(temperature);
  Serial.print("°C, Humidity: ");
  Serial.print(humidity);
  Serial.println("%");
}

void processData() {
  // Apply any processing needed to sensor data
  // For example:
  // - Apply filtering to reduce noise
  // - Apply calibration factors
  // - Detect specific patterns or peaks
}

void displayData() {
  // Display data for debugging
  Serial.println("\n===== NOIR Slave Data =====");
  Serial.print("Sound Level: ");
  Serial.print(soundLevel);
  Serial.print(" (Byte: ");
  Serial.print(noiseDataByte);
  Serial.println(")");
  
  Serial.print("Gas Level: ");
  Serial.print(gasLevel);
  Serial.print(" (Byte: ");
  Serial.print(gasDataByte);
  Serial.println(")");
  
  Serial.print("Humidity: ");
  Serial.print(humidity);
  Serial.print("% (Byte: ");
  Serial.print(humidityDataByte);
  Serial.println(")");
  
  Serial.print("Temperature: ");
  Serial.print(temperature);
  Serial.print("°C (Byte: ");
  Serial.print(temperatureDataByte);
  Serial.println(")");
  
  Serial.println("==========================");
}

// Function executed when data is requested by master
void requestEvent() {
  // Send four bytes to the master device when requested (noise, gas, humidity, temperature)
  Wire.write(noiseDataByte);
  Wire.write(gasDataByte);
  Wire.write(humidityDataByte);
  Wire.write(temperatureDataByte);
}

// Function executed when data is received from master
void receiveEvent(int byteCount) {
  // Handle incoming data from master
  while (Wire.available()) {
    byte command = Wire.read();
    
    // Process incoming command
    Serial.print("Received command from Master: ");
    Serial.println(command);
    
    // Handle different commands
    switch (command) {
      case 1:
        // Do something based on command 1
        break;
      case 2:
        // Do something based on command 2
        break;
      default:
        // Handle unknown command
        break;
    }
  }
}