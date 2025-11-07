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
    MOVLW 0x0F ; Set lower 4 bits of PORTB as inputs (your original)
    MOVWF TRISB ; TRISB in bank 3 mirror (0x186)
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
    MOVLW 0x00
    MOVWF PIE1 ; SSPIE=0 (no SSP interrupt)
    MOVLW 0x00
    MOVWF PIE2 ; BCLIE=0 (no bus collision interrupt)
    CLRF SSPCON2 ; Clear all action bits (SEN, RSEN, PEN, etc.)
    CLRF SSPSTAT ; SMP=0 (standard slew), CKE=0 (standard levels)
    MOVLW 0x09 ; SSPADD for 100 kHz @ 4 MHz FOSC: (FOSC/(4*100kHz))-1 = 9
    MOVWF SSPADD ; Adjust if FOSC != 4 MHz (e.g., 8 MHz: 0x13)
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
   
;Register/Variable setups
     COUNT1 EQU 0x20 ;For specific counts in below loops
     COUNT2 EQU 0x21 ;For specific counts in below loops
     COUNT3 EQU 0x22 ;For specific counts in below loops
     COUNT4 EQU 0X23 ;For specific counts in below loops
     COUNT5 EQU 0X24 ;For specific counts in below loops
     COUNT6 EQU 0X25 ;For specific counts in below loops
     COUNT7 EQU 0X26 ;For specific counts in below loops
    
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
  ;  MOVWF PORTC ;Registers hex code out of port c
    GOTO LOW0 ;Goes to the low0 loop
   
DISPLAYLOW:
   ; MOVLW 0X00 ;Stores 0 in register
    ;MOVWF PORTC;Data from register goes into PortC
    CALL I2C_SEND  ; Execute I2C send after each low display (inside the loop)
    GOTO HIGH0 ;Goes to the high portion of the code (keeps blinking infinite)
   
GOTO MAINLOOP  ; Redundant as loop is infinite, but harmless
   
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
    MOVLW 0xA0         ; Slave addr 0x50 <<1 | W (0)
    MOVWF SSPBUF       ; Load into buffer (starts transmit)
    BTFSS PIR1, 3      ; Wait for transmit complete (SSPIF=1)
    GOTO $-1
    BCF PIR1, 3        ; Clear SSPIF
    
    ; Check ACK for Address
    BSF STATUS, 5      ; To Bank 1
    BCF STATUS, 6
    BTFSC SSPCON2, 6   ; ACKSTAT=0? (good ACK)
    GOTO ERROR1        ; Jump to error if NACK
    
    ; Send First Data Byte (0x04)
    BCF STATUS, 5      ; To Bank 0
    BCF STATUS, 6
    MOVLW 0x04         ; Your original data byte
    MOVWF SSPBUF       ; Load (starts transmit)
    BTFSS PIR1, 3      ; Wait for complete
    GOTO $-1
    BCF PIR1, 3        ; Clear SSPIF
    
    ; Check ACK for First Data
    BSF STATUS, 5      ; To Bank 1
    BCF STATUS, 6
    BTFSC SSPCON2, 6   ; ACKSTAT=0?
    GOTO ERROR1
    
    ; Send Second Data Byte (Extra: 0x05) - Repeat Block for More Bytes
    BCF STATUS, 5      ; To Bank 0
    BCF STATUS, 6
    MOVLW 0x05         ; Example extra data (change as needed)
    MOVWF SSPBUF
    BTFSS PIR1, 3
    GOTO $-1
    BCF PIR1, 3
    
    ; Check ACK for Second Data
    BSF STATUS, 5      ; To Bank 1
    BCF STATUS, 6
    BTFSC SSPCON2, 6
    GOTO ERROR1
    
    ; Send Third Data Byte (Extra: 0x06) - Add More Here if Needed
    BCF STATUS, 5      ; To Bank 0
    BCF STATUS, 6
    MOVLW 0x06         ; Another example (expand pattern)
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
   
   
   
    RETFIE
END ;End of code. This is required