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
Current_Temp_Bin: ds 4
;===FLAG===
State_flag: ds 1
;===MATH.INC STUFF===
bcd: ds 4
x:   ds 4
y:   ds 4


bseg
seconds_flag: dbit 1 ; Set to one in the ISR every time 1000 ms had passed
e_shutdown_flag: dbit 1
oven_on_flag: dbit 1 ; Set to one when start is pressed, zero when emergency shutoff, stop, reset, finished
mf: dbit 1 ; Math.inc stuff

cseg
;LCD and other pins


$NOLIST
;FSM main can include the files that multiple modules will use 
$include(LCD_4bit.inc) 
$include(math32.inc)

;===MODULES WE'RE GONNA INCLUDE==
;$include(keypad_input.inc)
;$include(LCD_display.inc)
;$include(check_temp.inc)
;do we need a PWM module?
$LIST
	
;%%%%%%%%%%%% timer 2 stuff


;%%%%%%%%%%% do we put main here?
main:
	

State0Setting: 
	;%%%%%set the state flag to 0
	lcall ;{whatever check_temp function label is at the start}
	;lcall ;{whatever keypad function label is at the start} 
	;lcall ;{whatever LCD  display function label is at the start}
	jnb oven_on_flag, State0Setting ;if the oven isnt on stay in settings
	ljmp State1RampSoak

State1Shutdown:
	ljmp State5Shutdown
State1RampSoak:
	;%%%%%%% set the state flag to 1
	;below: basically gets stop temp (15 less than our soak temp)
	mov Stop_Temp_Bin, Soak_Temp_Bin
	Load_x(Stop_Temp_Bin)
	Load_y(15)
	lcall sub32
	jnb oven_on_flag, State1Shutdown
	;%%%%%% turn on SSR
	;lcall ;{whatever check_temp function label is at the start}
	lcall E_shutoff
	Load_y(Current_Temp_Bin)
	lcall x_gteq_y 
	jb mf, State1RampSoak ;if stop temp is >= current temp stay in loop
	ljmp State2HoldSoak

State2Shutdown:
	ljmp State5Shutdown
State2HoldSoak:
	;%%%%%% set the state flag to 2
	jnb oven_on_flag, State2Shutdown
	;lcall ;{whatever check_temp function label is at the start}
	Load_x(Time_Elapsed_Bin)
	Load_y(Soak_Time_Bin)
	lcall x_gteq_y
	jnb mf, State2HoldSoak
	ljmp State3RampReflow
	
State3Shutdown:
	ljmp State5Shutdown
State3RampReflow:
	;%%%%%%% set the state flag to 3
	mov Stop_Temp_Bin, Reflow_Temp_Bin
	Load_x(Stop_Temp_Bin)
	Load_y(15)
	lcall sub32
	jnb oven_on_flag, State3Shutdown
	;%%%%%% turn on SSR
	;lcall ;{whatever check_temp function label is at the start}
	lcall E_shutoff
	lcall Max_T_shutoff
	Load_y(Current_Temp_Bin)
	lcall x_gteq_y
	jb mf, State3RampReflow
	ljmp State4HoldReflow

State4Shutdown:
	ljmp State5Shutdown
State4HoldReflow:
	;%%%%%% set the state flag to 4
	jnb oven_on_flag, State4Shutdown
	;lcall ;{whatever check_temp function label is at the start}
	lcall Max_T_shutoff
	Load_x(Time_Elapsed_Bin)
	Load_y(Reflow_Time_Bin)
	lcall x_gteq_y
	jnb mf, State4HoldReflow

State5Shutdown:
	;%%%%%%% set the state flag to 5
	;%%%%%turn off SSR
	lcall ;{whatever check_temp function label is at the start}
	ljmp State0Setting
	
E_shutoff: 
	clr a
	mov a, Time_Elapsed
	cjne a, #0x60, Skip_E_shutoff ;if time elapsed is under 60 sec just leave
	Load_X_var(Current_Temp_Bin)
	Load_y(50)
	lcall x_lteq_y
	jnb mf, Skip_E_shutoff ;else, if temp is safe then leave
	setb e_shutdown_flag ;else, raise the error flag and go to shutdown
	ljmp State5Shutdown
Skip_E_shutoff:
	ret

Max_T_shutoff:
	Load_X_var(Current_Temp_Bin)
	Load_y(240)
	lcall x_lteq_y
	jnb mf, Skip_T_shutoff ;else, if temp is safe then leave
	;%%%%%%%%%%hmmmm do we raise the error flag?
	ljmp State5Shutdown
Skip_T_shutoff
	ret