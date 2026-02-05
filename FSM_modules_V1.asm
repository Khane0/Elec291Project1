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
；----------------dseg---------------
Start_Elapsed: ds 1      ; binary seconds since START
State_ID:      ds 1      ; for LCD
Error_Code:    ds 1      ; 1 = <50C@60s

;----------------bseg-----------------
error_flag: dbit 1
cool_flag:  dbit 1
done_flag:  dbit 1

; ============================================================

Handle_RunButton_Toggle:
    ; if NOT pressed (active-low), return
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
    ; clear safety/runtime
    clr error_flag
    mov Error_Code, #0
    mov Start_Elapsed, #0
    mov Time_Secs, #0x00          ; optional: reset displayed time

    ; enter first phase
    clr phase_two_flag
    clr phase_three_flag
    clr phase_four_flag
    clr cool_flag
    clr done_flag

    setb phase_one_flag           ; SOAK_RAMP
    mov State_ID, #ST_SOAK_RAMP

    ; turn oven on
    setb OVEN_POWER
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
    clr cool_flag
    clr done_flag

    ; --- keep error_flag? ---
    ; If abort is user stop, clear error.
    clr error_flag
    mov Error_Code, #0

    ; --- clear safety/runtime ---
    mov Start_Elapsed, #0
    mov Time_Secs, #0x00
    mov State_ID, #ST_IDLE
    clr seconds_flag

    ljmp settings_loop

;=================================================
; Safety timeout + LCD state
; 1-second service: called whenever seconds_flag is set
; - increments Start_Elapsed while running
; - safety timeout: after 60s, if Temp_Read < 50C => ERROR
; - updates State_ID and LCD
; ============================================================

Service_1s:
    jnb seconds_flag, S1_ret
    clr seconds_flag

    ; button has highest priority even here
    lcall Handle_RunButton_Toggle

    ; -------- running? then Start_Elapsed++ --------
    jb  oven_on_flag, S1_inc
    jb  phase_one_flag, S1_inc
    jb  phase_two_flag, S1_inc
    jb  phase_three_flag, S1_inc
    jb  phase_four_flag, S1_inc
    sjmp S1_skip

S1_inc:
    mov a, Start_Elapsed
    inc a
    mov Start_Elapsed, a

S1_skip:
    lcall Safety_Timeout_Check
    lcall Update_State_ID_From_Flags
    lcall LCD_Update_State_Display
S1_ret:
    ret


Safety_Timeout_Check:
    ; Only check while running
    jb  oven_on_flag, STC_go
    jb  phase_one_flag, STC_go
    jb  phase_two_flag, STC_go
    jb  phase_three_flag, STC_go
    jb  phase_four_flag, STC_go
    ret

STC_go:
    ; if Start_Elapsed < 60 return
    mov a, Start_Elapsed
    clr c
    subb a, #SAFE_TIMEOUT_S
    jc  STC_ret

    ; if Temp_Read >= 50 return
    mov a, Temp_Read
    clr c
    subb a, #SAFE_TEMP_C
    jnc STC_ret

    ; trigger ERROR
    setb error_flag
    mov Error_Code, #1
    mov State_ID, #ST_ERROR

    ; immediate heater off + clear phases
    clr OVEN_POWER
    clr oven_on_flag
    clr phase_one_flag
    clr phase_two_flag
    clr phase_three_flag
    clr phase_four_flag

    ljmp Error_Loop

STC_ret:
    ret


Error_Loop:
    ; Heater must stay OFF
    clr OVEN_POWER
    clr oven_on_flag

EL_loop:
    ; single button press clears error and returns to IDLE
    lcall Handle_RunButton_Toggle

    ; optional: keep updating LCD once per second
    lcall Service_1s
    sjmp EL_loop
;==========================================================
settings_loop:
    lcall Handle_RunButton_Toggle

    jnb seconds_flag, settings_loop
    ; seconds_flag will be cleared inside Service_1s
    lcall Service_1s

    lcall keypad_module
    lcall seven_seg_module
    sjmp settings_loop


