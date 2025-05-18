#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

.equ SCK,  5
.equ MOSI, 3
.equ SS,   2

; LED pin definitions
.equ LED_SOUND, 4    ; PD4 - lights when sound warning (was LED_NORMAL)
.equ LED_GAS, 3      ; PD3 - lights when gas warning (no change)
.equ LED_NORMAL, 2   ; PD2 - lights when no warnings (was LED_GAS)

; String constants stored in program memory
.section .progmem
str_sound:       .ascii "Sound: "
                .byte 0
str_gas:         .ascii "Gas: "
                .byte 0
str_warning:     .ascii " !! WARNING: High noise level!"
                .byte 0
str_gas_warning: .ascii " !! WARNING: Poor air quality detected!"
                .byte 0
str_newline:    .byte 13, 10, 0   ; \r\n

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

    ; SPI Master Init
    LDI   R16, (1<<MOSI)|(1<<SCK)|(1<<SS)
    OUT   DDRB, R16
    SBI   PORTB, SS          ; Slave initially deselected
    
    ; LED pins setup
    SBI   DDRD, LED_NORMAL   ; Set LED pins as outputs
    SBI   DDRD, LED_SOUND
    SBI   DDRD, LED_GAS
    
    ; Turn off all LEDs initially
    CBI   PORTD, LED_NORMAL
    CBI   PORTD, LED_SOUND
    CBI   PORTD, LED_GAS
    
    LDI   R16, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
    OUT   SPCR, R16          ; Enable SPI Master, fosc/16

    ; Wait for slave to be ready
    LDI   R20, 50
    RCALL delay_ms
    
    ; Initial read before entering main loop
    ; Read potentiometer 1
    RCALL read_spi_value     ; Read value into R18
    MOV   R22, R18           ; Save pot1 value in R22
    
    ; Read potentiometer 2
    RCALL read_spi_value     ; Read value into R18
    MOV   R23, R18           ; Save pot2 value in R23

loop:
    ; At the start of each loop, turn off all LEDs
    CBI   PORTD, LED_NORMAL
    CBI   PORTD, LED_SOUND
    CBI   PORTD, LED_GAS
    
    ; Display potentiometer 1 value (Sound)
    LDI   ZL, lo8(str_sound)
    LDI   ZH, hi8(str_sound)
    RCALL print_string
    
    MOV   R18, R22           ; Load pot1 value into R18
    RCALL dec_to_ascii       ; Convert and display as percentage
    
    ; Add space between Sound and Gas (instead of newline)
    LDI   R19, ' '           ; Space character
    RCALL uart_send
    LDI   R19, ' '           ; Double space for better spacing
    RCALL uart_send
    
    ; Display Gas info on same line
    LDI   ZL, lo8(str_gas)
    LDI   ZH, hi8(str_gas)
    RCALL print_string
    
    MOV   R18, R23           ; Load pot2 value into R18
    RCALL dec_to_ascii       ; Convert and display as percentage
    
    ; Send newline after both readings
    LDI   ZL, lo8(str_newline)
    LDI   ZH, hi8(str_newline)
    RCALL print_string
    
    ; Now check for warnings - Sound first
    CPI   R22, 153           ; Compare sound value with threshold
    BRLO  check_gas_warning  ; If below threshold, skip sound warning
    
    ; Sound warning - turn on sound LED
    SBI   PORTD, LED_SOUND
    
    ; Display sound warning message on its own line
    LDI   ZL, lo8(str_warning)
    LDI   ZH, hi8(str_warning)
    RCALL print_string
    LDI   ZL, lo8(str_newline)
    LDI   ZH, hi8(str_newline)
    RCALL print_string
    
check_gas_warning:
    ; Check gas level
    CPI   R23, 178           ; Compare gas value with threshold
    BRLO  check_normal_conditions  ; If below threshold, skip gas warning
    
    ; Gas warning - turn on gas LED
    SBI   PORTD, LED_GAS
    
    ; Display gas warning message on its own line
    LDI   ZL, lo8(str_gas_warning)
    LDI   ZH, hi8(str_gas_warning)
    RCALL print_string
    LDI   ZL, lo8(str_newline)
    LDI   ZH, hi8(str_newline)
    RCALL print_string
    RJMP  no_warnings  ; Skip normal LED check
    
check_normal_conditions:
    ; If we get here, check if both levels are normal
    CPI   R22, 153
    BRSH  no_warnings  ; If sound warning, skip normal LED
    CPI   R23, 178
    BRSH  no_warnings  ; If gas warning, skip normal LED
    
    ; If both are below threshold, turn on normal LED
    SBI   PORTD, LED_NORMAL
    
no_warnings:
    ; Add TWO newlines at end of every iteration
    LDI   ZL, lo8(str_newline)
    LDI   ZH, hi8(str_newline)
    RCALL print_string
    
    ; Second newline for extra spacing
    LDI   ZL, lo8(str_newline)
    LDI   ZH, hi8(str_newline)
    RCALL print_string
    
    ; Continue with delay and next readings
    LDI   R20, 200           ; Delay value (reduced from 255)
    RCALL delay_ms
    
    ; After displaying, read new values for next iteration
    ; Read potentiometer 1
    RCALL read_spi_value     ; Read value into R18
    MOV   R22, R18           ; Save pot1 value in R22
    
    ; Read potentiometer 2
    RCALL read_spi_value     ; Read value into R18
    MOV   R23, R18           ; Save pot2 value in R23
    
    RJMP  loop

; Read a value from slave via SPI
read_spi_value:
    ; Make sure slave is deselected before we start
    SBI   PORTB, SS          ; Ensure slave is deselected
    
    ; Small delay - REDUCE THIS
    LDI   R16, 5             ; Reduced from 10 to 5
delay_before_ss:
    NOP
    DEC   R16
    BRNE  delay_before_ss
    
    ; Begin SPI transaction
    CBI   PORTB, SS          ; Select slave (pull SS low)
    
    ; Small delay after SS goes low - REDUCE THIS
    LDI   R16, 10            ; Reduced from 20 to 10
delay_ss:
    NOP
    DEC   R16
    BRNE  delay_ss
    
    ; Send dummy byte to initiate transfer
    LDI   R16, 0             ; Dummy byte
    OUT   SPDR, R16

    ; Wait for transmission to complete
wait_spi:
    IN    R17, SPSR
    SBRS  R17, SPIF
    RJMP  wait_spi
    
    ; Read the received value
    IN    R18, SPDR          ; Read value from slave
    SBI   PORTB, SS          ; Deselect slave
    RET

; Convert R18 (0-255) to percentage (0-100%)
dec_to_ascii:
    PUSH  R20
    PUSH  R21
    PUSH  R22
    PUSH  R23                   
    
    ; IMPORTANT: Check for 255 FIRST before any other calculations
    CPI   R18, 255
    BRNE  not_max_value
    
    ; Handle 255 = 100% case immediately
    LDI   R19, '1'              ; Output "100%"
    RCALL uart_send
    LDI   R19, '0'
    RCALL uart_send
    LDI   R19, '0'
    RCALL uart_send
    LDI   R19, '%'
    RCALL uart_send
    
    ; Skip the rest of the calculation
    RJMP  calc_done
    
not_max_value:
    ; Normal percentage calculation for values 0-254
    MOV   R20, R18              ; Copy value to R20
    
    ; Multiply by 100
    LDI   R21, 100
    MUL   R20, R21              ; Result in R1:R0
    
    ; Divide by 255 (using approximation)
    MOV   R20, R1               ; Take high byte (approx. division by 256)
    
    ; Add correction for rounding
    MOV   R23, R0               ; Move R0 to higher register
    CPI   R23, 155
    BRLO  no_correction
    INC   R20                   ; Add 1 to compensate for approximation
    
no_correction:
    MOV   R22, R20              ; Save value for comparison
    
    ; Extract tens digit
    CLR   R19
    
tens_loop:
    CPI   R20, 10
    BRLO  tens_done
    SUBI  R20, 10
    INC   R19
    RJMP  tens_loop
    
tens_done:
    ; Only output tens digit if not zero
    CPI   R19, 0
    BRNE  output_tens           ; If tens digit is not zero, output it
    CPI   R22, 10               ; Check if value is 10 or more
    BRLO  skip_tens             ; If value < 10, skip tens
    
output_tens:
    ; Convert and send tens digit
    SUBI  R19, -'0'             ; Add ASCII '0'
    RCALL uart_send
    
skip_tens:
    ; Always output ones digit
    MOV   R19, R20
    SUBI  R19, -'0'             ; Add ASCII '0'
    RCALL uart_send
    
    ; Send % character
    LDI   R19, '%'
    RCALL uart_send
    
calc_done:
    POP   R23                   
    POP   R22
    POP   R21
    POP   R20
    RET

; UART Send Routine
uart_send:
uart_wait:
    LDS   R16, UCSR0A
    SBRS  R16, UDRE0
    RJMP  uart_wait
    STS   UDR0, R19
    RET

; Delay ~10ms
delay:
    LDI   R19, 100
d1: LDI   R20, 255
d2: DEC   R20
    BRNE  d2
    DEC   R19
    BRNE  d1
    RET

; Slightly faster delay routine for master
delay_ms:
    PUSH  R21
    PUSH  R22
delay_ms_outer:
    LDI   R21, 100           ; Decreased from 120 to 100
delay_ms_inner1:
    LDI   R22, 100           ; Decreased from 120 to 100
delay_ms_inner2:
    DEC   R22
    BRNE  delay_ms_inner2
    DEC   R21
    BRNE  delay_ms_inner1
    DEC   R20
    BRNE  delay_ms_outer
    POP   R22
    POP   R21
    RET

; Print a null-terminated string from program memory
; Input: Z (R30:R31) points to string in program memory
print_string:
    PUSH  R19
    PUSH  R30
    PUSH  R31
    
print_loop:
    LPM   R19, Z+            ; Load character from program memory and increment Z
    CPI   R19, 0             ; Check for null terminator
    BREQ  print_done         ; If null, we're done
    RCALL uart_send          ; Send the character
    RJMP  print_loop         ; Continue with next character
    
print_done:
    POP   R31
    POP   R30
    POP   R19
    RET
