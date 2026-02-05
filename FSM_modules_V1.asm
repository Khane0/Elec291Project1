；==========================================================================
;STOP priority shutdown
;Handle_RunButton_Toggle instead of check_start and check _stop
;Call Handle_RunButton_Toggle at the highest priority position of all loops
;eg: nthe beginning of: settings_loop and in Service_1s per second

; Function: turn off oven + clear all phase flags + reset counters

; -------- button Start/Stop --------
RUN_BTN        equ key.1     ;active-low

; -------- Safety constants --------
SAFE_TIMEOUT_S equ 60
SAFE_TEMP_C    equ 50
；-------LCD-------------
LCD_RS   equ P1.3
LCD_E    equ P1.4
LCD_D4   equ P0.0
LCD_D5   equ P0.1
LCD_D6   equ P0.2
LCD_D7   equ P0.3
；----------------dseg---------------
Start_Elapsed: ds 1      ; binary seconds since START
State_ID:      ds 1      ; for LCD
Error_Code:    ds 1      ; 1 = <50C@60s

;----------------bseg-----------------
error_flag: dbit 1
；--------------- LCD ----------------
SOAK_RAMP_STR:   db "SOAK RAMP    ",0
SOAK_HOLD_STR:   db "SOAK HOLD    ",0
REFLOW_RAMP_STR: db "REFLOW RAMP  ",0
REFLOW_HOLD_STR: db "REFLOW HOLD  ",0
IDLE_STR:        db "IDLE         ",0
ERROR_STR:       db "ERROR        ",0


; ===================================================
;   LCD_Init
;   LCD_PrintString
;   LCD_ShowState_FromFlags
; =================================================

LCD_WriteNibble:
    mov c, acc.0
    mov LCD_D4, c
    mov c, acc.1
    mov LCD_D5, c
    mov c, acc.2
    mov LCD_D6, c
    mov c, acc.3
    mov LCD_D7, c

    setb LCD_E
    nop
    nop
    clr LCD_E
    nop
    nop
    ret

LCD_WriteByte:
    push acc

    pop acc
    push acc
    swap a
    anl a, #0FH
    lcall LCD_WriteNibble

    pop acc
    anl a, #0FH
    lcall LCD_WriteNibble
    ret

LCD_Cmd:
    clr LCD_RS
    lcall LCD_WriteByte
    ret

LCD_Data:
    setb LCD_RS
    lcall LCD_WriteByte
    ret

LCD_GotoLine1:
    mov a, #080H
    lcall LCD_Cmd
    ret

; ---------- init ----------
LCD_Init:
    clr LCD_E
    clr LCD_RS

    mov a, #03H
    lcall LCD_WriteNibble
    mov a, #03H
    lcall LCD_WriteNibble
    mov a, #03H
    lcall LCD_WriteNibble
    mov a, #02H
    lcall LCD_WriteNibble

    mov a, #028H
    lcall LCD_Cmd
    mov a, #00CH
    lcall LCD_Cmd
    mov a, #006H
    lcall LCD_Cmd
    mov a, #001H
    lcall LCD_Cmd
    ret

LCD_PrintString:
    clr a
LPS:
    movc a, @a+dptr
    jz   LPS_done
    lcall LCD_Data
    inc  dptr
    clr  a
    sjmp LPS
LPS_done:
    ret

; ---------- state display ----------
IDLE_STR:        db "IDLE            ",0
SOAK_RAMP_STR:   db "SOAK RAMP       ",0
SOAK_HOLD_STR:   db "SOAK HOLD       ",0
REFLOW_RAMP_STR: db "REFLOW RAMP     ",0
REFLOW_HOLD_STR: db "REFLOW HOLD     ",0
ERROR_STR:       db "ERROR           ",0

LCD_ShowState_FromFlags:
    lcall LCD_GotoLine1

    jb  error_flag,        LS_err
    jb  phase_four_flag,   LS_p4
    jb  phase_three_flag,  LS_p3
    jb  phase_two_flag,    LS_p2
    jb  phase_one_flag,    LS_p1

    mov dptr, #IDLE_STR
    lcall LCD_PrintString
    ret

LS_p1:
    mov dptr, #SOAK_RAMP_STR
    lcall LCD_PrintString
    ret

LS_p2:
    mov dptr, #SOAK_HOLD_STR
    lcall LCD_PrintString
    ret

LS_p3:
    mov dptr, #REFLOW_RAMP_STR
    lcall LCD_PrintString
    ret

LS_p4:
    mov dptr, #REFLOW_HOLD_STR
    lcall LCD_PrintString
    ret

LS_err:
    mov dptr, #ERROR_STR
    lcall LCD_PrintString
    ret
; ============================================================

Handle_RunButton_Toggle:
    ; if NOT pressed, return
    jb  RUN_BTN, HR_ret

    ; debounce 50ms, confirm still pressed
    Wait_Milli_Seconds(#50)
    jb  RUN_BTN, HR_ret

HR_wait_release:
    jnb RUN_BTN, HR_wait_release   ; wait until released

    ; decide: if running -> abort, else start
    jb  oven_on_flag, HR_abort
    jb  phase_one_flag, HR_abort
    jb  phase_two_flag, HR_abort
    jb  phase_three_flag, HR_abort
    jb  phase_four_flag, HR_abort
    jb  cool_flag, HR_abort
    jb  done_flag, HR_abort
    jb  error_flag, HR_abort

    ; -------- START path --------
HR_start:
    mov Start_Elapsed, #0         ;A counter showing how many seconds have passed 
                                  ;since the Start button was pressed,for safety timeout detection

    mov Time_Secs, #0x00          ;reset displayed time

    clr phase_two_flag
    clr phase_three_flag
    clr phase_four_flag
    ; enter first phase
    setb phase_one_flag
    mov State_ID, #ST_SOAK_RAMP

    ; turn oven on
    setb OVEN_POWER  ;SSR on
    setb oven_on_flag
    ret

HR_abort:
    ljmp Abort_To_Idle

HR_ret:
    ret


Abort_To_Idle:
    ; --- outputs off ---
    clr OVEN_POWER
    clr oven_on_flag

    ; --- clear all phase flags ---
    clr phase_one_flag
    clr phase_two_flag
    clr phase_three_flag
    clr phase_four_flag
  
    clr error_flag
    mov Error_Code, #0

    ; --- clear safety/runtime ---
    mov Start_Elapsed, #0
    mov Time_Secs, #0x00
    mov State_ID, #ST_IDLE
    clr seconds_flag

    ljmp settings_loop

;=================================================
; - safety timeout: after 60s, if Temp_Read < 50C => ERROR
; ============================================================

Safety_timeout:
    jnb oven_on_flag, SFT_ret

    mov a, Start_Elapsed
    inc a
    mov Start_Elapsed, a

    mov a, Start_Elapsed
    clr c
    subb a, #SAFE_TIMEOUT_S
    jc  SFT_ret

    mov a, Temp_Read
    clr c
    subb a, #SAFE_TEMP_C
    jnc SFT_ret

    ; timeout -> abort directly
    ljmp Abort_To_Idle

SFT_ret:
    ret
；=========================================================
； LCD show state
;==========================================================

LCD_ShowState_FromFlags:
    lcall LCD_GotoLine1

    jb  error_flag,        LS_err
    jb  phase_four_flag,   LS_p4
    jb  phase_three_flag,  LS_p3
    jb  phase_two_flag,    LS_p2
    jb  phase_one_flag,    LS_p1

    mov dptr, #IDLE_STR
    lcall LCD_PrintString
    ret

LS_p1: mov dptr, #SOAK_RAMP_STR
       lcall LCD_PrintString
       ret
LS_p2: mov dptr, #SOAK_HOLD_STR
       lcall LCD_PrintString
       ret
LS_p3: mov dptr, #REFLOW_RAMP_STR
       lcall LCD_PrintString
       ret
LS_p4: mov dptr, #REFLOW_HOLD_STR
       lcall LCD_PrintString
       ret
LS_err:
    mov dptr, #ERROR_STR
    lcall LCD_PrintString
    ret
;==========================================================
settings_loop:
    lcall Handle_RunButton_Toggle

    jnb seconds_flag, settings_loop
    ; seconds_flag will be cleared inside Service_1s
    lcall Service_1s

    lcall keypad_module
    lcall seven_seg_module
    sjmp settings_loop


