;LAB 4
;Jacob Horsley
;RCET
;Fifth Semester
;PIC16F883 Familiarization
;Git URL: https://github.com/horsjaco117/Assembly_Code
       
;Device Setup
;--------------------------------------------------------------------------
;Configuration
    ; CONFIG1
  CONFIG  FOSC = XT   ; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

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

;Bank 3
BSF STATUS, 5 	; Go to Bank 3
BSF STATUS, 6	 ; Go to Bank 3
MOVLW 0X0F	 ;Bits all 1's to set port B as inputs
MOVWF TRISB	 ;Sets all TRISB to 0
CLRF ANSELH	 ; Sets pin function, Digital I/O
CLRF INTCON	;Controls interupts, which are needed for output
CLRF OPTION_REG ;Move w to address 0x81

;Bank 2
BSF STATUS, 6 ;Go to Bank 2
BCF STATUS, 5 ; Go to Bank 2
CLRF CM2CON1  ; Set all bits to 0

;Bank 1
BSF STATUS, 5 ;Sets bit 5 for bank 1
BCF STATUS, 6 ;Clears bit 6 to access bank 1
MOVLW 0XFF    ;Enables all pull up resistors on port B
MOVWF WPUB;  weak pullups
CLRF IOCB; Disables interruption change B
CLRF PSTRCON ;Disables PWM
CLRF TRISC   ;Sets port c as an output
    
;BANK 0
BCF STATUS, 5 ;Clears bit 5 to acces bank 0
BCF STATUS, 6 ;Clears bit 6 to access bank 0
CLRF CCP1CON  ;Disables the other PWM module
CLRF PORTC    ;Clears the port c register
CLRF CCP2CON  ;Disables the second PWM function
CLRF PORTB    ;Clears the bits in portB
CLRF RCSTA    ;Turns of the Control register
CLRF SSPCON   ;Turns off the serial control port
CLRF T1CON    ;Turns off timer control register
    
;Register/Variable setups
     COUNT1 EQU 0x20	;For specific counts in below loops
     COUNT2 EQU 0x21	;For specific counts in below loops
     COUNT3 EQU 0x22	;For specific counts in below loops
     COUNT4 EQU 0X23	;For specific counts in below loops
     COUNT5 EQU 0X24	;For specific counts in below loops
     COUNT6 EQU 0X25	;For specific counts in below loops
     COUNT7 EQU 0X26	;For specific counts in below loops
     
;Main Program Loop (Loops forever)   
MAINLOOP:
HIGH0:				;Nested loop for delay of 5 on display
	    MOVLW 0X59		;89 in decimal
	    MOVWF COUNT3	;References variable
FINALLOOP0:  MOVLW 0X5C		;92 in decimal
	    MOVWF COUNT2	;Reference variable
OUTERLOOP0:  MOVLW 0X13		;19 in decimal
	    MOVWF COUNT1	;Reference variable
INNERLOOP0:  DECFSZ COUNT1	;Decrements the # in count1 until 0 reached
	    GOTO INNERLOOP0	;Goes through inner loop until 0 reached
	    DECFSZ COUNT2	;Decrements the # in count1 until 0 reached
	    GOTO OUTERLOOP0	;Goes through outer loop until 0 reached
	    DECFSZ COUNT3	;Decrements the # in count1 until 0 reached
	    GOTO FINALLOOP0	;Goes through Final loop until 0 reached 
	    
	    Delay1:		;Simple loop for fine tuning delay time
		MOVLW	0X2F	;47 in decimal
		MOVWF	COUNT7	;Moves 47 into the count7 variable
	    LOOPA:		;Simple loop tied to 5 of display
		DECFSZ	COUNT7	;Decrement until count7 equals zero
		GOTO LOOPA	;Goes to loop A until count is zero 
		NOP		;Fine tune 1 microsecond delay
		NOP
	    GOTO DISPLAYHIGH	;Once the delay is passed a 5 displays
	    
LOW0:
	    MOVLW 0X59	    ;91 in decimal
	    MOVWF COUNT6    ;Reference variable
FINALLOOP1:  MOVLW 0X5C	    ;96 in decimal
	    MOVWF COUNT5    ;Reference variable
OUTERLOOP1:  MOVLW 0X13	    ; 19 in decimal
	    MOVWF COUNT4    ;Reference variable
INNERLOOP1:  DECFSZ COUNT4  ;Decrements the # in count1 until 0 reached
	    GOTO INNERLOOP1 ;Goes through the loop until 0 is reached
	    DECFSZ COUNT5   ;Decrements the # in count1 until 0 reached
	    GOTO OUTERLOOP1 ;Goes through the loop until 0 is reached
	    DECFSZ COUNT6   ;Decrements the # in count1 until 0 reached
	    GOTO FINALLOOP1 ;Goes through the loop until 0 is reached
	    
 Delay2:		    ;Simple loop for fine tuning delay time
    MOVLW	0X2F	    ;47 in decimal
    MOVWF	COUNT7	    ;Moves 47 into the count7 variable
LOOPB:			    ;Loop tied to display of low
    DECFSZ	COUNT7	    ;Decrement until count7 equals 0
    GOTO LOOPB		    ;goes to loop A until count is zero
    NOP			    ;Fine tune 1 microsecond delay
    NOP
    GOTO DISPLAYLOW	    ;Once the delay is passed a 0 is displayed
    
DISPLAYHIGH:
    MOVLW 0X05		    ;Hex code for high into register
    MOVWF PORTC		    ;Registers hex code out of port c
    GOTO LOW0		    ;Goes to the low0 loop
    
DISPLAYLOW:
    MOVLW 0X00 ;Stores 0 in register
    MOVWF PORTC;Data from register goes into PortC
    GOTO HIGH0 ;Goes to the high portion of the code   
    
GOTO MAINLOOP
    
INTERRUPT:
    
    
    
    RETFIE
END ;End of code. This is required




