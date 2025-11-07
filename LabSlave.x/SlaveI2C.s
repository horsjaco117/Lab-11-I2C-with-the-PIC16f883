;LAB 11 - Slave
;Jacob Horsley
;RCET 3375
;Fifth Semester
;I2C Communication (Slave)
;Git URL: https://github.com/horsjaco117/Assembly_Code
      
;Device Setup
;--------------------------------------------------------------------------
;Configuration (unchanged)
    ; CONFIG1
  CONFIG FOSC = XT
  CONFIG WDTE = OFF
  CONFIG PWRTE = OFF
  CONFIG MCLRE = ON
  CONFIG CP = OFF
  CONFIG CPD = OFF
  CONFIG BOREN = OFF
  CONFIG IESO = OFF
  CONFIG FCMEN = OFF
  CONFIG LVP = OFF
; CONFIG2
  CONFIG BOR4V = BOR40V
  CONFIG WRT = OFF
;Include Statements
#include <xc.inc>
 
;Code Section
;--------------------------------------------------------------------------
   
;Register/Variable Setup
  SOMEVALUE EQU 0x5f
  RECEIVED_DATA EQU 0x27 ; Variable to store received I2C data
 
 
;---------------------------------------------------------------------
; Reset & Interrupt vectors
;---------------------------------------------------------------------
PSECT resetVect, class=CODE, delta=2
    GOTO Start
PSECT isrVect, class=CODE, delta=2
    GOTO INTERRUPT
Start:
Setup:
; Bank 3 (unchanged)
    BSF STATUS, 5
    BSF STATUS, 6
    MOVLW 0x0F
    MOVWF TRISB
    CLRF ANSELH
    CLRF INTCON
    CLRF OPTION_REG
; Bank 2 (unchanged)
    BCF STATUS, 5
    CLRF CM2CON1
; Bank 1 (unchanged except order for stability)
    BSF STATUS, 5
    BCF STATUS, 6
    MOVLW 0xFF
    MOVWF WPUB
    CLRF IOCB
    CLRF PSTRCON
    MOVLW 0x18
    MOVWF TRISC
    MOVLW 0x08
    MOVWF PIE1 ; SSPIE=1
    MOVLW 0x08
    MOVWF PIE2 ; BCLIE=1
    CLRF SSPCON2
    MOVLW 0x80
    MOVWF SSPSTAT ; SMP=1, CKE=0
    MOVLW 0xA0
    MOVWF SSPADD ; Address 0x50 <<1
; Bank 0
    BCF STATUS, 5
    BCF STATUS, 6
    CLRF CCP1CON
    CLRF PORTC
    CLRF CCP2CON
    CLRF PORTB
    CLRF RCSTA
    CLRF T1CON
    CLRF PIR1
    CLRF PIR2
    MOVLW 0xC0
    MOVWF INTCON ; GIE=1, PEIE=1
    CLRF RECEIVED_DATA ; Initialize
    MOVLW 0x26 ; Fix: SSPM=0110 (slave), CKP=0 (no stretch), SSPEN=1 LAST
    MOVWF SSPCON
    ; Stabilization delay (~50 cycles)
    MOVLW 0x14 ; ~20 loops for ~50 cycles
    MOVWF 0x28 ; Temp GPR
DELAY_STAB:
    DECFSZ 0x28, F
    GOTO DELAY_STAB
   
;Register/Variable setups (unchanged)
     COUNT1 EQU 0x20
     COUNT2 EQU 0x21
     COUNT3 EQU 0x22
     COUNT4 EQU 0X23
     COUNT5 EQU 0X24
     COUNT6 EQU 0X25
     COUNT7 EQU 0X26
    
;Main Program Loop (unchanged)
MAINLOOP:
HIGH0:
    MOVLW 0X59
    MOVWF COUNT3
FINALLOOP0: MOVLW 0X5C
    MOVWF COUNT2
OUTERLOOP0: MOVLW 0X13
    MOVWF COUNT1
INNERLOOP0: DECFSZ COUNT1
    GOTO INNERLOOP0
    DECFSZ COUNT2
    GOTO OUTERLOOP0
    DECFSZ COUNT3
    GOTO FINALLOOP0
   
Delay1:
MOVLW 0X2F
MOVWF COUNT7
LOOPA:
DECFSZ COUNT7
GOTO LOOPA
NOP
NOP
    GOTO DISPLAYHIGH
   
LOW0:
    MOVLW 0X59
    MOVWF COUNT6
FINALLOOP1: MOVLW 0X5C
    MOVWF COUNT5
OUTERLOOP1: MOVLW 0X13
    MOVWF COUNT4
INNERLOOP1: DECFSZ COUNT4
    GOTO INNERLOOP1
    DECFSZ COUNT5
    GOTO OUTERLOOP1
    DECFSZ COUNT6
    GOTO FINALLOOP1
   
Delay2:
    MOVLW 0X2F
    MOVWF COUNT7
LOOPB:
    DECFSZ COUNT7
    GOTO LOOPB
    NOP
    NOP
    GOTO DISPLAYLOW
   
DISPLAYHIGH:
    MOVLW 0X05
    MOVWF PORTC
    GOTO LOW0
   
DISPLAYLOW:
    MOVF RECEIVED_DATA, W
    MOVWF PORTC
    GOTO HIGH0
   
GOTO MAINLOOP
   
INTERRUPT:
    BSF PORTC, 0 ; Debug: Toggle RC0 on ISR entry (confirms interrupts fire)
    NOP
    BCF PORTC, 0
    BTFSS PIR1, 3 ; SSPIF? (Bank 0)
    GOTO CHECK_BCL
    BCF PIR1, 3 ; Clear SSPIF
    BSF STATUS, 5 ; Bank 1 for SSPSTAT/SSPOV/WCOL
    BCF STATUS, 6
    BTFSC SSPSTAT, 4 ; Fix: Check SSPOV=1? (receive overflow ? NACK cause)
    CLRF SSPSTAT ; Clear SSPOV/WCOL (forces ACK on next)
    BTFSC SSPSTAT, 7 ; Check WCOL=1? (write collision)
    CLRF SSPSTAT ; Clear it
    BTFSC SSPSTAT, 2 ; D/A=1? (data phase)
    GOTO READ_DATA
    BCF STATUS, 5 ; Back to Bank 0
    BCF STATUS, 6
    MOVF SSPBUF, W ; Read address to clear BF (enables data ACK)
    GOTO INT_EXIT
   
READ_DATA:
    BCF STATUS, 5 ; Bank 0
    BCF STATUS, 6
    MOVF SSPBUF, W ; Read data ? clears BF ? auto-ACK
    MOVWF RECEIVED_DATA
    GOTO INT_EXIT
   
CHECK_BCL:
    BTFSS PIR2, 3 ; BCLIF?
    GOTO INT_EXIT
    BCF PIR2, 3
    BCF SSPCON, 5 ; Reset MSSP on collision
    BSF SSPCON, 5
   
INT_EXIT:
    RETFIE
END