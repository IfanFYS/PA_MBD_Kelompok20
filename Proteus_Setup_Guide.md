# NOIR System - Proteus Setup Guide

## Komponen yang Diperlukan

### Arduino Master
1. Arduino Uno (atau Arduino Uno microcontroller)

### Arduino Slave
1. Arduino Uno (atau Arduino Uno microcontroller)

### Komponen Output (terhubung ke Master)
1. LED Merah (dengan resistor 220Ω)
2. LED Kuning (dengan resistor 220Ω)
3. LED Hijau (dengan resistor 220Ω)
4. Buzzer
5. Push Button (dengan resistor pull-up 10kΩ)

### Sensor (terhubung ke Slave)
1. Sound Sensor KY-037 
   - *Jika tidak tersedia, ganti dengan potentiometer untuk simulasi*
2. Gas Sensor MQ-2/MQ-135
   - *Jika tidak tersedia, ganti dengan potentiometer untuk simulasi*

### Komponen Tambahan
1. Resistor 3 x 220Ω (untuk LED)
2. Resistor 1 x 10kΩ (untuk pull-up button)

## Koneksi Pin

### Arduino Master
* Pin D2 -> LED Merah (melalui resistor 220Ω)
* Pin D3 -> LED Kuning (melalui resistor 220Ω)
* Pin D4 -> LED Hijau (melalui resistor 220Ω)
* Pin D5 -> Buzzer+
* Pin D6 -> Button (dengan pull-up resistor 10kΩ ke 5V)
* Pin A4 (SDA) -> Pin A4 Arduino Slave
* Pin A5 (SCL) -> Pin A5 Arduino Slave
* 5V -> Common 5V line
* GND -> Common GND line

### Arduino Slave
* Pin A0 -> Sound Sensor Analog Output (KY-037)
* Pin A1 -> Gas Sensor Analog Output (MQ-135/MQ-2)
* Pin A4 (SDA) -> Pin A4 Arduino Master
* Pin A5 (SCL) -> Pin A5 Arduino Master
* 5V -> Common 5V line
* GND -> Common GND line

### Sound Sensor KY-037 (atau potentiometer)
* VCC -> 5V
* GND -> GND
* AO -> Pin A0 Arduino Slave
* DO -> Tidak terhubung (opsional)

### Gas Sensor MQ-135/MQ-2 (atau potentiometer)
* VCC -> 5V
* GND -> GND
* AO -> Pin A1 Arduino Slave
* DO -> Tidak terhubung (opsional)

## Langkah-langkah Setup di Proteus

1. **Membuat Project Baru**
   * Buka Proteus ISIS
   * Buat project baru
   * Atur ukuran lembar kerja yang sesuai

2. **Menambahkan Komponen**
   * Cari dan tambahkan 2 Arduino Uno 
   * Cari dan tambahkan 3 LED (Merah, Kuning, Hijau)
   * Cari dan tambahkan Buzzer
   * Cari dan tambahkan Push Button
   * Cari dan tambahkan Resistor (3 x 220Ω, 1 x 10kΩ)
   * Cari dan tambahkan KY-037 dan MQ-135 (jika tersedia)
   * Jika sensor tidak tersedia, tambahkan 2 potentiometer untuk simulasi

3. **Menghubungkan Komponen**
   * Hubungkan semua komponen sesuai dengan bagian Koneksi Pin di atas
   * Pastikan semua ground terhubung ke jalur GND bersama
   * Pastikan semua VCC terhubung ke jalur 5V bersama

4. **Mengatur Arduino**
   * Klik kanan pada Arduino Master -> Edit Properties
   * Pilih "Program File" dan arahkan ke file .hex dari NOIR_Master (setelah dikompilasi)
   * Klik kanan pada Arduino Slave -> Edit Properties
   * Pilih "Program File" dan arahkan ke file .hex dari NOIR_Slave (setelah dikompilasi)

5. **Simulasi**
   * Jalankan simulasi
   * Atur nilai potentiometer untuk menyimulasikan kondisi kebisingan dan kualitas udara yang berbeda
   * Verifikasi bahwa LED menyala dan buzzer berbunyi sesuai dengan desain

## Catatan Untuk Simulasi

1. **Pengganti Sensor**
   * Jika KY-037 atau MQ-135/MQ-2 tidak tersedia di Proteus, gunakan potentiometer (POT-HG) untuk mensimulasikan:
     * Putar potentiometer untuk mengubah tegangan analog yang dikirim ke pin Arduino
     * Tegangan rendah = Tingkat kebisingan/gas rendah
     * Tegangan tinggi = Tingkat kebisingan/gas tinggi

2. **Debug Serial**
   * Tambahkan komponen Virtual Terminal dan hubungkan ke pin TX/RX Arduino Master untuk melihat output serial

3. **Verifikasi I2C**
   * Gunakan Logic Analyzer untuk memeriksa komunikasi I2C antara Master dan Slave jika diperlukan

## Gambar Rangkaian

```
[Arduino Master] --- [I2C] --- [Arduino Slave]
     |                              |
     |                              |
[LED RGB, Buzzer, Button]     [Sound & Gas Sensors]
```

Dengan mengikuti panduan ini, Anda akan dapat membuat rangkaian NOIR (Noise and Air Quality Monitoring System) di Proteus untuk simulasi dan pengujian.
