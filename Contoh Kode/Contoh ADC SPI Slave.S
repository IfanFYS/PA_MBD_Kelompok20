#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

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

loop:
    ; Wait for SPI receive
wait_spi:
    IN    R17, SPSR
    SBRS  R17, SPIF
    RJMP  wait_spi

    ; Read SPI data
    IN    R18, SPDR              ; Data dari master

    ; Convert to ASCII Hex & Send
    MOV   R19, R18
    SWAP  R19
    ANDI  R19, 0x0F
    RCALL hex_to_ascii
    RCALL uart_send

    MOV   R19, R18
    ANDI  R19, 0x0F
    RCALL hex_to_ascii
    RCALL uart_send

    ; Kirim newline
    LDI   R19, 0x0D              ; \r
    RCALL uart_send
    LDI   R19, 0x0A              ; \n
    RCALL uart_send

    ; Delay
    LDI   R20, 50               ; Delay 50ms (sesuaikan sesuai kebutuhan)
    RCALL delay_ms

    RJMP  loop

; Convert 0-15 to ASCII (0-9A-F)
hex_to_ascii:
    CPI   R19, 10
    BRLT  digit
    LDI   R20, 'A'-10
    ADD   R19, R20
    RET
digit:
    LDI   R20, '0'
    ADD   R19, R20
    RET

; UART Send Routine
uart_send:
uart_wait:
    LDS   R16, UCSR0A
    SBRS  R16, UDRE0
    RJMP  uart_wait
    STS   UDR0, R19
    RET

; Delay Subroutine (milliseconds)
; Input: R20 = jumlah ms
delay_ms:
    PUSH  R20
    PUSH  R21
    PUSH  R22
delay_ms_outer:
    LDI   R21, 250              ; 1ms loop
delay_ms_inner1:
    LDI   R22, 200
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
