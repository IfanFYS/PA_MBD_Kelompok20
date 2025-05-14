; program menggunakan bahasa Assembly untuk ATmega328p (Arduino Uno) yang berinteraksi dengan sensor suhu DHT11 dan 3 buah LED (LED_A di PC0, LED_B di PC1, LED_C di PC2). Program harus melakukan hal berikut:
; Inisialisasi Port C sebagai output untuk LED.
; Secara berkala (misalnya setiap ~1-2 detik), baca nilai suhu integer (byte ke-3 dari data 40-bit) dari sensor DHT11 yang terhubung ke pin yang sesuai (misal PB1 seperti contoh modul).
; Atur kondisi ketiga LED berdasarkan nilai suhu yang dibaca:
; State 1: Jika Suhu < 26°C → LED_A menyala, LED_B mati, LED_C mati.
; State 2: Jika 26°C ≤ Suhu < 29°C → LED_A mati, LED_B menyala, LED_C mati.
; State 3: Jika Suhu ≥ 29°C → LED_A mati, LED_B mati, LED_C menyala.
; Program harus berjalan terus-menerus membaca dan mengatur LED.

#define __SFR_OFFSET 0x00
#include <avr/io.h>

.global main

main:
    ; Set PC0-PC2 as output for LED
    LDI R16, 0b00000111
    OUT DDRC, R16
    CLR R16
    OUT PORTC, R16

loop:
    RCALL delay_2s

    ; Send START signal to DHT11 via PB1
    SBI DDRB, 1       ; PB1 as output
    CBI PORTB, 1      ; Pull LOW
    RCALL delay_20ms  ; Wait at least 18ms (20ms)
    SBI PORTB, 1      ; Pull HIGH
    RCALL delay_40us  ; Short HIGH pulse
    CBI DDRB, 1       ; Set PB1 as input

    ; Wait for response from DHT11
wait_resp1:
    SBIC PINB, 1
    RJMP wait_resp1
wait_resp2:
    SBIS PINB, 1
    RJMP wait_resp2
wait_resp3:
    SBIC PINB, 1
    RJMP wait_resp3

    ; Read 5 bytes from DHT11 (40 bits)
    RCALL DHT11_reading ; Byte 1 - Humidity Int
    RCALL DHT11_reading ; Byte 2 - Humidity Dec
    RCALL DHT11_reading ; Byte 3 - Temperature Int
    MOV R20, R18        ; Save temperature integer in R20
    RCALL DHT11_reading ; Byte 4 - Temperature Dec
    RCALL DHT11_reading ; Byte 5 - Checksum

    ; Clear all LEDs first
    LDI R16, 0x00
    OUT PORTC, R16

    ; Compare R20 with 26 and 29
    LDI R21, 26
    CP R20, R21
    BRLO suhu_rendah

    LDI R21, 29
    CP R20, R21
    BRLO suhu_sedang

suhu_tinggi:
    LDI R16, 0b00000100   ; PC2 ON
    OUT PORTC, R16
    RJMP loop

suhu_sedang:
    LDI R16, 0b00000010   ; PC1 ON
    OUT PORTC, R16
    RJMP loop

suhu_rendah:
    LDI R16, 0b00000001   ; PC0 ON
    OUT PORTC, R16
    RJMP loop

; DHT11_reading
DHT11_reading:
    LDI R17, 8      ; 8 bits
    CLR R18         ; Clear byte
read_bit:
    ; Wait for HIGH (start of bit)
wait_high:
    SBIS PINB, 1
    RJMP wait_high

    RCALL delay_timer0    ; Delay ~50us

    ; Check if still HIGH → bit = 1
    SBIS PINB, 1
    RJMP bit_0

    SEC
    ROL R18
    RJMP bit_done

bit_0:
    LSL R18

bit_done:
    ; Wait for LOW (end of bit)
wait_low:
    SBIC PINB, 1
    RJMP wait_low

    DEC R17
    BRNE read_bit
    RET

; Delay ~2s
delay_2s:
    LDI R21, 255
d2s1: LDI R22, 255
d2s2: LDI R23, 164
d2s3: DEC R23
    BRNE d2s3
    DEC R22
    BRNE d2s2
    DEC R21
    BRNE d2s1
    RET

; Delay 20ms
delay_20ms:
    LDI R21, 255
d20_1: LDI R22, 210
d20_2: LDI R23, 2
d20_3: DEC R23
    BRNE d20_3
    DEC R22
    BRNE d20_2
    DEC R21
    BRNE d20_1
    RET

; Delay ~40us (manual NOPs)
delay_40us:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    RET

; Delay ~50us using Timer0
delay_timer0:
    CLR R16
    OUT TCNT0, R16
    LDI R16, 100
    OUT OCR0A, R16
    LDI R16, 0b00001010    ; CTC mode, prescaler 8
    OUT TCCR0B, R16
wait_ctc:
    IN R16, TIFR0
    SBRS R16, OCF0A
    RJMP wait_ctc
    CLR R16
    OUT TCCR0B, R16        ; Stop timer
    LDI R16, (1 << OCF0A)
    OUT TIFR0, R16         ; Clear flag
    RET
