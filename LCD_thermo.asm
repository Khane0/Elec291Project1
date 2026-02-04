$NOLIST
$MODMAX10
$LIST

CLK  EQU 33333333
BAUD EQU 57600

VREF_MV   EQU 4096

ADCREF_CH EQU 0    ; A0
LM335_CH  EQU 1    ; A1
OP07_CH   EQU 2    ; A2  

R1_OHM     EQU 3300    
R2_OHM     EQU 10

; Timer1 auto-reload (mode 2) for UART baud
TIMER_1_RELOAD EQU (256-((2*CLK)/(12*32*BAUD)))

; Timer0 1ms tick (mode 1, 16-bit)
TIMER0_RELOAD_1MS EQU (65536-(CLK/(12*1000)))

ORG 0000H
    ljmp main

DSEG at 30H
x:   ds 4
y:   ds 4
bcd: ds 5
adc_refL: ds 1
adc_refH: ds 1
tcold: ds 4

BSEG
mf:  dbit 1 

$NOLIST
$include(math32.asm)
$LIST

CSEG

Initialize_Serial_Port:
    clr TR1
    anl TMOD, #0x0F
    orl TMOD, #0x20        ; T1 mode2
    orl PCON, #080H        ; SMOD=1
    mov TH1,  #low(TIMER_1_RELOAD)
    mov TL1,  #low(TIMER_1_RELOAD)
    setb TR1
    mov SCON, #052H        
    ret

putchar:
    jbc TI, putchar_send   ; wait until TI=1, then clear it
    sjmp putchar
putchar_send:
    mov SBUF, a
    ret

Send_CRLF:
    mov a, #0DH
    lcall putchar
    mov a, #0AH
    lcall putchar
    ret

SendNibbleDigit:
    anl a, #0x0F
    add a, #'0'
    lcall putchar
    ret

;============================================================
; Print packed-BCD in bcd[] as temperature with 1 decimal:
; x holds |T*10| and hex2bcd already ran
;============================================================
Print_T10_from_BCD:
    mov R7, #0

    mov a, bcd+4
    swap a
    anl a, #0x0F
    jnz PT_out1
    sjmp PT_skip1
PT_out1:
    mov R7, #1
    lcall SendNibbleDigit
PT_skip1:
    mov a, bcd+4
    anl a, #0x0F
    jnz PT_out2
    sjmp PT_skip2
PT_out2:
    mov R7, #1
    lcall SendNibbleDigit
PT_skip2:

    ; bcd+3
    mov a, bcd+3
    swap a
    anl a, #0x0F
    jnz PT_out3
    sjmp PT_skip3
PT_out3:
    mov R7, #1
    lcall SendNibbleDigit
PT_skip3:
    mov a, bcd+3
    anl a, #0x0F
    jnz PT_out4
    sjmp PT_skip4
PT_out4:
    mov R7, #1
    lcall SendNibbleDigit
PT_skip4:

    ; bcd+2
    mov a, bcd+2
    swap a
    anl a, #0x0F
    jnz PT_out5
    sjmp PT_skip5
PT_out5:
    mov R7, #1
    lcall SendNibbleDigit
PT_skip5:
    mov a, bcd+2
    anl a, #0x0F
    jnz PT_out6
    sjmp PT_skip6
PT_out6:
    mov R7, #1
    lcall SendNibbleDigit
PT_skip6:

    ; bcd+1
    mov a, bcd+1
    swap a
    anl a, #0x0F
    jnz PT_out7
    sjmp PT_skip7
PT_out7:
    mov R7, #1
    lcall SendNibbleDigit
PT_skip7:
    mov a, bcd+1
    anl a, #0x0F
    jnz PT_out8
    sjmp PT_skip8
PT_out8:
    mov R7, #1
    lcall SendNibbleDigit
PT_skip8:

    ; bcd+0 HIGH nibble
    mov a, bcd+0
    swap a
    anl a, #0x0F
    cjne R7, #0, PT_tens_normal
    mov a, #0
    lcall SendNibbleDigit
    mov R7, #1
    sjmp PT_after_tens
PT_tens_normal:
    lcall SendNibbleDigit
PT_after_tens:

    mov a, #'.'
    lcall putchar

    ; bcd+0 LOW nibble
    mov a, bcd+0
    anl a, #0x0F
    lcall SendNibbleDigit
    ret

;============================================================
; Timer0 delay 
;============================================================
wait_1ms:
    clr TR0
    clr TF0
    ; T0 mode1 already set in Init_All
    mov TH0, #high(TIMER0_RELOAD_1MS)
    mov TL0, #low(TIMER0_RELOAD_1MS)
    setb TR0
    jnb TF0, $
    clr TR0
    ret

; Wait R2 milliseconds
waitms:
    lcall wait_1ms
    djnz R2, waitms
    ret

;============================================================
; ADC small delay + ADC read 
;============================================================
adc_small_delay:
    mov R6, #200        
ADL1:
    djnz R6, ADL1
    ret

Read_ADC:
    anl A, #07H
    mov R5, A

    ; reset ADC
    mov A, #080H
    mov ADC_C, A
    lcall adc_small_delay
    lcall adc_small_delay

    ; run + select channel
    mov A, R5
    anl A, #07H
    mov ADC_C, A
    lcall adc_small_delay
    lcall adc_small_delay
    lcall adc_small_delay

    mov A, ADC_L
    mov A, ADC_H

    lcall adc_small_delay

    ; real read result (12-bit -> [R1:R0])
    mov A, ADC_L
    mov R0, A
    mov A, ADC_H
    anl A, #0FH
    mov R1, A
    ret

;============================================================
; Init: UART + Timer0
;============================================================
Init_All:
    lcall Initialize_Serial_Port

    ; Timer0 mode1 (16-bit)
    clr TR0
    anl TMOD, #0xF0
    orl TMOD, #0x01
    ret

;============================================================
; main loop
;============================================================
main:
    mov sp, #0x7FH
    lcall Init_All

Forever:

    ; (0) Read ADCREF (A0)
    mov A, #ADCREF_CH
    lcall Read_ADC
    mov adc_refL, R0
    mov adc_refH, R1

    ; (1) Read LM335 (A1) -> Vlm_mV = ADC * VREF_MV / ADCREF
    mov A, #LM335_CH
    lcall Read_ADC

    mov x+0, R0
    mov x+1, R1
    mov x+2, #0
    mov x+3, #0
    Load_y(VREF_MV)
    lcall mul32

    mov y+0, adc_refL
    mov y+1, adc_refH
    mov y+2, #0
    mov y+3, #0
    lcall div32                 ; x = Vlm_mV

    ; Tcold10 = Vlm_mV - 2730
    Load_y(2730)
    lcall sub32                 ; x = Tcold10

    ; save Tcold10
	mov tcold+0, x+0
	mov tcold+1, x+1
	mov tcold+2, x+2
	mov tcold+3, x+3

    ; (2) Read OP07 (A2) -> Vop_mV = ADC * VREF_MV / ADCREF
    mov A, #OP07_CH
    lcall Read_ADC

    mov x+0, R0
    mov x+1, R1
    mov x+2, #0
    mov x+3, #0
    Load_y(VREF_MV)
    lcall mul32

    mov y+0, adc_refL
    mov y+1, adc_refH
    mov y+2, #0
    mov y+3, #0
    lcall div32                 ; x = Vop_mV

    ; (3) Thot10 = (Vop_mV * R2 / R1) * 10000 / 41

	Load_y(R2_OHM)
	lcall mul32          ; x = Vop_mV * R2

	Load_y(R1_OHM)
	lcall div32          ; x = (Vop_mV * R2) / R1

	Load_y(10000)
	lcall mul32          ; x = ((Vop_mV * R2) / R1) * 10000

	Load_y(41)
	lcall div32          ; x = Thot10

    ; (4) Total T10 = Thot10 + Tcold10
    mov y+0, tcold+0
	mov y+1, tcold+1
	mov y+2, tcold+2
	mov y+3, tcold+3
	lcall add32

    lcall hex2bcd
    lcall Print_T10_from_BCD
    lcall Send_CRLF

    ; wait 1000 ms
    mov R2, #250
    lcall waitms
    mov R2, #250
    lcall waitms
    mov R2, #250
    lcall waitms
    mov R2, #250
    lcall waitms

    ljmp Forever

END