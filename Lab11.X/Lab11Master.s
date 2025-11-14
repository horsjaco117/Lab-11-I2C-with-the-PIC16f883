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
; config statements should precede project file includes.
; Include Statements
#include <xc.inc>
; Code Section
;--------------------------------------------------------------------------
  
; Register/Variable Setup
  SOMEVALUE EQU 0x5f ; assign a value to a variable
;---------------------------------------------------------------------
; Reset & Interrupt vectors
;---------------------------------------------------------------------
PSECT resetVect, class=CODE, delta=2
    GOTO Start
PSECT isrVect, class=CODE, delta=2
    GOTO INTERRUPT

Start:
 ; No starting code for this section
Setup:
; Bank 3
    BSF STATUS, 5 ; RP0=1
    BSF STATUS, 6 ; RP1=1, now Bank 3
    MOVLW 0X07  ; Enable analog on AN0, AN1, AN2 (bits 0-2=1)
    MOVWF ANSEL
    CLRF ANSELH  ; Digital I/O for higher pins
    CLRF INTCON  ; Disable interrupts
    CLRF OPTION_REG ; 
; Bank 2
    BCF STATUS, 5 ; RP0=0, now Bank 2 (RP1=1)
    CLRF CM2CON1 ; Disable comparator
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
    MOVLW 0x0F ; Set lower 4 bits of PORTB as inputs
    MOVWF TRISB ; TRISB in bank 3 mirror (0x186)
    MOVLW 0XF0
    MOVWF PR2
    MOVLW 0XC5
    MOVWF ADCON1  ; ADC config: Fosc/32, AN0-AN3 analog, left-justified (ADFM=0 later)
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
    ; ADC Setup: Initial channel AN0, enable ADC, left-justified
    BANKSEL ADCON0
    MOVLW 0x01  ; CHS3:0=0000 (AN0), ADON=1 (bit0)
    MOVWF ADCON0  ; ADC enabled, conversion not started yet
    BANKSEL ADCON1
    BCF ADCON1, 7  ; ADFM=0: Left-justified results (high 8 bits in ADRESH)
    ; Initialize channel table for indirect addressing
    BANKSEL CHANNEL_TABLE
    MOVLW 0x00  ; AN0
    MOVWF CHANNEL_TABLE
    MOVLW 0x01  ; AN1
    MOVWF CHANNEL_TABLE+1
    MOVLW 0x02  ; AN2
    MOVWF CHANNEL_TABLE+2
    
; Register/Variable setups
     COUNT1 EQU 0x20 ; For specific counts in below loops
     COUNT2 EQU 0x21 ; For specific counts in below loops
     COUNT3 EQU 0x22 ; For specific counts in below loops
     COUNT4 EQU 0X23 ; For specific counts in below loops
     COUNT5 EQU 0X24 ; For specific counts in below loops
     COUNT6 EQU 0X25 ; For specific counts in below loops
     COUNT7 EQU 0X26 ; For specific counts in below loops
     W_TEMP EQU 0X2B
     STATUS_TEMP EQU 0X2C
     TEMP EQU 0x2D  ; Temporary register for shifts
     CURRENT_INDEX EQU 0x2E  ; New: Index for cycling through channels (0-2)
     DATA_TO_SEND EQU 0x2F  ; Single ADC value to send (now with LSBs as channel ID)
     CHANNEL_TABLE EQU 0x30  ; New: Base for channel array [0,1,2] for indirect cycle
 
; Main Program Loop (Loops forever)
MAINLOOP:
    ; Use indirect addressing to get current channel from table
    MOVLW CHANNEL_TABLE  ; Base address
    ADDWF CURRENT_INDEX, W  ; Add index (0-2)
    MOVWF FSR  ; FSR = CHANNEL_TABLE + CURRENT_INDEX
    MOVF INDF, W  ; W = channel number (0,1, or 2 via indirect)

    ; Set channel in ADCON0 (CHS3:0 = W)
    BANKSEL ADCON0  ; Bank 0
    MOVWF TEMP  ; Store to TEMP
    RLF TEMP, F  ; TEMP <<=1
    RLF TEMP, W  ; W = TEMP <<=1 (total <<2 for bits 5:2)
    MOVWF TEMP   ; Save shifted
    MOVF ADCON0, W  ; Load current ADCON0
    ANDLW 0xC3   ; Clear bits 5-2 (CHS3:0)
    IORWF TEMP, W  ; OR in the shifted channel
    MOVWF ADCON0  ; Update ADCON0 (preserves GO and ADON)

START_CONV:  ; Start/restart conversion
    BSF ADCON0, 1  ; GO/DONE=1 (bit 1)

    ; Poll for completion
    BANKSEL PIR1  ; Bank 0
    BTFSS PIR1, 6  ; ADIF set?
    GOTO $-1  ; Wait (tight poll for simplicity; add timeout if needed)
    BCF PIR1, 6  ; Clear ADIF

    ; Read high byte (high 8 bits from ADRESH, since left-justified)
    BANKSEL ADRESH  ; Bank 0
    MOVF ADRESH, W
    MOVWF DATA_TO_SEND  ; Store for I2C send
    
    ; Embed channel ID in low 2 LSBs (overwrites ADC bits 1:0; IDs: 1=01b for AD0, 2=10b for AD1, 3=11b for AD2)
    MOVF CURRENT_INDEX, W  ; Load index (0-2)
    ADDLW 0x01             ; W = 1-3 (channel ID)
    IORWF DATA_TO_SEND, F  ; OR into low bits of DATA_TO_SEND (clears nothing?direct OR assumes low bits free or acceptable overwrite)

; Blinking Delays (process one channel per cycle)
HIGH0: ; Nested loop for delay of 5 on display
    MOVLW 0X01 ; 89 in decimal? (original comment; actual cycles ~10x10x10)
    MOVWF COUNT3 ; References variable
FINALLOOP0: 
    MOVLW 0X01 ; 92 in decimal
    MOVWF COUNT2 ; Reference variable
OUTERLOOP0: 
    MOVLW 0X01 ; 19 in decimal
    MOVWF COUNT1 ; Reference variable
INNERLOOP0: 
    DECFSZ COUNT1 ; Decrements the # in count1 until 0 reached
    GOTO INNERLOOP0 ; Goes through inner loop until 0 reached
    DECFSZ COUNT2 ; Decrements the # in count2 until 0 reached
    GOTO OUTERLOOP0 ; Goes through outer loop until 0 reached
    DECFSZ COUNT3 ; Decrements the # in count3 until 0 reached
    GOTO FINALLOOP0 ; Goes through Final loop until 0 reached
  
    CALL Delay1 ; Simple loop for fine tuning delay time
    GOTO LOW0 ; Once the delay is passed a 5 displays (blinking intent)
  
LOW0:
    MOVLW 0X01 ; 91 in decimal
    MOVWF COUNT6 ; Reference variable
FINALLOOP1: 
    MOVLW 0X01 ; 96 in decimal
    MOVWF COUNT5 ; Reference variable
OUTERLOOP1: 
    MOVLW 0X01 ; 19 in decimal
    MOVWF COUNT4 ; Reference variable
INNERLOOP1: 
    DECFSZ COUNT4 ; Decrements the # in count4 until 0 reached
    GOTO INNERLOOP1 ; Goes through the loop until 0 is reached
    DECFSZ COUNT5 ; Decrements the # in count5 until 0 reached
    GOTO OUTERLOOP1 ; Goes through the loop until 0 is reached
    DECFSZ COUNT6 ; Decrements the # in count6 until 0 reached
    GOTO FINALLOOP1 ; Goes through the loop until 0 is reached
  
    CALL Delay2 ; Simple loop for fine tuning delay time
    CALL I2C_SEND ; Execute I2C send with single ADC value (LSBs as channel ID)
  
    ; Cycle to next channel index (mod 3)
    INCF CURRENT_INDEX, F
    MOVF CURRENT_INDEX, W
    SUBLW 0x02  ; W = 2 - CURRENT_INDEX
    BTFSS STATUS, 0  ; Carry set if <=2
    CLRF CURRENT_INDEX  ; Reset to 0 if 3
    GOTO MAINLOOP ; Repeat forever, processing next channel
  
; Delay Subroutines
Delay1: ; Simple loop for fine tuning delay time
    MOVLW 0X10 ; 47 in decimal
    MOVWF COUNT7 ; Moves 47 into the count7 variable
LOOPA: ; Simple loop tied to 5 of display
    DECFSZ COUNT7 ; Decrement until count7 equals zero
    GOTO LOOPA ; Goes to loop A until count is zero
    NOP ; Fine tune 1 microsecond delay
    NOP
    RETURN

Delay2: ; Simple loop for fine tuning delay time
    MOVLW 0X10 ; 47 in decimal
    MOVWF COUNT7 ; Moves 47 into the count7 variable
LOOPB: ; Loop tied to display of low
    DECFSZ COUNT7 ; Decrement until count7 equals 0
    GOTO LOOPB ; Goes to loop B until count is zero
    NOP ; Fine tune 1 microsecond delay
    NOP
    RETURN
  
; Sends I2C (Address + One Data Byte with embedded Channel ID in LSBs)
I2C_SEND:
    ; Check bus idle (in Bank 1)
    BSF STATUS, 5      ; To Bank 1
    BCF STATUS, 6
    BTFSC SSPSTAT, 2   ; If R/W=1 (busy/receive mode), wait
    GOTO $-1
    BSF SSPCON2, 0     ; SEN=1 (start condition)
    BTFSC SSPCON2, 0   ; Wait for start complete (SEN=0)
    GOTO $-1
    
    ; Send Slave Address + Write Bit (0xA0 for 0x50)
    BCF STATUS, 5      ; To Bank 0
    BCF STATUS, 6
    MOVLW 0x40         ; Slave addr 0x50 <<1 | W (0)
    MOVWF SSPBUF       ; Load into buffer (starts transmit)
    BTFSS PIR1, 3      ; Wait for transmit complete (SSPIF=1)
    GOTO $-1
    BCF PIR1, 3        ; Clear SSPIF
    
    ; Check ACK for Address
    BSF STATUS, 5      ; To Bank 1
    BCF STATUS, 6
    BTFSC SSPCON2, 6   ; ACKSTAT=0? (good ACK)
    GOTO ERROR1        ; Jump to error if NACK
    
    ; Send Single Data Byte (ADC value with Channel ID in low 2 bits)
    BCF STATUS, 5      ; To Bank 0
    BCF STATUS, 6
    MOVF DATA_TO_SEND, W  ; Load packed value (ADC high 6 bits + ID low 2 bits)
    MOVWF SSPBUF
    BTFSS PIR1, 3
    GOTO $-1
    BCF PIR1, 3
    
    ; Check ACK for Address
    BSF STATUS, 5      ; To Bank 1
    BCF STATUS, 6
    BTFSC SSPCON2, 6   ; ACKSTAT=0? (good ACK)
    GOTO ERROR1        ; Jump to error if NACK
    
    ; Send Single Data Byte (ADC value with Channel ID in low 2 bits)
    BCF STATUS, 5      ; To Bank 0
    BCF STATUS, 6
    MOVF DATA_TO_SEND, W  ; Load packed value (ADC high 6 bits + ID low 2 bits)
    MOVWF SSPBUF
    BTFSS PIR1, 3
    GOTO $-1
    BCF PIR1, 3
    
    ; Check ACK for Data
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
    ; Simple MSSP Reset
    BCF STATUS, 5      ; Ensure Bank 0
    BCF STATUS, 6
    BCF SSPCON, 5      ; SSPEN=0 (disable)
    BSF SSPCON, 5      ; SSPEN=1 (re-enable)
    RETURN

INTERRUPT:
    RETFIE
END