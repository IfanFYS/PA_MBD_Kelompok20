# 🎛️ NOIR - Noise and Air Quality Monitoring System 🌬️

<div align="center">
  <img src="https://img.shields.io/badge/Platform-Arduino-00979D?style=for-the-badge&logo=arduino" alt="Arduino"/>
  <img src="https://img.shields.io/badge/Language-Assembly-8A2BE2?style=for-the-badge" alt="Assembly"/>
  <img src="https://img.shields.io/badge/Simulation-Proteus-006175?style=for-the-badge" alt="Proteus"/>
</div>

## 📋 Deskripsi Proyek 

NOIR (Noise and Air Quality Monitoring System) adalah sistem pemantauan otomatis untuk ruang belajar seperti perpustakaan atau ruang kelas. Sistem ini melakukan pemantauan terhadap kebisingan (noise) dan kualitas udara (air quality) secara real-time untuk memastikan suasana belajar yang nyaman dan kondusif.

## 🏗️ Arsitektur Sistem 

Sistem NOIR menggunakan arsitektur master-slave dengan dua Arduino yang berkomunikasi menggunakan protokol SPI:

1. **Arduino Slave** 🔄:
   - Terhubung dengan sensor suara (KY-037) dan sensor gas (MQ-2/MQ-135)
   - Dalam simulasi Proteus, sensor direpresentasikan oleh potensiometer
   - Melakukan konversi analog-to-digital (ADC) dari nilai sensor
   - Mengirimkan data sensor ke Arduino Master melalui protokol SPI

2. **Arduino Master** 🧠:
   - Menerima data dari Arduino Slave
   - Mengevaluasi nilai sensor terhadap ambang batas yang ditentukan
   - Menampilkan nilai sensor melalui Serial Monitor
   - Mengontrol indikator visual (LED) sesuai dengan status kondisi
   - Mengelola peringatan audio (buzzer) saat kondisi berbahaya terdeteksi
   - Memproses input pengguna melalui button untuk mematikan buzzer

## ✨ Fitur Utama 

- **🎚️ Pemantauan Multi-Parameter**: Memantau tingkat kebisingan dan kualitas udara secara simultan 
- **💡 Indikator Status Visual**:
  - 🟢 LED Hijau: kondisi normal (semua parameter dalam batas aman)
  - 🟡 LED Kuning: peringatan kebisingan (tingkat suara melebihi ambang batas)
  - 🔴 LED Merah: peringatan kualitas udara (nilai gas melebihi ambang batas)
- **🔊 Sistem Peringatan Audio**:
  - Buzzer dengan pola bunyi teratur untuk peringatan
  - Dapat dimatikan sementara melalui tombol
  - Reaktivasi otomatis setelah timeout jika kondisi berbahaya masih berlanjut
- **👤 Interface Pengguna**:
  - Button untuk mematikan bunyi peringatan
  - Output data pemantauan melalui Serial Monitor dengan format persentase
  - Notifikasi status dan peringatan melalui Serial Monitor
- **📡 Komunikasi Antar-Mikrokontroler**: Implementasi protokol SPI untuk pertukaran data antar Arduino

## 💻 Implementasi Proyek 

### 🧩 Komponen Assembly

Proyek ini diimplementasikan dengan bahasa AVR Assembly yang diintegrasikan dengan Arduino IDE, mencakup:

- **⚙️ Pengaturan I/O**: Konfigurasi pin digital untuk LED, buzzer, dan button
- **📊 Konversi Analog-Digital**: Pembacaan nilai sensor dengan resolusi 8-bit
- **🔄 Protokol SPI**: Implementasi komunikasi master-slave antar Arduino
- **📝 Serial Formatting**: Konversi dan transmisi data dalam format persentase
- **🧠 Manajemen Status Sistem**: Pelacakan kondisi peringatan dan status buzzer
- **🔘 Debouncing Button**: Deteksi tepi (edge detection) untuk input button yang andal
- **⏱️ Timer Software**: Implementasi timer untuk manajemen buzzer dan timeout

### 🔧 Teknik Implementasi

- **↕️ Edge-Triggered Inputs**: Deteksi perubahan status button untuk interaksi yang responsif
- **⏲️ Timer Logic**: Implementasi timer software untuk buzzer cycling dan timeout
- **📊 State Management**: Pelacakan status peringatan dan kondisi silencing
- **🔬 Enhanced Simulation**: Teknik khusus untuk memastikan komponen simulasi di Proteus bekerja dengan baik
- **📂 Modular Code Structure**: Kode yang terorganisir dalam subrutin terkait fungsi tertentu
- **⚡ Real-time Processing**: Pemrosesan nilai sensor dan evaluasi kondisi secara real-time

## 📁 Struktur Kode

Proyek NOIR terdiri dari beberapa komponen kode yang terorganisir:

### 🎛️ NOIR_Master_FINAL

- **NOIR_Master.ino**: File wrapper Arduino yang mengintegrasikan kode Assembly
- **NOIR_Master.S**: Kode AVR Assembly untuk Arduino Master yang menangani:
  - Inisialisasi komunikasi SPI dan Serial
  - Pembacaan data dari Slave via SPI
  - Pemrosesan data sensor dan perbandingan dengan ambang batas
  - Pengendalian LED, buzzer, dan logika peringatan
  - Antarmuka pengguna melalui button dan LED
  - Pengelolaan status peringatan dan sistem silencing

### 🔌 NOIR_Slave_FINAL

- **NOIR_Slave.ino**: File wrapper Arduino yang mengintegrasikan kode Assembly
- **NOIR_Slave.S**: Kode AVR Assembly untuk Arduino Slave yang menangani:
  - Inisialisasi ADC dan komunikasi SPI
  - Pembacaan sensor analog (sound dan gas)
  - Konversi nilai sensor ke format digital
  - Pengiriman data ke Master saat diminta melalui SPI
  - Debug output ke Serial Monitor

### 📚 Folder Pendukung Lainnya

- **NOIR_CPP**: Versi C++ dari sistem sebagai referensi
- **Proteus Tests**: Berbagai program uji untuk komponen individual
- **Dokumentasi**: File dokumentasi dan rancangan proyek

## 🔌 Koneksi Pin

### 🎛️ Arduino Master

- **Digital I/O**:
  - PD2 (2): 🟢 LED Hijau - indikator status normal
  - PD3 (3): 🟡 LED Kuning - indikator peringatan suara
  - PD4 (4): 🔴 LED Merah - indikator peringatan gas
  - PD5 (5): 🔊 Buzzer - indikator audio peringatan
  - PD6 (6): 🔘 Button - kontrol mematikan buzzer
 
- **SPI (PORTB)**:
  - PB2 (SS): Slave Select
  - PB3 (MOSI): Master Out Slave In
  - PB4 (MISO): Master In Slave Out
  - PB5 (SCK): Serial Clock

### 🔌 Arduino Slave

- **Analog Input**:
  - PC0/A0: 🎚️ Sensor suara (KY-037) atau potensiometer
  - PC1/A1: 💨 Sensor gas (MQ-2/MQ-135) atau potensiometer

- **SPI (PORTB)**:
  - PB2 (SS): Slave Select
  - PB3 (MOSI): Master Out Slave In
  - PB4 (MISO): Master In Slave Out
  - PB5 (SCK): Serial Clock

## 📝 Cara Penggunaan

1. Upload kode NOIR_Slave.ino ke Arduino Slave
2. Upload kode NOIR_Master.ino ke Arduino Master
3. Hubungkan semua komponen (LED, buzzer, button, potensiometer) sesuai diagram koneksi
4. Buka Serial Monitor untuk Arduino Master dengan baud rate 9600
5. Atur nilai potensiometer untuk mensimulasikan berbagai kondisi sensor
6. Amati respons LED dan buzzer terhadap perubahan nilai sensor
7. Tekan button untuk mematikan buzzer saat peringatan aktif
8. Perhatikan reset otomatis silencing setelah timeout atau ketika kondisi kembali normal

## 📊 Nilai Ambang Batas (Threshold)

Sistem NOIR menggunakan ambang batas berikut untuk deteksi kondisi peringatan:

- **🎚️ Ambang Batas Suara**: 153 (60% dari nilai maksimum 255)
  - Nilai ≥ 153: Peringatan suara aktif
  - Nilai < 153: Status suara normal

- **💨 Ambang Batas Gas**: 178 (70% dari nilai maksimum 255)
  - Nilai ≥ 178: Peringatan gas aktif
  - Nilai < 178: Status gas normal

## 🖥️ Simulasi di Proteus

Proyek ini dikembangkan dan diuji menggunakan simulator Proteus untuk memastikan fungsionalitas sebelum implementasi pada perangkat keras. Beberapa pertimbangan khusus dalam simulasi:

- 🔊 Buzzer dalam Proteus memerlukan penanganan khusus (toggle beberapa kali) untuk simulasi yang akurat
- 📊 Nilai ADC disimulasikan menggunakan potensiometer
- ⏱️ Komunikasi SPI memerlukan pengaturan timing yang tepat untuk simulasi yang stabil

## 🧪 Pengembangan dan Pengujian

Proyek ini dikembangkan menggunakan pendekatan bertahap:

1. Implementasi dan pengujian fitur-fitur individual (ADC, SPI, LED, Button)
2. Integrasi komponen ke dalam sistem lengkap
3. Verifikasi fungsionalitas di simulator Proteus
4. Penyempurnaan kode untuk stabilitas dan ketahanan

## 👥 Anggota Kelompok

| Nama | NPM |
|------|-----|
| [Daffa Hardhan](https://github.com/DHard4114) | 2306161763 |
| [Fathan Yazid Satriani](https://github.com/IfanFYS) | 2306250560 |
| [Musyaffa Iman Supriadi](https://github.com/musyaffa-iman) | 2306208464 |
| [Raka Arrayan](https://github.com/raka-arrayan) | 2306161800 |

---

<div align="center">
  <p>© 2025 NOIR Team - Kelompok 23, Praktikum Sistem Embedded</p>
</div>