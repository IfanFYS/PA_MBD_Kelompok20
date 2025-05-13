#include <Wire.h>

// Definisi alamat I2C Slave
#define SLAVE_ADDRESS 0x08

// Definisi pin analog untuk sensor
#define SOUND_SENSOR_PIN A0
#define GAS_SENSOR_PIN A1

// Deklarasi fungsi assembly eksternal
extern "C" {
  void setup_slave_asm();
  void loop_slave_asm();
  void get_sensor_values(uint16_t* sound_value_ptr, uint16_t* gas_value_ptr);
}

// Variabel untuk menyimpan nilai sensor
uint16_t sound_value = 0;
uint16_t gas_value = 0;

void setup() {
  // Inisialisasi serial untuk debugging
  Serial.begin(9600);
  Serial.println("NOIR - Slave starting...");

  // Inisialisasi I2C sebagai Slave
  Wire.begin(SLAVE_ADDRESS);
  
  // Definisikan fungsi callback untuk request dari Master
  Wire.onRequest(requestEvent);
  
  // Panggil setup assembly
  setup_slave_asm();
  
  Serial.println("NOIR - Slave initialized");
}

void loop() {
  // Panggil loop assembly
  loop_slave_asm();
  
  // Baca langsung dari ADC untuk simulasi (mungkin nanti diganti dengan pembacaan dari assembly)
  static unsigned long lastSensorReadTime = 0;
  unsigned long currentTime = millis();
  
  if (currentTime - lastSensorReadTime >= 100) { // Read every 100ms
    lastSensorReadTime = currentTime;
    
    // Baca dari sensor fisik
    sound_value = analogRead(SOUND_SENSOR_PIN);
    gas_value = analogRead(GAS_SENSOR_PIN);
    
    // Update nilai di assembly
    get_sensor_values(&sound_value, &gas_value);
  }
  
  // Tampilkan nilai sensor untuk debugging
  static unsigned long lastPrintTime = 0;
  unsigned long currentTime = millis();
  
  if(currentTime - lastPrintTime >= 1000) {
    lastPrintTime = currentTime;
    
    Serial.print("Sound Sensor: ");
    Serial.print(sound_value);
    Serial.print(" | Gas Sensor: ");
    Serial.println(gas_value);
  }
  
  delay(100); // Sedikit delay untuk mengurangi beban CPU
}

// Fungsi callback saat Master minta data
void requestEvent() {
  // Kirim nilai sensor ke Master (low dan high byte)
  Wire.write((uint8_t)(sound_value & 0xFF));     // Noise low byte
  Wire.write((uint8_t)((sound_value >> 8) & 0xFF)); // Noise high byte
  Wire.write((uint8_t)(gas_value & 0xFF));       // Gas low byte
  Wire.write((uint8_t)((gas_value >> 8) & 0xFF));   // Gas high byte
}