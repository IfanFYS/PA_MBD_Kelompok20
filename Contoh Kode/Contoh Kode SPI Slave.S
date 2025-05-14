;------------------------
; Assembly Code SPI Slave
;------------------------
#define __SFR_OFFSET 0x00
#include "avr/io.h"
;------------------------
.global main
;============================================================
main:
;------------------------------------------------------------
      LDI   R17, 0xFF
      OUT   DDRD, R17       ;set PORTD for o/p
      ;------------------------------------------------------
      LDI   R17, (1<<SPE)
      OUT   SPCR, R17       ;enable SPI as slave
      ;------------------------------------------------------
agn:  IN    R18, SPSR
      SBRS  R18, SPIF       ;wait for byte reception
      RJMP  l1              ;to complete
      ;------------------------------------------------------
      IN    R18, SPDR       ;i/p byte from data register
      OUT   PORTD, R18      ;and o/p to PORTD
      ;------------------------------------------------------
      RJMP  agn             ;repeat reception


