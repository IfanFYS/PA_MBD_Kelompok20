# Dokumentasi NOIR - Noise and Air Quality Monitoring System

## Pendahuluan
NOIR (Noise and Air Quality Monitoring System) adalah sistem pemantauan kebisingan dan kualitas udara yang dirancang khusus untuk lingkungan belajar seperti perpustakaan dan ruang kelas. Sistem ini bertujuan untuk memastikan kondisi lingkungan yang optimal untuk kegiatan belajar.

## Spesifikasi Proyek

### Tujuan
- Memantau tingkat kebisingan ruangan secara real-time
- Memantau kualitas udara ruangan secara real-time
- Memberikan peringatan saat kondisi tidak ideal
- Menjaga lingkungan belajar tetap kondusif

### Komponen Hardware
1. **Arduino Board**
   - 1x Arduino Uno/Nano (Master)
   - 1x Arduino Uno/Nano (Slave)

2. **Sensor**
   - 1x Sound Sensor KY-037
   - 1x Gas Sensor MQ-135/MQ-2

3. **Output**
   - 1x LED Merah (indikator kebisingan)
   - 1x LED Kuning (indikator kualitas udara)
   - 1x LED Hijau (indikator kondisi normal)
   - 1x Buzzer (peringatan suara)

4. **Input User**
   - 1x Push Button (untuk mematikan buzzer)

5. **Komponen Pendukung**
   - 3x Resistor 220Ω (untuk LED)
   - 1x Resistor 10kΩ (untuk pull-up button)
   - Kabel jumper secukupnya
   - Breadboard

### Fitur Software
1. **Monitoring**
   - Pembacaan data sensor suara secara berkala
   - Pembacaan data sensor gas secara berkala
   - Evaluasi kondisi berdasarkan threshold

2. **Peringatan**
   - Visual: LED warna-warni
   - Audio: Buzzer

3. **Komunikasi**
   - Protokol I2C antara Master dan Slave
   - Output ke Serial Monitor

## Implementasi Teknis

### 1. Arduino Slave
Arduino Slave berfungsi sebagai pengumpul data dari sensor. Tugas utamanya:

- Membaca data analog dari sensor suara (KY-037) melalui pin A0
- Membaca data analog dari sensor gas (MQ-135/MQ-2) melalui pin A1
- Mengirim data ke Master melalui protokol I2C
- Menggunakan timer untuk sampling sensor secara berkala

#### Kode Assembly Slave
Kode assembly di `NOIR_Slave.S` menangani:
- Konfigurasi ADC untuk pembacaan sensor analog
- Timer interrupt untuk sampling berkala
- Fungsi untuk menyimpan dan mengambil nilai sensor

### 2. Arduino Master
Arduino Master berfungsi sebagai pengolah data dan pemberi peringatan. Tugas utamanya:

- Menerima data dari Slave melalui protokol I2C
- Mengevaluasi kondisi berdasarkan threshold
- Mengontrol LED indikator
- Mengontrol buzzer peringatan
- Menampilkan data ke Serial Monitor
- Menangani input dari button

#### Kode Assembly Master
Kode assembly di `NOIR_Master.S` menangani:
- Konfigurasi I/O (LED, buzzer, button)
- Evaluasi kondisi berdasarkan nilai threshold
- Timer interrupt untuk kedipan LED saat peringatan
- Interrupt untuk button yang mematikan buzzer

## Alur Kerja Sistem

1. **Slave**:
   - Membaca nilai sensor suara dan gas secara berkala
   - Menyimpan nilai ke dalam variable
   - Menunggu permintaan data dari Master

2. **Master**:
   - Meminta data dari Slave secara berkala
   - Menerima dan memproses data
   - Mengevaluasi kondisi berdasarkan threshold
   - Mengaktifkan peringatan jika diperlukan
   - Menampilkan data ke Serial Monitor

3. **Alur Peringatan**:
   - Jika kebisingan > threshold: LED Merah + Buzzer
   - Jika kualitas udara > threshold: LED Kuning + Buzzer
   - Jika semua normal: LED Hijau

4. **Input User**:
   - Button ditekan: Buzzer dimatikan

## Panduan Penggunaan

### Setup Hardware
1. Rangkai komponen sesuai dengan diagram koneksi
2. Pastikan sensor terpasang dengan benar
3. Pastikan koneksi I2C antara kedua Arduino sudah benar

### Mengupload Program
1. Upload `NOIR_Slave.ino` ke Arduino Slave
2. Upload `NOIR_Master.ino` ke Arduino Master

### Operasi Sistem
1. Power on kedua Arduino
2. Tunggu beberapa saat untuk inisialisasi sensor
3. Sistem akan mulai memantau secara otomatis
4. Buka Serial Monitor (baud rate 9600) untuk melihat data
5. Perhatikan indikator LED:
   - Hijau: Kondisi normal
   - Merah: Kebisingan tinggi
   - Kuning: Kualitas udara rendah
6. Jika buzzer berbunyi, tekan button untuk mematikannya

### Kalibrasi
Untuk kalibrasi threshold:
1. Buka file `NOIR_Master.S`
2. Sesuaikan nilai `NOISE_THRESHOLD_H`, `NOISE_THRESHOLD_L`, `GAS_THRESHOLD_H`, dan `GAS_THRESHOLD_L`
3. Upload ulang program ke Master

## Troubleshooting

### Masalah Komunikasi I2C
- Periksa koneksi kabel SDA dan SCL
- Pastikan alamat I2C Slave sudah benar (`0x08`)
- Jalankan program I2C scanner untuk memverifikasi koneksi

### Sensor Tidak Merespon
- Periksa koneksi VCC dan GND sensor
- Periksa pin analog yang digunakan (A0 untuk suara, A1 untuk gas)
- Coba kalibrasi sensor secara manual

### LED/Buzzer Tidak Berfungsi
- Periksa koneksi pin dan resistor
- Pastikan polaritas komponen sudah benar
- Verifikasi kode untuk konfigurasi pin output

## Lampiran

### Diagram Rangkaian
[Lihat file NOIR_Schematic.pdsprj]

### Panduan Simulasi Proteus
[Lihat file Proteus_Setup_Guide.md]

### Kode Sumber
- [NOIR_Master/NOIR_Master.ino](../NOIR_Master/NOIR_Master.ino)
- [NOIR_Master/NOIR_Master.S](../NOIR_Master/NOIR_Master.S)
- [NOIR_Slave/NOIR_Slave.ino](../NOIR_Slave/NOIR_Slave.ino)
- [NOIR_Slave/NOIR_Slave.S](../NOIR_Slave/NOIR_Slave.S)