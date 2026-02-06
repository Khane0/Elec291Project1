$MODMAX10

; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
;org 0x000B
	;ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
	
dseg at 0x30
;These variable will be stored in BCD format. They need to be displayed in each corner of the LCD in state zero
;None of these will be set by the LCD, just printed. So for testing purposes, you can probably set them to some constant values
Soak_Temp: ds 4
Soak_Time: ds 4
Reflow_Temp: ds 4
Reflow_Time: ds 4
;Time elapsed also in BCD format needs to be displayed in all states except state zero.
Time_Elapsed: ds 4
;Temperature is printed on the seven seg, not LCD

;Print different things based on the state we are in. State is set by the main module and not modified by LCD.
;Use push buttons or switches for debugging/testing different states.
State_flag: ds 1 ;states will probably be numbers 0-5

bcd: ds 4
x:   ds 4
y:   ds 4

bseg

oven_on_flag: dbit 1

cseg
;Here are some pins that I copy and pasted from one of joses example asm files. You might have to change these. I am not sure.
;Ask for a picture of my circuit if you need some help setting it up or look through jose examples
ELCD_RS equ P1.7
;ELCD_RW equ Px.x ; Not used.  Connected to ground. Double check this please; this one is assigned to a pin in one of jose examples.
ELCD_E  equ P1.1
ELCD_D4 equ P0.7
ELCD_D5 equ P0.5
ELCD_D6 equ P0.3
ELCD_D7 equ P0.1

$NOLIST
;One includes the ELCD_RW and one doesn't. We were having issues when using the no_RW, so it might be worth experimenting with both
;$include(LCD_4bit_DE10Lite.inc)
$include(LCD_4bit_DE10Lite_no_RW.inc)
$LIST

LCD_print:

main: ; This should just be for initiallizing things
	mov SP, #0x7F
	lcall ELCD_4BIT ; Configure LCD in four bit mode
testing_loop: ;Try to keep the amount of instructions in the loop minimal and easy to remove instructions that you use only for testing purposes
	lcall LCD_print
	sjmp testing_loop

END