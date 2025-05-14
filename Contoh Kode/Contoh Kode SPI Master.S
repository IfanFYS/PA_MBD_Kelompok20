;------------------------
; Assembly Code SPI Master
;------------------------
#define __SFR_OFFSET 0x00
#include "avr/io.h"
;------------------------
.global main
;==============================================================
main:
.equ  SCK, 5
.equ  MOSI, 3
.equ  SS, 2
;--------------------------------------------------------------
      LDI   R17, (1<<MOSI)|(1<<SCK)|(1<<SS)
      OUT   DDRB, R17       ;set MOSI, SCK, SS as o/p
      ;--------------------------------------------------------
      LDI   R17, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
      OUT   SPCR, R17       ;enable SPI as master, fsck=fosc/16
      ;--------------------------------------------------------
      LDI   R17, 0xAA       ;byte to be transmitted
      ;--------------------------------------------------------
again:CBI   PORTB, SS       ;enable slave device
      OUT   SPDR, R17       ;transmit byte to slave
      ;--------------------------------------------------------
loop: IN    R18, SPSR
      SBRS  R18, SPIF       ;wait for byte transmission
      RJMP  loop            ;to complete
      ;--------------------------------------------------------
      SBI   PORTB, SS       ;disable slave device
      ;--------------------------------------------------------
      RCALL my_delay        ;delay
      COM   R17             ;1's compliment of byte
      RJMP  again           ;repeat transmission
;==============================================================
my_delay:                   ;delay in ms
    LDI   R20, 255
l6: LDI   R21, 255
l7: LDI   R22, 40
l8: DEC   R22
    BRNE  l8
    DEC   R21
    BRNE  l7
    DEC   R20
    BRNE  l6
    RET


