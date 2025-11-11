;LAB 11 - ADC to I2C Master Tx
;Jacob Horsley
;RCET 3375
;Fifth Semester
;I2C Master with ADC Read (Slave Addr: 0x20 Write)
;Git URL: https://github.com/horsjaco117/Assembly_Code
;PIC16F883 @ 4MHz XT, MPLAB X IDE v6.20, XC8 Assembler

;Device Setup
;--------------------------------------------------------------------------
;Configuration
    ; CONFIG1
  CONFIG FOSC = XT          ; XT oscillator
  CONFIG WDTE = OFF         ; WDT disabled
  CONFIG PWRTE = OFF        ; PWRT disabled
  CONFIG MCLRE = ON         ; MCLR enabled
  CONFIG CP = OFF           ; Code protection off
  CONFIG CPD = OFF          ; Data protection off
  CONFIG BOREN = OFF        ; BOR disabled
  CONFIG IESO = OFF         ; IESO disabled
  CONFIG FCMEN = OFF        ; FCM disabled
  CONFIG LVP = OFF          ; LVP disabled
; CONFIG2
  CONFIG BOR4V = BOR40V     ; BOR at 4.0V
  CONFIG WRT = OFF          ; Write protection off

;Include Statements
#include <xc.inc>

;Register/Variable Setup
SOMEVALUE EQU 0x5F

;---------------------------------------------------------------------
; Reset & Interrupt vectors
;---------------------------------------------------------------------
PSECT resetVect, class=CODE, delta=2
    GOTO Start
PSECT isrVect, class=CODE, delta=2
    GOTO INTERRUPT

Start:
    ;No starting code for this section
Setup:
; Bank 3
    BANKSEL ANSEL        ; *** FIXED: Use BANKSEL for safety (expands to BSF STATUS,RP0/1)
    MOVLW 0x01           ; ANSEL=0x01 for AN0 analog only
    MOVWF ANSEL
    CLRF ANSELH          ; Digital I/O for higher pins
    CLRF INTCON          ; Disable interrupts
    CLRF OPTION_REG      ; Default T0CS=0, etc.

; Bank 2
    BANKSEL CM2CON1
    CLRF CM2CON1         ; Comparator off

; Bank 1
    BANKSEL WPUB
    MOVLW 0xFF           ; Enable weak pull-ups on PORTB
    MOVWF WPUB
    CLRF IOCB            ; No IOC on B
    CLRF PSTRCON         ; No PWM steering
    MOVLW 0x18           ; TRISC: RC3=SCL(1), RC4=SDA(1) for I2C
    MOVWF TRISC
    MOVLW 0x42           ; PIE1: No SSP/ADC ints
    MOVWF PIE1
    MOVLW 0x00           ; PIE2: No BCL
    MOVWF PIE2
    CLRF SSPCON2         ; Clear I2C actions
    CLRF SSPSTAT         ; SMP=0, CKE=0 (std mode)
    MOVLW 0x09           ; SSPADD=9 for 100kHz @4MHz
    MOVWF SSPADD
    MOVLW 0x0F           ; TRISB lower 4 inputs (for ADC if needed)
    MOVWF TRISB
    MOVLW 0xF0           ; PR2 for TMR2 (unused)
    MOVWF PR2
    MOVLW 0xC5           ; ADCON1: Vref=VDD/VSS, right-just, PCFG=1101 (AN0-3 analog)
    MOVWF ADCON1

; Bank 0
    BANKSEL CCP1CON
    CLRF CCP1CON         ; CCP1 off
    CLRF PORTC           ; Clear PORTC
    CLRF CCP2CON         ; CCP2 off
    CLRF PORTB           ; Clear PORTB
    CLRF RCSTA           ; UART off
    CLRF T1CON           ; T1 off
    CLRF INTCON          ; No global ints
    CLRF PIR1            ; Clear SSPIF
    CLRF PIR2            ; Clear BCLIF
    MOVLW 0x28           ; SSPCON: SSPM=1000 (I2C master), SSPEN=1
    MOVWF SSPCON
    ; Full ADC setup in Bank 0
    MOVLW 0x01           ; ADCON0: ADCS=01 (Fosc/8), CHS=000 (AN0), ADON=0 (off for now)
    MOVWF ADCON0
    BANKSEL ADCON1
    BCF ADCON1, 7        ; Ensure PCFG3=0 (part of 0xC5 setup)

;Register/Variable setups
    COUNT1 EQU 0x20
    COUNT2 EQU 0x21
    COUNT3 EQU 0x22
    COUNT4 EQU 0x23
    COUNT5 EQU 0x24
    COUNT6 EQU 0x25
    COUNT7 EQU 0x26
    RESULT_HI EQU 0x27   ; ADC high byte (bits 2-9)
    RESULT_LO EQU 0x28   ; ADC low byte (bits 0-1, padded)
    ADC_CONTINUOUS EQU 0x29  ; Flag: 1=continuous mode
    ADC_DATA EQU 0x2A    ; Temp for tx byte
    W_TEMP EQU 0x2B
    STATUS_TEMP EQU 0x2C
    RECEIVED_DATA EQU 0x2D

;Main Program Loop (Loops forever)
MAINLOOP:
HIGH0:  ; Delay ~250ms (your original nested loops)
    MOVLW 0x10
    MOVWF COUNT3
FINALLOOP0:
    MOVLW 0x10
    MOVWF COUNT2
OUTERLOOP0:
    MOVLW 0x10
    MOVWF COUNT1
INNERLOOP0:
    DECFSZ COUNT1, F
    GOTO INNERLOOP0
    DECFSZ COUNT2, F
    GOTO OUTERLOOP0
    DECFSZ COUNT3, F
    GOTO FINALLOOP0

    Delay1:
    MOVLW 0x10
    MOVWF COUNT7
LOOPA:
    DECFSZ COUNT7, F
    GOTO LOOPA
    NOP
    NOP
    GOTO DISPLAYHIGH

LOW0:
    MOVLW 0x10
    MOVWF COUNT6
FINALLOOP1:
    MOVLW 0x5C
    MOVWF COUNT5
OUTERLOOP1:
    MOVLW 0x13
    MOVWF COUNT4
INNERLOOP1:
    DECFSZ COUNT4, F
    GOTO INNERLOOP1
    DECFSZ COUNT5, F
    GOTO OUTERLOOP1
    DECFSZ COUNT6, F
    GOTO FINALLOOP1

Delay2:
    MOVLW 0x10
    MOVWF COUNT7
LOOPB:
    DECFSZ COUNT7, F
    GOTO LOOPB
    NOP
    NOP
    GOTO DISPLAYLOW

DISPLAYHIGH:
    ; Optional: Output high state to PORTC if needed (e.g., LED)
    ; BSF PORTC, 0
    GOTO LOW0

DISPLAYLOW:
    ; Optional: Output low state
    ; BCF PORTC, 0
    CALL ADC_READ        ; Acquire ADC data here (every cycle ~500ms)
    CALL I2C_SEND        ; Send ADC results via I2C
    GOTO HIGH0           ; Infinite loop

; ADC Read Subroutine (10-bit, right-justified, AN0)
ADC_READ:
    BANKSEL ADCON0
    BSF ADCON0, 0        ; Enable ADC (ADON=1, bit 0)
    BCF ADCON0, 2        ; Clear GO/DONE (bit 2)
    ; Channel select already 000 in ADCON0 (AN0)
    BSF ADCON0, 2        ; Start conversion (GO=1)
ADC_WAIT:
    BTFSC ADCON0, 2      ; Poll DONE (GO=0)
    GOTO ADC_WAIT
    MOVF ADRESH, W       ; High byte to RESULT_HI
    MOVWF RESULT_HI
    MOVF ADRESL, W       ; Low byte to RESULT_LO
    MOVWF RESULT_LO
    BCF ADCON0, 0        ; Disable ADC (power save)
    RETURN

; I2C Send (Transmits ADC data: slave addr, high byte, low byte)
I2C_SEND:
    ; Wait for bus idle *** FIXED: Numeric bits, manual bank if needed
    BANKSEL SSPSTAT
BUS_IDLE:                  ; *** FIXED: Label for loop
    BTFSC SSPSTAT, 2       ; R/W=1? (bit 2) Wait
    GOTO BUS_IDLE
    BSF SSPCON2, 0         ; SEN=1 (start, bit 0)
START_WAIT:
    BTFSC SSPCON2, 0       ; Wait for SEN=0 (bit 0)
    GOTO START_WAIT

    ; Send Slave Address + Write (0x40 = 0x20<<1 | 0)
    BANKSEL SSPBUF
    MOVLW 0x40
    MOVWF SSPBUF
TX_WAIT1:
    BTFSS PIR1, 3          ; SSPIF=1? (bit 3)
    GOTO TX_WAIT1
    BCF PIR1, 3            ; Clear SSPIF

    ; Check ACK for Addr
    BANKSEL SSPCON2
    BTFSC SSPCON2, 6       ; ACKSTAT=0? (bit 6) NACK?
    GOTO I2C_ERROR
    ; Send ADC High Byte (no reg addr; add if needed, e.g., MOVLW 0x00; MOVWF SSPBUF first)
    BANKSEL RESULT_HI
    MOVF RESULT_HI, W      ; Load ADC high
    MOVWF SSPBUF
TX_WAIT2:
    BTFSS PIR1, 3
    GOTO TX_WAIT2
    BCF PIR1, 3

    ; Check ACK for High
    BANKSEL SSPCON2
    BTFSC SSPCON2, 6
    GOTO I2C_ERROR

    ; Send ADC Low Byte
    BANKSEL RESULT_LO
    MOVF RESULT_LO, W
    MOVWF SSPBUF
TX_WAIT3:
    BTFSS PIR1, 3
    GOTO TX_WAIT3
    BCF PIR1, 3

    ; Check ACK for Low
    BANKSEL SSPCON2
    BTFSC SSPCON2, 6
    GOTO I2C_ERROR

    ; Stop
    BSF SSPCON2, 2         ; PEN=1 (bit 2)
STOP_WAIT:
    BTFSC SSPCON2, 2       ; Wait for PEN=0 (bit 2)
    GOTO STOP_WAIT
    BANKSEL PORTA          ; Back to Bank 0
    RETURN

I2C_ERROR:                 ; Simple reset on NACK/error
    BANKSEL SSPCON
    BCF SSPCON, 5          ; SSPEN=0 (bit 5, disable)
    NOP
    BSF SSPCON, 5          ; SSPEN=1 (re-enable)
    RETURN

INTERRUPT:                 ; Minimal ISR (for master TX, clears flags) *** FIXED: Valid bits only
    ; Optional debug: BSF PORTC, 0; NOP; BCF PORTC, 0
    BANKSEL PIR1
    BTFSS PIR1, 3          ; SSPIF set? (bit 3)
    GOTO CHECK_BCL
    BCF PIR1, 3            ; Clear SSPIF
    ; Clear write collision if set (WCOL bit 7 in SSPCON, Bank 0)
    BANKSEL SSPCON
    BTFSC SSPCON, 7
    BCF SSPCON, 7
    BANKSEL PORTA
    GOTO INT_EXIT

CHECK_BCL:
    BANKSEL PIR2
    BTFSS PIR2, 3          ; BCLIF? (bit 3, bus collision)
    GOTO INT_EXIT
    BCF PIR2, 3
    BANKSEL SSPCON
    BCF SSPCON, 5          ; Disable MSSP
    NOP
    BSF SSPCON, 5          ; Re-enable

INT_EXIT:
    BANKSEL INTCON
    RETFIE

END