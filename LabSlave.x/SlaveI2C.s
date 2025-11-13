;LAB 11 - Slave (Polling Version)
;Jacob Horsley
;RCET 3375
;Fifth Semester
;I2C Communication (Slave - Polling Mode)
;Git URL: https://github.com/horsjaco117/Assembly_Code
     
;Device Setup
;--------------------------------------------------------------------------
;Configuration (unchanged)
    ; CONFIG1
  CONFIG FOSC = HS
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
    GOTO INTERRUPT  ; ISR now just returns (polling mode)
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
    ; Note: PIE1 and PIE2 still set for flags, but interrupts disabled below
    MOVLW 0x08
    MOVWF PIE1 ; SSPIE=1 (enables flag, but no IRQ)
    MOVLW 0x08
    MOVWF PIE2 ; BCLIE=1 (enables flag, but no IRQ)
    CLRF SSPCON2
    MOVLW 0x80
    MOVWF SSPSTAT ; SMP=1, CKE=0
    MOVLW 0x40
    MOVWF SSPADD ; Address 0x50 <<1
    MOVLW 0XF0
    MOVWF PR2
; Bank 0
    BCF STATUS, 5
    BCF STATUS, 6
    MOVLW 0X7E
    MOVWF T2CON
    CLRF CCP1CON
    CLRF PORTC
    CLRF CCP2CON
    CLRF PORTB
    CLRF RCSTA
    CLRF T1CON
    CLRF PIR1
    CLRF PIR2
    ; Changed: Disable GIE/PEIE for polling mode
    MOVLW 0x00
    MOVWF INTCON ; GIE=0, PEIE=0 (no interrupts)
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
    W_TEMP EQU 0X21
    STATUS_TEMP EQU 0X22
    TIMER_COUNT EQU 0X23
    PR2_PulseWidth EQU 0X24
    PR2_PulseSpace EQU 0X25
    PulseSelect EQU 0X26
     COUNT7 EQU 0X26
   
;Main Program Loop (modified for polling)
MAINLOOP:

COMM_START:
    MOVF RECEIVED_DATA, W
    MOVWF PORTB          ; Display last RX byte on PORTB (binary)
    ; MOVWF PORTC       ; Uncomment if also show on PORTC
    
    ; Polling Logic: Moved from ISR - Check I2C flags here (after display for timing)
    BTFSS PIR1, 3 ; SSPIF set? (I2C activity)
    GOTO CHECK_BCL_POLL
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
    GOTO READ_DATA_POLL
    ; Address phase (D/A=0): Just ACK, discard value
    BCF STATUS, 5 ; Bank 0
    BCF STATUS, 6
    MOVF SSPBUF, W ; Read to clear BF ? generates ACK
    ; No store?address ignored
    GOTO POLL_EXIT
READ_DATA_POLL:
    BCF STATUS, 5 ; Bank 0
    BCF STATUS, 6
    MOVF SSPBUF, W ; Read data ? clears BF, auto-ACK
    MOVWF RECEIVED_DATA ; Store (overwrites: 0x04 ? 0x05 ? 0x06)
    ; Debug: Count data bytes received
    BTFSC COUNT1, 0 ; First data byte?
    GOTO SECOND_DATA_POLL
    BSF PORTC, 1 ; Toggle RC1 for 0x04 (first data)
    NOP
    BCF PORTC, 1
    INCF COUNT1, F ; COUNT1=2 now
    GOTO POLL_EXIT
SECOND_DATA_POLL:
    BSF PORTC, 2 ; Toggle RC2 for 0x05+ (subsequent)
    NOP
    BCF PORTC, 2
    GOTO POLL_EXIT
    ; Slave read mode (R/W=1, master requesting data from us?not your current case)
    ; BTFSC SSPSTAT, 2 ; If expanding: Test R/W=1 here
SLAVE_READ_PLACEHOLDER_POLL:
    MOVLW 0x40 ; Example: Load dummy response to SSPBUF
    MOVWF SSPBUF ; (Master will read this next)
    GOTO POLL_EXIT
CHECK_BCL_POLL:
    BTFSS PIR2, 3 ; BCLIF? (Bus collision?rare in sim)
    GOTO POLL_EXIT
    BCF PIR2, 3
    BCF SSPCON, 5 ; Disable/re-enable MSSP
    BSF SSPCON, 5
POLL_EXIT:
    ; End of polling - resume main loop
    
GOTO MAINLOOP
  
; Simplified ISR (just returns, since polling)
INTERRUPT:
        MOVWF W_TEMP
    SWAPF STATUS, W
    MOVWF STATUS_TEMP
    
   
HANDLE_SERVO:
    DECFSZ TIMER_COUNT, F
    GOTO INTERRUPT_END
   
    ;SEARCHING FOR THE RIGHT BITS
    BTFSC PORTB,7
    GOTO Bx1UUU
    BTFSC PORTB,6
    GOTO Bx01UU
    BTFSC PORTB,5
    GOTO Bx001U
    BTFSC PORTB,4
    GOTO Bx0001
    GOTO Bx0000
   
Bx1UUU:
    BTFSC PORTB,6
    GOTO Bx11UU
    BTFSC PORTB,5
    GOTO Bx101U
    BTFSC PORTB,4
    GOTO Bx1001
    GOTO Bx1000
   
Bx11UU:
    BTFSC PORTB,5
    GOTO Bx111U
    BTFSC PORTB,4
    GOTO Bx1101
    GOTO Bx1100
   
Bx101U:
    BTFSC PORTB,4
    GOTO Bx1011
    GOTO Bx1010
   
Bx111U:
    BTFSC PORTB,4
    GOTO Bx1111
    GOTO Bx1110
   
Bx01UU:
    BTFSC PORTB,5
    GOTO Bx011U
    BTFSC PORTB,4
    GOTO Bx0101
    GOTO Bx0100
   
Bx011U:
    BTFSC PORTB,4
    GOTO Bx0111
    GOTO Bx0110
   
Bx001U:
    BTFSC PORTB,4
    GOTO Bx0011
    GOTO Bx0010
   
;SETTING THE RIGHT TIMES FOR THE SELECTED BITS
Bx0000:
    MOVLW 0x4D
    MOVWF PR2_PulseWidth
    MOVLW 0xB9
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
Bx0001:
    MOVLW 0x52
    MOVWF PR2_PulseWidth
    MOVLW 0xB8
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
Bx0010:
    MOVLW 0x57
    MOVWF PR2_PulseWidth
    MOVLW 0xB7
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
Bx0011:
    MOVLW 0x5D
    MOVWF PR2_PulseWidth
    MOVLW 0xB7
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
Bx0100:
    MOVLW 0x62
    MOVWF PR2_PulseWidth
    MOVLW 0xB6
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
Bx0101:
    MOVLW 0x67
    MOVWF PR2_PulseWidth
    MOVLW 0xB5
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
Bx0110:
    MOVLW 0x6C
    MOVWF PR2_PulseWidth
    MOVLW 0xB5
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
Bx0111:
    MOVLW 0x71
    MOVWF PR2_PulseWidth
    MOVLW 0xB4
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
Bx1000:
    MOVLW 0x77
    MOVWF PR2_PulseWidth
    MOVLW 0xB3
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
Bx1001:
    MOVLW 0x7C
    MOVWF PR2_PulseWidth
    MOVLW 0xB3
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
Bx1010:
    MOVLW 0x81
    MOVWF PR2_PulseWidth
    MOVLW 0xB2
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
Bx1011:
    MOVLW 0x86
    MOVWF PR2_PulseWidth
    MOVLW 0xB1
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
Bx1100:
    MOVLW 0x8B
    MOVWF PR2_PulseWidth
    MOVLW 0xB1
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
Bx1101:
    MOVLW 0x91
    MOVWF PR2_PulseWidth
    MOVLW 0xB0
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
Bx1110:
    MOVLW 0x96
    MOVWF PR2_PulseWidth
    MOVLW 0xAF
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
Bx1111:
    MOVLW 0x9B
    MOVWF PR2_PulseWidth
    MOVLW 0xAF
    MOVWF PR2_PulseSpace
    BTFSC PulseSelect, 0
    GOTO PulseWidthTime
    GOTO PulseSpaceTime
   
PulseWidthTime:
    MOVF PR2_PulseWidth,0
    BSF STATUS,5
    MOVWF PR2
    BCF STATUS,5
    MOVLW 0x01
    MOVWF TIMER_COUNT
    BSF PORTA,1
    BCF PulseSelect, 0
    MOVLW 0x7D
    MOVWF T2CON
    GOTO INTERRUPT_END
   
PulseSpaceTime:
    MOVF PR2_PulseSpace,0
    BSF STATUS,5
    MOVWF PR2
    BCF STATUS,5
    MOVLW 0x02
    MOVWF TIMER_COUNT
    BCF PORTA,1
    BSF PulseSelect, 0
    MOVLW 0x7E
    MOVWF T2CON
    GOTO INTERRUPT_END
   
INTERRUPT_END:
    BCF PIR1,1 ;Clears TMR2 to PR2 Interrupt Flag
    CLRF TMR2 ;Clears TMR2
    SWAPF STATUS_TEMP, W
    MOVWF STATUS
    SWAPF W_TEMP, F
    SWAPF W_TEMP, W
    RETFIE ; Immediate return - no interrupt handling
END