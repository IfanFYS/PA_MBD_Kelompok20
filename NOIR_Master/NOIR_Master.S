#include <avr/io.h>

; ---------------------------------------------
; NOIR - Noise and Air Quality Monitoring System
; Master Controller Assembly Code
; ---------------------------------------------

; Konstanta untuk pin
.equ RED_LED_PIN,      2   ; Pin D2 untuk LED merah
.equ YELLOW_LED_PIN,   3   ; Pin D3 untuk LED kuning  
.equ GREEN_LED_PIN,    4   ; Pin D4 untuk LED hijau
.equ BUZZER_PIN,       5   ; Pin D5 untuk buzzer
.equ BUTTON_PIN,       6   ; Pin D6 untuk button mematikan buzzer

; Konstanta threshold 
.equ NOISE_THRESHOLD_H, 2    ; Ambang batas kebisingan high byte (512 >> 8)
.equ NOISE_THRESHOLD_L, 0    ; Ambang batas kebisingan low byte (512 & 0xFF)
.equ GAS_THRESHOLD_H,   2    ; Ambang batas gas high byte (600 >> 8)
.equ GAS_THRESHOLD_L,   88   ; Ambang batas gas low byte (600 & 0xFF)

; Konstanta untuk LED dan Buzzer states
.equ LED_ON,           1   
.equ LED_OFF,          0
.equ BUZZER_ON,        1
.equ BUZZER_OFF,       0

; Konstanta untuk timer
.equ TIMER_PRESCALER,  64
.equ TIMER_INTERVAL,   15625 ; untuk 1 detik dengan prescaler 64, F_CPU=16MHz

; Variabel di global data section
.section .data
    noise_value:   .word 0      ; Nilai kebisingan terakhir dari slave (16-bit)
    gas_value:     .word 0      ; Nilai kualitas udara dari slave (16-bit)
    buzzer_state:  .byte 0      ; Status buzzer (on/off)
    button_state:  .byte 0      ; Status button
    led_state:     .byte 0      ; Status LED
    prev_button:   .byte 1      ; Status button sebelumnya (1=tidak ditekan)

; Kode assembly untuk fungsi C setup()
.global setup_asm
.section .text
setup_asm:
    ; Simpan register yang digunakan
    push r24
    push r25
    
    ; Konfigurasi pin LED sebagai output (DDRD)
    ldi r24, (1<<RED_LED_PIN) | (1<<YELLOW_LED_PIN) | (1<<GREEN_LED_PIN) | (1<<BUZZER_PIN)
    in r25, _SFR_IO_ADDR(DDRD)
    or r25, r24
    out _SFR_IO_ADDR(DDRD), r25
    
    ; Konfigurasi pin button sebagai input dengan pull-up resistor
    cbi _SFR_IO_ADDR(DDRD), BUTTON_PIN    ; Set as input
    sbi _SFR_IO_ADDR(PORTD), BUTTON_PIN   ; Enable pull-up resistor
    
    ; Setup Timer1 untuk interval kontrol LED dan evaluasi kondisi
    ; Setting Timer1 dengan prescaler 64 untuk interrupt setiap ~1 detik
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
    
    ; Enable external interrupt for button (INT0)
    ldi r24, (1<<ISC01) | (1<<ISC00)      ; Trigger on rising edge
    sts EICRA, r24
    ldi r24, (1<<INT0)                    ; Enable INT0
    out _SFR_IO_ADDR(EIMSK), r24
    
    ; Restore registers and return
    pop r25
    pop r24
    ret

; Kode assembly untuk fungsi C loop()
.global loop_asm
.section .text
loop_asm:
    push r24
    push r25
    
    ; Baca status button
    in r24, _SFR_IO_ADDR(PIND)
    andi r24, (1<<BUTTON_PIN)
    brne button_not_pressed
    
    ; Button ditekan (logika 0 karena pull-up)
    ldi r24, 0
    sts button_state, r24
    rjmp check_button_done
    
button_not_pressed:
    ldi r24, 1
    sts button_state, r24
    
check_button_done:
    ; Cek apakah button baru saja ditekan (edge detection)
    lds r24, button_state
    lds r25, prev_button
    cp r24, r25
    breq no_button_change
    
    ; Simpan status button sekarang untuk next iteration
    sts prev_button, r24
    
    ; Jika button state = 0 (ditekan), matikan buzzer
    tst r24
    brne no_button_change
    
    ; Button ditekan, matikan buzzer
    ldi r24, BUZZER_OFF
    sts buzzer_state, r24
    cbi _SFR_IO_ADDR(PORTD), BUZZER_PIN
    
no_button_change:
    ; Evaluasi kondisi berdasarkan data dari slave
    rcall evaluate_conditions
    
    pop r25
    pop r24
    ret

; Fungsi untuk mengevaluasi kondisi berdasarkan data sensor
.global evaluate_conditions
evaluate_conditions:
    push r24
    push r25
    push r26
    push r27
    
    ; Bandingkan noise_value dengan NOISE_THRESHOLD
    lds r24, noise_value        ; Low byte
    lds r25, noise_value+1      ; High byte
    
    ; Compare high byte first
    cpi r25, NOISE_THRESHOLD_H
    brlo noise_normal          ; Jika high byte lebih kecil, pasti di bawah threshold
    brne noise_high            ; Jika high byte lebih besar, pasti di atas threshold
    
    ; High byte sama, compare low byte
    cpi r24, NOISE_THRESHOLD_L
    brlo noise_normal          ; Jika low byte lebih kecil, di bawah threshold
    
    ; Noise tinggi, nyalakan LED merah
    sbi _SFR_IO_ADDR(PORTD), RED_LED_PIN
    cbi _SFR_IO_ADDR(PORTD), GREEN_LED_PIN
    
    ; Nyalakan buzzer jika dalam status ON
    lds r24, buzzer_state
    tst r24
    breq check_gas
    sbi _SFR_IO_ADDR(PORTD), BUZZER_PIN
    rjmp check_gas
    
noise_high:
    ; Noise tinggi (lanjutan)
    sbi _SFR_IO_ADDR(PORTD), RED_LED_PIN
    cbi _SFR_IO_ADDR(PORTD), GREEN_LED_PIN
    
    ; Nyalakan buzzer jika dalam status ON
    lds r24, buzzer_state
    tst r24
    breq check_gas
    sbi _SFR_IO_ADDR(PORTD), BUZZER_PIN
    rjmp check_gas
    
noise_normal:
    ; Noise normal, nyalakan LED hijau untuk noise
    cbi _SFR_IO_ADDR(PORTD), RED_LED_PIN
    sbi _SFR_IO_ADDR(PORTD), GREEN_LED_PIN
    
check_gas:
    ; Bandingkan gas_value dengan GAS_THRESHOLD
    lds r24, gas_value        ; Low byte
    lds r25, gas_value+1      ; High byte
    
    ; Compare high byte first
    cpi r25, GAS_THRESHOLD_H
    brlo gas_normal          ; Jika high byte lebih kecil, pasti di bawah threshold
    brne gas_high            ; Jika high byte lebih besar, pasti di atas threshold
    
    ; High byte sama, compare low byte
    cpi r24, GAS_THRESHOLD_L
    brlo gas_normal          ; Jika low byte lebih kecil, di bawah threshold
    
    ; Gas tinggi, nyalakan LED kuning
    sbi _SFR_IO_ADDR(PORTD), YELLOW_LED_PIN
    
    ; Nyalakan buzzer jika dalam status ON
    lds r24, buzzer_state
    tst r24
    breq done_evaluation
    sbi _SFR_IO_ADDR(PORTD), BUZZER_PIN
    rjmp done_evaluation
    
gas_high:
    ; Gas tinggi (lanjutan)
    sbi _SFR_IO_ADDR(PORTD), YELLOW_LED_PIN
    
    ; Nyalakan buzzer jika dalam status ON
    lds r24, buzzer_state
    tst r24
    breq done_evaluation
    sbi _SFR_IO_ADDR(PORTD), BUZZER_PIN
    rjmp done_evaluation

gas_normal:
    ; Gas normal, matikan LED kuning
    cbi _SFR_IO_ADDR(PORTD), YELLOW_LED_PIN
    
done_evaluation:
    pop r27
    pop r26
    pop r25
    pop r24
    ret

; Timer1 Compare Match A Interrupt Service Routine
.global TIMER1_COMPA_vect
TIMER1_COMPA_vect:
    push r0
    push r1
    push r24
    in r0, _SFR_IO_ADDR(SREG)
    push r0
    
    ; Toggle LED state setiap beberapa detik jika ada peringatan
    lds r24, led_state
    ldi r1, 1
    eor r24, r1
    sts led_state, r24
      ; Toggle LED merah jika noise di atas threshold
    lds r24, noise_value        ; Low byte
    lds r25, noise_value+1      ; High byte
    
    ; Compare high byte first
    cpi r25, NOISE_THRESHOLD_H
    brlo skip_red_toggle        ; Jika high byte lebih kecil, pasti di bawah threshold
    brne noise_above_threshold  ; Jika high byte lebih besar, pasti di atas threshold
    
    ; High byte sama, compare low byte
    cpi r24, NOISE_THRESHOLD_L
    brlo skip_red_toggle        ; Jika low byte lebih kecil, di bawah threshold
    
noise_above_threshold:
    lds r24, led_state
    sbrc r24, 0
    sbi _SFR_IO_ADDR(PORTD), RED_LED_PIN
    sbrs r24, 0
    cbi _SFR_IO_ADDR(PORTD), RED_LED_PIN
    
skip_red_toggle:
    ; Toggle LED kuning jika gas di atas threshold
    lds r24, gas_value        ; Low byte
    lds r25, gas_value+1      ; High byte
    
    ; Compare high byte first
    cpi r25, GAS_THRESHOLD_H
    brlo isr_done             ; Jika high byte lebih kecil, pasti di bawah threshold
    brne gas_above_threshold  ; Jika high byte lebih besar, pasti di atas threshold
    
    ; High byte sama, compare low byte
    cpi r24, GAS_THRESHOLD_L
    brlo isr_done             ; Jika low byte lebih kecil, di bawah threshold
    
gas_above_threshold:
    lds r24, led_state
    sbrc r24, 0
    sbi _SFR_IO_ADDR(PORTD), YELLOW_LED_PIN
    sbrs r24, 0
    cbi _SFR_IO_ADDR(PORTD), YELLOW_LED_PIN
    
isr_done:
    pop r0
    out _SFR_IO_ADDR(SREG), r0
    pop r24
    pop r1
    pop r0
    reti

; External Interrupt 0 untuk button
.global INT0_vect
INT0_vect:
    push r24
    in r24, _SFR_IO_ADDR(SREG)
    push r24
    
    ; Set buzzer state ke OFF
    ldi r24, BUZZER_OFF
    sts buzzer_state, r24
    
    ; Matikan buzzer
    cbi _SFR_IO_ADDR(PORTD), BUZZER_PIN
    
    pop r24
    out _SFR_IO_ADDR(SREG), r24
    pop r24
    reti

; Setter untuk nilai noise dan gas dari I2C/SPI
.global set_sensor_values
set_sensor_values:
    ; r24 = noise_value_low, r25 = noise_value_high,
    ; r22 = gas_value_low, r23 = gas_value_high
    sts noise_value, r24
    sts noise_value+1, r25
    sts gas_value, r22
    sts gas_value+1, r23
    
    ; Reset buzzer state jika nilai melebihi threshold
    ; Cek noise threshold
    cpi r25, NOISE_THRESHOLD_H
    brhi set_buzzer_on        ; Jika high byte > threshold high byte
    brne check_gas_threshold  ; Jika high byte < threshold high byte
    
    ; High byte sama, bandingkan low byte
    cpi r24, NOISE_THRESHOLD_L
    brsh set_buzzer_on        ; Jika low byte >= threshold low byte
    
check_gas_threshold:
    ; Cek gas threshold
    cpi r23, GAS_THRESHOLD_H
    brhi set_buzzer_on        ; Jika high byte > threshold high byte
    brne exit_set_values      ; Jika high byte < threshold high byte
    
    ; High byte sama, bandingkan low byte
    cpi r22, GAS_THRESHOLD_L
    brlo exit_set_values      ; Jika low byte < threshold low byte
    
set_buzzer_on:
    ldi r24, BUZZER_ON
    sts buzzer_state, r24
    
exit_set_values:
    ret