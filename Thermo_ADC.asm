$NOLIST
$MODMAX10
$LIST

CLK  EQU 33333333
BAUD EQU 57600

VREF_MV   EQU 4096

OP07_CH   EQU 2    ; A2 (Vout)

R1_OHM     EQU 3300
R2_OHM     EQU 10

TCOLD10    EQU 220        ;room temperature


TIMER_1_RELOAD EQU (256-((2*CLK)/(12*32*BAUD)))


TIMER0_RELOAD_1MS EQU (65536-(CLK/(12*1000)))

ORG 0000H
    ljmp main

DSEG at 30H
x:   ds 4
y:   ds 4
bcd: ds 5

BSEG
mf:  dbit 1

$NOLIST
$include(math32.asm)
$LIST

CSEG

; -------------------- UART / print --------------------
Initialize_Serial_Port:
    clr TR1
    anl TMOD, #0x0F
    orl TMOD, #0x20        ; T1 mode2
    orl PCON, #080H        ; SMOD=1
    mov TH1,  #low(TIMER_1_RELOAD)
	mov TL1,  #low(TIMER_1_RELOAD)
	mov SCON, #050H
	setb TR1
	setb TI
	ret

putchar:
    jbc TI, putchar_send
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

    mov a, bcd+0
    anl a, #0x0F
    lcall SendNibbleDigit
    ret

; -------------------- delay --------------------
wait_1ms:
    clr TR0
    clr TF0
    mov TH0, #high(TIMER0_RELOAD_1MS)
    mov TL0, #low(TIMER0_RELOAD_1MS)
    setb TR0
    jnb TF0, $
    clr TR0
    ret

waitms:
    lcall wait_1ms
    djnz R2, waitms
    ret

; -------------------- ADC read --------------------
adc_small_delay:
    mov R6, #200
ADL1:
    djnz R6, ADL1
    ret

Read_ADC:
    anl A, #07H
    mov R5, A

    mov A, #080H
    mov ADC_C, A
    lcall adc_small_delay
    lcall adc_small_delay

    mov A, R5
    anl A, #07H
    mov ADC_C, A
    lcall adc_small_delay
    lcall adc_small_delay
    lcall adc_small_delay

    mov A, ADC_L
    mov A, ADC_H

    lcall adc_small_delay

    mov A, ADC_L
    mov R0, A
    mov A, ADC_H
    anl A, #0FH
    mov R1, A
    ret

; -------------------- init --------------------
Init_All:
    lcall Initialize_Serial_Port
    clr TR0
    anl TMOD, #0xF0
    orl TMOD, #0x01        ; Timer0 mode1
    ret

; -------------------- main --------------------
main:
    mov sp, #0x7FH
    lcall Init_All

Forever:
    ; Read OP07 (A2)
    mov A, #OP07_CH
    lcall Read_ADC

    ; x = ADC (12-bit)
    mov x+0, R0
    mov x+1, R1
    mov x+2, #0
    mov x+3, #0

    ; x = Vop_mV = ADC * 4096 / 4095
    Load_y(VREF_MV)
    lcall mul32
    Load_y(4095)
    lcall div32

    ; x = Thot10 = Vop_mV * (10000*R2) / (41*R1)
    Load_y(R2_OHM)
    lcall mul32
    Load_y(10000)
    lcall mul32
    Load_y(R1_OHM)
    lcall div32
    Load_y(41)
    lcall div32

    ; x = TotalT10 = Thot10 + Tcold10 (assumed)
    Load_y(TCOLD10)
    lcall add32

    lcall hex2bcd
    lcall Print_T10_from_BCD
    lcall Send_CRLF

    ; wait ~1000 ms
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