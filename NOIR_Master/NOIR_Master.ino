#include <Wire.h>

// Definisi alamat I2C Slave
#define SLAVE_ADDRESS 0x08

// Deklarasi fungsi assembly eksternal
extern "C" {
  void setup_asm();
  void loop_asm();
  void set_sensor_values(uint8_t noise_value_low, uint8_t noise_value_high, uint8_t gas_value_low, uint8_t gas_value_high);
}

// Nilai sensor terakhir yang diterima dari Slave
uint16_t last_noise_value = 0;
uint16_t last_gas_value = 0;

// Waktu request terakhir
unsigned long lastRequestTime = 0;
const unsigned long requestInterval = 500; // 500ms interval polling

void setup() {
  // Inisialisasi serial untuk debugging
  Serial.begin(9600);
  Serial.println("NOIR - Master starting...");
  
  // Inisialisasi I2C sebagai Master
  Wire.begin();
  
  // Panggil setup assembly
  setup_asm();
  
  Serial.println("NOIR - Master initialized");
}

void loop() {
  // Request data dari Slave setiap interval waktu tertentu
  unsigned long currentTime = millis();
  if (currentTime - lastRequestTime >= requestInterval) {
    lastRequestTime = currentTime;
    requestDataFromSlave();
  }
  
  // Panggil loop assembly
  loop_asm();
  
  // Tampilkan data ke Serial Monitor
  displaySensorData();
  
  delay(100); // Sedikit delay untuk mengurangi beban CPU
}

// Fungsi untuk meminta data dari Slave
void requestDataFromSlave() {
  Wire.requestFrom(SLAVE_ADDRESS, 4); // Request 4 byte data (noise low, noise high, gas low, gas high)
  
  if (Wire.available() >= 4) {
    // Baca data noise (low dan high byte)
    uint8_t noise_low = Wire.read();
    uint8_t noise_high = Wire.read();
    last_noise_value = (noise_high << 8) | noise_low;
    
    // Baca data gas (low dan high byte)
    uint8_t gas_low = Wire.read();
    uint8_t gas_high = Wire.read();
    last_gas_value = (gas_high << 8) | gas_low;
    
    // Set nilai sensor ke fungsi assembly
    set_sensor_values(noise_low, noise_high, gas_low, gas_high);
  }
}

// Fungsi untuk menampilkan data sensor ke Serial Monitor
void displaySensorData() {
  static unsigned long lastDisplayTime = 0;
  unsigned long currentTime = millis();
  
  // Update tampilan setiap 1 detik
  if (currentTime - lastDisplayTime >= 1000) {
    lastDisplayTime = currentTime;
    
    Serial.println("==========================");
    Serial.println("NOIR Monitoring System");
    Serial.println("--------------------------");
    Serial.print("Noise Level: ");
    Serial.print(last_noise_value);
    Serial.print("/1023 (");
    
    // Interprestasi nilai noise
    if (last_noise_value < 200) {
      Serial.println("Silent)");
    } else if (last_noise_value < 400) {
      Serial.println("Quiet)");
    } else if (last_noise_value < 600) {
      Serial.println("Normal)");
    } else if (last_noise_value < 800) {
      Serial.println("Noisy)");
    } else {
      Serial.println("Very Noisy)");
    }
    
    Serial.print("Gas Level: ");
    Serial.print(last_gas_value);
    Serial.print("/1023 (");
    
    // Interprestasi nilai gas
    if (last_gas_value < 200) {
      Serial.println("Excellent)");
    } else if (last_gas_value < 400) {
      Serial.println("Good)");
    } else if (last_gas_value < 600) {
      Serial.println("Moderate)");
    } else if (last_gas_value < 800) {
      Serial.println("Poor)");
    } else {
      Serial.println("Hazardous)");
    }
    
    Serial.println("==========================");
  }
}