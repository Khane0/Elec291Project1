$NOLIST

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

Display_LCD:
	mov dptr, #ASCII_table
	mov a, State_flag
	cjne a, #0, State_1
	Store_BCD(Soak_Temp)
	Set_Cursor(1,5)
	;showBCD_LCD(bcd+4)
	;showBCD_LCD(bcd+3)
	;showBCD_LCD(bcd+2)
	showBCD_LCD(bcd+1)
	showBCD_LCD(bcd+0)
	
	Store_BCD(Soak_Time)
	Set_Cursor(1,13)
	;showBCD_LCD(bcd+4)
	;showBCD_LCD(bcd+3)
	;showBCD_LCD(bcd+2)
	showBCD_LCD(bcd+1)
	showBCD_LCD(bcd+0)
	
	Store_BCD(Reflow_Temp)
	Set_Cursor(2,5)
	;showBCD_LCD(bcd+4)
	;showBCD_LCD(bcd+3)
	;showBCD_LCD(bcd+2)
	showBCD_LCD(bcd+1)
	showBCD_LCD(bcd+0)
	
	Store_BCD(Reflow_Time)
	Set_Cursor(2,13)
	;showBCD_LCD(bcd+4)
	;showBCD_LCD(bcd+3)
	;showBCD_LCD(bcd+2)
	showBCD_LCD(bcd+1)
	showBCD_LCD(bcd+0)
	ljmp ending
state_1:
	
	
state_2:


state_3:


state_4:

state_5:


ending:
	clr c
	ret
	
$LIST