$MODDE1SOC

CLK           EQU 33333333 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/(12*TIMER0_RATE)))) ; The prescaler in the CV-8052 is 12 unlike the AT89LP51RC2 where is 1.
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/(12*TIMER2_RATE))))

OVEN_POWER  			equ P1.1 ; Pin to turn the SSR on/off

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
;Time_Secs keeps track of time in seconds
Time_Secs:  ds 4
Seconds_Bin: ds 4 
;Four below should be set by the keypad subroutine/s to be used in the other subroutines
;I'm worried we might need to convert things from 1 byte to 4 bytes in some cases, but we can test that
Soak_Temp_Bin: ds 4
Soak_Time_Bin: ds 4
Reflow_Temp_Bin: ds 4
Reflow_Time_Bin: ds 4
;Stop_Temp, Flat_Time, and Hold_Time are used in FSM to start/stop oven power
;at certain times. Ex. We set Soak_Time = 60 s, then Hold_Time = Current Time + Soak_Time
;as I am writing this, I realize Flat_Time and Hold_Time are probably interchangable and we only need one
Stop_Temp_Bin: ds 4
Flat_Time_Bin: ds 4
Hold_Time_Bin: ds 4
Current_Temp_Bin: ds 4
; Math.inc stuff
bcd: ds 5
x:   ds 4
y:   ds 4


bseg
seconds_flag: dbit 1 ; Set to one in the ISR every time 1000 ms had passed
;The four phase flags can be replace by a single thing that we increment between phases.
phase_one_flag: dbit 1 ; Set to one when start button pressed, zero when oven has reached Stop_Temp = Soak_Temp - 20
phase_two_flag: dbit 1 ; Set to one when oven reaches Stop_Temp, zero when Soak_Time has passed
phase_three_flag: dbit 1 ; Set to one when Soak_Time has passed, zero when oven has reached Stop_Temp = Reflow_Temp - 20
phase_four_flag: dbit 1 ; Set to one when oven reaches Stop_Temp, zero when Reflow_Time has passed
oven_on_flag: dbit 1 ; Set to one when start is pressed, zero when emergency shutoff, stop, reset, finished
mf: dbit 1 ; Math.inc stuff

$NOLIST
$include(math32.inc)
$LIST

cseg
;LCD and other pins



;$NOLIST
;$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
;$LIST
keypad_module:
	
seven_seg_module:
	
LCD_module:
	
send_comm:
	
PWM_module:

Check_Temp: ; Calls to this might be missing in some phases
	
	
E_shutoff: ; Calls to this might be missing in some phases
;Emergency Shuttoff once time hits sixty seconds, check if current temp is less than or equal to 50C
;If not, clear all state flags and goes back to initial settings state. Turns off oven
	clr a
	mov a, Time_Secs
	cjne a, #0x60, Skip_E_shutoff
	Load_X_var(Current_Temp_Bin)
	Load_y(50)
	lcall x_lteq_y
	jnb mf, Skip_E_shutoff
	clr OVEN_POWER
	clr phase_one_flag
	clr phase_two_flag
	clr phase_three_flag
	clr phase_four_flag
	clr oven_on_flag
Skip_E_shutoff:
	ret

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
	
	jnb oven_on_flag, Timer2_ISR_done ; Don't count unless oven is on
	
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
	
Timer2_ISR_done:
	pop psw
	pop acc
Timer2_ISR_skip:
	reti
	;This seven seg stuff just prints the seconds for FSM/SSR testing purposes
T_7seg:
    DB 40H, 79H, 24H, 30H, 19H, 12H, 02H, 78H, 00H, 10H

; Displays Time_Secs number in HEX1-HEX0
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
;Initialize things
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
    
    clr OVEN_POWER
	clr phase_one_flag
	clr phase_two_flag
	clr phase_three_flag
	clr phase_four_flag
	clr oven_on_flag
    clr seconds_flag
    
	mov Time_Secs, #0x00 ; Initialize counter to zero
	;mov Soak_Time, #0x10
	
	; This first loop is basically phase 0 where we check for keypad inputs and set the times/temps
settings_loop:
	jnb key.1, settings_state ; First check if start is pressed, if not, run the loop for setting/displaying the numbers. If pressed, continue to next phase, soak_ramp
	;Wait_Milli_Seconds(#50) This doesn't compile. Need other debounce method
	jnb key.1, settings_state ; Start/stop could be replaced with a button ISR and might be ideal
	jnb key.1, $
	; Start the oven and move on to next phase
	setb phase_one_flag
	Load_X_var(Soak_Temp_Bin)
	Load_y(20)
	lcall sub32
	Store_X_var(Stop_Temp_Bin)
	Load_y_var(Stop_Temp_Bin)
	setb OVEN_POWER
	setb oven_on_flag
	ljmp check_stop
settings_state: 		; Call keypad which checks for input and stores desired temps/times in Soak_Temp/Time etc. Could be split into different subroutine calls
	lcall keypad_module ; Also check current temp and update displays. Some subroutines can be merged into one or expanded into more.
	lcall Check_Temp ; It is better to check temperatures outside of ISR. If in ISR, it could mess with the delicate timing
	lcall seven_seg_module
	lcall LCD_module
	lcall send_comm
	ljmp settings_loop
	
check_stop: ; This is jumped to from every phase, every one second to check if stop/start button is pressed
	jnb key.1, soak_ramp
	;Wait_Milli_Seconds(#50) This doesn't compile. Need other debounce method
	jnb key.1, soak_ramp ; Start/stop could be replaced with a button ISR and might be ideal
	jnb key.1, $
	clr OVEN_POWER
	clr phase_one_flag
	clr phase_two_flag
	clr phase_three_flag
	clr phase_four_flag
	clr oven_on_flag

p1_stop: 			; Exists because a jnb comparison jump is too far to go directly to check_stop from some phases
	ljmp check_stop ; Included for every phase for consistency reasons
; Oven is 100% power in ramp phase; no PWM
soak_ramp: 
	jnb phase_one_flag, temp_flatten_one ; If phase_one_flag is set, run this soak_ramp loop, else jump to next phase
	lcall Check_Temp
	jnb seconds_flag, soak_ramp ; This ensures that the majority of the loop will only run every one second
	clr seconds_flag
	lcall E_shutoff ; Check emergency shutoff conditions
	lcall LCD_module
	Load_X_var(Current_Temp_Bin)
	lcall x_gteq_y
	jnb mf, p1_stop ; If Current temp is desired temp, continue to next phase, else restart soak_ramp loop
	clr OVEN_POWER
	clr phase_one_flag
	setb phase_two_flag
;Set shut_off temp for curve flattening.
	Load_y(10)
;Convert Time_Secs to HEX in Seconds_Bin
;Then Load_X_var Seconds_Bin
	Load_X_var(Time_Secs)
	lcall add32
	Store_X_var(Flat_Time_Bin)
	ljmp temp_flatten_one
	
flat_one_stop:
	ljmp check_stop

;This can be replaced by a function that moves to the next phase
;when the instantaneous rate of temp change is less than or eq zero
;for better consistency. Too complicated for my brain right now
temp_flatten_one: ; Turn off for fixed amount of time to reach temp without going over.
	jnb seconds_flag, temp_flatten_one
	mov a, Time_Secs
	clr seconds_flag
	cjne a, Flat_Time, flat_one_stop
	Load_y_var(Soak_Time_Bin)
;Convert Time_Secs to HEX in Seconds_Bin
;Then Load_X_var Seconds_Bin
	Load_X_var(Time_Secs)
	lcall add32
	mov Hold_Time, x
	ljmp soak_hold
	
p2_stop:
	ljmp check_stop
; Everything below is a work in progress. Everything above is unrefined.
soak_hold: ; If phase_two_flag is set, run this soak_hold loop, else jump to next phase
	jnb phase_two_flag, reflow_ramp
	jnb seconds_flag, p2_stop
	clr seconds_flag
	lcall LCD_module
	lcall PWM_module
	mov a, Time_Secs
	cjne a, Hold_Time, soak_hold
	
	
reflow_ramp:
	jnb phase_three_flag, reflow_hold
	jnb seconds_flag, reflow_ramp
	clr seconds_flag
	
	
temp_flatten_two:

	
reflow_hold:
	
	jnb seconds_flag, reflow_hold
	clr seconds_flag
	

END
