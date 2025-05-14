#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

.equ SCK,  5
.equ MOSI, 3
.equ SS,   2
.equ POT,  0   ; ADC0 (PC0)

main:
    ; SPI Master Init
    LDI   R16, (1<<MOSI)|(1<<SCK)|(1<<SS)
    OUT   DDRB, R16
    SBI   PORTB, SS          ; Slave initially deselected
    
    LDI   R16, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
    OUT   SPCR, R16          ; Enable SPI Master, fosc/16

    ; ADC Init
    LDI   R16, (1<<REFS0)    ; AVcc reference
    STS   ADMUX, R16
    LDI   R16, (1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
    STS   ADCSRA, R16        ; Enable ADC, prescaler 128

loop:
    ; Start ADC conversion
    LDS   R16, ADCSRA
    ORI   R16, (1<<ADSC)     ; Start conversion
    STS   ADCSRA, R16

wait_adc:
    LDS   R16, ADCSRA
    SBRS  R16, ADIF          ; Wait for conversion
    RJMP  wait_adc
    
    ; Clear ADIF flag PROPERLY
    LDS   R16, ADCSRA
    ORI   R16, (1<<ADIF)     ; Write 1 to clear flag
    STS   ADCSRA, R16

    ; Read ADC value (8-bit)
    LDS   R18, ADCH          ; Use only high byte

    ; SPI Transmission
    CBI   PORTB, SS          ; Select slave
    OUT   SPDR, R18          ; Send data

wait_spi:
    IN    R17, SPSR
    SBRS  R17, SPIF          ; Wait for transmission
    RJMP  wait_spi
    
    SBI   PORTB, SS          ; Deselect slave
    
    RCALL delay
    RJMP  loop

; Delay ~10ms
delay:
    LDI   R19, 100
d1: LDI   R20, 255
d2: DEC   R20
    BRNE  d2
    DEC   R19
    BRNE  d1
    RET
