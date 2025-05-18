#define __SFR_OFFSET 0x00
#include "avr/io.h"

;============================================================================
; NOIR (Noise and Air Quality Monitoring System) - SLAVE CONTROLLER
;
; This file contains AVR assembly code for the slave Arduino in the NOIR
; system. The slave continuously reads data from sensors connected to analog 
; inputs (simulated by potentiometers in Proteus) and sends this data to the
; master Arduino via SPI communication when requested.
;
; Key responsibilities:
; 1. Read analog values from sound and gas sensors
; 2. Convert analog readings to digital values
; 3. Respond to SPI requests from the master Arduino
; 4. Send current sensor values when requested
; 5. Provide debug information via serial communication
;============================================================================

.global main

; ADC channel definitions
.equ POT1, 0   ; ADC0 (PC0) - Sound sensor/potentiometer
.equ POT2, 1   ; ADC1 (PC1) - Gas sensor/potentiometer

main:
    ;============================================================================
    ; SYSTEM INITIALIZATION
    ; Sets up all communication interfaces and analog-to-digital conversion
    ;============================================================================
    
    ; Initialize UART for debug serial communication (9600 baud with 16MHz clock)
    CLR   R16                   ; Clear register
    STS   UCSR0A, R16           ; Clear UART control register A
    STS   UBRR0H, R16           ; Clear high byte of baud rate register
    LDI   R16, 103              ; Set baud rate to 9600 bps (16MHz / (16 * 9600) - 1 = 103)
    STS   UBRR0L, R16           ; Set low byte of baud rate register
    LDI   R16, (1<<RXEN0)|(1<<TXEN0) ; Enable transmitter and receiver
    STS   UCSR0B, R16           ; Set UART control register B
    LDI   R16, (1<<UCSZ01)|(1<<UCSZ00) ; 8-bit character size
    STS   UCSR0C, R16           ; Set UART control register C

    ; Initialize SPI in Slave mode
    CBI   DDRB, 3               ; MOSI (PB3) as input - Master sends data to us
    CBI   DDRB, 5               ; SCK (PB5) as input - Master controls clock
    SBI   DDRB, 4               ; MISO (PB4) as output - We send data to Master
    LDI   R16, (1<<SPE)         ; Enable SPI in slave mode
    OUT   SPCR, R16             ; Configure SPI control register

    ; Initialize analog-to-digital converter (ADC)
    LDI   R16, (1<<REFS0)|(1<<ADLAR) ; AVcc reference voltage, Left-adjust result
                                     ; Left-adjust for 8-bit resolution in ADCH
    STS   ADMUX, R16             ; Set ADC multiplexer register
    LDI   R16, (1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0) ; Enable ADC, set prescaler to 128
                                 ; For 16MHz clock, ADC clock becomes 125kHz (optimal 50-200kHz range)
    STS   ADCSRA, R16           ; Set ADC control and status register

loop:
    ;============================================================================
    ; MAIN PROCESSING LOOP
    ; Continually reads sensor values and responds to SPI requests from the master
    ;============================================================================
    
    ; Read sound sensor/potentiometer (ADC0/PC0)
    LDS   R16, ADMUX            ; Load current ADC multiplexer register value
    ANDI  R16, 0xF0             ; Clear lower 4 bits (MUX3:0) to select channel
    ORI   R16, POT1             ; Set channel to POT1 (ADC0)
    STS   ADMUX, R16            ; Update ADC multiplexer register
    RCALL read_adc              ; Read ADC value into R18
    MOV   R23, R18              ; Save sound sensor value in R23

    ; Read gas sensor/potentiometer (ADC1/PC1)
    LDS   R16, ADMUX            ; Load current ADC multiplexer register value
    ANDI  R16, 0xF0             ; Clear lower 4 bits (MUX3:0) to select channel
    ORI   R16, POT2             ; Set channel to POT2 (ADC1)
    STS   ADMUX, R16            ; Update ADC multiplexer register
    RCALL read_adc              ; Read ADC value into R18
    MOV   R24, R18              ; Save gas sensor value in R24

    ; DEBUG: Send sensor values via UART for monitoring/debugging
    ; Format: "P1: xxx P2: yyy" followed by newline
    LDI   R19, 'P'              ; Output "P1: " prefix for sound sensor
    RCALL uart_send
    LDI   R19, '1'
    RCALL uart_send
    LDI   R19, ':'
    RCALL uart_send
    LDI   R19, ' '
    RCALL uart_send
    MOV   R19, R23              ; Send sound sensor value (converted to decimal)
    RCALL send_decimal
    
    LDI   R19, ' '              ; Add space between values
    RCALL uart_send
    LDI   R19, 'P'              ; Output "P2: " prefix for gas sensor
    RCALL uart_send
    LDI   R19, '2'
    RCALL uart_send
    LDI   R19, ':'
    RCALL uart_send
    LDI   R19, ' '
    RCALL uart_send
    MOV   R19, R24              ; Send gas sensor value (converted to decimal)
    RCALL send_decimal

    ; Send newline characters for proper formatting
    LDI   R19, 13               ; Carriage return (\r)
    RCALL uart_send
    LDI   R19, 10               ; Line feed (\n)
    RCALL uart_send
    
    ; Handle SPI communication with Master - send sound sensor value first
    RCALL wait_for_master       ; Wait for Master to select us (SS low)
    OUT   SPDR, R23             ; Send sound sensor value through SPI Data Register
    RCALL wait_for_spi_complete ; Wait for transmission to complete
    
    ; Handle SPI communication with Master - send gas sensor value next
    RCALL wait_for_master       ; Wait for Master to select us (SS low)
    OUT   SPDR, R24             ; Send gas sensor value through SPI Data Register
    RCALL wait_for_spi_complete ; Wait for transmission to complete
    
    ; Small delay before next ADC conversion (reduces sampling rate)
    LDI   R20, 10               ; 10ms delay between readings
    RCALL delay_ms              ; Call delay subroutine
    
    RJMP  loop                  ; Repeat the loop indefinitely

;============================================================================
; ANALOG-TO-DIGITAL CONVERSION
; Handles reading analog values from sensors with proper timing and control
;============================================================================

; Read ADC value into R18
read_adc:
    ; Start a new ADC conversion
    LDS   R16, ADCSRA           ; Load ADC Control and Status Register A
    ORI   R16, (1<<ADSC)        ; Set ADC Start Conversion bit
    STS   ADCSRA, R16           ; Start the conversion

    ; Wait for the conversion to complete (polling ADIF flag)
wait_adc_complete:
    LDS   R16, ADCSRA           ; Read ADC Status Register
    SBRS  R16, ADIF             ; Skip next instruction if ADIF (ADC Interrupt Flag) is set
    RJMP  wait_adc_complete     ; Loop until conversion completes
    
    ; Clear the ADC Interrupt Flag by writing a 1 to it
    LDS   R16, ADCSRA
    ORI   R16, (1<<ADIF)        ; Set ADIF bit to clear it (writing 1 clears the flag)
    STS   ADCSRA, R16

    ; Read ADC value (8-bit precision from left-adjusted result)
    LDS   R18, ADCH             ; Read only the high byte (ADCH) for 8-bit resolution
    RET                         ; Return with value in R18

;============================================================================
; SPI COMMUNICATION FUNCTIONS
; Manages SPI slave mode communication with the master Arduino
;============================================================================

; Wait for master to select this slave (by pulling SS low)
wait_for_master:
    SBIC  PINB, 2               ; Skip if SS pin (PB2) is low (active)
    RJMP  wait_for_master       ; Keep waiting until master selects us
    
    ; Prepare for SPI transfer by clearing any pending status
    IN    R17, SPSR             ; Read SPI Status Register (clears some flags)
    IN    R17, SPDR             ; Read SPI Data Register to clear any previous data
    RET                         ; Return when SS is active (low)

; Wait for current SPI transfer to complete
wait_for_spi_complete:
    IN    R17, SPSR             ; Read SPI Status Register
    SBRS  R17, SPIF             ; Skip next instruction if SPIF (SPI Interrupt Flag) is set
    RJMP  wait_for_spi_complete ; Loop until transfer completes
    RET                         ; Return when transfer is complete

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
