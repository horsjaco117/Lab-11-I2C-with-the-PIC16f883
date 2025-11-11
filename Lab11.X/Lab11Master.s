;LAB 11
;Jacob Horsley
;RCET 3375
;Fifth Semester
;I2C Communication (Master)
;Git URL: https://github.com/horsjaco117/Assembly_Code
     
;Device Setup
;--------------------------------------------------------------------------
;Configuration
    ; CONFIG1
  CONFIG FOSC = XT ; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
  CONFIG WDTE = OFF ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG PWRTE = OFF ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG MCLRE = ON ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG CP = OFF ; Code Protection bit (Program memory code protection is disabled)
  CONFIG CPD = OFF ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG BOREN = OFF ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG IESO = OFF ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG FCMEN = OFF ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG LVP = OFF ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)
; CONFIG2
  CONFIG BOR4V = BOR40V ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG WRT = OFF ; Flash Program Memory Self Write Enable bits (Write protection off)
// config statements should precede project file includes.
;Include Statements
#include <xc.inc>
;Code Section
;--------------------------------------------------------------------------
  
;Register/Variable Setup
  SOMEVALUE EQU 0x5f ;assign a value to a variable
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
    BSF STATUS, 5 ; RP0=1
    BSF STATUS, 6 ; RP1=1, now Bank 3
   MOVLW 0X02
   MOVWF ANSEL
    CLRF ANSELH ; Digital I/O for higher pins
    CLRF INTCON ; Disable interrupts (your original)
    CLRF OPTION_REG ; Your original
; Bank 2
    BCF STATUS, 5 ; RP0=0, now Bank 2 (RP1=1)
    CLRF CM2CON1 ; Your original (assuming comparator disable)
; Bank 1
    BSF STATUS, 5 ; RP0=1, now Bank 1 (RP1=0)
    BCF STATUS, 6 ; RP1=0
    MOVLW 0xFF ; Enable weak pull-ups on PORTB
    MOVWF WPUB
    CLRF IOCB ; Disable interrupt-on-change for PORTB
    CLRF PSTRCON ; Disable PWM steering
    MOVLW 0x18 ; Set TRISC: bits 3 (SCL) and 4 (SDA) to 1 for I2C, others 0 (outputs)
    MOVWF TRISC ; Critical for I2C pin control
    MOVLW 0x42
    MOVWF PIE1 ; SSPIE=0 (no SSP interrupt)
    MOVLW 0x00
    MOVWF PIE2 ; BCLIE=0 (no bus collision interrupt)
    CLRF SSPCON2 ; Clear all action bits (SEN, RSEN, PEN, etc.)
    CLRF SSPSTAT ; SMP=0 (standard slew), CKE=0 (standard levels)
    MOVLW 0x09 ; SSPADD for 100 kHz @ 4 MHz FOSC: (FOSC/(4*100kHz))-1 = 9
    MOVWF SSPADD ; Adjust if FOSC != 4 MHz (e.g., 8 MHz: 0x13)
     MOVLW 0x0F ; Set lower 4 bits of PORTB as inputs (your original)
    MOVWF TRISB ; TRISB in bank 3 mirror (0x186)
    MOVLW 0XF0
    MOVWF PR2
    MOVLW 0XC5
    MOVWF ADCON1
; Bank 0
    BCF STATUS, 5 ; RP0=0
    BCF STATUS, 6 ; RP1=0, now Bank 0
    CLRF CCP1CON ; Disable PWM1
    CLRF PORTC ; Clear PORTC
    CLRF CCP2CON ; Disable PWM2
    CLRF PORTB ; Clear PORTB
    CLRF RCSTA ; Disable USART
    CLRF T1CON ; Disable Timer1
    CLRF INTCON ; GIE=0, PEIE=0
    CLRF PIR1 ; Clear SSPIF
    CLRF PIR2 ; Clear BCLIF
    MOVLW 0x28 ; SSPCON: SSPEN=1 (enable last), CKP=0 (don't-care), SSPM=1000 (I2C master)
    MOVWF SSPCON
    BSF ADCON0, 1
    
    BANKSEL ADCON1
    BCF ADCON1, 7
  
;Register/Variable setups
     COUNT1 EQU 0x20 ;For specific counts in below loops
     COUNT2 EQU 0x21 ;For specific counts in below loops
     COUNT3 EQU 0x22 ;For specific counts in below loops
     COUNT4 EQU 0X23 ;For specific counts in below loops
     COUNT5 EQU 0X24 ;For specific counts in below loops
     COUNT6 EQU 0X25 ;For specific counts in below loops
     COUNT7 EQU 0X26 ;For specific counts in below loops
     RESULT_HI EQU 0X27
     RESULT_LO EQU 0X28
     ADC_CONTINUOUS EQU 0X29
     ADC_DATA EQU 0X2A
     W_TEMP EQU 0X2B
     STATUS_TEMP EQU 0X2C
     ADC_GO EQU 0X2D
 
;Main Program Loop (Loops forever)
MAINLOOP:
    
HIGH0: ;Nested loop for delay of 5 on display
    MOVLW 0X10 ;89 in decimal
    MOVWF COUNT3 ;References variable
FINALLOOP0: MOVLW 0X10 ;92 in decimal
    MOVWF COUNT2 ;Reference variable
OUTERLOOP0: MOVLW 0X10 ;19 in decimal
    MOVWF COUNT1 ;Reference variable
INNERLOOP0: DECFSZ COUNT1 ;Decrements the # in count1 until 0 reached
    GOTO INNERLOOP0 ;Goes through inner loop until 0 reached
    DECFSZ COUNT2 ;Decrements the # in count1 until 0 reached
    GOTO OUTERLOOP0 ;Goes through outer loop until 0 reached
    DECFSZ COUNT3 ;Decrements the # in count1 until 0 reached
    GOTO FINALLOOP0 ;Goes through Final loop until 0 reached
  
    Delay1: ;Simple loop for fine tuning delay time
MOVLW 0X10 ;47 in decimal
MOVWF COUNT7 ;Moves 47 into the count7 variable
    LOOPA: ;Simple loop tied to 5 of display
DECFSZ COUNT7 ;Decrement until count7 equals zero
GOTO LOOPA ;Goes to loop A until count is zero
NOP ;Fine tune 1 microsecond delay
NOP
    GOTO DISPLAYHIGH ;Once the delay is passed a 5 displays
  
LOW0:
    MOVLW 0X10 ;91 in decimal
    MOVWF COUNT6 ;Reference variable
FINALLOOP1: MOVLW 0X5C ;96 in decimal
    MOVWF COUNT5 ;Reference variable
OUTERLOOP1: MOVLW 0X13 ; 19 in decimal
    MOVWF COUNT4 ;Reference variable
INNERLOOP1: DECFSZ COUNT4 ;Decrements the # in count1 until 0 reached
    GOTO INNERLOOP1 ;Goes through the loop until 0 is reached
    DECFSZ COUNT5 ;Decrements the # in count1 until 0 reached
    GOTO OUTERLOOP1 ;Goes through the loop until 0 is reached
    DECFSZ COUNT6 ;Decrements the # in count1 until 0 reached
    GOTO FINALLOOP1 ;Goes through the loop until 0 is reached
  
 Delay2: ;Simple loop for fine tuning delay time
    MOVLW 0X10 ;47 in decimal
    MOVWF COUNT7 ;Moves 47 into the count7 variable
LOOPB: ;Loop tied to display of low
    DECFSZ COUNT7 ;Decrement until count7 equals 0
    GOTO LOOPB ;goes to loop A until count is zero
    NOP ;Fine tune 1 microsecond delay
    NOP
    GOTO DISPLAYLOW ;Once the delay is passed a 0 is displayed
  
DISPLAYHIGH:
   ; MOVLW 0X05 ;Hex code for high into register
  ; MOVWF PORTC ;Registers hex code out of port c
    GOTO LOW0 ;Goes to the low0 loop
  
DISPLAYLOW:
   ; MOVLW 0X00 ;Stores 0 in register
    ;MOVWF PORTC;Data from register goes into PortC
    CALL I2C_SEND ; Execute I2C send after each low display (inside the loop)
    GOTO HIGH0 ;Goes to the high portion of the code (keeps blinking infinite)
  
GOTO MAINLOOP ; Redundant as loop is infinite, but harmless
  
; Sends I2C
; Sends I2C (Multi-Byte Write Example)
I2C_SEND:
    ; Check bus idle (in Bank 1)
    BSF STATUS, 5      ; To Bank 1
    BCF STATUS, 6
    BTFSC SSPSTAT, 2   ; If R/W=1 (busy/receive mode), wait
    GOTO $-1
    BSF SSPCON2, 0     ; SEN=1 (start condition)
    BTFSC SSPCON2, 0   ; Wait for start complete (SEN=0)
    GOTO $-1
    
    ; Send Slave Address + Write Bit (0xA0)
    BCF STATUS, 5      ; To Bank 0
    BCF STATUS, 6
    MOVLW 0x40        ; Slave addr 0x50 <<1 | W (0)
    MOVWF SSPBUF       ; Load into buffer (starts transmit)
    BTFSS PIR1, 3      ; Wait for transmit complete (SSPIF=1)
    GOTO $-1
    BCF PIR1, 3        ; Clear SSPIF
    
    ; Check ACK for Address
    BSF STATUS, 5      ; To Bank 1
    BCF STATUS, 6
    BTFSC SSPCON2, 6   ; ACKSTAT=0? (good ACK)
    GOTO ERROR1        ; Jump to error if NACK
    
    ; Send  Data Byte (Extra: 0x05) - Repeat Block for More Bytes
    BCF STATUS, 5      ; To Bank 0
    BCF STATUS, 6
    MOVLW 0x03        ; Example extra data (change as needed)
    MOVWF SSPBUF
    BTFSS PIR1, 3
    GOTO $-1
    BCF PIR1, 3
    
    ; Check ACK for Second Data
    BSF STATUS, 5      ; To Bank 1
    BCF STATUS, 6
    BTFSC SSPCON2, 6
    GOTO ERROR1
    
    ; Send  Data Byte (Extra: 0x06) - Add More Here if Needed
    BCF STATUS, 5      ; To Bank 0
    BCF STATUS, 6
  ;  MOVLW 0x06  ; Another example (expand pattern)
    MOVF ADC_GO, W
    MOVWF SSPBUF
    BTFSS PIR1, 3
    GOTO $-1
    BCF PIR1, 3
    
    ; Check ACK for Third Data
    BSF STATUS, 5      ; To Bank 1
    BCF STATUS, 6
    BTFSC SSPCON2, 6
    GOTO ERROR1
    
    ; Stop Condition (Ends Transaction)
    BSF SSPCON2, 2     ; PEN=1
    BTFSC SSPCON2, 2   ; Wait for stop complete (PEN=0)
    GOTO $-1
    
    BCF STATUS, 5      ; Back to Bank 0 (good practice)
    BCF STATUS, 6
    RETURN

ERROR1:
    ; Simple MSSP Reset (Your Original)
    BCF STATUS, 5      ; Ensure Bank 0
    BCF STATUS, 6
    BCF SSPCON, 5      ; SSPEN=0 (disable)
    BSF SSPCON, 5      ; SSPEN=1 (re-enable)
    RETURN
  
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
    MOVF ADC_GO, W ; Store (overwrites: 0x04 ? 0x05 ? 0x06)
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
END ;End of code. This is required