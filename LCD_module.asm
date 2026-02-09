;==================== LCD MODULE (FINAL) ====================
; 16x2 HD44780-compatible LCD, 4-bit mode
; Line1:  T=123C t=45s
; Line2:  ST: S_RAMP / S_HOLD / R_RAMP / R_HOLD / IDLE / ERROR
;
; Depends on these external variables (same names as your project):
;   State_flag      ; byte, 0..5
;   e_shutdown_flag ; bit
;   curr_temp       ; BCD bytes from your Read_ADC -> hex2bcd
;                  ; curr_temp+1: hundreds digit in low nibble
;                  ; curr_temp+0: tens in high nibble, ones in low nibble
;   Time_Elapsed    ; BCD (00..99) seconds (your ISR uses DA)
;
; Pins (edit if your wiring differs):
LCD_RS   equ P1.3
LCD_E    equ P1.4
LCD_D4   equ P0.0
LCD_D5   equ P0.1
LCD_D6   equ P0.2
LCD_D7   equ P0.3

;-------- internal RAM used by LCD module --------
LCD_last_state  EQU  60h   ; 1 byte in internal RAM

;-------- short state strings (pad to 8 chars) --------
ST_IDLE:    db "IDLE    ",0
ST_S_RAMP:  db "S_RAMP  ",0
ST_S_HOLD:  db "S_HOLD  ",0
ST_R_RAMP:  db "R_RAMP  ",0
ST_R_HOLD:  db "R_HOLD  ",0
ST_ERROR:   db "ERROR   ",0

;==================== Low-level write ====================
LCD_WriteNibble:
    ; ACC[3:0] -> D7..D4 lines (D4=bit0)
    mov c, acc.0
    mov LCD_D4, c
    mov c, acc.1
    mov LCD_D5, c
    mov c, acc.2
    mov LCD_D6, c
    mov c, acc.3
    mov LCD_D7, c

    setb LCD_E
    lcall LCD_Delay100us
    clr  LCD_E
    lcall LCD_Delay100us
    ret

LCD_WriteByte:
    ; send high nibble then low nibble (4-bit mode)
    push acc
    swap a
    anl  a, #0Fh
    lcall LCD_WriteNibble
    pop  acc
    anl  a, #0Fh
    lcall LCD_WriteNibble
    ret

LCD_Cmd:
    clr LCD_RS
    lcall LCD_WriteByte
    lcall LCD_Delay100us
    ret

LCD_Data:
    setb LCD_RS
    lcall LCD_WriteByte
    lcall LCD_Delay100us
    ret

;==================== Cursor helpers ====================
LCD_GotoLine1:
    mov a, #080h
    lcall LCD_Cmd
    ret

LCD_GotoLine2:
    mov a, #0C0h
    lcall LCD_Cmd
    ret

;==================== Init ====================
LCD_Init:
    clr LCD_E
    clr LCD_RS
    lcall LCD_Delay20ms

    ; 4-bit init sequence
    mov a, #03h
    lcall LCD_WriteNibble
    lcall LCD_Delay5ms
    mov a, #03h
    lcall LCD_WriteNibble
    lcall LCD_Delay5ms
    mov a, #03h
    lcall LCD_WriteNibble
    lcall LCD_Delay5ms
    mov a, #02h
    lcall LCD_WriteNibble
    lcall LCD_Delay5ms

    ; function set: 4-bit, 2 lines, 5x8
    mov a, #028h
    lcall LCD_Cmd
    ; display on, cursor off
    mov a, #00Ch
    lcall LCD_Cmd
    ; entry mode
    mov a, #006h
    lcall LCD_Cmd
    ; clear display
    mov a, #001h
    lcall LCD_Cmd
    lcall LCD_Delay5ms

    mov LCD_last_state, #0FFh ; force first state update
    ret

;==================== Print string (DPTR -> 0-terminated) ====================
LCD_PrintString:
    clr a
LPS_loop:
    movc a, @a+dptr
    jz   LPS_done
    lcall LCD_Data
    inc  dptr
    clr  a
    sjmp LPS_loop
LPS_done:
    ret

;==================== Line1: T=123C t=45s ====================
; Uses your curr_temp BCD layout and Time_Elapsed BCD (00..99)
LCD_UpdateLine1:
    lcall LCD_GotoLine1

    mov a, #'T'      ; T=
    lcall LCD_Data
    mov a, #'='
    lcall LCD_Data

    ; print temp 3 digits from curr_temp (BCD)
    lcall LCD_PrintTemp3Digits

    mov a, #'C'
    lcall LCD_Data
    mov a, #' '
    lcall LCD_Data

    mov a, #'t'      ; t=
    lcall LCD_Data
    mov a, #'='
    lcall LCD_Data

    ; print time as 2-digit seconds from Time_Elapsed (BCD)
    lcall LCD_PrintTime2Digits

    mov a, #'s'
    lcall LCD_Data

    ; pad rest with spaces to overwrite old chars
    mov a, #' '
    lcall LCD_Data
    mov a, #' '
    lcall LCD_Data
    mov a, #' '
    lcall LCD_Data
    ret

; temp: curr_temp+1 low nibble = hundreds
;       curr_temp+0 high nibble = tens, low nibble = ones
LCD_PrintTemp3Digits:
    ; hundreds
    mov a, curr_temp+1
    anl a, #0Fh
    add a, #'0'
    lcall LCD_Data
    ; tens
    mov a, curr_temp+0
    swap a
    anl a, #0Fh
    add a, #'0'
    lcall LCD_Data
    ; ones
    mov a, curr_temp+0
    anl a, #0Fh
    add a, #'0'
    lcall LCD_Data
    ret

; time: Time_Elapsed is BCD 00..99 (your ISR uses DA)
LCD_PrintTime2Digits:
    mov a, Time_Elapsed
    ; tens nibble
    swap a
    anl a, #0Fh
    add a, #'0'
    lcall LCD_Data
    ; ones nibble
    mov a, Time_Elapsed
    anl a, #0Fh
    add a, #'0'
    lcall LCD_Data
    ret

;==================== Line2: state (update only if changed) ====================
LCD_UpdateLine2_StateIfChanged:
    ; compute desired state code into A:
    ; priority: e_shutdown_flag -> ERROR
    jb  e_shutdown_flag, LCD_state_err

    mov a, State_flag
    ; if equals last, return
    cjne a, LCD_last_state, LCD_state_changed
    ret

LCD_state_err:
    mov a, #5          ; use 5 to represent error in last_state cache
    cjne a, LCD_last_state, LCD_state_changed
    ret

LCD_state_changed:
    mov LCD_last_state, a

    lcall LCD_GotoLine2
    ; print "ST: "
    mov a, #'S'
    lcall LCD_Data
    mov a, #'T'
    lcall LCD_Data
    mov a, #':'
    lcall LCD_Data
    mov a, #' '
    lcall LCD_Data

    ; choose string by A (cached state)
    mov a, LCD_last_state
    cjne a, #0, _st1
    mov dptr, #ST_IDLE
    sjmp _stprint
_st1:
    cjne a, #1, _st2
    mov dptr, #ST_S_RAMP
    sjmp _stprint
_st2:
    cjne a, #2, _st3
    mov dptr, #ST_S_HOLD
    sjmp _stprint
_st3:
    cjne a, #3, _st4
    mov dptr, #ST_R_RAMP
    sjmp _stprint
_st4:
    cjne a, #4, _sterr
    mov dptr, #ST_R_HOLD
    sjmp _stprint
_sterr:
    mov dptr, #ST_ERROR

_stprint:
    lcall LCD_PrintString

    ; pad to end of line (16 chars total, we've printed 4 + 8 = 12, add 4 spaces)
    mov a, #' '
    lcall LCD_Data
    mov a, #' '
    lcall LCD_Data
    mov a, #' '
    lcall LCD_Data
    mov a, #' '
    lcall LCD_Data
    ret

;==================== Delay routines ====================
; Conservative delays; tune if needed.
LCD_Delay100us:
    mov R6, #25
D100_loop:
    djnz R6, D100_loop
    ret

LCD_Delay1ms:
    mov R7, #250
D1_loop:
    mov R6, #4
D1_in:
    djnz R6, D1_in
    djnz R7, D1_loop
    ret

LCD_Delay5ms:
    mov R5, #5
D5_loop:
    lcall LCD_Delay1ms
    djnz R5, D5_loop
    ret

LCD_Delay20ms:
    mov R5, #20
D20_loop:
    lcall LCD_Delay1ms
    djnz R5, D20_loop
    ret

;==================== END LCD MODULE ====================
