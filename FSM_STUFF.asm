;$NOLIST
;$MODN76E003
;$LIST
$MODDE1SOC

;  N76E003 pinout:
;                               -------
;       PWM2/IC6/T0/AIN4/P0.5 -|1    20|- P0.4/AIN5/STADC/PWM3/IC3
;               TXD/AIN3/P0.6 -|2    19|- P0.3/PWM5/IC5/AIN6
;               RXD/AIN2/P0.7 -|3    18|- P0.2/ICPCK/OCDCK/RXD_1/[SCL]
;                    RST/P2.0 -|4    17|- P0.1/PWM4/IC4/MISO
;        INT0/OSCIN/AIN1/P3.0 -|5    16|- P0.0/PWM3/IC3/MOSI/T1
;              INT1/AIN0/P1.7 -|6    15|- P1.0/PWM2/IC2/SPCLK
;                         GND -|7    14|- P1.1/PWM1/IC1/AIN7/CLO
;[SDA]/TXD_1/ICPDA/OCDDA/P1.6 -|8    13|- P1.2/PWM0/IC0
;                         VDD -|9    12|- P1.3/SCL/[STADC]
;            PWM5/IC7/SS/P1.5 -|10   11|- P1.4/SDA/FB/PWM1
;                               -------
;

CLK           EQU 33333333 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/(12*TIMER0_RATE)))) ; The prescaler in the CV-8052 is 12 unlike the AT89LP51RC2 where is 1.
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/(12*TIMER2_RATE))))

OVEN_POWER  			equ P1.1

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
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR
	
dseg at 0x30
Count1ms:     ds 2 ; Used to determine when one second has passed
Time_Secs:  ds 1 
Soak_Temp: ds 1
Soak_Time: ds 1
Reflow_Temp: ds 1
Reflow_Time: ds 1
Stop_Temp: ds 1
Temp_Read: ds 1
bcd: ds 5
x:   ds 4
y:   ds 4


bseg
seconds_flag: dbit 1 ; Set to one in the ISR every time 1000 ms had passed
phase_one_flag: dbit 1
phase_two_flag: dbit 1
phase_three_flag: dbit 1
phase_four_flag: dbit 1
oven_on_flag: dbit 1
mf: dbit 1

$NOLIST
$include(math32.inc)
$LIST

cseg
; These 'equ' must match the hardware wiring
;LCD_RS equ P1.3
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
;LCD_E  equ P1.4
;LCD_D4 equ P0.0
;LCD_D5 equ P0.1
;LCD_D6 equ P0.2
;LCD_D7 equ P0.3



;$NOLIST
;$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
;$LIST
keypad_module:
	


Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	mov RCAP2H, #high(TIMER2_RELOAD)
	mov RCAP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
    setb ET2  ; Enable timer 2 interrupt
    setb TR2  ; Enable timer 2
	ret
	
Timer2_ISR:
	clr TF2
	
	push acc
	push psw
	
	inc Count1ms+0
	mov a, Count1ms+0
	jnz Inc_Done
	inc Count1ms+1
	
Inc_Done:
	mov a, Count1ms+0
	cjne a, #low(1000), Timer2_ISR_done
	mov a, Count1ms+1
	cjne a, #high(1000), Timer2_ISR_done
	
	setb seconds_flag
	
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	mov a, Time_Secs
	add a, #0x01

Timer2_ISR_da:
	da a
	mov Time_Secs, a
	jnb oven_on_flag, Timer2_ISR_done
	
	
Timer2_ISR_done:
	pop psw
	pop acc
Timer2_ISR_skip:
	reti
	
T_7seg:
    DB 40H, 79H, 24H, 30H, 19H, 12H, 02H, 78H, 00H, 10H

; Displays a BCD number in HEX1-HEX0
Display_BCD_7_Seg:
	
	mov dptr, #T_7seg

	mov a, Time_Secs
	swap a
	anl a, #0FH
	movc a, @a+dptr
	mov HEX1, a
	
	mov a, Time_Secs
	anl a, #0FH
	movc a, @a+dptr
	mov HEX0, a
	
	ret
	
main:
	mov SP, #0x7F
    lcall Timer2_Init
    ; We use the pins of P0 to control the LCD.  Configure as outputs.
    mov P0MOD, #01111111b ; P0.0 to P0.6 are outputs.  ('1' makes the pin output)
    ; We use pins P1.0 and P1.1 as outputs also.  Configure accordingly.
    mov P1MOD, #00000011b ; P1.0 and P1.1 are outputs
    ; Turn off all the LEDs
    mov LEDRA, #0 ; LEDRA is bit addressable
    mov LEDRB, #0 ; LEDRB is NOT bit addresable
    setb EA   ; Enable Global interrupts
    setb seconds_flag
	mov Time_Secs, #0x00 ; Initialize counter to zero
	;mov Soak_Time, #0x10
	
settings_loop:
	jnb key.1, settings_state
	Wait_Milli_Seconds(#50)
	jnb key.1, settings_state
	setb phase_one_flag
	Load_X(Soak_Temp)
	Load_y(20)
	lcall sub32
	mov Stop_Temp, x
	Load_y(Stop_Temp)
	setb OVEN_POWER
	setb oven_on_flag
	ljmp check_stop
settings_state:
	jnb seconds_flag, settings_loop
	clr seconds_flag
	lcall keypad_module
	lcall seven_seg_module
	
	
END