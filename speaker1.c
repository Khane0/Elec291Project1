$MOD8052

SPEAKER     BIT     P1.7


T0_RELOAD EQU     0FDH

T0_RELOAD_L EQU     04CH


BEEP_ON_MS  EQU     100
BEEP_OFF_MS EQU     100

RAMP_TO_SOAK EQU    0
SOAK_HOLD         EQU    1
RAMP_REFLOW EQU    2
RANMP_HOLD      EQU    3
SHUTOFF      EQU    4

BSEG    AT 20h
err_beeped: DS 1
done_beeped:DS 1
err_flag:   DS 1
done_flag:  DS 1

            DSEG
ms_cnt:     DS 1
tmp:        DS 1
cur_state:  DS 1
last_state: DS 1

            CSEG
            ORG     0000H
            LJMP    START

            ORG     000BH
            LJMP    T0_ISR

START:
            CLR     SPEAKER
            MOV     TMOD, #01H
            MOV     TH0, #T0_RELOAD_H
            MOV     TL0, #T0_RELOAD_L
            SETB    ET0
            SETB    EA
            CLR     TR0
            MOV     cur_state,  #RAMP_TO_SOAK
            MOV     last_state, #RAMP_TO_SOAK
            CLR     err_beeped
            CLR     done_beeped
            CLR     err_flag
            CLR     done_flag

MAIN_LOOP:
            ACALL   BEEP_ON_STATE_CHANGE
            ACALL   BEEP_ERROR_ONCE
            ACALL   BEEP_DONE_ONCE
            SJMP    MAIN_LOOP

T0_ISR:
            MOV     TH0, #T0_RELOAD_H
            MOV     TL0, #T0_RELOAD_L
            CPL     SPEAKER
            RETI

BEEP_ON_STATE_CHANGE:
            MOV     A, cur_state
            CJNE    A, last_state, _CHG
            RET
_CHG:
            MOV     last_state, A
            ACALL   BEEP_1
            RET

BEEP_ERROR_ONCE:
            JB      err_flag, _ERR_CHECK
            RET
_ERR_CHECK:
            JB      err_beeped, _ERR_DONE
            SETB    err_beeped
            ACALL   BEEP_10
_ERR_DONE:
            RET

BEEP_DONE_ONCE:
            JB      done_flag, _DONE_CHECK
            RET
_DONE_CHECK:
            JB      done_beeped, _DONE_DONE
            SETB    done_beeped
            ACALL   BEEP_5
_DONE_DONE:
            RET

BEEP_1:
            MOV     A, #1
            SJMP    BEEP_N

BEEP_5:
            MOV     A, #5
            SJMP    BEEP_N

BEEP_10:
            MOV     A, #10

BEEP_N:
            MOV     tmp, A

BEEP_LOOP:
            SETB    TR0
            MOV     A, #BEEP_ON_MS
            ACALL   DELAY_MS
            CLR     TR0
            CLR     SPEAKER
            MOV     A, #BEEP_OFF_MS
            ACALL   DELAY_MS
            DJNZ    tmp, BEEP_LOOP
            RET

DELAY_MS:
            MOV     ms_cnt, A

DELAY_MS_LOOP:
            MOV     R7, #250
D1:         MOV     R6, #250
D2:         DJNZ    R6, D2
            DJNZ    R7, D1
            DJNZ    ms_cnt, DELAY_MS_LOOP
            RET

            END