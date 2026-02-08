$NOLIST
$MODMAX10
$LIST

BAUD      EQU 57600
FREQ      EQU 33333333
T1LOAD    EQU (256-((2*FREQ)/(12*32*BAUD)))


Ave_num   EQU 32
VREF_MV   EQU 4096

OP07_CH   EQU 1

DEN_41_GAIN EQU 12300
TCOLD10   EQU 220

TIMER0_RELOAD_1MS EQU (65536-(FREQ/(12*1000)))

ORG 0000H
    ljmp main

DSEG at 30H
x:       ds 4
y:       ds 4
bcd:     ds 5
temp10L: ds 1
temp10H: ds 1

BSEG
mf:  dbit 1

$NOLIST
$include(math32.asm)
$LIST

CSEG

Initialize_Serial_Port:
    clr TR1
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
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret

Send_CRLF:
    mov a, #0DH
    lcall putchar
    mov a, #0AH
    lcall putchar
    ret

PrintDigit_Lead:
    anl a, #0x0F
    jnz PDL_print
    cjne R7, #0, PDL_print
    ret
    
PDL_print:
    mov R7, #1
    add a, #'0'
    lcall putchar
    ret

Print_T10_from_BCD:
    mov R7, #0

    mov a, bcd+1
    swap a
    lcall PrintDigit_Lead

    mov a, bcd+1
    lcall PrintDigit_Lead

    mov a, bcd+0
    swap a
    anl a, #0x0F
    cjne R7, #0, PT_noForce0
    mov a, #0
PT_noForce0:
    mov R7, #1
    add a, #'0'
    lcall putchar

    mov a, #'.'
    lcall putchar

    mov a, bcd+0
    anl a, #0x0F
    add a, #'0'
    lcall putchar
    ret

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

Average_ADC:
    mov R4, A

    mov x+0, #0
    mov x+1, #0
    mov x+2, #0
    mov x+3, #0

    mov R3, #Ave_num

Avg_Loop:
    mov A, R4
    lcall Read_ADC

    mov y+0, R0
    mov y+1, R1
    mov y+2, #0
    mov y+3, #0

    lcall add32
    djnz R3, Avg_Loop

    Load_y(Ave_num)
    lcall div32

    mov R0, x+0
    mov R1, x+1
    ret

Temp_Step:
    mov A, #OP07_CH
    lcall Average_ADC

    mov x+0, R0
    mov x+1, R1
    mov x+2, #0
    mov x+3, #0

    Load_y(VREF_MV)
    lcall mul32
    Load_y(4095)
    lcall div32

    Load_y(1000)
    lcall mul32

    Load_y(DEN_41_GAIN)
    lcall div32

    Load_y(10)
    lcall mul32

    Load_y(TCOLD10)
    lcall add32

    mov temp10L, x+0
    mov temp10H, x+1
    ret

Temp_Print:
    mov x+0, temp10L
    mov x+1, temp10H
    mov x+2, #0
    mov x+3, #0
    lcall hex2bcd
    lcall Print_T10_from_BCD
    lcall Send_CRLF
    ret

Init_All:
    lcall Initialize_Serial_Port
    clr TR0
    anl TMOD, #0xF0
    orl TMOD, #0x01
    ret

Delay_1s:
    mov R2, #250
    lcall waitms
    mov R2, #250
    lcall waitms
    mov R2, #250
    lcall waitms
    mov R2, #250
    lcall waitms
    ret
    
main:
    mov SP, #7FH
    lcall Init_All

Forever:
    lcall Temp_Step
    lcall Temp_Print
    lcall Delay_1s
    ljmp Forever

END
