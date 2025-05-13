#include <avr/io.h>

; ---------------------------------------------
; NOIR - Noise and Air Quality Monitoring System
; Slave Controller Assembly Code
; ---------------------------------------------

; Konstanta untuk pin dan setelan ADC
.equ SOUND_SENSOR_PIN, 0    ; Pin A0 untuk sensor suara KY-037
.equ GAS_SENSOR_PIN, 1      ; Pin A1 untuk sensor gas MQ-2/MQ-135

; Konstanta untuk pengaturan I2C
.equ SLAVE_ADDRESS, 0x08    ; Alamat I2C untuk Slave

; Konstanta untuk timer
.equ TIMER_PRESCALER, 64
.equ TIMER_INTERVAL, 7812   ; untuk 0.5 detik dengan prescaler 64, F_CPU=16MHz

; Variabel di global data section
.section .data
    sound_value:   .word 0  ; Hasil konversi ADC untuk sensor suara
    gas_value:     .word 0  ; Hasil konversi ADC untuk sensor gas
    adc_channel:   .byte 0  ; Channel ADC saat ini

; Kode assembly untuk fungsi C setup()
.global setup_slave_asm
.section .text
setup_slave_asm:
    ; Simpan register yang digunakan
    push r24
    push r25
      ; Setup ADC
    ; Memilih AVCC sebagai referensi, align ke kanan
    ldi r24, (1<<REFS0)
    sts ADMUX, r24
    
    ; Enable ADC, Prescaler 128 untuk sampling yang stabil
    ; Kita tidak akan menggunakan ADC interrupt karena konflik dengan Arduino
    ; ADC akan dikontrol oleh Arduino Framework
    ldi r24, (1<<ADEN) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0)
    sts ADCSRA, r24
    
    ; Setup Timer1 untuk pengambilan data sensor secara berkala
    ; Setting Timer1 dengan prescaler 64 untuk interrupt setiap 0.5 detik
    ldi r24, (1<<WGM12)                   ; CTC mode
    sts TCCR1A, r24
    ldi r24, (1<<CS11) | (1<<CS10)        ; Prescaler 64
    sts TCCR1B, r24
    ldi r24, lo8(TIMER_INTERVAL)          ; Set compare match value
    ldi r25, hi8(TIMER_INTERVAL)
    sts OCR1AH, r25
    sts OCR1AL, r24
    ldi r24, (1<<OCIE1A)                  ; Enable compare match interrupt
    sts TIMSK1, r24
    
        ; Kita akan menggunakan library Wire untuk I2C, 
    ; jadi tidak perlu setup TWI di sini
    
    ; Restore register dan return
    pop r25
    pop r24
    ret

; Kode assembly untuk fungsi C loop()
.global loop_slave_asm
.section .text
loop_slave_asm:
    ; Tidak melakukan apapun di loop karena sensor sampling dihandle oleh interrupt timer
    ret

; Timer1 Compare Match A Interrupt Service Routine untuk pengambilan sample sensor
.global TIMER1_COMPA_vect
TIMER1_COMPA_vect:
    push r24
    push r25
    in r24, _SFR_IO_ADDR(SREG)
    push r24
    
    ; Toggle antara channel 0 (Sound) dan 1 (Gas) untuk ADC
    lds r24, adc_channel
    ldi r25, 1
    eor r24, r25
    sts adc_channel, r24
    
    ; Set channel ADC sesuai dengan nilai adc_channel
    tst r24
    brne set_gas_channel
    
    ; Set channel untuk sensor suara (A0)
    lds r24, ADMUX
    andi r24, 0xF0        ; Bersihkan bit MUX[3:0]
    ori r24, SOUND_SENSOR_PIN
    sts ADMUX, r24
    rjmp start_conversion
    
set_gas_channel:
    ; Set channel untuk sensor gas (A1)
    lds r24, ADMUX
    andi r24, 0xF0        ; Bersihkan bit MUX[3:0]
    ori r24, GAS_SENSOR_PIN
    sts ADMUX, r24
    
start_conversion:
    ; Mulai konversi ADC
    lds r24, ADCSRA
    ori r24, (1<<ADSC)
    sts ADCSRA, r24
    
    pop r24
    out _SFR_IO_ADDR(SREG), r24
    pop r25
    pop r24
    reti

; Kita tidak akan menggunakan ADC interrupt langsung
; Fungsi ini akan digantikan oleh pembacaan ADC menggunakan Arduino framework
; dan set_sensor_values akan digunakan untuk menyimpan nilai

; Tidak menggunakan interrupt TWI sendiri karena menggunakan library Wire Arduino
; Library Wire sudah mendefinisikan handler untuk TWI_vect (__vector_24)
; Jadi kita tidak perlu mendefinisikan handler tersebut di sini

; Getter untuk nilai sensor sound dan gas
.global get_sensor_values
get_sensor_values:
    ; r24-r25 menyimpan pointer ke variabel sound_value
    ; r22-r23 menyimpan pointer ke variabel gas_value
    
    ; Simpan sementara pointer-pointer
    movw r18, r24  ; r18:r19 = sound_value pointer
    movw r20, r22  ; r20:r21 = gas_value pointer
    
    ; Copy sound value ke lokasi yang ditunjuk pointer
    lds r24, sound_value
    lds r25, sound_value+1
    movw r26, r18  ; X = r26:r27 = sound_value pointer
    st X+, r24     ; *sound_value = low byte
    st X, r25      ; *(sound_value+1) = high byte
    
    ; Copy gas value ke lokasi yang ditunjuk pointer
    lds r24, gas_value
    lds r25, gas_value+1
    movw r26, r20  ; X = r26:r27 = gas_value pointer
    st X+, r24     ; *gas_value = low byte
    st X, r25      ; *(gas_value+1) = high byte
    
    ret