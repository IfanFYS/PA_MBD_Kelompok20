.global main
.global __vector_1

.text
main:
    ; Set up stack pointer
    ldi r16, 0x08
    out 0x3E, r16           ; SPH (Stack Pointer High)
    ldi r16, 0xFF
    out 0x3D, r16           ; SPL (Stack Pointer Low)

    ; Configure PB0 (LED1) and PB1 (LED2) as outputs
    ldi r16, (1<<0)|(1<<1)
    out 0x04, r16           ; DDRB (Data Direction Register B)

    ; USART
    ldi r16, 0x67
    sts 0xC4, r16           ; UBRR0L (Baud Rate Low)
    ldi r16, 0x00
    sts 0xC5, r16           ; UBRR0H (Baud Rate High)
    ldi r16, (1<<3)
    sts 0xC1, r16           ; UCSR0B (Enable Transmitter)
    ldi r16, (1<<1)|(1<<2)
    sts 0xC2, r16           ; UCSR0C (8-bit data, 1 stop bit)

    ; Set PD2 (INT0) as input
    cbi 0x0A, 2             ; Clear PD2 direction (input) - DDRD
    sbi 0x0B, 2             ; Enable pull-up on PD2 - PORTD

    ; INT0 setup
    ldi r16, (1<<1)
    sts 0x69, r16           ; EICRA (INT0 falling edge)
    ldi r16, (1<<0)
    out 0x1D, r16           ; EIMSK (Enable INT0)

    sei                     ; Enable global interrupts

main_loop:
    ; Daytime
    sbi 0x05, 0             ; Set PB0 high - PORTB
    ldi r30, lo8(day_msg)
    ldi r31, hi8(day_msg)
    rcall print_string
    rcall delay

    ; Nighttime
    cbi 0x05, 0             ; Clear PB0 - LED1 OFF
    ldi r30, lo8(night_msg)
    ldi r31, hi8(night_msg)
    rcall print_string
    rcall delay

    rjmp main_loop          ; Repeat forever

; External Interrupt Handler 
__vector_1:
    ; Save registers (context switch)
    push r16
    in r16, 0x3F             ; Save status register (SREG)
    push r16
    push r30
    push r31
    breq shark

shark:
    in r17, 0x05            ; Read current PORTB state
    ldi r18, (1 << 1)       ; Bitmask for PB1 (LED2)
    eor r17, r18            ; Toggle PB1
    out 0x05, r17           ; Write back to PORTB

    sbrs r17, 1             ; If PB1 is now 1 (LED2 ON), skip next
    rjmp shark_off          ; If PB1 is 0, it's a Shark Attack!

shark_on:
    ldi r30, lo8(shark_msg)
    ldi r31, hi8(shark_msg)
    rjmp print

shark_off:
    ldi r30, lo8(shark_gone_msg)
    ldi r31, hi8(shark_gone_msg)

print:
    rcall print_string      ; Send message over USART

    ; Restore context and return from interrupt
    pop r31
    pop r30
    pop r16
    out 0x3F, r16
    pop r16
    reti

print_string:
    ; Print string from Z register until null terminator
    lpm r16, Z+
    cpi r16, 0
    breq print_done
tx_wait:
    lds r17, 0xC0           ; UCSR0A (check if ready to send)
    sbrs r17, 5             ; Wait until UDRE0 is set
    rjmp tx_wait
    sts 0xC6, r16           ; UDR0 (send character)
    rjmp print_string
print_done:
    ret

delay:
    push r16
    push r17
    push r18
    ldi r16, 40
dly1: ldi r17, 255
dly2: ldi r18, 255
dly3: dec r18
    brne dly3
    dec r17
    brne dly2
    dec r16
    brne dly1
    pop r18
    pop r17
    pop r16
    ret

; === String Messages ===
day_msg:        .asciz "Day\r\n"
night_msg:      .asciz "Night\r\n"
shark_msg:      .asciz "Shark Attack!\r\n"
shark_gone_msg: .asciz "Shark Gone!\r\n"

