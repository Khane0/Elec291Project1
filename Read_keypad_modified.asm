; keypad module, modified to include sw input and LCD display
$MODMAX10

	CSEG at 0
	ljmp main_code

	DSEG at 30H
bcd:	ds 5

	CSEG
	
; These 'equ' must match the wiring between the DE10Lite board and the LCD!
; P0 is in connector JPIO.  Check "CV-8052 Soft Processor in the DE10Lite Board: Getting
; Started Guide" for the details.
ELCD_RS equ P1.7
; ELCD_RW equ Px.x ; Not used.  Connected to ground 
ELCD_E  equ P1.1
ELCD_D4 equ P0.7
ELCD_D5 equ P0.5
ELCD_D6 equ P0.3
ELCD_D7 equ P0.1
$NOLIST
$include(LCD_4bit_DE10Lite_no_RW.inc) ; A library of LCD related functions and utility macros

; Look-up table for 7-seg displays
myLUT:
    DB 0xC0, 0xF9, 0xA4, 0xB0, 0x99        ; 0 TO 4
    DB 0x92, 0x82, 0xF8, 0x80, 0x90        ; 5 TO 9
    DB 0x88, 0x83, 0xC6, 0xA1, 0x86, 0x8E  ; A to F

showBCD MAC
	; Display LSD
    mov A, %0
    anl a, #0fh
    movc A, @A+dptr
    mov %1, A
	; Display MSD
    mov A, %0
    swap a
    anl a, #0fh
    movc A, @A+dptr
    mov %2, A
ENDMAC

Display:
	mov dptr, #myLUT
	
	$MESSAGE TIP: If digits 10, 9, 8, and 7 are not zero, LEDR7: on
	lcall ELCD_4BIT ; Configure LCD in four bit mode
    ; For convenience a few handy macros are included in 'LCD_4bit_DE1Lite.inc':
	
	Set_Cursor(1,5)
	;Send_Constant_String(#"Input: ")
	mov A, bcd+4
	add A, #30h
	lcall ?Display_BCD
	mov A, bcd+3
	add A, #30h
	lcall ?Display_BCD
	mov A, bcd+2
	add A, #30h
	lcall ?Display_BCD
	mov A, bcd+1
	add A, #30h
	lcall ?Display_BCD
	mov A, bcd+0
	add A, #30h
	lcall ?Display_BCD
	
	
	;Display_BCD(bcd+4)
    ;Display_BCD(bcd+3)
    ;Display_BCD(bcd+2)
    ;Display_BCD(bcd+1)
    ;isplay_BCD(bcd+0)

    ret
	
;	mov a, bcd+3
;	orl a, bcd+4
;	jz Display_L1
;	setb LEDRA.7 ; Non-zero digits alert
;	sjmp Display_L2
;Display_L1:
;	clr LEDRA.7
;Display_L2:
;
;	$MESSAGE TIP: Pressing KEY3, displays the most significant digits of the 10-digit number
;	
;	jnb key.3, Display_high_digits
;	showBCD(bcd+0, HEX0, HEX1)
;	showBCD(bcd+1, HEX2, HEX3)
;	showBCD(bcd+2, HEX4, HEX5)
;	sjmp Display_end

;Display_high_digits:
;	showBCD(bcd+3, HEX0, HEX1)
;	showBCD(bcd+4, HEX2, HEX3)
;	mov HEX4, #0xff	
;	mov HEX5, #0xff	
	
Display_end:
    ret

MYRLC MAC
	mov a, %0
	rlc a
	mov %0, a
ENDMAC

Shift_Digits_Left:
	mov R0, #4 ; shift left four bits
	; Uncomment the following four lines if you want to limit input to 10 digits
	; mov a, bcd+4
	; anl a, #0xf0
	; jz Shift_Digits_Left_L0
	; ret
Shift_Digits_Left_L0:
	clr c
	MYRLC(bcd+0)
	MYRLC(bcd+1)
	MYRLC(bcd+2)
	MYRLC(bcd+3)
	MYRLC(bcd+4)
	djnz R0, Shift_Digits_Left_L0
	; R7 has the new bcd digit	
	mov a, R7
	orl a, bcd+0
	mov bcd+0, a
	ret
	
MYRRC MAC
	mov a, %0
	rrc a
	mov %0, a
ENDMAC

Shift_Digits_Right:
	mov R0, #4 ; shift right four bits

Shift_Digits_Right_L0:
	clr c
	MYRRC(bcd+4)
	MYRRC(bcd+3)
	MYRRC(bcd+2)
	MYRRC(bcd+1)
	MYRRC(bcd+0)
	djnz R0, Shift_Digits_Right_L0
	ret

Wait25ms:
;33.33MHz, 1 clk per cycle: 0.03us
	mov R0, #15
msL3: mov R1, #74
msL2: mov R2, #250
msL1: djnz R2, msL1 ;3*250*0.03us=22.5us
    djnz R1, msL2 ;74*22.5us=1.665ms
    djnz R0, msL3 ;1.665ms*15=25ms
    ret

CHECK_COLUMN MAC
	jb %0, CHECK_COL_%M
	mov R7, %1
	jnb %0, $ ; wait for key release
	setb c
	ret
CHECK_COL_%M:
ENDMAC

Configure_Keypad_Pins:
	; Configure the row pins as output and the column pins as inputs
	orl P1MOD, #0b_01010100 ; P1.6, P1.4, P1.2 output
	orl P2MOD, #0b_00000001 ; P2.0 output
	anl P2MOD, #0b_10101011 ; P2.6, P2.4, P2.2 input
	anl P3MOD, #0b_11111110 ; P3.0 input
	ret

; These are the pins used for the keypad in this program:
ROW1 EQU P1.2
ROW2 EQU P1.4
ROW3 EQU P1.6
ROw4 EQU P2.0
COL1 EQU P2.2
COL2 EQU P2.4
COL3 EQU P2.6
COL4 EQU P3.0

; This subroutine scans a 4x4 keypad.  If a key is pressed sets the carry
; to one and returns the key code in register R7.
; It works with both a default keypad or a modified keypad with the labels
; rotated 90 deg ccw.  The type of keypad is determined by SW0, which is bit SWA.0
Keypad:
	; First check the backspace/correction pushbutton.  We use KEY1 for this function.
	$MESSAGE TIP: KEY1 is the erase key
	jb KEY.1, keypad_L0
	lcall Wait25ms ; debounce
	jb KEY.1, keypad_L0
	jnb KEY.1, $ ; The key was pressed, wait for release
	lcall Shift_Digits_Right
	clr c
	ret
	
keypad_L0:
	; Make all the rows zero.  If any column is zero then a key is pressed.
	clr ROW1
	clr ROW2
	clr ROW3
	clr ROW4
	mov c, COL1
	anl c, COL2
	anl c, COL3
	anl c, COL4
	jnc Keypad_Debounce
	clr c
	ret
		
Keypad_Debounce:
	; A key maybe pressed.  Wait and check again to discard bounces.
	lcall Wait25ms ; debounce
	mov c, COL1
	anl c, COL2
	anl c, COL3
	anl c, COL4
	jnc Keypad_Key_Code
	clr c
	ret
	
Keypad_Key_Code:	
	; A key is pressed.  Find out which one by checking each possible column and row combination.

	setb ROW1
	setb ROW2
	setb ROW3
	setb ROW4
	
	$MESSAGE TIP: SW0 is used to control the layout of the keypad. SW0=0: unmodified keypad. SW0=1: keypad rotated 90 deg CCW

	jnb SWA.0, keypad_default
	ljmp keypad_90deg
	
	; This check section is for an un-modified keypad
keypad_default:	
	; Check row 1	
	clr ROW1
	CHECK_COLUMN(COL1, #01H)
	CHECK_COLUMN(COL2, #02H)
	CHECK_COLUMN(COL3, #03H)
	CHECK_COLUMN(COL4, #0AH)
	setb ROW1

	; Check row 2	
	clr ROW2
	CHECK_COLUMN(COL1, #04H)
	CHECK_COLUMN(COL2, #05H)
	CHECK_COLUMN(COL3, #06H)
	CHECK_COLUMN(COL4, #0BH)
	setb ROW2

	; Check row 3	
	clr ROW3
	CHECK_COLUMN(COL1, #07H)
	CHECK_COLUMN(COL2, #08H)
	CHECK_COLUMN(COL3, #09H)
	CHECK_COLUMN(COL4, #0CH)
	setb ROW3

	; Check row 4	
	clr ROW4
	CHECK_COLUMN(COL1, #0EH)
	CHECK_COLUMN(COL2, #00H)
	CHECK_COLUMN(COL3, #0FH)
	CHECK_COLUMN(COL4, #0DH)
	setb ROW4

	clr c
	ret
	
	; This check section is for a keypad with the labels rotated 90 deg ccw
keypad_90deg:
	; Check row 1	
	clr ROW1
	CHECK_COLUMN(COL1, #0AH)
	CHECK_COLUMN(COL2, #0BH)
	CHECK_COLUMN(COL3, #0CH)
	CHECK_COLUMN(COL4, #0DH)
	setb ROW1

	; Check row 2	
	clr ROW2
	CHECK_COLUMN(COL1, #03H)
	CHECK_COLUMN(COL2, #06H)
	CHECK_COLUMN(COL3, #09H)
	CHECK_COLUMN(COL4, #0FH)
	setb ROW2

	; Check row 3	
	clr ROW3
	CHECK_COLUMN(COL1, #02H)
	CHECK_COLUMN(COL2, #05H)
	CHECK_COLUMN(COL3, #08H)
	CHECK_COLUMN(COL4, #00H)
	setb ROW3

	; Check row 4	
	clr ROW4
	CHECK_COLUMN(COL1, #01H)
	CHECK_COLUMN(COL2, #04H)
	CHECK_COLUMN(COL3, #07H)
	CHECK_COLUMN(COL4, #0EH)
	setb ROW4

	clr c
	ret
	
main_code:
	mov SP, #7FH
	clr a
	mov LEDRA, a
	mov LEDRB, a
	mov bcd+0, a
	mov bcd+1, a
	mov bcd+2, a
	mov bcd+3, a
	mov bcd+4, a
	lcall Configure_Keypad_Pins

forever:

	; modify so we have a check sw routine (sw can be treated like bits w/ jb type instructions)
	; use four of our switches to modify profiles (reflow temp, soak temp, reflow time interval, soak time interval)
	; run check to make sure only one setting is selected, display invalid if multiple are
	; display profiles / which profile is being modified
	; save keyboard inputs as variables 
	; define a START button, STOP button (maybe not in this module, but somewhere idk)
	; KEY 1 is already defined as the backspace button btw 
	; I feel like we might run out of display space for everything, so we might need to discuss that but I have some ideas
	; (display switches OR multiple LCD OR something else?)

	lcall Keypad
	lcall Display
	jnc forever
	lcall Shift_Digits_Left
	ljmp forever
	
end
