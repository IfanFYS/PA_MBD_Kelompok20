;-------------------------
; Assembly Code - Slave Rx
;-------------------------
#define __SFR_OFFSET 0x00
#include "avr/io.h"
;------------------------
.global main
;==============================================================
main:
    LDI   R21, 0xFF
    OUT   DDRD, R21         ;port D is o/p
    CBI   DDRC, 3           ;pin PC3 is i/p
;--------------------------------------------------------------
agn:RCALL I2C_init          ;initialize TWI module
    RCALL I2C_listen        ;listen to bus to be addressed
    RCALL I2C_read          ;read data byte
    OUT   PORTD, R27        ;and o/p to port D
;--------------------------------------------------------------
l1: SBIS  PINC, 3
    RJMP  l1                ;wait for "listen" button press
;--------------------------------------------------------------
    LDI   R26, 0
    OUT   PORTD, R26        ;clear port D
    RJMP  agn               ;& go back & listen to bus
;==============================================================
I2C_init:
    LDI   R21, 0b10010000
    STS   TWAR, R21         ;store slave address 0b10010000
    LDI   R21, (1<<TWEN)
    STS   TWCR, R21         ;enable TWI
    LDI   R21, (1<<TWINT)|(1<<TWEN)|(1<<TWEA)
    STS   TWCR, R21         ;enable TWI & ACK
    RET
;==============================================================
I2C_listen:
    LDS   R21, TWCR
    SBRS  R21, TWINT
    RJMP  I2C_listen        ;wait for slave to be addressed
    RET
;==============================================================
I2C_read:
    LDI   R21, (1<<TWINT)|(1<<TWEA)|(1<<TWEN)
    STS   TWCR, R21         ;enable TWI & ACK
    ;----------------------------------------------------------
wt: LDS   R21, TWCR
    SBRS  R21, TWINT
    RJMP  wt                ;wait for data byte to be read
    ;----------------------------------------------------------
    LDS   R27, TWDR         ;store received byte
    RET
