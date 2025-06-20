#!/ucvm/bin/sh
# UCVM Time Synchronization Service
# Ring: KERNEL (requires privileged access to modify system time)
# Size: 4KB
#
# Synchronizes UCVM system time with host system via REPL interface

.text:
timesync_main:
    mov sp, 0x9000      ; Stack for timesync
    call check_privileges
    call init_timesync
    call fetch_host_time
    call update_system_time
    call broadcast_time_update
    call cleanup
    ret

check_privileges:
    ; Verify running in KERNEL ring
    mov ax, [current_ring]
    cmp ax, KERNEL
    jne privilege_error
    ret

fetch_host_time:
    ; Prepare REPL request for host time
    mov si, repl_time_script
    mov di, repl_buffer
    call prepare_repl_request
    
    ; System call to REPL interface
    mov ax, SYS_REPL_EXEC
    mov bx, REPL_HOST_TIME
    int 0x80
    
    ; Parse response
    call parse_time_response
    ret

update_system_time:
    ; Calculate time difference
    mov eax, [new_timestamp]
    sub eax, [old_timestamp]
    mov [time_delta], eax
    
    ; Update system tick counter
    mov eax, [system_ticks]
    add eax, [time_delta]
    mov [system_ticks], eax
    
    ; Update RTC registers
    mov al, [new_hours]
    out RTC_HOURS, al
    mov al, [new_minutes]
    out RTC_MINUTES, al
    mov al, [new_seconds]
    out RTC_SECONDS, al
    ret

broadcast_time_update:
    ; Send time update message to all nodes
    mov cx, [node_count]
    mov si, node_list
update_loop:
    push cx
    mov ax, [si]
    call send_time_update_msg
    add si, 2
    pop cx
    loop update_loop
    ret

.data:
repl_time_script:
    .asciz "const now = new Date();"
    .asciz "const timestamp = now.getTime();"
    .asciz "console.log(`${now.toISOString()}|${timestamp}`);"

time_update_msg:
    .db MSG_TIME_SYNC
    .dw 0  ; node_id
    .dd 0  ; new_timestamp
    .dd 0  ; vector_clock

.bss:
repl_buffer: .space 1024
old_timestamp: .dword 0
new_timestamp: .dword 0
time_delta: .dword 0
new_hours: .byte 0
new_minutes: .byte 0
new_seconds: .byte 0
node_list: .space 256

; RTC ports
RTC_HOURS   equ 0x70
RTC_MINUTES equ 0x71
RTC_SECONDS equ 0x72
