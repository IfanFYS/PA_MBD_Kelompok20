# NOIR - Noise and Air Quality Monitoring System

## Deskripsi Proyek
NOIR (Noise and Air Quality Monitoring System) adalah sistem pemantauan otomatis untuk ruang belajar seperti perpustakaan atau ruang kelas. Sistem ini melakukan pemantauan terhadap kebisingan (noise) dan kualitas udara (air quality) secara real-time untuk memastikan suasana belajar yang nyaman dan kondusif.

## Arsitektur Sistem
Sistem NOIR terdiri dari dua komponen Arduino:
1. **Arduino Slave**: Terhubung dengan sensor-sensor dan melakukan pengumpulan data.
2. **Arduino Master**: Menerima data dari Slave, mengevaluasi kondisi, dan memberikan peringatan bila diperlukan.

## Fitur Utama
- Pemantauan tingkat kebisingan menggunakan sensor suara KY-037
- Pemantauan kualitas udara menggunakan sensor gas MQ-2/MQ-135
- Indikator visual (3 LED) untuk status kondisi lingkungan
- Indikator suara (buzzer) untuk peringatan
- Button untuk mematikan bunyi peringatan
- Komunikasi antara Arduino menggunakan protokol I2C
- Output data pemantauan melalui Serial Monitor

## Implementasi Modul
### Modul 2 (Introduction to Assembly & I/O Programming)
- Program Assembly untuk mengontrol komponen I/O pada Master (LED, buzzer, button)
- Pengaturan pin digital untuk komponen I/O dasar

### Modul 3 (ADC - Analog to Digital Conversion)
- Konversi analog ke digital untuk sensor suara dan gas
- Pemrosesan data analog menjadi nilai digital
- Penentuan ambang batas (threshold) untuk tingkat kebisingan dan konsentrasi gas

### Modul 4 (Serial Port - USART)
- Komunikasi serial pada Master untuk menampilkan data ke Serial Monitor
- Format pesan untuk menampilkan status pemantauan secara real-time

### Modul 6 (Timer)
- Pengambilan data sensor pada interval waktu tetap
- Pengaturan frekuensi kedipan LED peringatan
- Pengaturan durasi bunyi buzzer

### Modul 7 (Interrupt)
- Interrupt untuk button yang mematikan buzzer
- Interrupt pada kondisi threshold terlampaui

### Modul 8 (I2C)
- Komunikasi I2C untuk pengiriman data dari Slave ke Master
- Format paket data untuk transmisi nilai kebisingan dan kualitas udara

### Modul 9 (Sensor Interfacing)
- Antarmuka untuk sensor suara KY-037
- Antarmuka untuk sensor gas MQ-2/MQ-135
- Pengolahan sinyal sensor untuk mendapatkan pembacaan yang akurat

## Struktur Kode
### NOIR_Master
- **NOIR_Master.ino**: Kode Arduino utama untuk Master
- **NOIR_Master.S**: Kode Assembly untuk fungsi-fungsi pemrosesan data dan kontrol I/O

### NOIR_Slave
- **NOIR_Slave.ino**: Kode Arduino utama untuk Slave
- **NOIR_Slave.S**: Kode Assembly untuk fungsi-fungsi pembacaan sensor dan konversi data

## Koneksi Pin
### Arduino Master
- D2: LED Merah (warning kebisingan)
- D3: LED Kuning (warning kualitas udara)
- D4: LED Hijau (status normal)
- D5: Buzzer
- D6: Button (mematikan buzzer)
- A4/A5: I2C (SDA/SCL) terhubung ke Slave

### Arduino Slave
- A0: Sensor Suara (KY-037)
- A1: Sensor Gas (MQ-2/MQ-135)
- A4/A5: I2C (SDA/SCL) terhubung ke Master

## Cara Penggunaan
1. Upload kode NOIR_Slave.ino ke Arduino Slave
2. Upload kode NOIR_Master.ino ke Arduino Master
3. Hubungkan semua komponen sesuai dengan koneksi pin yang telah ditentukan
4. Buka Serial Monitor untuk melihat data pemantauan
5. Amati indikator LED dan buzzer untuk status kondisi

## Simulasi di Proteus
Untuk simulasi sistem di Proteus, silakan merujuk ke file [Proteus_Setup_Guide.md](./Proteus_Setup_Guide.md) untuk petunjuk lengkap.

## Anggota Kelompok
- [Nama Anggota 1]
- [Nama Anggota 2]
- [Nama Anggota 3]
- ...

## Lisensi
[Sesuaikan dengan lisensi proyek]