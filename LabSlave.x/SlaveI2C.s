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
; Bank 3 (Modified: TRISB=0x00 for full PORTB outputs)
    BSF STATUS, 5
    BSF STATUS, 6
    MOVLW 0x00          ; All PORTB as outputs (for binary display)
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
    MOVLW 0x40
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
    MOVLW 0X10
    MOVWF COUNT3
FINALLOOP0: MOVLW 0X10
    MOVWF COUNT2
OUTERLOOP0: MOVLW 0X10
    MOVWF COUNT1
INNERLOOP0: DECFSZ COUNT1
    GOTO INNERLOOP0
    DECFSZ COUNT2
    GOTO OUTERLOOP0
    DECFSZ COUNT3
    GOTO FINALLOOP0
  
Delay1:
MOVLW 0X10
MOVWF COUNT7
LOOPA:
DECFSZ COUNT7
GOTO LOOPA
NOP
NOP
    GOTO DISPLAYHIGH
  
LOW0:
    MOVLW 0X10
    MOVWF COUNT6
FINALLOOP1: MOVLW 0X10
    MOVWF COUNT5
OUTERLOOP1: MOVLW 0X10
    MOVWF COUNT4
INNERLOOP1: DECFSZ COUNT4
    GOTO INNERLOOP1
    DECFSZ COUNT5
    GOTO OUTERLOOP1
    DECFSZ COUNT6
    GOTO FINALLOOP1
  
Delay2:
    MOVLW 0X10
    MOVWF COUNT7
LOOPB:
    DECFSZ COUNT7
    GOTO LOOPB
    NOP
    NOP
    GOTO DISPLAYLOW
  
DISPLAYHIGH:
    MOVLW 0X05
    MOVWF PORTC          ; High on PORTC
;    CLRF PORTB           ; Blank PORTB during high
    GOTO LOW0
  
DISPLAYLOW:
    MOVF RECEIVED_DATA, W
    MOVWF PORTB          ; Display last RX byte on PORTB (binary)
    ; MOVWF PORTC       ; Uncomment if also show on PORTC
    GOTO HIGH0
  
GOTO MAINLOOP
  
INTERRUPT:
    BSF PORTC, 0 ; Debug: Toggle RC0 on ISR entry (scope/LED for ISR hits)
    NOP
    BCF PORTC, 0
    BTFSS PIR1, 3 ; SSPIF set? (I2C activity)
    GOTO CHECK_BCL
    BCF PIR1, 3 ; Clear SSPIF
    BSF STATUS, 5 ; Bank 1: Check/clear errors in SSPSTAT
    BCF STATUS, 6
    BTFSC SSPSTAT, 4 ; SSPOV=1? (overflow, e.g., unread data)
    CLRF SSPSTAT ; Clears SSPOV & WCOL, forces next ACK
    BTFSC SSPSTAT, 7 ; WCOL=1? (write collision)
    CLRF SSPSTAT
    MOVLW 0x01 ; Init counter for data bytes (your COUNT1=0x20)
    MOVWF COUNT1 ; Reset on each transaction (or use flag)
    BTFSC SSPSTAT, 5 ; D/A=1? (data phase?store it!)
    GOTO READ_DATA
    ; Address phase (D/A=0): Just ACK, discard value
    BCF STATUS, 5 ; Bank 0
    BCF STATUS, 6
    MOVF SSPBUF, W ; Read to clear BF ? generates ACK
    ; No store?address ignored
    GOTO INT_EXIT
READ_DATA:
    BCF STATUS, 5 ; Bank 0
    BCF STATUS, 6
    MOVF SSPBUF, W ; Read data ? clears BF, auto-ACK
    MOVWF RECEIVED_DATA ; Store (overwrites: 0x04 ? 0x05 ? 0x06)
    ; Debug: Count data bytes received
    BTFSC COUNT1, 0 ; First data byte?
    GOTO SECOND_DATA
    BSF PORTC, 1 ; Toggle RC1 for 0x04 (first data)
    NOP
    BCF PORTC, 1
    INCF COUNT1, F ; COUNT1=2 now
    GOTO INT_EXIT
SECOND_DATA:
    BSF PORTC, 2 ; Toggle RC2 for 0x05+ (subsequent)
    NOP
    BCF PORTC, 2
    GOTO INT_EXIT
    ; Slave read mode (R/W=1, master requesting data from us?not your current case)
    ; BTFSC SSPSTAT, 2 ; If expanding: Test R/W=1 here
SLAVE_READ_PLACEHOLDER:
    MOVLW 0xAA ; Example: Load dummy response to SSPBUF
    MOVWF SSPBUF ; (Master will read this next)
    GOTO INT_EXIT
CHECK_BCL:
    BTFSS PIR2, 3 ; BCLIF? (Bus collision?rare in sim)
    GOTO INT_EXIT
    BCF PIR2, 3
    BCF SSPCON, 5 ; Disable/re-enable MSSP
    BSF SSPCON, 5
INT_EXIT:
    RETFIE ; Return, re-enable interrupts
END