$NOLIST
$MODMAX10
$LIST

	CSEG at 0
	ljmp main_code

;	DSEG at 30H
;bcd:	ds 5
;Soak_Temp:  ds 5
;Soak_Time:  ds 5
;Reflow_Temp:  ds 5
;Reflow_Time:  ds 5

	CSEG

cseg
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

Soak_temp_msg: db 'STE', 0
Soak_time_msg: db 'STI', 0
Reflow_temp_msg: db 'RTE', 0
Reflow_time_msg: db 'RTI', 0

Elapsed: db 'ELAPSED:', 0

state_1_msg: db 'Soak Ramp CJ:22C', 0
state_2_msg: db 'Soak Hold CJ:22C', 0
state_3_msg: db 'Ref Ramp  CJ:22C', 0
state_4_msg: db 'Ref Hold  CJ:22C', 0
state_5_msg: db 'Cooldown  CJ:22C', 0
e_shutdown_msg: db '   EMERGENCY    ', 0
invalid_state_msg: db ' INVALID STATE  ', 0
clr_msg: db '                ', 0

Configure_LCD_Pins:
	orl P0MOD, #10101010b ; P0.1, P0.3, P0.5, P0.7 are outputs.  ('1' makes the pin output)
	orl P1MOD, #10000010b ; P1.7 and P1.1 are outputs
	ret

Wait25ms:
;33.33MHz, 1 clk per cycle: 0.03us
	 mov R0, #15
L3b: mov R1, #74
L2b: mov R2, #250
L1b: djnz R2, L1b ;3*250*0.03us=22.5us
     djnz R1, L2b ;74*22.5us=1.665ms
     djnz R0, L3b ;1.665ms*15=25ms
     ret

ASCII_table: db '0123456789ABCDEF'

showBCD_LCD MAC
	; Convert high part
	mov a, %0
	swap a ; exchange high and low parts
	anl a, #0xf ; mask off low part
	movc a, @a+dptr ; convert to ASCII
	lcall ?WriteData ; send to LCD	
	; Convert low part
	mov a, %0
	anl a, #0xf ; mask off high part
	movc a, @a+dptr ; convert to ASCII
	lcall ?WriteData ; Send to LCD
ENDMAC
	
Display_LCD_S0:
	mov dptr, #ASCII_table
	Set_Cursor(1,5)
	mov bcd+1, Soak_Temp+1
	mov bcd+0, Soak_Temp+0
	showBCD_LCD(bcd+1)
	showBCD_LCD(bcd+0)
	
	Set_Cursor(1,13)
	mov bcd+1, Soak_Time+1
	mov bcd+0, Soak_Time+0
	showBCD_LCD(bcd+1)
	showBCD_LCD(bcd+0)

	Set_Cursor(2,5)
	mov bcd+1, Reflow_Temp+1
	mov bcd+0, Reflow_Temp+0
	showBCD_LCD(bcd+1)
	showBCD_LCD(bcd+0)

	Set_Cursor(2,13)
	mov bcd+1, Reflow_Time+1
	mov bcd+0, Reflow_Time+0
	showBCD_LCD(bcd+1)
	showBCD_LCD(bcd+0)
ret

Display_Time_Elapsed:
	mov dptr, #ASCII_table
	Set_Cursor(2,9)
	mov bcd+1, Time_Elapsed+1
	mov bcd+0, Time_Elapsed+0
	showBCD_LCD(bcd+1)
	showBCD_LCD(bcd+0)
ret

Display_S0_constant:
	Set_Cursor(1, 1)
    Send_Constant_String(#Soak_temp_msg)
    
    Set_Cursor(1, 9)
    Send_Constant_String(#Reflow_temp_msg)
    
    Set_Cursor(2, 1)
    Send_Constant_String(#Soak_time_msg)
    
    Set_Cursor(2, 9)
    Send_Constant_String(#Reflow_time_msg)
ret

Display_S1_constant:
	Set_Cursor(1,1)
	Send_Constant_String(#state_1_msg)
	Set_Cursor(2,1)
	Send_Constant_String(#Elapsed)
ret

Display_S2_constant:
	Set_Cursor(1,1)
	Send_Constant_String(#state_2_msg)
	Set_Cursor(2,1)
	Send_Constant_String(#Elapsed)
ret

Display_S3_constant:
	Set_Cursor(1,1)
	Send_Constant_String(#state_3_msg)
	Set_Cursor(2,1)
	Send_Constant_String(#Elapsed)
ret

Display_S4_constant:
	Set_Cursor(1,1)
	Send_Constant_String(#state_4_msg)
	Set_Cursor(2,1)
	Send_Constant_String(#Elapsed)
ret

Display_S5_constant:
	Set_Cursor(1,1)
	Send_Constant_String(#state_5_msg)
	Set_Cursor(2,1)
	Send_Constant_String(#Elapsed)
ret

Display_E_Shutdown:
	Set_Cursor(1,1)
	Send_Constant_String(#e_shutdown_msg)
	Set_Cursor(2,1)
	Send_Constant_String(#clr_msg)
ret

Display_Invalid_State:
	Set_Cursor(1,1)
	Send_Constant_String(#invalid_state_msg)
	Set_Cursor(2,1)
	Send_Constant_String(#clr_msg)
ret

main_code:
	
	; Configure the pins used as outputs
	lcall Configure_LCD_Pins
	
	; Initialize LCD and display something
	lcall ELCD_4BIT
check_state:
state_0:
	cjne State_flag, #0, state_1
	lcall Display_S0_constant
	lcall Display_LCD_S0
	ljmp finished_state_check
state_1:
	cjne State_flag, #1, state_2
	lcall Display_S1_constant
	lcall Display_Time_Elapsed
	ljmp finished_state_check
state_2:
	cjne State_flag, #2, state_3
	lcall Display_S2_constant
	lcall Display_Time_Elapsed
	ljmp finished_state_check
state_3:
	cjne State_flag, #3, state_4
	lcall Display_S3_constant
	lcall Display_Time_Elapsed
	ljmp finished_state_check
state_4:
	cjne State_flag, #4, state_5
	lcall Display_S4_constant
	lcall Display_Time_Elapsed
	ljmp finished_state_check
state_5:
	cjne e_shutdown_flag, #0, E_Shutdown
	cjne State_flag, #5, Invalid_State
	lcall Display_S5_constant
	lcall Display_Time_Elapsed
	ljmp finished_state_check
E_Shutdown:
	lcall Display_E_Shutdown
	ljmp finished_state_check
Invalid_State:
	lcall Display_Invalid_State
	ljmp finished_state_check
finished_state_check:
	ljmp check_state	
end