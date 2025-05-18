# 🎛️ NOIR – Noise and Air Quality Monitoring System 🌬️

## 📋 Deskripsi Proyek

NOIR (Noise and Air Quality Monitoring System) adalah sistem pemantauan otomatis untuk ruang belajar seperti perpustakaan atau ruang kelas. Sistem ini melakukan pemantauan terhadap kebisingan (noise) dan kualitas udara (air quality) secara real-time untuk memastikan suasana belajar yang nyaman dan kondusif. 

Sistem menggunakan arsitektur master-slave dengan dua Arduino yang berkomunikasi menggunakan protokol SPI. Arduino Slave terhubung dengan sensor suara (KY-037) dan sensor gas (MQ-2/MQ-135) - yang dalam simulasi Proteus direpresentasikan oleh potensiometer. Arduino Master bertanggung jawab menerima data dari Slave, mengevaluasi nilai sensor terhadap ambang batas, menampilkan nilai sensor melalui Serial Monitor, dan mengontrol indikator visual (LED) serta peringatan audio (buzzer).

## 💻 Implementasi Modul

### ⚙️ Modul 2 (Introduction to Assembly & I/O Programming):
- Implementasi program Assembly untuk mengontrol indikator visual pada Master:
  - LED hijau (PD2) - indikator status normal
  - LED kuning (PD3) - indikator peringatan suara/kebisingan
  - LED merah (PD4) - indikator peringatan gas/kualitas udara
- Implementasi program Assembly untuk mengontrol buzzer (PD5) dengan pola bunyi teratur
- Implementasi program Assembly untuk memproses input button (PD6) untuk mematikan buzzer
- Pengaturan pin digital I/O dengan implementasi AVR Assembly langsung

### 📊 Modul 3 (ADC - Analog to Digital Conversion):
- Implementasi ADC pada Slave untuk dua kanal masukan analog:
  - PC0/A0: Sensor suara (direpresentasikan oleh potensiometer dalam simulasi)
  - PC1/A1: Sensor gas (direpresentasikan oleh potensiometer dalam simulasi)
- Konfigurasi ADC dengan resolusi 8-bit dan left-adjusted result
- Implementasi pembacaan sekuensial dari dua kanal ADC
- Penentuan nilai ambang batas (threshold):
  - Ambang batas suara: 153 (60% dari nilai maksimum 255)
  - Ambang batas gas: 178 (70% dari nilai maksimum 255)

### 📡 Modul 4 (Serial Port - USART):
- Implementasi komunikasi serial pada Master dengan baud rate 9600
- Pengiriman data sensor ke Serial Monitor dengan format yang dibuat khusus:
  - Nilai sensor ditampilkan dalam format persentase (0-100%)
  - Penggunaan pesan status khusus untuk kondisi peringatan
  - Notifikasi "[BUZZER SILENCED]" saat buzzer dimatikan
- Implementasi komunikasi serial pada Slave untuk debugging

### ⏱️ Modul 6 (Timer):
- Implementasi software timer untuk berbagai fungsi sistem:
  - Timer untuk kontrol frekuensi buzzer (toggle buzzer untuk output audio)
  - Timer untuk silencing timeout (reaktivasi buzzer otomatis setelah periode tertentu)
  - Timer untuk pembacaan sensor berulang dengan interval konsisten
- Penerapan delay software untuk debouncing button

### 🔘 Modul 7 (Penanganan Input dan State Management):
- Implementasi deteksi tepi (edge detection) untuk tombol:
  - Deteksi perubahan status button dari tidak ditekan ke ditekan (rising edge)
  - Logika debouncing untuk mencegah false trigger
- Implementasi state machine untuk kondisi sistem:
  - Pelacakan status peringatan (sound dan gas warnings)
  - Pengelolaan status buzzer (active, silenced)
  - Timeout counter untuk reaktivasi buzzer otomatis

### 🔄 Modul 8 (SPI - Serial Peripheral Interface):
- Implementasi protokol SPI untuk komunikasi master-slave:
  - Master: Konfigurasi PORTB (SS, MOSI, MISO, SCK) dengan manajemen Slave Select
  - Slave: Respons terhadap permintaan data dari Master
- Pengaturan SPI register untuk mode master dan slave
- Protokol transfer data untuk transmisi nilai sensor:
  - Master mengirim byte permintaan yang menentukan sensor mana yang diminta
  - Slave merespons dengan nilai ADC dari sensor yang diminta
- Manajemen timing dan sinkronisasi untuk transfer data yang andal

### 🔌 Modul 9 (Sensor Interfacing):
- Implementasi pembacaan dari dua sensor analog dengan teknik ADC multiplexing
- Adaptasi kode untuk penggunaan potensiometer sebagai simulator sensor dalam Proteus:
  - Kalibrasi nilai range potensiometer untuk merepresentasikan range sensor
  - Teknik simulasi khusus untuk pengujian Proteus
- Konversi nilai sensor menjadi persentase untuk tampilan yang lebih intuitif
- Filtering dan smoothing algoritma untuk mengurangi fluktuasi pembacaan

## 🧪 Pengembangan dan Simulasi

Proyek dikembangkan menggunakan simulator Proteus dengan beberapa penyesuaian khusus:
- Penggunaan potensiometer sebagai simulator sensor analog
- Modifikasi frekuensi toggle buzzer untuk simulasi yang lebih akurat dalam Proteus
- Implementasi pengujian komponen individual sebelum integrasi sistem lengkap
- Pendekatan modular dengan file terpisah untuk Master dan Slave

## 🔧 Implementasi Tambahan

Fitur tambahan yang diimplementasikan:
- Penyempurnaan komunikasi serial dengan formatting data yang konsisten
- Sistem reaktivasi buzzer otomatis setelah periode diam tertentu
- State machine yang menangani berbagai kondisi sistem
- Edge detection untuk button input dengan debouncing
- Konversi nilai sensor ke persentase untuk pembacaan yang lebih intuitif

## 👥 Anggota Kelompok

| Nama | NPM |
|------|-----|
| Daffa Hardhan | 2306161763 |
| Fathan Yazid Satriani | 2306250560 |
| Musyaffa Iman Supriadi | 2306208464 |
| Raka Arrayan | 2306161800 |