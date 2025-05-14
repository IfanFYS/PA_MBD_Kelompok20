;------------------------
; Assembly Code
;------------------------
#define __SFR_OFFSET 0x00
#include "avr/io.h"
;------------------------
.global main


;=======================================================================
main:
    SBI   DDRC, 0         ;set pin PC0 as i/p for ADC0
    LDI   R20, 0xC0       ;internal 2.56V, right-justified data, ADC0
    STS   ADMUX, R20
    LDI   R20, 0x87       ;enable ADC, ADC prescaler CLK/128
    STS   ADCSRA, R20
    
;-----------------------------------------------------------------------
init_serial:
    CLR   R24
    STS   UCSR0A, R24     ;clear UCSR0A register
    STS   UBRR0H, R24     ;clear UBRR0H register
    LDI   R24, 103        ;& store in UBRR0L 103
    STS   UBRR0L, R24     ;to set baud rate 9600
    LDI   R24, 1<<RXEN0 | 1<<TXEN0
    STS   UCSR0B, R24     ;enable RXB & TXB
    LDI   R24, 1<<UCSZ00 | 1<<UCSZ01
    STS   UCSR0C, R24     ;asynch, no parity, 1 stop, 8 bits
    
;-----------------------------------------------------------------------
print_ADC:
    LDI   R23, 48         ;constants used to get ASCII values
    LDI   R24, 7          ;for chars 0-->9 & A-->F
    ;-------------------------------------------------------------------
    LDI   R20, 0xC7       ;set ADSC in ADCSRA to start conversion
    STS   ADCSRA, R20
    ;-------------------------------------------------------------------
wait_ADC:
    LDS   R21, ADCSRA     ;check ADIF flag in ADCSRA
    SBRS  R21, 4          ;skip jump when conversion is done (flag set)
    RJMP  wait_ADC        ;loop until ADIF flag is set
    ;------------------------------------------------------------------
    LDI   R17, 0xD7       ;set ADIF flag again
    STS   ADCSRA, R17     ;so that controller clears ADIF
    ;------------------------------------------------------------------
    LDS   R16, ADCL       ;get low-byte result from ADCL
    LDS   R25, ADCH       ;get high-byte result from ADCH
    ;-----------------------------------------------------------------
    ADD   R25, R23        ;add 48 to byte to get ASCII char 0 to 9
    ;-----------------------------------------------------------------
l1: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  l1
    ;-----------------------------------------------------------------
    STS   UDR0, R25       ;print ADC MSD on serial monitor
    ;-----------------------------------------------------------------
    PUSH  R16             ;store copy of ADCH in STACK register
    ANDI  R16, 0xF0       ;mask & extract high-nibble
    SWAP  R16             ;swap high-nibble with low-nibble
    ADD   R16, R23        ;add 48 to byte to get ASCII char 0 to 9
    MOV   R28, R16        ;store a copy of byte in R28
    SUBI  R28, 58         ;subtract 58 from R28
    BRPL  A_F_MSD         ;jump if result is +ve
    ;-----------------------------------------------------------------
l2: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  l2
    ;-----------------------------------------------------------------
    STS   UDR0, R16       ;print ADC mid digit on serial monitor
    ;-----------------------------------------------------------------
    POP   R16             ;restore ADCH value from STACK register
    ANDI  R16, 0x0F       ;mask & extract low-nibble
    ADD   R16, R23
    MOV   R28, R16
    SUBI  R28, 58
    BRPL  A_F_LSD
    ;-----------------------------------------------------------------
l3: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  l3
    ;-----------------------------------------------------------------
    STS   UDR0, R16       ;print ADC LSD on serial monitor
    ;-----------------------------------------------------------------
l4: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  l4
    ;-----------------------------------------------------------------
    LDI   R18, 0x0A
    STS   UDR0, R18       ;print newline on serial monitor    
    ;-----------------------------------------------------------------
l5: LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ;test data buffer if data can be sent
    RJMP  l5
    ;-----------------------------------------------------------------
    LDI   R18, 0x0D
    STS   UDR0, R18       ;print carriage return on serial monitor    
    ;-----------------------------------------------------------------
    RCALL delay_sec       ;1 second delay  
    RJMP  print_ADC
;=====================================================================
A_F_MSD:
    ADD   R16, R24        ;add 7 to byte to get ASCII chars A to F
    RJMP  l2
;---------------------------------------------------------------------
A_F_LSD:
    ADD   R16, R24        ;add 7 to byte to get ASCII chars A to F
    RJMP  l3
;---------------------------------------------------------------------
delay_sec:                ;1s delay
    LDI   R20, 255
l6: LDI   R21, 255
l7: LDI   R22, 80
l8: DEC   R22
    BRNE  l8
    DEC   R21
    BRNE  l7
    DEC   R20
    BRNE  l6
    RET