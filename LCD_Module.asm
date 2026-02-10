; ====================================================================
; LCD_Module.asm - 针对 DE10-Lite (MAX10) 优化的 4-bit 驱动
; ====================================================================
LCD_RS    equ P1.7
LCD_E     equ P1.5
LCD_D4    equ P0.7
LCD_D5    equ P0.5
LCD_D6    equ P0.3
LCD_D7    equ P0.1
; --- 底层硬件延时 ---
DelaySmall:
    mov r7, #80
DSS1: mov r6, #255
DSS2: djnz r6, DSS2
     djnz r7, DSS1
     ret

DelayMs:
    push ar0
    push ar1
DM3: mov r1, #74
DM2: mov r0, #250
DM1: djnz r0, DM1
     djnz r1, DM2
     djnz r2, DM3
    pop ar1
    pop ar0
    ret

; --- LCD 4-bit 原始驱动 ---
LCD_pulse:
    setb LCD_E
    lcall DelaySmall
    clr LCD_E
    lcall DelaySmall
    ret

LCD_byte:
    ; 发送高 4 位
    mov c, ACC.7
    mov LCD_D7, c
    mov c, ACC.6
    mov LCD_D6, c
    mov c, ACC.5
    mov LCD_D5, c
    mov c, ACC.4
    mov LCD_D4, c
    lcall LCD_pulse
    ; 发送低 4 位
    mov c, ACC.3
    mov LCD_D7, c
    mov c, ACC.2
    mov LCD_D6, c
    mov c, ACC.1
    mov LCD_D5, c
    mov c, ACC.0
    mov LCD_D4, c
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
    mov r2, #80
    lcall DelayMs
    mov a, #033h
    lcall LCD_cmd
    mov r2, #10
    lcall DelayMs
    mov a, #033h
    lcall LCD_cmd
    mov r2, #10
    lcall DelayMs
    mov a, #032h
    lcall LCD_cmd
    mov r2, #10
    lcall DelayMs
    mov a, #028h  ; 4-bit, 2 line
    lcall LCD_cmd
    mov a, #00Ch  ; display on
    lcall LCD_cmd
    mov a, #006h  ; entry mode
    lcall LCD_cmd
    mov a, #001h  ; clear display
    lcall LCD_cmd
    mov r2, #20
    lcall DelayMs
    ret

PrintString:
    clr a
    movc a, @a+dptr
    jz PrintDone
    lcall LCD_data
    inc dptr
    sjmp PrintString
PrintDone:
    ret

; ====================================================================
; 高级显示功能 (由 FSM 调用)
; ====================================================================

; 显示设定页面 (State 0 使用)
LCD_ShowSettings:
    mov a, #080H        ; 第一行
    lcall LCD_cmd
    mov dptr, #STR_SOAK
    lcall PrintString
    mov r0, #0x34       ; Soak_Temp 地址
    lcall LCD_PrintTemp3_R0
    
    mov a, #0C0H        ; 第二行
    lcall LCD_cmd
    mov dptr, #STR_REFL
    lcall PrintString
    mov r0, #0x37       ; Reflow_Temp 地址
    lcall LCD_PrintTemp3_R0
    ret

; 显示运行页面 (State 1-5 使用)
LCD_ShowRun:
    mov a, #080H        ; 第一行显示温度
    lcall LCD_cmd
    mov dptr, #STR_T
    lcall PrintString
    lcall LCD_PrintTemp3_curr
    mov dptr, #STR_TJ
    lcall PrintString

    mov a, #0C0H        ; 第二行显示时间和状态
    lcall LCD_cmd
    lcall LCD_PrintTime2_Elapsed
    mov dptr, #STR_SEC
    lcall PrintString

    ; 状态文字分支
    jb e_shutdown_flag, _MSG_ERR
    mov a, State_flag
    cjne a, #0, _MSG_S1
    jb oven_on_flag, _MSG_ACT
    mov dptr, #ST_IDLE
    sjmp _MSG_DO
_MSG_ACT: mov dptr, #ST_ACT
    sjmp _MSG_DO
_MSG_S1: cjne a, #1, _MSG_S2
    mov dptr, #ST_RAMP
    sjmp _MSG_DO
_MSG_S2: cjne a, #2, _MSG_S3
    mov dptr, #ST_SOAK
    sjmp _MSG_DO
_MSG_S3: cjne a, #3, _MSG_S4
    mov dptr, #ST_RAMP
    sjmp _MSG_DO
_MSG_S4: cjne a, #4, _MSG_S5
    mov dptr, #ST_SOAK
    sjmp _MSG_DO
_MSG_S5: mov dptr, #ST_COOL
_MSG_DO:
    lcall PrintString
    ret
_MSG_ERR:
    mov dptr, #ST_ERROR
    lcall PrintString
    ret

; --- 内部辅助子程序 ---

; 打印 R0 指向的 BCD 温度 (3位)
LCD_PrintTemp3_R0:
    inc r0              ; 移动到百位地址
    mov a, @r0
    anl a, #0Fh
    add a, #'0'
    lcall LCD_data
    dec r0              ; 移动回十位个位地址
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

; 打印当前温度 (读取 33H 和 34H)
; --- 内部辅助子程序 ---

; 打印当前温度 (读取 Temp_High=0x35 和 Temp_Low=0x34)
LCD_PrintTemp3_curr:
    push acc
    push ar0
    
    ; 1. 打印百位
    mov r0, #Temp_High       ; 显式使用 EQU 名字 (0x35)
    mov a, @r0
    anl a, #0Fh
    add a, #'0'
    lcall LCD_data
    
    ; 2. 打印十位
    mov r0, #Temp_Low        ; 显式使用 EQU 名字 (0x34)
    mov a, @r0
    swap a                   ; 取高4位（十位）
    anl a, #0Fh
    add a, #'0'
    lcall LCD_data
    
    ; 3. 打印个位
    mov a, @r0               ; 重新读一次低位字节
    anl a, #0Fh              ; 取低4位（个位）
    add a, #'0'
    lcall LCD_data
    
    pop ar0
    pop acc
    ret

; 打印运行时间 (读取 Time_Elapsed_High=0x33 和 Time_Elapsed_Low=0x32)
LCD_PrintTime2_Elapsed:
    push acc
    push ar0

    ; 1. 打印百位
    mov r0, #Time_Elapsed_High ; (0x33)
    mov a, @r0
    anl a, #0Fh
    add a, #'0'
    lcall LCD_data
    
    ; 2. 打印十位
    mov r0, #Time_Elapsed_Low  ; (0x32)
    mov a, @r0
    swap a
    anl a, #0Fh
    add a, #'0'
    lcall LCD_data
    
    ; 3. 打印个位
    mov a, @r0
    anl a, #0Fh
    add a, #'0'
    lcall LCD_data
    
    pop ar0
    pop acc
    ret
    
STR_SOAK: DB 'SOAK ', 0
STR_REFL: DB 'REFL ', 0
STR_T:    DB 'T=', 0
STR_TJ:   DB 'C Tj=22C', 0
STR_SEC:  DB 's ', 0

ST_COOL: DB 'COOL DOWN ', 0

ST_IDLE: DB 'IDLE      ',0
ST_ACT:  DB 'ACTIVATION',0
ST_RAMP: DB 'RAMP UP   ',0
ST_SOAK: DB 'SOAKING   ',0
ST_ERROR:DB 'ERROR     ',0
