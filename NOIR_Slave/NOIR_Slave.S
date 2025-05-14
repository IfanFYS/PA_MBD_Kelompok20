; NOIR_Slave.S - Implementation of Noise and Air Quality Monitoring System in AVR Assembly
; For ATmega328p (Arduino UNO)
; Slave receives data from master and displays it

#define __SFR_OFFSET 0x00
#include <avr/io.h>

; Register definitions for clarity
.equ RED_LED_PIN, 9            ; Digital pin 9
.equ YELLOW_LED_PIN, 10        ; Digital pin 10
.equ GREEN_LED_PIN, 11         ; Digital pin 11
.equ BUZZER_PIN, 8             ; Digital pin 8

; Define bit positions for PORTB
.equ RED_LED_BIT, 1      ; pin 9 = PORTB1
.equ YELLOW_LED_BIT, 2   ; pin 10 = PORTB2
.equ GREEN_LED_BIT, 3    ; pin 11 = PORTB3
.equ BUZZER_BIT, 0       ; pin 8 = PORTB0

; SPI Pins
.equ MISO_BIT, 4         ; MISO pin (PB4)
.equ MOSI_BIT, 3         ; MOSI pin (PB3)
.equ SCK_BIT, 5          ; SCK pin (PB5)
.equ SS_BIT, 2           ; SS pin (PB2)

; Communication command codes
.equ CMD_SEND_NOISE, 1     ; Command for noise value
.equ CMD_SEND_GAS, 2       ; Command for gas value
.equ CMD_SEND_STATUS, 3    ; Command for status

; Create section for code
.section .text

; Export the reset vector so it can be called from C
.global reset_handler
.global main

; Variables for sensor values
.lcomm noise_value, 2          ; Reserve 2 bytes (16-bit) for noise value
.lcomm gas_value, 2            ; Reserve 2 bytes (16-bit) for gas value
.lcomm status_value, 1         ; Reserve 1 byte for status value
.lcomm spi_command, 1          ; Reserve 1 byte for SPI command
.lcomm byte_counter, 1         ; Counter for multi-byte transfers
.lcomm tick_counter, 1         ; Counter for heartbeat messages

; Setup routine - equivalent to void setup()
reset_handler:
main:
    ; Initialize stack pointer
    ldi r16, hi8(RAMEND)       ; Load high byte of RAMEND into r16
    out 0x3E, r16              ; Set stack pointer high byte (SPH = 0x3E)
    ldi r16, lo8(RAMEND)       ; Load low byte of RAMEND into r16
    out 0x3D, r16              ; Set stack pointer low byte (SPL = 0x3D)

    ; Initialize UART for debugging (9600 baud for 16MHz)
    ldi r16, 103               ; Baud rate divisor for 9600 at 16MHz
    sts UBRR0L, r16            ; Set baud rate low byte
    ldi r16, 0                 ; High byte is 0
    sts UBRR0H, r16            ; Set baud rate high byte
    
    ; Enable both UART transmitter and receiver for better debugging
    ldi r16, (1<<TXEN0) | (1<<RXEN0)
    sts UCSR0B, r16
    
    ; Set frame format: 8N1
    ldi r16, (1<<UCSZ01) | (1<<UCSZ00)  ; 8 data bits
    sts UCSR0C, r16
    
    ; Configure GPIO pins
    ; Set LED pins and buzzer as outputs
    in r16, DDRB
    sbr r16, (1<<RED_LED_BIT) | (1<<YELLOW_LED_BIT) | (1<<GREEN_LED_BIT) | (1<<BUZZER_BIT)
    out DDRB, r16
    
    ; Initialize all outputs to LOW
    in r16, PORTB
    cbr r16, (1<<RED_LED_BIT) | (1<<YELLOW_LED_BIT) | (1<<GREEN_LED_BIT) | (1<<BUZZER_BIT)
    out PORTB, r16    ; Setup SPI as Slave
    ; Configure MISO as output, others as input
    in r16, DDRB
    sbr r16, (1<<MISO_BIT)              ; Set MISO as output
    cbr r16, (1<<MOSI_BIT) | (1<<SCK_BIT) | (1<<SS_BIT)  ; Set others as input
    out DDRB, r16
    
    ; Enable pullup on SS to improve noise immunity
    sbi PORTB, SS_BIT
    
    ; Enable SPI, Slave mode, interrupt enabled
    ; SPE: Enable SPI
    ; SPIE: Enable SPI interrupt
    ; SPI Mode 0 (CPOL=0, CPHA=0) to match master
    ldi r16, (1<<SPE) | (1<<SPIE)
    out SPCR, r16                      ; Using symbolic name SPCR
    
    ; Clear SPIF flag by reading SPSR and SPDR
    in r16, SPSR                       ; Read SPSR to clear SPIF
    in r16, SPDR                       ; Read SPDR to complete flag clearing
    
    ; Initialize SPI command and counter
    ldi r16, 0
    sts spi_command, r16
    sts byte_counter, r16
    sts tick_counter, r16
    sts noise_value, r16
    sts noise_value+1, r16
    sts gas_value, r16
    sts gas_value+1, r16
    sts status_value, r16
      ; Initial debug output
    ldi ZL, lo8(init_message)
    ldi ZH, hi8(init_message)
    rcall send_string
    
    ; Enable global interrupts
    sei

; Main loop - equivalent to void loop()
main_loop:
    ; Debug heartbeat message to verify loop is running
    lds r16, tick_counter
    inc r16
    sts tick_counter, r16
    
    cpi r16, 100                   ; Every 100 ticks (about 1 sec)
    brne skip_heartbeat
    
    ldi ZL, lo8(heartbeat_msg)
    ldi ZH, hi8(heartbeat_msg)
    rcall send_string
    
    clr r16
    sts tick_counter, r16          ; Reset counter
    
skip_heartbeat:
    ; Update display based on received values
    rcall update_display
    
    ; Debug output (periodically)
    lds r16, tick_counter
    andi r16, 0x0F                 ; Check if divisible by 16
    brne skip_debug
    
    rcall send_debug_info
    
skip_debug:
    ; Small delay to reduce CPU load
    ldi r24, lo8(10000)            ; 10ms delay
    ldi r25, hi8(10000)
    rcall delay_us
    
    rjmp main_loop                 ; Repeat loop

; Function to handle SPI communication
handle_spi:
    ; Check if SPI data is available
    in r16, SPSR
    sbrs r16, SPIF                 ; Skip if SPI Flag is set (data received)
    ret                            ; Return if no data
    
    ; Read received data (this also clears the SPIF flag)
    in r16, SPDR
    
    ; Process based on current state
    lds r17, spi_command
    cpi r17, 0                     ; Check if waiting for command
    brne process_data
    
    ; This is a command byte
    sts spi_command, r16           ; Store the command
    ldi r17, 1                     ; Reset byte counter to 1
    sts byte_counter, r17
    
    ; Debug command received
    push r16                       ; Save command
    ldi ZL, lo8(cmd_received_msg)
    ldi ZH, hi8(cmd_received_msg)
    rcall send_string
    pop r16                        ; Restore command
    push r16                       ; Save it again
    mov r24, r16                   ; Move to r24 for send_number
    clr r25                        ; Clear high byte
    rcall send_number
    ldi r16, '\r'
    rcall send_char
    ldi r16, '\n'
    rcall send_char
    pop r16                        ; Restore command
    
    ret
    
process_data:
    ; Process data based on command
    lds r17, spi_command           ; Get current command
    lds r18, byte_counter          ; Get byte counter
    
    cpi r17, CMD_SEND_NOISE
    breq process_noise_data
    
    cpi r17, CMD_SEND_GAS
    breq process_gas_data
    
    cpi r17, CMD_SEND_STATUS
    breq process_status_data
    
    ; Unknown command - reset state
    ldi r17, 0
    sts spi_command, r17
    ret
    
process_noise_data:
    cpi r18, 1                     ; First data byte (low byte)
    brne process_noise_high
    
    ; Store noise low byte
    sts noise_value, r16
    
    ; Increment byte counter
    inc r18
    sts byte_counter, r18
    ret
    
process_noise_high:
    ; Store noise high byte
    sts noise_value+1, r16
    
    ; Reset command state for next command
    ldi r17, 0
    sts spi_command, r17
    
    ; Debug: received complete noise value
    ldi ZL, lo8(noise_received_msg)
    ldi ZH, hi8(noise_received_msg)
    rcall send_string
    lds r24, noise_value
    lds r25, noise_value+1
    rcall send_number
    ldi r16, '\r'
    rcall send_char
    ldi r16, '\n'
    rcall send_char
    
    ret
    
process_gas_data:
    cpi r18, 1                     ; First data byte (low byte)
    brne process_gas_high
    
    ; Store gas low byte
    sts gas_value, r16
    
    ; Increment byte counter
    inc r18
    sts byte_counter, r18
    ret
    
process_gas_high:
    ; Store gas high byte
    sts gas_value+1, r16
    
    ; Reset command state for next command
    ldi r17, 0
    sts spi_command, r17
    
    ; Debug: received complete gas value
    ldi ZL, lo8(gas_received_msg)
    ldi ZH, hi8(gas_received_msg)
    rcall send_string
    lds r24, gas_value
    lds r25, gas_value+1
    rcall send_number
    ldi r16, '\r'
    rcall send_char
    ldi r16, '\n'
    rcall send_char
    
    ret
    
process_status_data:
    ; Store status byte
    sts status_value, r16
    
    ; Reset command state for next command
    ldi r17, 0
    sts spi_command, r17
    
    ; Debug: received status value
    ldi ZL, lo8(status_received_msg)
    ldi ZH, hi8(status_received_msg)
    rcall send_string
    mov r24, r16
    clr r25
    rcall send_number
    
    ; Print status text
    ldi r16, ' '
    rcall send_char
    ldi r16, '('
    rcall send_char
    
    lds r16, status_value
    cpi r16, 2
    breq print_danger
    cpi r16, 1
    breq print_warning
    
    ; Normal status
    ldi ZL, lo8(normal_status)
    ldi ZH, hi8(normal_status)
    rjmp print_status_text
    
print_danger:
    ldi ZL, lo8(danger_status)
    ldi ZH, hi8(danger_status)
    rjmp print_status_text
    
print_warning:
    ldi ZL, lo8(warning_status)
    ldi ZH, hi8(warning_status)
    
print_status_text:
    rcall send_string
    
    ldi r16, ')'
    rcall send_char
    ldi r16, '\r'
    rcall send_char
    ldi r16, '\n'
    rcall send_char
    
    ret

; Function to update LED display based on received status
update_display:
    ; Get current PORTB value
    in r16, PORTB
    
    ; Clear LED bits
    cbr r16, (1<<RED_LED_BIT) | (1<<YELLOW_LED_BIT) | (1<<GREEN_LED_BIT) | (1<<BUZZER_BIT)
      ; Get status value
    lds r17, status_value
    
    cpi r17, 2                     ; Check if danger (2)
    brne check_warning
    
    ; Danger state - Red LED and Buzzer ON
    sbr r16, (1<<RED_LED_BIT) | (1<<BUZZER_BIT)
    out PORTB, r16
    
    ; Also toggle buzzer for more attention
    ldi r24, 5
    rcall toggle_buzzer
    
    ret
    
check_warning:
    cpi r17, 1                     ; Check if warning (1)
    brne normal_state
    
    ; Warning state - Yellow LED ON
    sbr r16, (1<<YELLOW_LED_BIT)
    out PORTB, r16
    ret
    
normal_state:
    ; Normal state - Green LED ON
    sbr r16, (1<<GREEN_LED_BIT)
    out PORTB, r16
    ret

; Function to send debug information
send_debug_info:
    ; Print header
    ldi ZL, lo8(equals_line)
    ldi ZH, hi8(equals_line)
    rcall send_string
    
    ldi ZL, lo8(system_title)
    ldi ZH, hi8(system_title)
    rcall send_string
    
    ldi ZL, lo8(dash_line)
    ldi ZH, hi8(dash_line)
    rcall send_string
    
    ; Print noise level
    ldi ZL, lo8(noise_level_msg)
    ldi ZH, hi8(noise_level_msg)
    rcall send_string
    
    ; Print noise value
    lds r24, noise_value
    lds r25, noise_value+1
    rcall send_number
    
    ldi r16, '\r'
    rcall send_char
    ldi r16, '\n'
    rcall send_char
    
    ; Print gas level
    ldi ZL, lo8(gas_level_msg)
    ldi ZH, hi8(gas_level_msg)
    rcall send_string
    
    ; Print gas value
    lds r24, gas_value
    lds r25, gas_value+1
    rcall send_number
    
    ldi r16, '\r'
    rcall send_char
    ldi r16, '\n'
    rcall send_char
    
    ; Print status
    ldi ZL, lo8(status_msg)
    ldi ZH, hi8(status_msg)
    rcall send_string
    
    ; Get status value
    lds r17, status_value
    
    cpi r17, 2                     ; Check if danger (2)
    brne debug_check_warning
    
    ldi ZL, lo8(danger_status)
    ldi ZH, hi8(danger_status)
    rjmp debug_print_status
    
debug_check_warning:
    cpi r17, 1                     ; Check if warning (1)
    brne debug_normal_state
    
    ldi ZL, lo8(warning_status)
    ldi ZH, hi8(warning_status)
    rjmp debug_print_status
    
debug_normal_state:
    ldi ZL, lo8(normal_status)
    ldi ZH, hi8(normal_status)
    
debug_print_status:
    rcall send_string
    
    ldi r16, '\r'
    rcall send_char
    ldi r16, '\n'
    rcall send_char
    
    ; Print footer
    ldi ZL, lo8(equals_line)
    ldi ZH, hi8(equals_line)
    rcall send_string
    
    ret

; Utility function for delay in microseconds
delay_us:
    ; Simple delay loop - not cycle accurate
1:  sbiw r24, 1
    brne 1b
    ret

; Function to send a string to UART
send_string:
    ld r16, Z+                     ; Load character from string
    cpi r16, 0                     ; Check if null-terminated
    breq 1f                        ; If null, return
    rcall send_char                ; Send the character
    rjmp send_string               ; Loop for next character
1:  ret

; Function to send a single character to UART
send_char:
    ; Wait for transmit buffer to be empty
1:  lds r17, UCSR0A
    sbrs r17, UDRE0                ; Skip if UDRE0 is set (buffer empty)
    rjmp 1b
    
    ; Send the character
    sts UDR0, r16
    ret

; Function to send a 16-bit number as decimal
send_number:
    ; Convert 16-bit number to ASCII
    ; This is a simplified version, not handling all cases
    ; properly but sufficient for debug output
    
    ; Check if value is 1000 or more
    cpi r25, 0x03                  ; Check high byte (>= 1000)
    brlo check_hundreds
    
    ; Value is 1000+
    subi r24, lo8(1000)
    sbci r25, hi8(1000)
    ldi r16, '1'
    rcall send_char
    rjmp check_hundreds
    
check_hundreds:
    ; Check hundreds digit
    ldi r16, '0'                   ; Start with '0'
hundreds_loop:
    cpi r25, 0                     ; Check if high byte is 0
    brne subtract_hundred
    cpi r24, 100                   ; Check if low byte >= 100
    brlo send_hundreds
subtract_hundred:
    subi r24, 100                  ; Subtract 100
    sbci r25, 0
    inc r16                        ; Increment digit
    rjmp hundreds_loop
send_hundreds:
    rcall send_char
    
    ; Check tens digit
    ldi r16, '0'                   ; Start with '0'
tens_loop:
    cpi r24, 10                    ; Check if >= 10
    brlo send_tens
    subi r24, 10                   ; Subtract 10
    inc r16                        ; Increment digit
    rjmp tens_loop
send_tens:
    rcall send_char
    
    ; Units digit (remainder)
    ldi r16, '0'
    add r16, r24                   ; Convert to ASCII
    rcall send_char
    
    ret

; Function to send a byte as hex
send_hex_byte:
    push r16                       ; Save original value
    swap r16                       ; Swap high and low nibbles
    andi r16, 0x0F                 ; Mask to get only the low nibble
    rcall send_hex_nibble
    pop r16                        ; Restore original value
    andi r16, 0x0F                 ; Mask to get only the low nibble
    rcall send_hex_nibble
    ret

; Function to send a nibble (4 bits) as hex
send_hex_nibble:
    cpi r16, 10
    brlo 1f                        ; If < 10, use '0'-'9'
    subi r16, -('A'-'0'-10)        ; Else use 'A'-'F'
1:  subi r16, -'0'                 ; Convert to ASCII
    rcall send_char
    ret

; Function to toggle buzzer a number of times
; Input: r24 = number of toggles
toggle_buzzer:
    push r16
    push r17
    
toggle_loop:
    cpi r24, 0
    breq toggle_done
    
    ; Toggle buzzer
    in r16, PORTB
    ldi r17, (1<<BUZZER_BIT)
    eor r16, r17           ; Exclusive OR to toggle just the buzzer bit
    out PORTB, r16
    
    ; Short delay
    push r24
    ldi r24, lo8(20000)
    ldi r25, hi8(20000)
    rcall delay_us
    pop r24
    
    dec r24
    rjmp toggle_loop
    
toggle_done:
    pop r17
    pop r16
    ret

; String constants
init_message:
    .asciz "NOIR - Slave initialized (Display Mode)\r\n"
heartbeat_msg:
    .asciz "Slave main loop running...\r\n"
cmd_received_msg:
    .asciz "Command received: "
noise_received_msg:
    .asciz "Noise value received: "
gas_received_msg:
    .asciz "Gas value received: "
status_received_msg:
    .asciz "Status received: "
equals_line:
    .asciz "==========================\r\n"
system_title:
    .asciz "NOIR Display Status\r\n"
dash_line:
    .asciz "--------------------------\r\n"
noise_level_msg:
    .asciz "Noise Level: "
gas_level_msg:
    .asciz "Gas Level: "
status_msg:
    .asciz "Status: "
normal_status:
    .asciz "NORMAL"
warning_status:
    .asciz "WARNING"
danger_status:
    .asciz "DANGER"

; Interrupt vectors
.section .vectors
    .word RAMEND                   ; Stack pointer initialization
    .word reset_handler            ; Reset vector
    .org 0x14                     ; SPI transfer complete interrupt
    .word spi_interrupt
    ; ... other interrupt vectors would go here

; SPI Interrupt handler
.global SPI_STC_vect
SPI_STC_vect:
spi_interrupt:
    push r16
    push r17
    push r18
    
    ; Read SPI data register
    in r16, SPDR
    
    ; Process based on current state
    lds r17, spi_command
    cpi r17, 0                     ; Check if waiting for command
    brne spi_process_data
    
    ; This is a command byte
    sts spi_command, r16           ; Store the command
    ldi r17, 1                     ; Reset byte counter to 1
    sts byte_counter, r17
    
    ; Debug command received (disabled in interrupt for speed)
    rjmp spi_int_done
    
spi_process_data:
    ; Process data based on command
    lds r17, spi_command           ; Get current command
    lds r18, byte_counter          ; Get byte counter
    
    cpi r17, CMD_SEND_NOISE
    breq spi_process_noise_data
    
    cpi r17, CMD_SEND_GAS
    breq spi_process_gas_data
    
    cpi r17, CMD_SEND_STATUS
    breq spi_process_status_data
    
    ; Unknown command - reset state
    ldi r17, 0
    sts spi_command, r17
    rjmp spi_int_done
    
spi_process_noise_data:
    cpi r18, 1                     ; First data byte (low byte)
    brne spi_process_noise_high
    
    ; Store noise low byte
    sts noise_value, r16
    
    ; Increment byte counter
    inc r18
    sts byte_counter, r18
    rjmp spi_int_done
    
spi_process_noise_high:
    ; Store noise high byte
    sts noise_value+1, r16
    
    ; Reset command state for next command
    ldi r17, 0
    sts spi_command, r17
    rjmp spi_int_done
    
spi_process_gas_data:
    cpi r18, 1                     ; First data byte (low byte)
    brne spi_process_gas_high
    
    ; Store gas low byte
    sts gas_value, r16
    
    ; Increment byte counter
    inc r18
    sts byte_counter, r18
    rjmp spi_int_done
    
spi_process_gas_high:
    ; Store gas high byte
    sts gas_value+1, r16
    
    ; Reset command state for next command
    ldi r17, 0
    sts spi_command, r17
    rjmp spi_int_done
    
spi_process_status_data:
    ; Store status byte
    sts status_value, r16
    
    ; Reset command state for next command
    ldi r17, 0
    sts spi_command, r17
    
spi_int_done:
    pop r18
    pop r17
    pop r16
    reti
