#define __SFR_OFFSET 0x00
#include "avr/io.h"

; Define the global entry point that Arduino expects
.global setup
.global loop
.global main

.equ SCK,  5
.equ MOSI, 3
.equ SS,   2

; LED pin definitions
.equ LED_GAS, 4      ; PD4 - lights when gas warning (was LED_SOUND)
.equ LED_SOUND, 3    ; PD3 - lights when sound warning (was LED_GAS)
.equ LED_NORMAL, 2   ; PD2 - lights when no warnings (no change)

; Button and Buzzer pin definitions
.equ BUTTON_PIN, 6   ; PD6 - button for silencing buzzer
.equ BUZZER_PIN, 5   ; PD5 - buzzer for audio alerts

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
str_buzzer_silenced: .ascii " [BUZZER SILENCED]"
                .byte 0
str_buzzer_active:   .ascii " [BUZZER ACTIVE]"
                .byte 0
str_newline:    .byte 13, 10, 0   ; \r\n

; Variables in the .bss section (uninitialized data)
.section .bss
.global button_state
.global last_button_state
.global buzzer_silenced
.global buzzer_state
.global buzzer_timer
.global silence_timer
.global warnings_active

button_state:      .space 1     ; Current button state (0=not pressed, 1=pressed)
last_button_state: .space 1     ; Previous button state for edge detection
buzzer_silenced:   .space 1     ; Buzzer silence flag (0=not silenced, 1=silenced)
buzzer_state:      .space 1     ; Buzzer state (0=off, 1=on)
buzzer_timer:      .space 2     ; Timer for buzzer on/off cycles
silence_timer:     .space 2     ; Timer for auto-reset of silence after timeout
warnings_active:   .space 1     ; Flag indicating if warnings are active

; Define proper Arduino entry points
.section .text

; setup function - called once at startup
setup:
    ; Call our main initialization function
    CALL  main_init
    RET

; loop function - called repeatedly
loop:
    ; Call our main loop function 
    CALL  main_loop
    RET

; Main initialization code
main_init:
    ; UART Init (9600 baud, 16MHz)
    CLR   R16
    STS   UCSR0A, R16
    STS   UBRR0H, R16
    LDI   R16, 103                ; 9600 baud
    STS   UBRR0L, R16
    LDI   R16, (1<<RXEN0)|(1<<TXEN0)
    STS   UCSR0B, R16
    LDI   R16, (1<<UCSZ01)|(1<<UCSZ00)
    STS   UCSR0C, R16    ; SPI Master Init
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
    
    ; Setup button and buzzer pins
    SBI   DDRD, BUZZER_PIN   ; Buzzer pin as output
    CBI   DDRD, BUTTON_PIN   ; Button pin as input
    SBI   PORTD, BUTTON_PIN  ; Enable internal pull-up for button
    CBI   PORTD, BUZZER_PIN  ; Ensure buzzer is off
    
    ; Initialize button/buzzer variables
    LDI   R16, 0
    STS   button_state, R16
    STS   last_button_state, R16
    STS   buzzer_silenced, R16
    STS   buzzer_state, R16
    STS   buzzer_timer, R16
    STS   buzzer_timer+1, R16
    STS   silence_timer, R16
    STS   silence_timer+1, R16
    STS   warnings_active, R16
    
    ; Test buzzer at startup
    SBI   PORTD, BUZZER_PIN
    LDI   R20, 50            ; Short delay for buzzer test
    RCALL delay_ms
    CBI   PORTD, BUZZER_PIN
    
    LDI   R16, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
    OUT   SPCR, R16          ; Enable SPI Master, fosc/16

    ; Wait for slave to be ready
    LDI   R20, 50
    RCALL delay_ms
    
    ; Initial read before entering main loop
    ; Read potentiometer 1
    RCALL read_spi_value     ; Read value into R18    MOV   R22, R18           ; Save pot1 value in R22
    
    ; Read potentiometer 2
    RCALL read_spi_value     ; Read value into R18
    MOV   R23, R18           ; Save pot2 value in R23

    RET   ; Return from main_init

; Our actual main loop that gets called repeatedly
main_loop:
    ; At the start of each loop, turn off all LEDs
    CBI   PORTD, LED_NORMAL
    CBI   PORTD, LED_SOUND
    CBI   PORTD, LED_GAS
    
    ; Check and reset silence timeout if needed
    RCALL check_silence_timeout
    
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
    
    ; Check button state
    RCALL check_button
    
    ; Update buzzer state
    RCALL update_buzzer
    
    ; Now check for warnings - Sound first
    CPI   R22, 153           ; Compare sound value with threshold
    BRLO  check_gas_warning  ; If below threshold, skip sound warning
    
    ; Sound warning - turn on sound LED
    SBI   PORTD, LED_SOUND
    
    ; Display sound warning message on its own line    LDI   ZL, lo8(str_warning)
    LDI   ZH, hi8(str_warning)
    RCALL print_string
    LDI   ZL, lo8(str_newline)
    LDI   ZH, hi8(str_newline)
    RCALL print_string
    
    ; Skip to check_gas_warning
    ; We won't set warnings_active here because we still need to check gas
    
check_gas_warning:
    ; Check gas level
    CPI   R23, 178           ; Compare gas value with threshold
    BRLO  check_normal_conditions  ; If below threshold, skip gas warning
    
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
    
    ; Clear warnings_active flag
    LDI   R16, 0
    STS   warnings_active, R16
    
    ; Reset buzzer silenced when conditions return to normal
    STS   buzzer_silenced, R16
    RJMP  no_warnings
    
check_warnings_done:
    ; If we reach here, at least one warning is active
    LDS   R17, warnings_active
    CPI   R17, 0
    BRNE  skip_silence_reset    ; Skip if warnings were already active
    
    ; This is a transition from normal to warning state
    ; Reset silence state to ensure buzzer works
    LDI   R16, 0
    STS   buzzer_silenced, R16
    
skip_silence_reset:
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
    
; Update buzzer state based on warnings and silence status
update_buzzer:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    PUSH  R19
    PUSH  R20
    
    ; Check if warnings are active
    LDS   R16, warnings_active
    CPI   R16, 0
    BREQ  buzzer_off          ; If no warnings, turn buzzer off
    
    ; Check if buzzer is silenced
    LDS   R16, buzzer_silenced
    CPI   R16, 0
    BRNE  buzzer_off          ; If silenced, keep buzzer off
    
    ; Get current buzzer state
    LDS   R16, buzzer_state
      ; Get current timer value    LDS   R24, buzzer_timer
    LDS   R25, buzzer_timer+1
    
    ; Increment timer
    ADIW  R24, 1
    
    ; Store updated timer value
    STS   buzzer_timer, R24
    STS   buzzer_timer+1, R25
    
    ; Check buzzer state
    CPI   R16, 0
    BRNE  buzzer_is_on    ; Buzzer is off - check if it's time to turn on
    CPI   R25, 0             ; Check high byte first
    BRNE  check_high_byte_off
    CPI   R24, 40            ; 40 cycles = ~400ms off time
    BRLO  update_buzzer_done
    RJMP  toggle_buzzer
    
check_high_byte_off:
    CPI   R25, 1             ; >256 cycles, definitely time to toggle
    BRLO  update_buzzer_done
    RJMP  toggle_buzzer
    
buzzer_is_on:
    ; Buzzer is on - check if it's time to turn off
    CPI   R25, 0             ; Check high byte first
    BRNE  check_high_byte_on
    CPI   R24, 30            ; 30 cycles = ~300ms on time 
    BRLO  update_buzzer_done
    RJMP  toggle_buzzer
    
check_high_byte_on:
    CPI   R25, 1             ; >256 cycles, definitely time to toggle
    BRLO  update_buzzer_done
    
toggle_buzzer:
    ; Toggle buzzer state
    LDS   R16, buzzer_state
    COM   R16                ; Complement bits (0->1, 1->0)
    ANDI  R16, 1             ; Keep only lowest bit
    STS   buzzer_state, R16
      ; Reset timer
    LDI   R24, 0
    STS   buzzer_timer, R24
    STS   buzzer_timer+1, R24
    
    ; Update buzzer output pin
    CPI   R16, 0
    BREQ  set_buzzer_off
    
    ; Turn buzzer on - with Proteus-specific enhancements
    ; Ensure pin is output mode
    SBI   DDRD, BUZZER_PIN
    ; Drive buzzer with stronger signal
    SBI   PORTD, BUZZER_PIN
    
    ; Toggle a few times for Proteus simulation
    PUSH  R21
    LDI   R21, 5             ; Toggle 5 times
toggle_loop:
    CBI   PORTD, BUZZER_PIN
    LDI   R20, 1             ; Very short delay
    RCALL delay_ms
    SBI   PORTD, BUZZER_PIN
    LDI   R20, 1             ; Very short delay
    RCALL delay_ms
    DEC   R21
    BRNE  toggle_loop
    POP   R21
    
    RJMP  update_buzzer_done
    
set_buzzer_off:
    ; Turn buzzer off
    CBI   PORTD, BUZZER_PIN
    RJMP  update_buzzer_done
    
buzzer_off:
    ; Ensure buzzer is off
    CBI   PORTD, BUZZER_PIN
    
    ; Reset buzzer state and timer
    LDI   R16, 0
    STS   buzzer_state, R16
    STS   buzzer_timer, R16
    STS   buzzer_timer+1, R16
    
update_buzzer_done:
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
