#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

.equ POT1, 0   ; ADC0 (PC0)
.equ POT2, 1   ; ADC1 (PC1)

main:
    ; UART Init (9600 baud, 16MHz)
    CLR   R16
    STS   UCSR0A, R16
    STS   UBRR0H, R16
    LDI   R16, 103                ; 9600 baud
    STS   UBRR0L, R16
    LDI   R16, (1<<RXEN0)|(1<<TXEN0)
    STS   UCSR0B, R16
    LDI   R16, (1<<UCSZ01)|(1<<UCSZ00)
    STS   UCSR0C, R16

    ; SPI Slave Init
    CBI   DDRB, 3                ; MOSI input
    CBI   DDRB, 5                ; SCK input
    SBI   DDRB, 4                ; MISO output
    LDI   R16, (1<<SPE)          ; Enable SPI
    OUT   SPCR, R16

    ; ADC Init - basic setup, will select channel later
    LDI   R16, (1<<REFS0)|(1<<ADLAR)    ; AVcc reference, Left-adjust result
    STS   ADMUX, R16
    LDI   R16, (1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
    STS   ADCSRA, R16        ; Enable ADC, prescaler 128

loop:
    ; Read potentiometer 1
    LDS   R16, ADMUX
    ANDI  R16, 0xF0           ; Clear MUX bits
    ORI   R16, POT1           ; Select ADC0
    STS   ADMUX, R16
    RCALL read_adc            ; Read ADC value into R18
    MOV   R23, R18            ; Save pot1 value in R23

    ; Read potentiometer 2
    LDS   R16, ADMUX
    ANDI  R16, 0xF0           ; Clear MUX bits
    ORI   R16, POT2           ; Select ADC1
    STS   ADMUX, R16
    RCALL read_adc            ; Read ADC value into R18
    MOV   R24, R18            ; Save pot2 value in R24

    ; DEBUG: Send both values via UART
    LDI   R19, 'P'            ; P1: for potentiometer 1
    RCALL uart_send
    LDI   R19, '1'
    RCALL uart_send
    LDI   R19, ':'
    RCALL uart_send
    LDI   R19, ' '
    RCALL uart_send
    MOV   R19, R23            ; First potentiometer value
    RCALL send_decimal
    
    LDI   R19, ' '            ; Spacer
    RCALL uart_send
    LDI   R19, 'P'            ; P2: for potentiometer 2
    RCALL uart_send
    LDI   R19, '2'
    RCALL uart_send
    LDI   R19, ':'
    RCALL uart_send
    LDI   R19, ' '
    RCALL uart_send
    MOV   R19, R24            ; Second potentiometer value
    RCALL send_decimal

    ; Send newline
    LDI   R19, 13             ; \r
    RCALL uart_send
    LDI   R19, 10             ; \n
    RCALL uart_send
    
    ; SPI transaction for potentiometer 1
    RCALL wait_for_master
    OUT   SPDR, R23           ; Send pot1 value
    RCALL wait_for_spi_complete
    
    ; SPI transaction for potentiometer 2
    RCALL wait_for_master
    OUT   SPDR, R24           ; Send pot2 value
    RCALL wait_for_spi_complete
    
    ; Small delay before next ADC conversion
    LDI   R20, 10            ; Reduced from 50ms to 10ms
    RCALL delay_ms
    
    RJMP  loop

; Read ADC value into R18
read_adc:
    ; Start ADC conversion
    LDS   R16, ADCSRA
    ORI   R16, (1<<ADSC)      ; Start conversion
    STS   ADCSRA, R16

wait_adc_complete:
    LDS   R16, ADCSRA
    SBRS  R16, ADIF           ; Wait for conversion
    RJMP  wait_adc_complete
    
    ; Clear ADIF flag
    LDS   R16, ADCSRA
    ORI   R16, (1<<ADIF)      ; Write 1 to clear flag
    STS   ADCSRA, R16

    ; Read ADC value (8-bit)
    LDS   R18, ADCH           ; Use only high byte (left-adjusted)
    RET

; Wait for master to select slave
wait_for_master:
    SBIC  PINB, 2             ; Check if SS is pulled low (active)
    RJMP  wait_for_master     ; If not low yet, keep waiting
    
    ; Clear any previous SPI flags
    IN    R17, SPSR           ; Read SPI status register
    IN    R17, SPDR           ; Clear the SPDR by reading it
    RET

; Wait for SPI transfer to complete
wait_for_spi_complete:
    IN    R17, SPSR
    SBRS  R17, SPIF
    RJMP  wait_for_spi_complete
    RET

; Convert byte in R19 (0-255) to decimal ASCII and send
send_decimal:
    PUSH  R19
    PUSH  R20
    PUSH  R21
    
    MOV   R20, R19           ; Save original value
    
    ; Extract hundreds digit
    CLR   R21                ; Clear hundreds counter
    
hundreds_loop:
    CPI   R20, 100
    BRLO  hundreds_done
    SUBI  R20, 100
    INC   R21
    RJMP  hundreds_loop
    
hundreds_done:
    ; Convert and send hundreds digit if non-zero
    CPI   R21, 0
    BREQ  skip_hundreds
    
    ; Send hundreds digit
    SUBI  R21, -'0'          ; Convert to ASCII
    MOV   R19, R21
    RCALL uart_send
    
skip_hundreds:
    ; Extract tens digit
    CLR   R21                ; Clear tens counter
    
tens_loop:
    CPI   R20, 10
    BRLO  tens_done
    SUBI  R20, 10
    INC   R21
    RJMP  tens_loop
    
tens_done:
    ; Only output tens digit if either hundreds was non-zero or tens is non-zero
    CPI   R21, 0
    BRNE  output_tens        ; If tens digit is not zero, output it
    
    ; Check if we had a hundreds digit
    POP   R19                ; Get original value
    PUSH  R19
    CPI   R19, 100
    BRLO  skip_tens          ; If < 100 and tens=0, skip tens
    
output_tens:
    ; Send tens digit
    SUBI  R21, -'0'          ; Convert to ASCII
    MOV   R19, R21
    RCALL uart_send
    
skip_tens:
    ; Always send ones digit
    SUBI  R20, -'0'          ; Convert to ASCII
    MOV   R19, R20
    RCALL uart_send
    
    POP   R21
    POP   R20
    POP   R19
    RET

; UART Send Routine - send character in R19
uart_send:
    PUSH  R16
uart_wait:
    LDS   R16, UCSR0A
    SBRS  R16, UDRE0
    RJMP  uart_wait
    STS   UDR0, R19
    POP   R16
    RET

; Delay Subroutine (milliseconds)
; Input: R20 = jumlah ms
delay_ms:
    PUSH  R20
    PUSH  R21
    PUSH  R22
delay_ms_outer:
    LDI   R21, 100           ; Reduced from 250 to 100
delay_ms_inner1:
    LDI   R22, 100           ; Reduced from 200 to 100
delay_ms_inner2:
    DEC   R22
    BRNE  delay_ms_inner2
    DEC   R21
    BRNE  delay_ms_inner1
    DEC   R20
    BRNE  delay_ms_outer
    POP   R22
    POP   R21
    POP   R20
    RET
