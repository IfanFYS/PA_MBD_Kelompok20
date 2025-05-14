;--------------------------
; Assembly Code - Master Tx
;--------------------------
#define __SFR_OFFSET 0x00
#include "avr/io.h"
;------------------------
.global main
;==============================================================
main:
    CBI   DDRC, 3         ;pin PC3 is i/p
    ;----------------------------------------------------------
    RCALL I2C_init        ;initialize TWI module
    ;----------------------------------------------------------
l1: SBIS  PINC, 3
    RJMP  l1              ;wait for "transmit" button press
    ;----------------------------------------------------------
    RCALL I2C_start       ;transmit START condition
    LDI   R27, 0b10010000 ;SLA(1001000) + W(0)
    RCALL I2C_write       ;write slave address SLA+W
    LDI   R27, 0b11110101 ;data byte to be transmitted
    RCALL I2C_write       ;write data byte
    RCALL I2C_stop        ;transmit STOP condition
    ;----------------------------------------------------------
    RJMP  l1              ;go back for another transmit
;==============================================================
I2C_init:
    LDI   R21, 0
    STS   TWSR, R21       ;prescaler = 0
    LDI   R21, 12         ;division factor = 12
    STS   TWBR, R21       ;SCK freq = 400kHz
    LDI   R21, (1<<TWEN)
    STS   TWCR, R21       ;enable TWI
    RET
;==============================================================
I2C_start:
    LDI   R21, (1<<TWINT)|(1<<TWSTA)|(1<<TWEN)
    STS   TWCR, R21       ;transmit START condition
    ;----------------------------------------------------------
wt1:LDS   R21, TWCR
    SBRS  R21, TWINT      ;TWI interrupt = 1?
    RJMP  wt1             ;no, wait for end of transmission
    ;----------------------------------------------------------
    RET
;==============================================================
I2C_write:
    STS   TWDR, R27       ;copy SLA+W into data register
    LDI   R21, (1<<TWINT)|(1<<TWEN)
    STS   TWCR, R21       ;transmit SLA+W
    ;----------------------------------------------------------
wt2:LDS   R21, TWCR
    SBRS  R21, TWINT
    RJMP  wt2             ;wait for end of transmission
    ;----------------------------------------------------------
    RET
;==============================================================
I2C_stop:
    LDI   R21, (1<<TWINT)|(1<<TWSTO)|(1<<TWEN)
    STS   TWCR, R21       ;transmit STOP condition
    RET

