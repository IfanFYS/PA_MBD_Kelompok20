#define __SFR_OFFSET 0x00
#include "avr/io.h"

;============================================================================
; NOIR (Noise and Air Quality Monitoring System) - MASTER CONTROLLER
;
; This file contains AVR assembly code for the master Arduino in the NOIR
; system. The master receives sensor data from a slave Arduino via SPI
; communication, processes the data, and controls warning indicators
; (LEDs and buzzer) based on threshold values.
;
; Key responsibilities:
; 1. Establish and maintain SPI communication with the slave Arduino
; 2. Process received data from sound and gas sensors
; 3. Display sensor values via serial communication
; 4. Control LEDs based on sensor threshold values
; 5. Manage audio alerts via buzzer with silencing capabilities
; 6. Handle button input for buzzer silencing with debounce logic
;============================================================================

; Define the global entry points that Arduino expects
.global setup        ; Arduino setup function
.global loop         ; Arduino loop function
.global main         ; Traditional entry point

; SPI pin definitions (PORTB)
.equ SCK,  5         ; PB5 - SPI Clock pin
.equ MOSI, 3         ; PB3 - Master Out Slave In pin
.equ SS,   2         ; PB2 - Slave Select pin

; LED pin definitions (PORTD)
.equ LED_GAS, 4      ; PD4 - Red LED for gas/air quality warning
.equ LED_SOUND, 3    ; PD3 - Yellow LED for sound/noise warning
.equ LED_NORMAL, 2   ; PD2 - Green LED for normal status

; Button and Buzzer pin definitions (PORTD)
.equ BUTTON_PIN, 6   ; PD6 - Button for silencing buzzer
.equ BUZZER_PIN, 5   ; PD5 - Buzzer for audio alerts

; String constants stored in program memory (flash) for serial output
.section .progmem
str_sound:           .ascii "Sound: "       ; Label for sound level readings
                    .byte 0                 ; Null terminator
str_gas:             .ascii "Gas: "         ; Label for gas level readings
                    .byte 0                 ; Null terminator
str_warning:         .ascii " !! WARNING: High noise level!"  ; Sound warning message
                    .byte 0                 ; Null terminator
str_gas_warning:     .ascii " !! WARNING: Poor air quality detected!"  ; Gas warning message
                    .byte 0                 ; Null terminator
str_buzzer_silenced: .ascii " [BUZZER SILENCED]"    ; Status message when buzzer is muted
                    .byte 0                 ; Null terminator
str_buzzer_active:   .ascii " [BUZZER ACTIVE]"      ; Status message when buzzer is active
                    .byte 0                 ; Null terminator
str_newline:        .byte 13, 10, 0         ; Carriage return + Line feed + Null terminator

;============================================================================
; SYSTEM STATE VARIABLES
; These variables track the current state of the monitoring system
;============================================================================
.section .bss
.global button_state         ; Expose variables for possible C integration
.global last_button_state
.global buzzer_silenced
.global buzzer_state
.global buzzer_timer
.global silence_timer
.global warnings_active

; Button state tracking variables
button_state:      .space 1     ; Current button state (0=not pressed, 1=pressed)
last_button_state: .space 1     ; Previous button state for edge detection (debouncing)

; Buzzer control variables
buzzer_silenced:   .space 1     ; Buzzer silence flag (0=not silenced, 1=silenced)
buzzer_state:      .space 1     ; Buzzer state (0=off, 1=on)
buzzer_timer:      .space 2     ; 16-bit timer for buzzer on/off cycles
silence_timer:     .space 2     ; 16-bit timer for auto-reset of silence after timeout

; System state variables
warnings_active:   .space 1     ; Flag indicating if any warnings are active (0=no, 1=yes)

;============================================================================
; ARDUINO INTEGRATION FUNCTIONS
; These functions provide the necessary integration with the Arduino framework
;============================================================================
.section .text

; setup() - Arduino entry point, called once at startup
setup:
    CALL  main_init        ; Call our main initialization function
    RET                    ; Return to Arduino framework

; loop() - Arduino entry point, called repeatedly in the main program loop
loop:
    CALL  main_loop        ; Call our main processing loop
    RET                    ; Return to Arduino framework

;============================================================================
; SYSTEM INITIALIZATION
; Sets up all I/O, timers, communication interfaces, and initial system state
;============================================================================
main_init:
    ; Initialize UART for serial communication (9600 baud with 16MHz clock)
    CLR   R16
    STS   UCSR0A, R16      ; Clear UART control registers
    STS   UBRR0H, R16      ; Clear high byte of baud rate register
    LDI   R16, 103         ; Set baud rate to 9600 bps (16MHz / (16 * 9600) - 1 = 103)
    STS   UBRR0L, R16      ; Set low byte of baud rate register
    LDI   R16, (1<<RXEN0)|(1<<TXEN0)  ; Enable transmitter and receiver
    STS   UCSR0B, R16      ; Set UART control register B
    LDI   R16, (1<<UCSZ01)|(1<<UCSZ00); 8-bit character size
    STS   UCSR0C, R16      ; Set UART control register C
    
    ; Initialize SPI Master configuration
    LDI   R16, (1<<MOSI)|(1<<SCK)|(1<<SS)  ; Set SPI pins as outputs
    OUT   DDRB, R16        ; Configure PORTB SPI pins
    SBI   PORTB, SS        ; Set SS high to deselect slave
    
    ; Configure LED pins as outputs
    SBI   DDRD, LED_NORMAL ; Set LED_NORMAL pin as output
    SBI   DDRD, LED_SOUND  ; Set LED_SOUND pin as output
    SBI   DDRD, LED_GAS    ; Set LED_GAS pin as output
    
    ; Initialize LEDs to off state
    CBI   PORTD, LED_NORMAL; Turn off normal LED
    CBI   PORTD, LED_SOUND ; Turn off sound warning LED
    CBI   PORTD, LED_GAS   ; Turn off gas warning LED
    
    ; Configure buzzer and button pins
    SBI   DDRD, BUZZER_PIN ; Set buzzer pin as output
    CBI   DDRD, BUTTON_PIN ; Set button pin as input
    SBI   PORTD, BUTTON_PIN; Enable internal pull-up for button
    CBI   PORTD, BUZZER_PIN; Ensure buzzer is off initially
      ; Initialize all system state variables to zero
    LDI   R16, 0
    STS   button_state, R16     ; Clear button state
    STS   last_button_state, R16; Clear last button state
    STS   buzzer_silenced, R16  ; Clear buzzer silenced flag
    STS   buzzer_state, R16     ; Clear buzzer state
    STS   buzzer_timer, R16     ; Clear buzzer timer (low byte)
    STS   buzzer_timer+1, R16   ; Clear buzzer timer (high byte)
    STS   silence_timer, R16    ; Clear silence timer (low byte)
    STS   silence_timer+1, R16  ; Clear silence timer (high byte)
    STS   warnings_active, R16  ; Clear warnings active flag
    
    ; Perform startup test of the buzzer
    SBI   PORTD, BUZZER_PIN     ; Briefly activate buzzer
    LDI   R20, 50               ; 50ms delay
    RCALL delay_ms              ; Call delay subroutine
    CBI   PORTD, BUZZER_PIN     ; Deactivate buzzer
    
    ; Complete SPI initialization
    LDI   R16, (1<<SPE)|(1<<MSTR)|(1<<SPR0) ; Enable SPI, Master mode, clock rate fosc/16
    OUT   SPCR, R16             ; Configure SPI control register

    ; Wait for the slave Arduino to complete its initialization
    LDI   R20, 50               ; 50ms delay
    RCALL delay_ms              ; Call delay subroutine
    
    ; Perform initial sensor readings before entering main loop
    RCALL read_spi_value        ; Read sound sensor value through SPI
    MOV   R22, R18              ; Store sound value in R22
    
    RCALL read_spi_value        ; Read gas sensor value through SPI
    MOV   R23, R18              ; Store gas value in R23

    RET                         ; Return from initialization function

;============================================================================
; MAIN PROCESSING LOOP
; This is the primary control loop that runs continuously, handling:
; - Reading sensor values from the slave via SPI
; - Updating status displays and warnings
; - Processing user input (button presses)
; - Managing timers and state transitions
;============================================================================
main_loop:
    ; Reset all LEDs at the start of each cycle
    CBI   PORTD, LED_NORMAL     ; Turn off normal LED
    CBI   PORTD, LED_SOUND      ; Turn off sound warning LED
    CBI   PORTD, LED_GAS        ; Turn off gas warning LED
    
    ; Check if buzzer silence timeout has expired
    RCALL check_silence_timeout ; Call timeout checking subroutine
    
    ; Display current sound sensor reading via serial
    LDI   ZL, lo8(str_sound)    ; Load address of sound label string (low byte)
    LDI   ZH, hi8(str_sound)    ; Load address of sound label string (high byte)
    RCALL print_string          ; Print "Sound: " to serial
    
    MOV   R18, R22              ; Copy sound value to R18 for conversion
    RCALL dec_to_ascii          ; Convert value to decimal ASCII and send to serial
    
    ; Add spacing between sound and gas values
    LDI   R19, ' '              ; Load space character
    RCALL uart_send             ; Send space
    LDI   R19, ' '              ; Load space character
    RCALL uart_send             ; Send another space for better formatting
    
    ; Display current gas sensor reading via serial (on same line)
    LDI   ZL, lo8(str_gas)      ; Load address of gas label string (low byte)
    LDI   ZH, hi8(str_gas)      ; Load address of gas label string (high byte)
    RCALL print_string          ; Print "Gas: " to serial
    
    MOV   R18, R23              ; Copy gas value to R18 for conversion
    RCALL dec_to_ascii          ; Convert value to decimal ASCII and send to serial
    
    ; End the sensor readings line with a newline
    LDI   ZL, lo8(str_newline)  ; Load address of newline string (low byte)
    LDI   ZH, hi8(str_newline)  ; Load address of newline string (high byte)
    RCALL print_string          ; Send CR+LF to serial
    
    ; Process button input for buzzer silencing
    RCALL check_button          ; Check if button was pressed
    
    ; Update buzzer state based on warnings and button presses
    RCALL update_buzzer         ; Update buzzer on/off state
      ;============================================================================
    ; THRESHOLD CHECKING AND WARNING PROCESSING
    ; Check sensor values against predefined thresholds and activate warnings
    ;============================================================================
    
    ; Check sound level against threshold
    CPI   R22, 153               ; Compare sound value with threshold (60% of max)
    BRLO  check_gas_warning      ; If below threshold, skip sound warning
    
    ; Sound warning condition detected
    SBI   PORTD, LED_SOUND       ; Turn on sound warning LED
    
    ; Display sound warning message
    LDI   ZL, lo8(str_warning)   ; Load address of sound warning string (low byte)
    LDI   ZH, hi8(str_warning)   ; Load address of sound warning string (high byte)
    RCALL print_string           ; Print warning message
    LDI   ZL, lo8(str_newline)   ; Load address of newline string (low byte)
    LDI   ZH, hi8(str_newline)   ; Load address of newline string (high byte)
    RCALL print_string           ; Send CR+LF to serial
    
    ; Note: We won't set warnings_active here since we still need to check gas
    
check_gas_warning:
    ; Check gas level against threshold
    CPI   R23, 178               ; Compare gas value with threshold (70% of max)
    BRLO  check_normal_conditions ; If below threshold, skip gas warning
    
    ; Gas warning - turn on gas LED
    SBI   PORTD, LED_GAS
    
    ; Display gas warning message on its own line    LDI   ZL, lo8(str_gas_warning)
    LDI   ZH, hi8(str_gas_warning)
    RCALL print_string
    LDI   ZL, lo8(str_newline)
    LDI   ZH, hi8(str_newline)
    RCALL print_string
    RJMP  check_warnings_done  ; Go to common warning handler
    
check_normal_conditions:
    ; If we get here, check if both levels are normal
    CPI   R22, 153
    BRSH  no_warnings  ; If sound warning, skip normal LED
    CPI   R23, 178
    BRSH  no_warnings  ; If gas warning, skip normal LED
      ; If both are below threshold, turn on normal LED
    SBI   PORTD, LED_NORMAL
    
    ; First check if we were previously in warning state
    LDS   R17, warnings_active
    CPI   R17, 0
    BREQ  still_normal     ; If already normal, skip reset
    
    ; Transitioning from warning to normal state
    ; Reset buzzer silenced when conditions return to normal
    LDI   R16, 0
    STS   buzzer_silenced, R16
    STS   silence_timer, R16
    STS   silence_timer+1, R16
    
still_normal:
    ; Clear warnings_active flag
    LDI   R16, 0
    STS   warnings_active, R16
    
    RJMP  no_warnings
    
check_warnings_done:
    ; If we reach here, at least one warning is active
    LDS   R17, warnings_active
    CPI   R17, 0
    BRNE  still_warning    ; Skip if warnings were already active
    
    ; This is a transition from normal to warning state
    ; Reset silence state to ensure buzzer works
    LDI   R16, 0
    STS   buzzer_silenced, R16
    
still_warning:
    ; Set the warnings active flag
    LDI   R16, 1
    STS   warnings_active, R16
    
no_warnings:
    ; Display buzzer status if warnings are active
    LDS   R16, warnings_active
    CPI   R16, 0
    BREQ  skip_buzzer_status
    
    ; Display appropriate buzzer status message
    LDS   R16, buzzer_silenced
    CPI   R16, 0
    BREQ  buzzer_active_msg
    
    ; Buzzer silenced message
    LDI   ZL, lo8(str_buzzer_silenced)
    LDI   ZH, hi8(str_buzzer_silenced)
    RCALL print_string
    RJMP  buzzer_status_done
    
buzzer_active_msg:
    ; Buzzer active message
    LDI   ZL, lo8(str_buzzer_active)
    LDI   ZH, hi8(str_buzzer_active)
    RCALL print_string
    
buzzer_status_done:
skip_buzzer_status:
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
    
    RET  ; Return from main_loop to Arduino framework

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

; Check button state and handle button press
check_button:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    
    ; Read current button state (inverted because of pull-up)
    IN    R16, PIND
    ANDI  R16, (1<<BUTTON_PIN)
    ; Button is active LOW (pressed when 0)
    LDI   R17, 0
    CPI   R16, 0
    BRNE  not_pressed
    LDI   R17, 1         ; Button is pressed
    
not_pressed:
    ; Store current button state
    STS   button_state, R17
    
    ; Check for button state change (button pressed)
    LDS   R18, last_button_state
    CP    R17, R18
    BREQ  button_no_change
    
    ; Button state changed
    CPI   R17, 1         ; Check if button is now pressed
    BRNE  button_released
    
    ; Button pressed!
    ; Check if warnings are active
    LDS   R16, warnings_active
    CPI   R16, 0
    BREQ  button_state_update  ; If no warnings, ignore button press
      ; Silence the buzzer
    LDI   R16, 1
    STS   buzzer_silenced, R16
    
    ; Reset the silence timeout counter
    LDI   R16, 0
    STS   silence_timer, R16
    STS   silence_timer+1, R16
    
    ; Turn off buzzer immediately
    CBI   PORTD, BUZZER_PIN
    
    ; Blink green LED to acknowledge button press
    LDI   R18, 3              ; Blink 3 times
button_ack_loop:
    SBI   PORTD, LED_NORMAL
    LDI   R20, 5              ; Short delay
    RCALL delay_ms
    CBI   PORTD, LED_NORMAL
    LDI   R20, 5              ; Short delay
    RCALL delay_ms
    DEC   R18
    BRNE  button_ack_loop
    
    RJMP  button_state_update
    
button_released:
    ; Button has been released, nothing special to do
    
button_state_update:
    ; Update last_button_state for next time
    LDS   R16, button_state
    STS   last_button_state, R16
    
button_no_change:
    POP   R18
    POP   R17
    POP   R16
    RET
    
; Update buzzer state based on warnings and silence status - completely rewritten to match C++ version
update_buzzer:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    PUSH  R19
    PUSH  R20
    PUSH  R21
    
    ; Check if warnings are active
    LDS   R16, warnings_active
    CPI   R16, 0
    BREQ  no_warnings_active     ; If no warnings, turn buzzer off
    
    ; Check if buzzer is silenced
    LDS   R16, buzzer_silenced
    CPI   R16, 0
    BRNE  no_warnings_active     ; If silenced, keep buzzer off
    
    ; If we're here, we have warnings and buzzer is not silenced
    ; Check if buzzer is already active
    LDS   R16, buzzer_state
    CPI   R16, 0
    BRNE  check_buzzer_off_time  ; If buzzer already active, check if time to turn off
    
    ; Buzzer not active, turn it on with Proteus-specific enhancements
    ; First make sure pin is output mode
    SBI   DDRD, BUZZER_PIN
    
    ; Drive the buzzer with stronger signal
    SBI   PORTD, BUZZER_PIN
    
    ; For Proteus, toggle a few times to make sure the simulation registers it
    LDI   R21, 5                ; Toggle 5 times
buzzer_toggle_loop:
    CBI   PORTD, BUZZER_PIN
    LDI   R20, 1                ; Very short delay
    RCALL delay_ms
    SBI   PORTD, BUZZER_PIN
    LDI   R20, 1                ; Very short delay
    RCALL delay_ms
    DEC   R21
    BRNE  buzzer_toggle_loop
    
    ; Set buzzer as active and reset timer
    LDI   R16, 1
    STS   buzzer_state, R16
    LDI   R16, 0
    STS   buzzer_timer, R16
    STS   buzzer_timer+1, R16
    
    RJMP  update_buzzer_done
    
check_buzzer_off_time:
    ; Buzzer is active, check if time to turn off (300ms)
    LDS   R24, buzzer_timer
    LDS   R25, buzzer_timer+1
    
    ; Increment timer
    ADIW  R24, 1
    STS   buzzer_timer, R24
    STS   buzzer_timer+1, R25
    
    ; Check if reached 30 (~300ms)
    CPI   R25, 0                ; Check high byte
    BRNE  turn_buzzer_off       ; >255 means definitely time to turn off
    CPI   R24, 30               ; 30 cycles = ~300ms
    BRLO  update_buzzer_done    ; Not time yet
    
turn_buzzer_off:
    ; Time to turn buzzer off
    CBI   PORTD, BUZZER_PIN
    LDI   R16, 0
    STS   buzzer_state, R16
    STS   buzzer_timer, R16     ; Reset timer for next cycle
    STS   buzzer_timer+1, R16
    
    RJMP  update_buzzer_done
    
no_warnings_active:
    ; No warnings or silenced
    CBI   PORTD, BUZZER_PIN     ; Ensure buzzer is off
    LDI   R16, 0
    STS   buzzer_state, R16
    STS   buzzer_timer, R16
    STS   buzzer_timer+1, R16
    
update_buzzer_done:
    POP   R21
    POP   R20
    POP   R19
    POP   R18
    POP   R17
    POP   R16
    RET

; Check silence timeout and reset if needed
check_silence_timeout:
    PUSH  R16
    PUSH  R17
    PUSH  R24
    PUSH  R25
    
    ; Check if buzzer is silenced
    LDS   R16, buzzer_silenced
    CPI   R16, 0
    BREQ  silence_timeout_done   ; If not silenced, nothing to do
    
    ; Check if warnings are active
    LDS   R16, warnings_active
    CPI   R16, 0
    BREQ  reset_silence_state    ; Reset silencing when no warnings active
    
    ; If we're here, buzzer is silenced and warnings are active
    ; Increment silence timer
    LDS   R24, silence_timer
    LDS   R25, silence_timer+1
    ADIW  R24, 1
    STS   silence_timer, R24
    STS   silence_timer+1, R25
    
    ; Check if silence timed out (about 10 seconds)
    ; Since main loop runs ~5 times per second, count to ~50
    CPI   R25, 0
    BRNE  reset_silence_state   ; > 256 means definitely timed out
    CPI   R24, 50
    BRLO  silence_timeout_done
    
reset_silence_state:
    ; Reset silencing state and timer
    LDI   R16, 0
    STS   buzzer_silenced, R16
    STS   silence_timer, R16
    STS   silence_timer+1, R16
    
    ; Optionally display a message that silence timed out
    ; For now, we'll skip this and just reset the state
    
silence_timeout_done:
    POP   R25
    POP   R24
    POP   R17
    POP   R16
    RET
