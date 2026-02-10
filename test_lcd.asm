$NOLIST
$MODMAX10
$LIST

; ====================================================================
LCD_RS    equ P1.7
LCD_E     equ P1.1
LCD_D4    equ P0.7
LCD_D5    equ P0.5
LCD_D6    equ P0.3
LCD_D7    equ P0.1

; ====================================================================
DSEG AT 30H
curr_temp_0:  DS 1
curr_temp_1:  DS 1
Time_Elapsed: DS 1
State_flag:   DS 1

BSEG AT 0
e_shutdown_bit: DBIT 1
oven_on_bit:    DBIT 1

; ====================================================================
CSEG
ORG 0000H
    ljmp main

; ====================================================================
DelaySmall:
    mov r7,#80
DSS1: mov r6,#255
DSS2: djnz r6,DSS2
     djnz r7,DSS1
     ret

DelayMs:
    push ar0
    push ar1
DM3: mov r1,#74
DM2: mov r0,#250
DM1: djnz r0,DM1
     djnz r1,DM2
     djnz r2,DM3
    pop ar1
    pop ar0
    ret

LCD_pulse:
    setb LCD_E
    lcall DelaySmall
    clr LCD_E
    lcall DelaySmall
    ret

LCD_byte:
    mov c,ACC.7
    mov LCD_D7,c
    mov c,ACC.6
    mov LCD_D6,c
    mov c,ACC.5
    mov LCD_D5,c
    mov c,ACC.4
    mov LCD_D4,c
    lcall LCD_pulse
    mov c,ACC.3
    mov LCD_D7,c
    mov c,ACC.2
    mov LCD_D6,c
    mov c,ACC.1
    mov LCD_D5,c
    mov c,ACC.0
    mov LCD_D4,c
    lcall LCD_pulse
    ret

LCD_cmd:
    clr LCD_RS
    lcall LCD_byte
    lcall DelaySmall
    ret

LCD_data:
    setb LCD_RS
    lcall LCD_byte
    lcall DelaySmall
    ret

LCD_init:
    clr LCD_E
    mov r2,#80
    lcall DelayMs
    mov a,#033h
    lcall LCD_cmd
    mov r2,#10
    lcall DelayMs
    mov a,#033h
    lcall LCD_cmd
    mov r2,#10
    lcall DelayMs
    mov a,#032h
    lcall LCD_cmd
    mov r2,#10
    lcall DelayMs
    mov a,#028h
    lcall LCD_cmd
    mov a,#00Ch
    lcall LCD_cmd
    mov a,#006h
    lcall LCD_cmd
    mov a,#001h
    lcall LCD_cmd
    mov r2,#20
    lcall DelayMs
    ret

PrintString:
    clr a
    movc a,@a+dptr
    jz PrintDone
    lcall LCD_data
    inc dptr
    sjmp PrintString
PrintDone:
    ret

; ====================================================================
LCD_PrintTemp3_curr:
    mov r0, #31H
    mov a, @r0
    anl a, #0Fh
    add a, #'0'
    lcall LCD_data
    
    mov r0, #30H
    mov a, @r0
    swap a
    anl a, #0Fh
    add a, #'0'
    lcall LCD_data
    
    mov a, @r0
    anl a, #0Fh
    add a, #'0'
    lcall LCD_data
    ret

LCD_PrintTime2_Elapsed:
    mov r0, #32H
    mov a, @r0
    swap a
    anl a, #0Fh
    add a, #'0'
    lcall LCD_data
    mov a, @r0
    anl a, #0Fh
    add a, #'0'
    lcall LCD_data
    ret

; ====================================================================
LCD_ShowRun:
    mov a, #080H
    lcall LCD_cmd
    mov dptr, #STR_T
    lcall PrintString
    lcall LCD_PrintTemp3_curr
    mov dptr, #STR_TJ
    lcall PrintString

    mov a, #0C0H
    lcall LCD_cmd
    lcall LCD_PrintTime2_Elapsed
    mov dptr, #STR_SEC
    lcall PrintString

    jb e_shutdown_bit, _ERR_L
    mov a, State_flag
    cjne a, #0, _S1_L
    jb oven_on_bit, _ACT_L
    mov dptr, #ST_IDLE
    sjmp _PRINT_ST
_ACT_L: mov dptr, #ST_ACT
    sjmp _PRINT_ST
_S1_L: cjne a, #1, _S2_L
    mov dptr, #ST_RAMP
    sjmp _PRINT_ST
_S2_L: mov dptr, #ST_SOAK   
_PRINT_ST:
    lcall PrintString
    ret
_ERR_L:
    mov dptr, #ST_ERROR
    lcall PrintString
    ret

; ====================================================================
main:
    mov SP, #7FH
    mov P0MOD, #0FFh
    mov P1MOD, #0FFh

    lcall LCD_init

    mov curr_temp_1, #01h
    mov curr_temp_0, #50h
    mov Time_Elapsed, #45h
    mov State_flag, #1
    
    clr e_shutdown_bit
    setb oven_on_bit

Forever:
    lcall LCD_ShowRun
    
    mov HEX0, #0C0h
    mov r2, #250
    lcall DelayMs
    mov HEX0, #080h
    mov r2, #250
    lcall DelayMs
    sjmp Forever

; ====================================================================
STR_T:   DB 'T=',0
STR_TJ:  DB 'C Tj=22C',0
STR_SEC: DB 's ',0
ST_IDLE: DB 'IDLE      ',0
ST_ACT:  DB 'ACTIVATION',0
ST_RAMP: DB 'RAMP UP   ',0
ST_SOAK: DB 'SOAKING   ',0
ST_ERROR:DB 'ERROR     ',0

END
