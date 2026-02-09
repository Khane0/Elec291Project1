;$MODDE1SOC
$MODMAX10

; ADC_C DATA 0xa1
; ADC_L DATA 0xa2
; ADC_H DATA 0xa3

CLK           EQU 33333333 ; Microcontroller system crystal frequency in Hz

;===SOUND TIMER===
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/(12*TIMER0_RATE)))) ; The prescaler in the CV-8052 is 12 unlike the AT89LP51RC2 where is 1.
;===SOUND TIMER END===

;===SERIAL TIMER===
BAUD   EQU 57600 ;115200
T2LOAD EQU 256-((CLK*2)/(32*12*BAUD))
;===SERIAL TIMER c===

;===MS TIMER===
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/(12*TIMER2_RATE))))
;===MS TIMER END===

OVEN_POWER  			equ P1.1 ; Pin to turn the SSR on/off
SOUND_OUT				equ P2.1


; These are the pins used for the keypad in this program:
;ROW1 EQU P1.2
;ROW2 EQU P1.4
;ROW3 EQU P1.6
;ROw4 EQU P2.0
;COL1 EQU P2.2
;COL2 EQU P2.4
;COL3 EQU P2.6
;COL4 EQU P3.0




;//// CLEANUP REQUIRED /////
;add the math include with load variables and insert where needed

;when comparing integers with binary variables using gteq lteq etc,
;convert the bin ones to hex (maybe)

;/////////////////




; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	reti

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
Count1ms:     ds 2 ; Used to determine when one millisecond has passed
;====SET BY ISR====
Time_Elapsed:  ds 4
Time_Elapsed_Bin: ds 4 
;===SET BY KEYPAD===
;we'll receive in hex so might just keep these as hex, don't know if we need to convert to binary anymore
Soak_Temp: ds 4
Soak_Time: ds 4
Reflow_Temp: ds 4
Reflow_Time: ds 4
Soak_Temp_Bin: ds 4
Soak_Time_Bin: ds 4
Reflow_Temp_Bin: ds 4
Reflow_Time_Bin: ds 4
;===SET DEPENDING ON STATE===
;Hold time and flat time were removed: no need bc
;the state machine will just compare elapsed and reflow/soak time
Stop_Temp_Bin: ds 4
;===SET BY TEMP CHECK===
curr_temp:	ds 4
;Current_Temp_Bin: ds 4
;===FLAG===
State_flag: ds 1
;===MATH.INC STUFF===
bcd: ds 5
x:   ds 4
y:   ds 4


bseg
seconds_flag: dbit 1 ; Set to one in the ISR every time 1000 ms had passed
e_shutdown_flag: dbit 1
oven_on_flag: dbit 1 ; Set to one when start is pressed, zero when emergency shutoff, stop, reset, finished
mf: dbit 1 ; Math.inc stuff
state_transitioning: dbit 1 ;set to one when going from one state to the next
;%%%%%%link pin for speaker to this

cseg
;LCD and other pins
;Variable selection for storing numbers. Keypad
SW0     BIT 0E8h.0
SW1     BIT 0E8h.1
SW2     BIT 0E8h.2
SW3     BIT 0E8h.3
SW4     BIT 0E8h.4
ON_OFF		BIT 0E8h.5
;End keypad
$NOLIST
;FSM main can include the files that multiple modules will use 
;$include(LCD_4bit.inc) 
$include(math32.inc)
$include(Keypad_Module.inc)
$include(Thermo_Module.inc)
$include(LCD_module.asm)

;===MODULES WE'RE GONNA INCLUDE==
;$include(keypad_input.inc)
;$include(LCD_display.inc)
;$include(check_temp.inc)
;do we need a PWM module?
$LIST
	
;================TIMER 2 STUFF=======
;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz square wave at pin P3.7 ;
;---------------------------------;
Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	mov TH0, #high(TIMER0_RELOAD) ; Timer 0 doesn't have autoreload in the CV-8052
	mov TL0, #low(TIMER0_RELOAD)
	;cpl SOUND_OUT
	reti

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;
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

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done
	inc Count1ms+1

Inc_Done:
	mov a, State_flag
	cjne a, #2, CheckState4
	sjmp PWM
CheckState4:
	cjne a, #4, SkipPWM
PWM:
	;clr OVEN_POWER
	mov a, Count1ms+0
	cjne a, #low(800), SkipPWM
	mov a, Count1ms+1
	cjne a, #high(800), SkipPWM
	setb OVEN_POWER
SkipPWM:
	; Check if one second has passed
	mov a, Count1ms+0
	cjne a, #low(1000), Timer2_ISR_done ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(1000), Timer2_ISR_done
	
	clr OVEN_POWER
	
	; 1 second has passed.  Set a flag so the main program knows
	setb seconds_flag
	; Toggle LEDR0 so it blinks
	cpl LEDRA.0
	;cpl TR0 ; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	; Reset to zero the milli-seconds counter, it is a 16-bit variable
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	
	; Increment or reset the Time_Elapsed counter
	mov a, Time_Elapsed 
	jb state_transitioning, Time_Elapsed_Reset 
	add a, #0x01
	;clr SOUND_OUT
	sjmp Decimal_Adjust
Time_Elapsed_Reset:
	;setb SOUND_OUT
Decimal_Adjust:
	da a ; Decimal adjust instruction.  Check datasheet for more details!
	mov Time_Elapsed, a 
;assign oven on flag to the on/off switch unless in shutdown, where it must be off
	mov a, State_flag
	cjne a, #5, Not_In_S5
	clr oven_on_flag
	sjmp Timer2_ISR_done
Not_In_S5:
	mov oven_on_flag, ON_OFF
	
Timer2_ISR_done:
	pop psw
	pop acc
	reti
;=============TIMER 2 STUFF DONE =========

main:
	mov SP, #0x7F
    lcall Timer0_Init
    lcall Timer2_Init
;======CONFIGS THERMO STUFF====
	clr a
	mov LEDRA, a
	mov LEDRB, a
	
	lcall InitSerialPort
	
	mov dptr, #Initial_Message
	lcall SendString
	mov a, #'\r'
	lcall putchar
	mov a, #'\n'
	lcall putchar
	
	mov ADC_C, #0x80 ; Reset ADC
	lcall Wait50ms
	
	mov curr_temp+1, #0
	mov curr_temp, #0

	jb SW4, Enable_Interrupt ; Displays variables instead of temp
	lcall Display_Voltage_7seg
;====THERMO STUFF END======
Enable_Interrupt:
    setb EA   ; Enable Global interrupts
	setb seconds_flag
	mov Time_Elapsed, #0x00 ; Initialize time elapsed to zero
	mov State_flag, #0
	clr OVEN_POWER
	
;==========LCD=======
	lcall LCD_Init

;======CONFIGS KEYPAD STUFF====
;pasted from keypad module
	mov SP, #7FH
	clr a
	mov LEDRA, a
	mov LEDRB, a
	mov bcd+0, a
	mov bcd+1, a
	mov bcd+2, a
	mov bcd+3, a
	mov bcd+4, a
	
	mov Soak_Temp+0, a
	mov Soak_Temp+1, a
	mov Soak_Temp+2, a
	mov Soak_Temp+3, a
	mov Soak_Temp+4, a
	
	mov Soak_Time+0, a
	mov Soak_Time+1, a
	mov Soak_Time+2, a
	mov Soak_Time+3, a
	mov Soak_Time+4, a
	
	mov Reflow_Temp+0, a
	mov Reflow_Temp+1, a
	mov Reflow_Temp+2, a
	mov Reflow_Temp+3, a
	mov Reflow_Temp+4, a
	
	mov Reflow_Time+0, a
	mov Reflow_Time+1, a
	mov Reflow_Time+2, a
	mov Reflow_Time+3, a
	mov Reflow_Time+4, a
	lcall Configure_Keypad_Pins
;====KEYPAD STUFF END======
	
State0Setting:
;===KEYPAD CALLS===
	lcall Keypad
	jb SW4, display_var 
	;lcall Display
	lcall store_variable
	sjmp default_display 
display_var: 
	lcall variable_display
default_display:
	jnc State0Setting
	lcall Shift_Digits_Left
	ljmp State0Setting
;===KEYPAD CALLS END===
	jnb seconds_flag, State0Setting
	clr seconds_flag 
;===THERMO CALLS===
	lcall Read_ADC
	lcall Display_Voltage_Serial
	lcall Display_Voltage_7seg
	
; ===== LCD refresh (1 Hz) =====
    lcall LCD_UpdateLine1
    lcall LCD_UpdateLine2_StateIfChanged
    
;==THERMO CALLS END===
	;lcall ;{whatever LCD  display function label is at the start}
	jnb oven_on_flag, State0Setting ;if the oven isnt on stay in settings
	
	setb state_transitioning
	mov Time_Elapsed, #0x00
	setb SOUND_OUT
	mov State_flag, #1
	setb OVEN_POWER
;===SOAK TEMP BCD-->BINARY MINUS 15, STORE IN NEW VAR===
	Store_BCD(Soak_Temp)
	lcall bcd2hex
	Load_y(15)
	lcall sub32
	Store_X_var(Stop_Temp_Bin)
;===MATH END===
	ljmp State1RampSoak

State1Shutdown:
	ljmp State5Shutdown
State1RampSoak:
;===THERMO CALLS===
	lcall Read_ADC
	lcall Display_Voltage_7seg
;===THERMO CALLS END===
	jnb seconds_flag, State1RampSoak
	clr seconds_flag
	clr SOUND_OUT
;===SERIAL SEND===
	lcall Display_Voltage_Serial ;Serial can only handle about 1 reading per second, maybe more. But this is convenient

;==========LCD=======
    lcall LCD_UpdateLine1
    lcall LCD_UpdateLine2_StateIfChanged

;===SERIAL SEND END===
	clr state_transitioning
	jnb oven_on_flag, State1Shutdown
	lcall E_shutoff
	Store_BCD(curr_temp)
	lcall bcd2hex
	Load_y_var(Stop_Temp_Bin)
	lcall x_gteq_y 
	jnb mf, State1RampSoak ;if stop temp is >= current temp stay in loop
	
	setb state_transitioning
	mov State_flag, #2
	setb SOUND_OUT
	clr OVEN_POWER
	mov Time_Elapsed, #0x00
	ljmp State2HoldSoak

State2Shutdown:
	ljmp State5Shutdown
State2HoldSoak:
;===THERMO CALLS===
	lcall Read_ADC
	lcall Display_Voltage_7seg
;===THERMO CALLS END===
	jnb seconds_flag, State2HoldSoak
	clr seconds_flag
	clr SOUND_OUT
;===SERIAL SEND===
	lcall Display_Voltage_Serial ;Serial can only handle about 1 reading per second, maybe more. But this is convenient
;===SERIAL SEND END===
	clr state_transitioning
	jnb oven_on_flag, State2Shutdown
	mov a, Time_Elapsed
	cjne a, Soak_Time, State2HoldSoak
	
	setb state_transitioning
	mov Time_Elapsed, #0x00
	setb SOUND_OUT
	mov State_flag, #3
	setb OVEN_POWER
;===REFLOW TEMP BCD-->BINARY MINUS 15, STORE IN NEW VAR===
	Store_BCD(Reflow_Temp)
	lcall bcd2hex
	Load_y(15)
	lcall sub32
	Store_X_var(Stop_Temp_Bin)
;===MATH END===
	ljmp State3RampReflow
	
State3Shutdown:
	ljmp State5Shutdown
State3RampReflow:
;===THERMO CALLS===
	lcall Read_ADC
	lcall Display_Voltage_7seg
;===THERMO CALLS END===
	jnb seconds_flag, State3RampReflow
	clr seconds_flag
	clr SOUND_OUT
;===SERIAL SEND===
	lcall Display_Voltage_Serial ;Serial can only handle about 1 reading per second, maybe more. But this is convenient
;===SERIAL SEND END===
	clr state_transitioning
	jnb oven_on_flag, State3Shutdown
	lcall E_shutoff
	lcall Max_T_shutoff
	Store_BCD(curr_temp)
	lcall bcd2hex
	Load_y_var(Stop_Temp_Bin)
	lcall x_gteq_y
	jb mf, State3RampReflow
	
	setb state_transitioning
	mov State_flag, #4
	setb SOUND_OUT
	clr OVEN_POWER
	mov Time_Elapsed, #0x00
	ljmp State4HoldReflow

State4Shutdown:
	ljmp State5Shutdown
State4HoldReflow:
;===THERMO CALLS===
	lcall Read_ADC
	lcall Display_Voltage_7seg
;===THERMO CALLS END===
	jnb seconds_flag, State4HoldReflow
	clr seconds_flag
	clr SOUND_OUT
;===SERIAL SEND===
	lcall Display_Voltage_Serial ;Serial can only handle about 1 reading per second, maybe more. But this is convenient
;===SERIAL SEND END===
	clr state_transitioning
	jnb oven_on_flag, State4Shutdown
	lcall Max_T_shutoff
	mov a, Time_Elapsed
	cjne a, Reflow_Time, State4HoldReflow

	mov State_flag, #5
	clr OVEN_POWER
	mov Time_Elapsed, #0x00
	
State5Shutdown:
;===THERMO CALLS===
	lcall Read_ADC
	lcall Display_Voltage_7seg
;===THERMO CALLS END===
	jnb seconds_flag, State5Shutdown
	clr seconds_flag
;===SERIAL SEND===
	lcall Display_Voltage_Serial ;Serial can only handle about 1 reading per second, maybe more. But this is convenient
;===SERIAL SEND END===
	jnb e_shutdown_flag, RegShutdown
SomeTypeofEmShutdown:
	
RegShutdown:
	;Load_y(10)
	;Load_x(10)
	;lcall x_gteq_y
	;jb mf LeavingState5
	mov r2, #0x10
	cpl SOUND_OUT
	djnz r2, State5Shutdown
LeavingState5:
	ljmp State0Setting
	
E_shutoff: 
	clr a
	mov a, Time_Elapsed
	cjne a, #0x60, Skip_E_shutoff ;if time elapsed is under 60 sec just leave
	Store_BCD(curr_temp)
	lcall bcd2hex
	Load_y(50)
	lcall x_lteq_y
	jnb mf, Skip_E_shutoff ;else, if temp is safe then leave
	setb e_shutdown_flag ;else, raise the error flag and go to shutdown
	ljmp State5Shutdown
Skip_E_shutoff:
	ret

Max_T_shutoff:
	Store_BCD(curr_temp)
	lcall bcd2hex
	Load_y(240)
	lcall x_lteq_y
	jb mf, Skip_T_shutoff ;else, if temp is safe then leave
	setb e_shutdown_flag
	ljmp State5Shutdown
Skip_T_shutoff:

	ret
END