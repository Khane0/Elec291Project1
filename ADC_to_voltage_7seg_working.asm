$MODMAX10

; The Special Function Registers below were added to 'MODMAX10' recently.
; If you are getting an error, uncomment the three lines below.

; ADC_C DATA 0xa1
; ADC_L DATA 0xa2
; ADC_H DATA 0xa3

	CSEG at 0
	ljmp mycode

dseg at 30h

x:		ds	4
y:		ds	4
bcd:	ds	5
curr_temp:	ds 5

bseg

mf:		dbit 1

FREQ   EQU 33333333
BAUD   EQU 115200
;T2LOAD EQU 65536-(FREQ/(32*BAUD))
T1LOAD    EQU (256-((2*FREQ)/(12*32*BAUD)))


CSEG

InitSerialPort:
	; Configure serial port and baud rate
;	clr TR2 ; Disable timer 0
;	mov T2CON, #30H ; RCLK=1, TCLK=1 
;	mov RCAP2H, #high(T2LOAD)  
;	mov RCAP2L, #low(T2LOAD)
;	setb TR2 ; Enable timer 1
;	mov SCON, #52H
;	ret


	clr TR1 ; disablee time 1
    anl TMOD, #0x0F
    orl TMOD, #0x20
    orl PCON, #080H

    mov TH1, #low(T1LOAD)
    mov TL1, #low(T1LOAD)

    setb TR1
    mov SCON, #052H
    setb TI
ret

putchar:
    JNB TI, putchar
    CLR TI
    MOV SBUF, a
    RET

SendString:
    CLR A
    MOVC A, @A+DPTR
    JZ SSDone
    LCALL putchar
    INC DPTR
    SJMP SendString
SSDone:
    ret

$include(math32.asm)

cseg
$NOLIST
$LIST

; Look-up table for 7-seg displays
myLUT:
    DB 0xC0, 0xF9, 0xA4, 0xB0, 0x99        ; 0 TO 4
    DB 0x92, 0x82, 0xF8, 0x80, 0x90        ; 4 TO 9
    DB 0x88, 0x83, 0xC6, 0xA1, 0x86, 0x8E  ; A to F

Wait50ms:
;33.33MHz, 1 clk per cycle: 0.03us
	mov R0, #30
Wait50ms_L3:
	mov R1, #74
Wait50ms_L2:
	mov R2, #250
Wait50ms_L1:
	djnz R2, Wait50ms_L1 ;3*250*0.03us=22.5us
    djnz R1, Wait50ms_L2 ;74*22.5us=1.665ms
    djnz R0, Wait50ms_L3 ;1.665ms*30=50ms
    ret

Display_Voltage_7seg:
	
	mov dptr, #myLUT
	
	mov a, curr_temp+1
	anl a, #0FH
	movc a, @a+dptr
	mov HEX2, a

	mov a, curr_temp+0
	swap a
	anl a, #0FH
	movc a, @a+dptr
	mov HEX1, a
	
	mov a, curr_temp+0
	anl a, #0FH
	movc a, @a+dptr
	mov HEX0, a
	
	ret

	
Display_Voltage_Serial:

	mov a, curr_temp+1
	anl a, #0FH
	add a, #'0'
	lcall putchar

	mov a, curr_temp+0
	swap a
	anl a, #0FH
	add a, #'0'
	lcall putchar
	
	mov a, curr_temp+0
	anl a, #0FH
	add a, #'0'
	lcall putchar
	
	mov a, #'\r'
	lcall putchar
	mov a, #'\n'
	lcall putchar
	
	ret

Initial_Message:  db 'Voltmeter test', 0

Read_ADC:
	mov ADC_C, #0
	
	; Load 32-bit 'x' with 12-bit adc result
	mov x+3, #0
	mov x+2, #0
	mov x+1, ADC_H
	mov x+0, ADC_L
	
	; Convert to voltage by multiplying by 5.000 and dividing by 4096
	Load_y(5000)
	lcall mul32
	Load_y(4096)
	lcall div32
	
	; from Jesus' Easy-peasy Thermocouple instructions
	
	Load_y(1000) ; convert to microvolts
	lcall mul32
	Load_y(12500) ; 41 * 300
	lcall div32
	Load_y(22) ; add cold junction temperature
	lcall add32
	
	; at this point x is temp in celcius
	
	lcall hex2bcd
	
	mov curr_temp+0, bcd+0
	mov curr_temp+1, bcd+1
	mov curr_temp+2, bcd+2
	mov curr_temp+3, bcd+3
ret


SendSerialString:
	mov r7, a
	mov a, r7
	swap a
	anl a, #0fh
	add a, #'0'
	lcall putchar
	mov a, r7
	anl a, #0fh
	anl a, #'0'
	lcall putchar
ret

mycode:
	mov SP, #7FH
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
	lcall Display_Voltage_7seg

forever:
	lcall Read_ADC
	lcall Display_Voltage_Serial
	lcall Display_Voltage_7seg

; wait 1 second

	lcall Wait50ms
	lcall Wait50ms ; 100
	lcall Wait50ms
	lcall Wait50ms ; 200
	
	lcall Wait50ms
	lcall Wait50ms ; 300
	lcall Wait50ms
	lcall Wait50ms ; 400
	lcall Wait50ms
	lcall Wait50ms ; 500
	lcall Wait50ms
	lcall Wait50ms ; 600
	lcall Wait50ms
	lcall Wait50ms ; 700
	lcall Wait50ms
	lcall Wait50ms ; 800
	lcall Wait50ms
	lcall Wait50ms ; 900
	lcall Wait50ms
	lcall Wait50ms ; 1000

	
	ljmp forever
	
end
