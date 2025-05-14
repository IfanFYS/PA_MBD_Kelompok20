; NOIR_Master.S - Implementation of Noise and Air Quality Monitoring System in AVR Assembly
; For ATmega328p (Arduino UNO)
; Master reads sensors and sends data to slave via SPI

#define __SFR_OFFSET 0x00
#include <avr/io.h>

; Register definitions for clarity
; Analog pins for sensors
.equ SOUND_SENSOR_PIN, 0       ; A0
.equ GAS_SENSOR_PIN, 1         ; A1

; SPI Pins
.equ SCK, 5        ; SCK pin (PB5)
.equ MOSI, 3       ; MOSI pin (PB3)
.equ MISO, 4       ; MISO pin (PB4)
.equ SS, 2         ; SS pin (PB2)

; LED pin for debugging
.equ DEBUG_LED, 7  ; Digital pin 13 (PB5)

; Communication command codes
.equ CMD_SEND_NOISE, 1     ; Command to send noise value
.equ CMD_SEND_GAS, 2       ; Command to send gas value
.equ CMD_SEND_STATUS, 3    ; Command to send status

; Constants for warning thresholds
.equ NOISE_WARNING_THRESHOLD, 600
.equ NOISE_DANGER_THRESHOLD, 800
.equ GAS_WARNING_THRESHOLD, 600
.equ GAS_DANGER_THRESHOLD, 800

; Create section for code
.section .text

; Export the reset vector so it can be called from C
.global reset_handler
.global main

; Variables for sensor values
.lcomm sound_value, 2          ; Reserve 2 bytes (16-bit) for sound value
.lcomm gas_value, 2            ; Reserve 2 bytes (16-bit) for gas value
.lcomm current_time, 4         ; Reserve 4 bytes for current time counter
.lcomm last_send_time, 4       ; Reserve 4 bytes for last data send time
.lcomm status_value, 1         ; Reserve 1 byte for status value (0=normal, 1=warning, 2=danger)

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
    
    ; Enable UART transmitter and receiver
    ldi r16, (1<<TXEN0) | (1<<RXEN0)
    sts UCSR0B, r16
    
    ; Set frame format: 8N1
    ldi r16, (1<<UCSZ01) | (1<<UCSZ00)  ; 8 data bits
    sts UCSR0C, r16
    
    ; Initialize SPI as Master
    ; Configure SPI pins: Set MOSI, SCK, SS as outputs
    sbi DDRB, MOSI      ; MOSI as output
    sbi DDRB, SCK       ; SCK as output
    sbi DDRB, SS        ; SS as output
    cbi DDRB, MISO      ; MISO as input
    sbi PORTB, SS       ; Ensure SS is HIGH initially (slave disabled)
    
    ; Also set the debug LED pin as output
    sbi DDRB, DEBUG_LED
    cbi PORTB, DEBUG_LED    ; Initially off
    
    ; SPE: Enable SPI
    ; MSTR: Master mode
    ; SPR0: Clock = fosc/16
    ; CPOL=0, CPHA=0 - SPI Mode 0 (default)
    ldi r16, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
    out SPCR, r16                         ; Using symbolic name SPCR instead of 0x2C
    
    ; Initialize ADC
    ldi r16, (1<<REFS0)            ; Use AVCC as reference
    sts ADMUX, r16
    ldi r16, (1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0) ; Enable ADC with prescaler 128
    sts ADCSRA, r16
      ; Initialize variables
    clr r16
    clr r17
    sts sound_value, r16
    sts sound_value+1, r17
    sts gas_value, r16
    sts gas_value+1, r17
    sts status_value, r16
    
    ; Initialize timing variables
    sts current_time, r16
    sts current_time+1, r17
    sts current_time+2, r16
    sts current_time+3, r17
    sts last_send_time, r16
    sts last_send_time+1, r17
    sts last_send_time+2, r16
    sts last_send_time+3, r17
    
    ; Send "initialization complete" message via UART
    ldi ZL, lo8(init_message)
    ldi ZH, hi8(init_message)
    rcall send_string
    
    ; Flash the debug LED to indicate successful initialization
    rcall flash_debug_led

; Main loop - equivalent to void loop()
main_loop:
    ; Print a heartbeat message to verify the loop is running
    ldi ZL, lo8(heartbeat_msg)
    ldi ZH, hi8(heartbeat_msg)
    rcall send_string
    
    ; Read sensors
    rcall read_adc_sound
    sts sound_value, r24           ; Store low byte
    sts sound_value+1, r25         ; Store high byte
    
    rcall read_adc_gas
    sts gas_value, r24             ; Store low byte
    sts gas_value+1, r25           ; Store high byte
    
    ; Update status based on sensor values
    rcall update_status
    
    ; Get current time (simulated)
    rcall millis
    
    ; Store current time
    sts current_time, r22
    sts current_time+1, r23
    sts current_time+2, r24
    sts current_time+3, r25
    
    ; Check if it's time to send data to slave (every 500ms)
    ; if (currentTime - lastSendTime >= 500)
    lds r18, current_time         ; Load current time
    lds r19, current_time+1
    lds r20, current_time+2
    lds r21, current_time+3
    
    lds r22, last_send_time       ; Load last send time
    lds r23, last_send_time+1
    lds r24, last_send_time+2
    lds r25, last_send_time+3
    
    ; Subtract to get elapsed time
    sub r18, r22
    sbc r19, r23
    sbc r20, r24
    sbc r21, r25
    
    ; Compare with 500ms
    cpi r18, lo8(500)
    ldi r22, hi8(500)
    cpc r19, r22
    brlo skip_send                 ; Branch if elapsed time < 500ms
    
    ; It's time to send data
    ; lastSendTime = currentTime
    lds r22, current_time
    lds r23, current_time+1
    lds r24, current_time+2
    lds r25, current_time+3
    
    sts last_send_time, r22
    sts last_send_time+1, r23
    sts last_send_time+2, r24
    sts last_send_time+3, r25
    
    ; Send data to slave
    rcall send_sensor_data_to_slave
    
    ; Print debug info to UART
    rcall print_sensor_values

skip_send:
    ; Small delay to reduce CPU load
    ldi r24, lo8(100000)           ; 100ms delay
    ldi r25, hi8(100000)
    rcall delay_us
    
    rjmp main_loop                 ; Repeat loop

; Function to read sound sensor (ADC0)
read_adc_sound:
    ldi r16, (1<<REFS0)            ; Use AVCC as reference
    ori r16, SOUND_SENSOR_PIN      ; Select ADC0 channel
    sts ADMUX, r16
    rjmp read_adc_common

; Function to read gas sensor (ADC1)
read_adc_gas:
    ldi r16, (1<<REFS0)            ; Use AVCC as reference
    ori r16, GAS_SENSOR_PIN        ; Select ADC1 channel
    sts ADMUX, r16
    ; Fall through to read_adc_common

; Common ADC reading code
read_adc_common:
    ; Start ADC conversion
    lds r16, ADCSRA
    ori r16, (1<<ADSC)             ; Start conversion
    sts ADCSRA, r16
    
    ; Wait for conversion to complete
adc_wait:
    lds r16, ADCSRA
    sbrc r16, ADSC                 ; Skip if conversion complete
    rjmp adc_wait
    
    ; Read ADC result (10-bit)
    lds r24, ADCL                  ; Read low byte first
    lds r25, ADCH                  ; Then high byte
    
    ret

; Function to send sensor data to slave via SPI
send_sensor_data_to_slave:
    ldi ZL, lo8(send_data_msg)
    ldi ZH, hi8(send_data_msg)
    rcall send_string
    
    ; Toggle debug LED to indicate transmission start
    sbi PORTB, DEBUG_LED            ; Turn on debug LED
    
    ; Send noise value
    cbi PORTB, SS                  ; Select slave (SS low)
    
    ; Small delay to ensure SS is recognized
    ldi r24, 20
    ldi r25, 0
    rcall delay_us
    
    ; Send command for noise value
    ldi r16, CMD_SEND_NOISE
    out SPDR, r16                  ; Send command to SPDR
    
    ; Wait for transmission to complete
1:  in r16, SPSR
    sbrs r16, SPIF                 ; Skip if transfer complete
    rjmp 1b
    
    ; Small delay between bytes
    ldi r24, 10
    ldi r25, 0
    rcall delay_us
    
    ; Send noise value low byte
    lds r16, sound_value           ; Load low byte
    out SPDR, r16                  ; Send to SPDR
    
    ; Wait for transmission to complete
2:  in r16, SPSR
    sbrs r16, SPIF
    rjmp 2b
    
    ; Small delay between bytes
    ldi r24, 10
    ldi r25, 0
    rcall delay_us
    
    ; Send noise value high byte
    lds r16, sound_value+1         ; Load high byte
    out SPDR, r16                  ; Send to SPDR
    
    ; Wait for transmission to complete
3:  in r16, SPSR
    sbrs r16, SPIF
    rjmp 3b
    
    ; Deselect slave between commands
    sbi PORTB, SS                  ; Deselect slave (SS high)
    
    ; Small delay between transactions
    ldi r24, 100
    ldi r25, 0
    rcall delay_us
      ; Send gas value
    cbi PORTB, SS                  ; Select slave (SS low)
    
    ; Small delay to ensure SS is recognized
    ldi r24, 20
    ldi r25, 0
    rcall delay_us
    
    ; Send command for gas value
    ldi r16, CMD_SEND_GAS
    out SPDR, r16                  ; Send command to SPDR
    
    ; Wait for transmission to complete
4:  in r16, SPSR
    sbrs r16, SPIF
    rjmp 4b
    
    ; Small delay between bytes
    ldi r24, 10
    ldi r25, 0
    rcall delay_us
    
    ; Send gas value low byte
    lds r16, gas_value             ; Load low byte
    out SPDR, r16                  ; Send to SPDR
    
    ; Wait for transmission to complete
5:  in r16, SPSR
    sbrs r16, SPIF
    rjmp 5b
    
    ; Small delay between bytes
    ldi r24, 10
    ldi r25, 0
    rcall delay_us
    
    ; Send gas value high byte
    lds r16, gas_value+1           ; Load high byte
    out SPDR, r16                  ; Send to SPDR
    
    ; Wait for transmission to complete
6:  in r16, SPSR
    sbrs r16, SPIF
    rjmp 6b
    
    ; Deselect slave between commands
    sbi PORTB, SS                  ; Deselect slave (SS high)
    
    ; Small delay between transactions
    ldi r24, 100
    ldi r25, 0
    rcall delay_us
      ; Small delay between transactions
    ldi r24, 100
    ldi r25, 0
    rcall delay_us
    
    ; Send status value
    cbi PORTB, SS                  ; Select slave (SS low)
    
    ; Small delay to ensure SS is recognized
    ldi r24, 20
    ldi r25, 0
    rcall delay_us
    
    ; Send command for status
    ldi r16, CMD_SEND_STATUS
    out SPDR, r16                  ; Send command to SPDR
    
    ; Wait for transmission to complete
7:  in r16, SPSR
    sbrs r16, SPIF
    rjmp 7b
    
    ; Small delay between bytes
    ldi r24, 10
    ldi r25, 0
    rcall delay_us
    
    ; Send status byte
    lds r16, status_value          ; Load status
    out SPDR, r16                  ; Send to SPDR
    
    ; Wait for transmission to complete
8:  in r16, SPSR
    sbrs r16, SPIF
    rjmp 8b
    
    ; Deselect slave
    sbi PORTB, SS                  ; Deselect slave (SS high)
    
    ; Turn off debug LED to indicate transmission complete
    cbi PORTB, DEBUG_LED
    
    ret

; Function to update status based on sensor values
update_status:
    ; Default to normal state
    ldi r20, 0                     ; isDanger flag
    ldi r21, 0                     ; isWarning flag
    ldi r22, 1                     ; isNormal flag
    
    ; Check noise level
    lds r16, sound_value           ; Load low byte
    lds r17, sound_value+1         ; Load high byte
    
    ; Check against NOISE_DANGER_THRESHOLD
    cpi r16, lo8(NOISE_DANGER_THRESHOLD)
    ldi r18, hi8(NOISE_DANGER_THRESHOLD)
    cpc r17, r18
    brlo check_noise_warning       ; Branch if lower
    
    ; Danger condition
    ldi r20, 1                     ; Set isDanger
    ldi r22, 0                     ; Clear isNormal
    rjmp check_gas_level
    
check_noise_warning:
    ; Check against NOISE_WARNING_THRESHOLD
    cpi r16, lo8(NOISE_WARNING_THRESHOLD)
    ldi r18, hi8(NOISE_WARNING_THRESHOLD)
    cpc r17, r18
    brlo check_gas_level           ; Branch if lower
    
    ; Warning condition
    ldi r21, 1                     ; Set isWarning
    ldi r22, 0                     ; Clear isNormal
    
check_gas_level:
    ; Check gas level
    lds r16, gas_value             ; Load low byte
    lds r17, gas_value+1           ; Load high byte
    
    ; Check against GAS_DANGER_THRESHOLD
    cpi r16, lo8(GAS_DANGER_THRESHOLD)
    ldi r18, hi8(GAS_DANGER_THRESHOLD)
    cpc r17, r18
    brlo check_gas_warning         ; Branch if lower
    
    ; Danger condition
    ldi r20, 1                     ; Set isDanger
    ldi r22, 0                     ; Clear isNormal
    rjmp determine_status
    
check_gas_warning:
    ; Check against GAS_WARNING_THRESHOLD
    cpi r16, lo8(GAS_WARNING_THRESHOLD)
    ldi r18, hi8(GAS_WARNING_THRESHOLD)
    cpc r17, r18
    brlo determine_status          ; Branch if lower
    
    ; Warning condition
    ldi r21, 1                     ; Set isWarning
    ldi r22, 0                     ; Clear isNormal
    
determine_status:
    ; Determine overall status value (0=normal, 1=warning, 2=danger)
    ldi r16, 0                     ; Default: normal (0)
    
    cpi r20, 1                     ; Check isDanger flag
    brne check_warning
    ldi r16, 2                     ; Danger status code
    rjmp store_status
    
check_warning:
    cpi r21, 1                     ; Check isWarning flag
    brne store_status
    ldi r16, 1                     ; Warning status code
    
store_status:
    sts status_value, r16          ; Store status
    
    ; Debug output for status change
    ldi ZL, lo8(status_update_msg)
    ldi ZH, hi8(status_update_msg)
    rcall send_string
    
    mov r24, r16
    clr r25
    rcall send_number
    
    ldi r16, '\r'
    rcall send_char
    ldi r16, '\n'
    rcall send_char
    
    ret

; Function to print sensor values via UART
print_sensor_values:
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
    lds r24, sound_value
    lds r25, sound_value+1
    rcall send_number
    
    ldi ZL, lo8(slash_1023)
    ldi ZH, hi8(slash_1023)
    rcall send_string
    
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
    
    ldi ZL, lo8(slash_1023)
    ldi ZH, hi8(slash_1023)
    rcall send_string
    
    ldi r16, '\r'
    rcall send_char
    ldi r16, '\n'
    
    ; Print status
    ldi ZL, lo8(status_msg)
    ldi ZH, hi8(status_msg)
    rcall send_string
    
    ; Print status value
    lds r16, status_value
    
    cpi r16, 2
    breq print_danger
    
    cpi r16, 1
    breq print_warning
    
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
    
    ldi r16, '\r'
    rcall send_char
    ldi r16, '\n'
    rcall send_char
    
    ; Print footer
    ldi ZL, lo8(equals_line)
    ldi ZH, hi8(equals_line)
    rcall send_string
    
    ret

; Placeholder for millis() function - would need a timer interrupt in real implementation
millis:
    ; This is a simplified version just for demonstration
    ; In reality, this would use Timer0 and an interrupt to track time
    ; Returns a simulated timestamp in r25:r24:r23:r22
    lds r22, current_time
    lds r23, current_time+1
    lds r24, current_time+2
    lds r25, current_time+3
    
    ; Increment by 10 to simulate time passing
    ldi r16, 10
    add r22, r16
    clr r16
    adc r23, r16
    adc r24, r16
    adc r25, r16
    
    ; Return the new time
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

; Function to flash debug LED to indicate initialization
flash_debug_led:
    ; Flash the LED 3 times
    ldi r20, 3
flash_loop:
    ; Turn on LED
    sbi PORTB, DEBUG_LED
    
    ; Delay
    ldi r24, lo8(30000)
    ldi r25, hi8(30000)
    rcall delay_us
    
    ; Turn off LED
    cbi PORTB, DEBUG_LED
    
    ; Delay
    ldi r24, lo8(30000)
    ldi r25, hi8(30000)
    rcall delay_us
    
    ; Decrement counter
    dec r20
    brne flash_loop
    
    ret

; String constants
init_message:
    .asciz "NOIR - Master initialized (Sensor Mode)\r\n"
heartbeat_msg:
    .asciz "Master main loop running...\r\n"
send_data_msg:
    .asciz "Sending sensor data to slave...\r\n"
status_update_msg:
    .asciz "Status updated to: "
equals_line:
    .asciz "==========================\r\n"
system_title:
    .asciz "NOIR Monitoring System\r\n"
dash_line:
    .asciz "--------------------------\r\n"
noise_level_msg:
    .asciz "Noise Level: "
gas_level_msg:
    .asciz "Gas Level: "
status_msg:
    .asciz "Status: "
slash_1023:
    .asciz "/1023"
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
    ; ... other interrupt vectors would go here
