; LAB 11
; Jacob Horsley
; RCET 3375
; Fifth Semester
; I2C Communication (Master)
; Git URL: https://github.com/horsjaco117/Assembly_Code
    
; Device Setup
;--------------------------------------------------------------------------
; Configuration
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
; Include Statements
#include <xc.inc>
; Code Section
;--------------------------------------------------------------------------
 
; Register/Variable Setup
  SOMEVALUE EQU 0x5f
;---------------------------------------------------------------------
; Reset & Interrupt vectors
;---------------------------------------------------------------------
PSECT resetVect, class=CODE, delta=2
    GOTO Start
PSECT isrVect, class=CODE, delta=2
    GOTO INTERRUPT
Start:
Setup:
; Bank 3
    BSF STATUS, 5
    BSF STATUS, 6
    MOVLW 0x17 ; AN0, AN1, AN2, AN4 analog (bits 0,1,2,4): Analog inputs
    MOVWF ANSEL
    CLRF ANSELH
    CLRF INTCON
    CLRF OPTION_REG
; Bank 2
    BCF STATUS, 5
    CLRF CM2CON1
; Bank 1
    BSF STATUS, 5
    BCF STATUS, 6
    MOVLW 0xFF
    MOVWF WPUB
    CLRF IOCB
    CLRF PSTRCON
    MOVLW 0x18
    MOVWF TRISC
    MOVLW 0x42
    MOVWF PIE1 ;(I2C associated)
    MOVLW 0x00
    MOVWF PIE2 ;(I2C associated)
    CLRF SSPCON2 ;(I2C associated)
    CLRF SSPSTAT ;(I2C associated)
    MOVLW 0x09
    MOVWF SSPADD ;(I2C associated)
    MOVLW 0x0F
    MOVWF TRISB
    MOVLW 0XC5
    MOVWF ADCON1
; Bank 0
    BCF STATUS, 5
    BCF STATUS, 6
    CLRF CCP1CON
    CLRF PORTC
    CLRF CCP2CON
    CLRF PORTB
    CLRF RCSTA
    CLRF T1CON
    CLRF INTCON
    CLRF PIR1
    CLRF PIR2
    MOVLW 0x28
    MOVWF SSPCON ;(I2C associated)
    BANKSEL ADCON0
    MOVLW 0x01
    MOVWF ADCON0
    BANKSEL ADCON1
    BCF ADCON1, 7
    
    ;Indirect addressing (Present in bank0 I believe)
    BANKSEL CHANNEL_TABLE
    MOVLW 0x00 ; AN0 (new channel 0)
    MOVWF CHANNEL_TABLE
    MOVLW 0x04 ; AN4 (channel 1)
    MOVWF CHANNEL_TABLE+1
    MOVLW 0x01 ; AN1 (channel 2)
    MOVWF CHANNEL_TABLE+2
    MOVLW 0x02 ; AN2 (channel 3)
    MOVWF CHANNEL_TABLE+3
    ; ID table for servo IDs (0: servo4 ID=00, 1: servo1 ID=11, 2: servo2 ID=01, 3: servo3 ID=10)
    ; Different addresses due to slave bugs
    MOVLW 0x00
    MOVWF ID_TABLE
    MOVLW 0x03
    MOVWF ID_TABLE+1
    MOVLW 0x01
    MOVWF ID_TABLE+2
    MOVLW 0x02
    MOVWF ID_TABLE+3
   
; Register/Variable setups
    BCF STATUS, 5
    BCF STATUS, 6
     COUNT1 EQU 0x20
     COUNT2 EQU 0x21
     COUNT3 EQU 0x22
     COUNT4 EQU 0X23
     COUNT5 EQU 0X24
     COUNT6 EQU 0X25
     COUNT7 EQU 0X26
     W_TEMP EQU 0X2B
     STATUS_TEMP EQU 0X2C
     TEMP EQU 0x2D
     CURRENT_INDEX EQU 0x2E
     DATA_TO_SEND EQU 0x2F
     CHANNEL_TABLE EQU 0x30
     ID_TABLE EQU 0x34
; Main Program Loop
MAINLOOP:
    ;Handles the addressing of the data to be sent
    MOVLW CHANNEL_TABLE ;Indirect addressing
    ADDWF CURRENT_INDEX, W ;Moves through the addresses 1-4 sequentially Repeats
    MOVWF FSR
    MOVF INDF, W
    BANKSEL ADCON0
    MOVWF TEMP
    RLF TEMP, F
    RLF TEMP, W
    MOVWF TEMP
    MOVF ADCON0, W
    ANDLW 0xC3
    IORWF TEMP, W
    MOVWF ADCON0
;Starts ADC conversion for associated address
START_CONV:
    BSF ADCON0, 1
    BANKSEL PIR1
    BTFSS PIR1, 6 ;Waits for ADC conversion to finish
    GOTO $-1
    BCF PIR1, 6
    BANKSEL ADRESH
    MOVF ADRESH, W ;Saves data to ADRESH then sends it
    MOVWF DATA_TO_SEND
   
    ; Embed ID from table
    MOVLW ID_TABLE
    ADDWF CURRENT_INDEX, W
    MOVWF FSR
    MOVF INDF, W
    MOVWF TEMP
    MOVF DATA_TO_SEND, W
    ANDLW 0xFC
    IORWF TEMP, W
    MOVWF DATA_TO_SEND
;Small delay for processing and testing
HIGH0:
    MOVLW 0X01
    MOVWF COUNT3
FINALLOOP0:
    MOVLW 0X01
    MOVWF COUNT2
OUTERLOOP0:
    MOVLW 0X01
    MOVWF COUNT1
INNERLOOP0:
    DECFSZ COUNT1
    GOTO INNERLOOP0
    DECFSZ COUNT2
    GOTO OUTERLOOP0
    DECFSZ COUNT3
    GOTO FINALLOOP0
 
    CALL Delay1
    GOTO LOW0
 
LOW0:
    MOVLW 0X01
    MOVWF COUNT6
FINALLOOP1:
    MOVLW 0X01
    MOVWF COUNT5
OUTERLOOP1:
    MOVLW 0X01
    MOVWF COUNT4
INNERLOOP1:
    DECFSZ COUNT4
    GOTO INNERLOOP1
    DECFSZ COUNT5
    GOTO OUTERLOOP1
    DECFSZ COUNT6
    GOTO FINALLOOP1
    CALL Delay2
    ;After the buffer the saved ADC data is sent through I2C
    CALL I2C_SEND
 
    INCF CURRENT_INDEX, F ;Increments the address
    MOVF CURRENT_INDEX, W
    SUBLW 0x03 ;Max of four unique addresses
    BTFSS STATUS, 0
    CLRF CURRENT_INDEX ;Resets the address after max reached
    GOTO MAINLOOP
 
; Delay Subroutines
Delay1:
    MOVLW 0X10
    MOVWF COUNT7
LOOPA:
    DECFSZ COUNT7
    GOTO LOOPA
    NOP
    NOP
    RETURN
Delay2:
    MOVLW 0X10
    MOVWF COUNT7
LOOPB:
    DECFSZ COUNT7
    GOTO LOOPB
    NOP
    NOP
    RETURN
 
; Sends I2C
I2C_SEND:
    ;Polling to prevent COM errors
    BSF STATUS, 5
    BCF STATUS, 6
    BTFSC SSPSTAT, 2
    GOTO $-1
    BSF SSPCON2, 0
    BTFSC SSPCON2, 0
    GOTO $-1
   ;This sends the address of 20. The R/W bit should be taken into account
    BCF STATUS, 5
    BCF STATUS, 6
    MOVLW 0x40
    MOVWF SSPBUF
    BTFSS PIR1, 3
    GOTO $-1
    BCF PIR1, 3
   ;Check for errors
    BSF STATUS, 5
    BCF STATUS, 6
    BTFSC SSPCON2, 6
    GOTO ERROR1
   ;Buffer of 24. This byte is ignored to send other data
    BCF STATUS, 5
    BCF STATUS, 6
    MOVLW 0x24
    MOVWF SSPBUF
    BTFSS PIR1, 3
    GOTO $-1
    BCF PIR1, 3
   ;Error check again
    BSF STATUS, 5
    BCF STATUS, 6
    BTFSC SSPCON2, 6
    GOTO ERROR1
   ;Now the ADC data is sent with appropriate address
    BCF STATUS, 5
    BCF STATUS, 6
    MOVF DATA_TO_SEND, W
    MOVWF SSPBUF
    BTFSS PIR1, 3
    GOTO $-1
    BCF PIR1, 3
   ;Error check
    BSF STATUS, 5
    BCF STATUS, 6
    BTFSC SSPCON2, 6
    GOTO ERROR1
   ;Ensure COMMS are good to finish
    BSF SSPCON2, 2
    BTFSC SSPCON2, 2
    GOTO $-1
   ;Bank change
    BCF STATUS, 5
    BCF STATUS, 6
    RETURN
    ;Errors handling
ERROR1:
    BCF STATUS, 5
    BCF STATUS, 6
    BCF SSPCON, 5
    BSF SSPCON, 5
    RETURN
    ;In case interrupt is triggered immediate RETFIE
INTERRUPT:
    RETFIE
END
