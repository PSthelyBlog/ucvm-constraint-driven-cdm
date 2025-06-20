; === TIMESYNC - UCVM Time Synchronization Utility ===
; One-shot time synchronization with host system via toolbridge
; Ring: KERNEL (privileged time operations)
; Dependencies: toolbridge.kmod (MANDATORY)
; Size: 3KB

.text:
; Entry point - immediate dependency verification
timesync_main:
    ; Minimal stack setup
    mov rsp, 0x9000
    
    ; CRITICAL: Check toolbridge FIRST before any other operations
    call strict_toolbridge_check
    ; If we return here, check failed and we should be dead
    ; This should never happen, but add failsafe
    jmp .fatal_halt

; Strict dependency checking with multiple verification methods
strict_toolbridge_check:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    ; Set check counter
    mov qword [rsp], 0           ; Failed checks counter
    
    ; Method 1: Check if module is in kernel module list
    call check_module_loaded
    test rax, rax
    jnz .check1_pass
    inc qword [rsp]
    
.check1_pass:
    ; Method 2: Verify syscalls are registered
    call verify_syscalls_exist
    test rax, rax
    jnz .check2_pass
    inc qword [rsp]
    
.check2_pass:
    ; Method 3: Check device nodes exist
    call verify_device_nodes
    test rax, rax
    jnz .check3_pass
    inc qword [rsp]
    
.check3_pass:
    ; Method 4: Try to open toolbridge device
    call test_device_open
    test rax, rax
    jnz .check4_pass
    inc qword [rsp]
    
.check4_pass:
    ; If ANY check failed, abort immediately
    cmp qword [rsp], 0
    jne .dependency_failed
    
    ; All checks passed - continue with main program
    call timesync_main_verified
    leave
    ret
    
.dependency_failed:
    ; Log detailed failure information
    lea rdi, [crit_no_toolbridge]
    call kernel_crit             ; Critical log level
    
    ; Log which checks failed
    mov rax, [rsp]
    lea rdi, [crit_checks_failed]
    mov rsi, rax
    call kernel_crit_fmt
    
    ; Print to console for visibility
    lea rdi, [fatal_banner]
    call kernel_console_write
    
    ; Attempt to provide helpful information
    call suggest_module_load
    
    ; Terminate immediately with error
    mov rdi, 127                 ; Special exit code for missing deps
    call kernel_exit_immediate   ; No cleanup, just die
    
    ; Failsafe: If exit fails, halt the CPU
    cli                          ; Disable interrupts
    hlt                          ; Halt processor
    jmp $                        ; Infinite loop if somehow we continue

; Continue with verified toolbridge available
timesync_main_verified:
    push rbp
    mov rbp, rsp
    
    ; NOW we can safely continue with normal initialization
    call check_privileges
    test rax, rax
    jnz .privilege_error
    
    call parse_args
    call init_timesync
    call register_with_toolbridge
    
    ; Perform sync
    call perform_sync_once
    test rax, rax
    js .sync_failed
    
    call report_sync_results
    
    ; Success exit
    xor rax, rax
    call kernel_exit
    
.privilege_error:
    lea rdi, [err_privilege]
    call kernel_error
    mov rax, 2
    call kernel_exit
    
.sync_failed:
    lea rdi, [err_sync_failed]
    call kernel_error
    mov rax, 3
    call kernel_exit

; Fatal halt if dependency check is bypassed somehow
.fatal_halt:
    lea rdi, [crit_fatal_halt]
    call kernel_panic            ; This will halt the system

; Detailed module loaded check
check_module_loaded:
    push rbp
    mov rbp, rsp
    
    ; Try multiple methods to ensure module is loaded
    
    ; Check /proc/modules
    lea rdi, [proc_modules_path]
    mov rsi, O_RDONLY
    call kernel_open
    cmp rax, -1
    je .module_not_found
    
    mov r12, rax                 ; Save fd
    
    ; Read modules file
    lea rsi, [module_buffer]
    mov rdx, 4096
    mov rdi, r12
    call kernel_read
    
    ; Close file
    mov rdi, r12
    call kernel_close
    
    ; Search for toolbridge
    lea rdi, [module_buffer]
    lea rsi, [toolbridge_pattern]
    call strstr
    test rax, rax
    jz .module_not_found
    
    ; Verify it's actually loaded (not just in file)
    lea rdi, [module_buffer]
    lea rsi, [loaded_pattern]
    call strstr
    test rax, rax
    jz .module_not_found
    
    mov rax, 1                   ; Found
    leave
    ret
    
.module_not_found:
    xor rax, rax
    leave
    ret

; Verify syscalls are actually registered
verify_syscalls_exist:
    push rbp
    mov rbp, rsp
    
    ; Test each syscall with invalid params to check existence
    
    ; Test SYS_COMPUTE (0x80)
    xor rdi, rdi
    xor rsi, rsi
    mov rax, 0x80
    syscall
    cmp rax, -ENOSYS             ; No such syscall
    je .syscalls_missing
    
    ; Test SYS_WEBSEARCH (0x81)
    xor rdi, rdi
    xor rsi, rsi
    mov rax, 0x81
    syscall
    cmp rax, -ENOSYS
    je .syscalls_missing
    
    ; Test SYS_ARTIFACT (0x82)
    xor rdi, rdi
    xor rsi, rsi
    mov rax, 0x82
    syscall
    cmp rax, -ENOSYS
    je .syscalls_missing
    
    mov rax, 1                   ; All exist
    leave
    ret
    
.syscalls_missing:
    xor rax, rax
    leave
    ret

; Verify device nodes exist and have correct properties
verify_device_nodes:
    push rbp
    mov rbp, rsp
    sub rsp, 144                 ; struct stat size
    
    ; Check /dev/repl0
    lea rdi, [dev_repl_path]
    lea rsi, [rsp]
    call kernel_stat
    test rax, rax
    jnz .devices_missing
    
    ; Verify it's a character device
    mov ax, [rsp+st_mode]
    and ax, S_IFMT
    cmp ax, S_IFCHR
    jne .devices_missing
    
    ; Check /dev/web0
    lea rdi, [dev_web_path]
    lea rsi, [rsp]
    call kernel_stat
    test rax, rax
    jnz .devices_missing
    
    ; Check /dev/art0
    lea rdi, [dev_art_path]
    lea rsi, [rsp]
    call kernel_stat
    test rax, rax
    jnz .devices_missing
    
    mov rax, 1                   ; All exist
    leave
    ret
    
.devices_missing:
    xor rax, rax
    leave
    ret

; Try to actually open a toolbridge device
test_device_open:
    push rbp
    mov rbp, rsp
    
    ; Try to open /dev/repl0
    lea rdi, [dev_repl_path]
    mov rsi, O_RDONLY
    call kernel_open
    cmp rax, -1
    je .open_failed
    
    ; Success - close it
    mov rdi, rax
    call kernel_close
    
    mov rax, 1
    leave
    ret
    
.open_failed:
    xor rax, rax
    leave
    ret

; Suggest how to load the module
suggest_module_load:
    push rbp
    mov rbp, rsp
    
    lea rdi, [help_load_module]
    call kernel_console_write
    
    ; Check if module file exists
    lea rdi, [module_file_path]
    call kernel_access
    test rax, rax
    jnz .module_file_missing
    
    lea rdi, [help_insmod_cmd]
    call kernel_console_write
    jmp .suggestion_done
    
.module_file_missing:
    lea rdi, [help_no_module_file]
    call kernel_console_write
    
.suggestion_done:
    leave
    ret

; Initialize timesync structures
init_timesync:
    push rbp
    mov rbp, rsp
    
    ; Set default threshold
    mov qword [sync_threshold], 1000  ; 1 second default
    
    ; Clear buffers
    xor rax, rax
    mov [new_timestamp], rax
    mov [old_timestamp], rax
    mov [calculated_drift], rax
    mov [flags], al
    
    leave
    ret

; Check kernel privileges
check_privileges:
    push rbp
    mov rbp, rsp
    
    ; Get current ring level
    mov rax, cs
    and rax, 0x3
    test rax, rax                ; Ring 0?
    jz .has_privilege
    
    mov rax, -EPERM
    leave
    ret
    
.has_privilege:
    xor rax, rax
    leave
    ret

; Register with toolbridge
register_with_toolbridge:
    push rbp
    mov rbp, rsp
    
    ; Open /dev/repl0 to establish connection
    lea rdi, [dev_repl_path]
    mov rsi, O_RDWR
    call kernel_open
    mov [repl_fd], rax
    
    ; Set process name for debugging
    lea rdi, [timesync_ident]
    call set_process_name
    
    leave
    ret

; Parse command line arguments
parse_args:
    push rbp
    mov rbp, rsp
    
    call get_argc
    cmp rax, 1
    jle .no_args
    
    mov r12, rax                 ; Save argc
    call get_argv
    mov r13, rax                 ; Save argv
    
    mov rbx, 1                   ; Start at argv[1]
.parse_loop:
    cmp rbx, r12
    jge .parse_done
    
    mov rdi, [r13 + rbx*8]
    
    ; Check --force
    lea rsi, [arg_force]
    call strcmp
    test rax, rax
    jz .set_force
    
    ; Check --dry-run
    lea rsi, [arg_dry_run]
    call strcmp
    test rax, rax
    jz .set_dry_run
    
    ; Check --broadcast
    lea rsi, [arg_broadcast]
    call strcmp
    test rax, rax
    jz .set_broadcast
    
    ; Check --threshold=N
    lea rsi, [arg_threshold]
    mov rcx, 11                  ; Length of "--threshold="
    call strncmp
    test rax, rax
    jz .set_threshold
    
    ; Unknown argument
    lea rdi, [warn_unknown_arg]
    mov rsi, [r13 + rbx*8]
    call kernel_log_fmt
    
.next_arg:
    inc rbx
    jmp .parse_loop
    
.set_force:
    or byte [flags], FLAG_FORCE
    jmp .next_arg
    
.set_dry_run:
    or byte [flags], FLAG_DRY_RUN
    jmp .next_arg
    
.set_broadcast:
    or byte [flags], FLAG_BROADCAST
    jmp .next_arg
    
.set_threshold:
    add rdi, 11                  ; Skip "--threshold="
    call atoi
    mov [sync_threshold], rax
    jmp .next_arg
    
.no_args:
.parse_done:
    leave
    ret

; Single sync operation
perform_sync_once:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    ; Save current UCVM time
    call get_system_ticks
    mov [old_time], rax
    
    ; Fetch host time via toolbridge
    call fetch_host_time_toolbridge
    test rax, rax
    js .fetch_error
    
    ; Calculate drift
    call calculate_time_drift
    
    ; Check if update needed
    mov rax, [calculated_drift]
    cmp rax, 0
    jge .check_threshold
    neg rax
.check_threshold:
    cmp rax, [sync_threshold]    ; Default 1000ms threshold
    jl .no_update_needed
    
    ; Check dry-run mode
    test byte [flags], FLAG_DRY_RUN
    jnz .dry_run_exit
    
    ; Apply time update
    call update_system_time
    
    ; Broadcast to other nodes if requested
    test byte [flags], FLAG_BROADCAST
    jz .skip_broadcast
    call broadcast_time_update
    
.skip_broadcast:
    mov rax, 0                   ; Success
    leave
    ret
    
.no_update_needed:
    mov byte [sync_result], SYNC_NO_CHANGE
    lea rdi, [info_no_update]
    call kernel_log
    mov rax, 0
    leave
    ret
    
.dry_run_exit:
    mov byte [sync_result], SYNC_DRY_RUN
    lea rdi, [info_dry_run]
    mov rsi, [calculated_drift]
    call kernel_log_fmt
    mov rax, 0
    leave
    ret
    
.fetch_error:
    mov [last_error], rax
    leave
    ret

; Fetch time using toolbridge REPL syscall
fetch_host_time_toolbridge:
    push rbp
    mov rbp, rsp
    sub rsp, 16                  ; Local variables
    
    ; Build REPL script with current UCVM time
    lea rdi, [repl_buffer]
    lea rsi, [repl_time_script_p1]
    call strcpy
    
    ; Append current time
    call get_system_ticks
    mov rdi, rax
    lea rsi, [repl_buffer + 64]
    call itoa
    
    ; Append rest of script
    lea rdi, [repl_buffer]
    call strlen
    add rax, repl_buffer
    mov rdi, rax
    lea rsi, [repl_time_script_p2]
    call strcpy
    
    ; Execute via SYS_COMPUTE
    lea rdi, [repl_buffer]
    mov rsi, 2000                ; 2 second timeout
    mov rax, 0x80                ; SYS_COMPUTE
    syscall
    
    ; Handle all possible returns
    cmp rax, 0
    jl .handle_error
    
    ; Success - rax points to result
    mov [rsp], rax               ; Save result pointer
    
    ; Parse JSON response
    mov rdi, rax
    call parse_json_time_response
    test rax, rax
    jz .parse_error
    
    ; Free result buffer
    mov rdi, [rsp]
    call kernel_free
    
    xor rax, rax                 ; Success
    leave
    ret
    
.handle_error:
    cmp rax, -EPERM
    je .permission_denied
    cmp rax, -EAGAIN
    je .rate_limited
    cmp rax, -EINVAL
    je .invalid_params
    cmp rax, -EBYZANTINE
    je .byzantine_detected
    
    ; Unknown error
    mov [last_error], rax
    leave
    ret
    
.permission_denied:
    lea rdi, [err_repl_permission]
    call kernel_log
    mov rax, -EPERM
    leave
    ret
    
.rate_limited:
    lea rdi, [err_rate_limit]
    call kernel_log
    mov rax, -EAGAIN
    leave
    ret
    
.parse_error:
    lea rdi, [err_parse_failed]
    call kernel_log
    mov rax, -EINVAL
    leave
    ret

; Parse JSON time response
parse_json_time_response:
    push rbp
    mov rbp, rsp
    push rbx
    
    mov rbx, rdi                 ; Save JSON pointer
    
    ; Extract unix timestamp
    lea rsi, [unix_key]
    call json_get_number
    test rax, rax
    jz .invalid_json
    
    ; Validate timestamp is reasonable (year 2020-2030)
    cmp rax, 1577836800000       ; Jan 1 2020
    jl .invalid_timestamp
    cmp rax, 1893456000000       ; Jan 1 2030
    jg .invalid_timestamp
    
    mov [new_timestamp], rax
    
    ; Extract ISO string for logging
    mov rdi, rbx
    lea rsi, [iso_key]
    lea rdx, [iso_time_buffer]
    call json_get_string
    
    mov rax, 1                   ; Success
    pop rbx
    leave
    ret
    
.invalid_json:
    xor rax, rax
    pop rbx
    leave
    ret
    
.invalid_timestamp:
    lea rdi, [err_invalid_time]
    call kernel_log
    xor rax, rax
    pop rbx
    leave
    ret

; Calculate time drift
calculate_time_drift:
    push rbp
    mov rbp, rsp
    
    ; Get current UCVM time in ms
    mov rax, [old_time]
    mov rcx, 1000
    mul rcx
    
    ; Calculate drift
    mov rcx, [new_timestamp]
    sub rcx, rax
    mov [calculated_drift], rcx
    
    leave
    ret

; Update system time
update_system_time:
    push rbp
    mov rbp, rsp
    
    ; Convert new timestamp to ticks
    mov rax, [new_timestamp]
    mov rcx, 1000
    xor rdx, rdx
    div rcx
    
    ; Set new system time
    mov rdi, rax
    call set_system_ticks
    
    mov byte [sync_result], SYNC_SUCCESS
    
    leave
    ret

; Broadcast time update to all nodes
broadcast_time_update:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    
    ; Build time sync message
    lea rdi, [time_update_msg]
    mov byte [rdi], MSG_TIME_SYNC
    mov rax, [new_timestamp]
    mov [rdi+8], rax
    mov rax, [calculated_drift]
    mov [rdi+16], rax
    
    ; Get node list
    call get_active_nodes
    mov r12, rax                 ; Node count
    mov r13, rdx                 ; Node list pointer
    
    xor rbx, rbx                 ; Index
.broadcast_loop:
    cmp rbx, r12
    jge .broadcast_done
    
    ; Skip self
    mov rax, [r13 + rbx*8]
    call get_current_node_id
    cmp rax, rdx
    je .next_node
    
    ; Send update
    mov rdi, rax                 ; Target node
    lea rsi, [time_update_msg]
    mov rdx, 24                  ; Message size
    call send_node_message
    
.next_node:
    inc rbx
    jmp .broadcast_loop
    
.broadcast_done:
    ; Log broadcast complete
    lea rdi, [info_broadcast]
    mov rsi, r12
    call kernel_log_fmt
    
    pop r13
    pop r12
    leave
    ret

; Report sync results
report_sync_results:
    push rbp
    mov rbp, rsp
    
    ; Build report
    lea rdi, [report_header]
    call kernel_print
    
    ; Old time
    lea rdi, [report_old_time]
    mov rsi, [old_time]
    call kernel_print_fmt
    
    ; New time (if fetched successfully)
    cmp qword [new_timestamp], 0
    je .skip_new_time
    lea rdi, [report_new_time]
    mov rsi, [new_timestamp]
    call kernel_print_fmt
    
    ; ISO format time
    lea rdi, [report_iso_time]
    lea rsi, [iso_time_buffer]
    call kernel_print_fmt
    
.skip_new_time:
    ; Drift
    lea rdi, [report_drift]
    mov rsi, [calculated_drift]
    call kernel_print_fmt
    
    ; Result
    movzx rax, byte [sync_result]
    cmp rax, SYNC_SUCCESS
    je .report_success
    cmp rax, SYNC_NO_CHANGE
    je .report_no_change
    cmp rax, SYNC_DRY_RUN
    je .report_dry_run
    cmp rax, SYNC_FAILED
    je .report_failed
    
.report_success:
    lea rdi, [report_success_msg]
    call kernel_print
    jmp .report_done
    
.report_no_change:
    lea rdi, [report_no_change_msg]
    call kernel_print
    jmp .report_done
    
.report_dry_run:
    lea rdi, [report_dry_run_msg]
    call kernel_print
    jmp .report_done
    
.report_failed:
    lea rdi, [report_failed_msg]
    mov rsi, [last_error]
    call kernel_print_fmt
    
.report_done:
    leave
    ret

.data:
; Critical error messages
crit_no_toolbridge: db "CRITICAL: toolbridge kernel module is not loaded!", 0
crit_checks_failed: db "CRITICAL: %d dependency checks failed", 0
crit_fatal_halt:    db "FATAL: Dependency bypass detected - halting system", 0

fatal_banner:   db 10
                db "**********************************************", 10
                db "* FATAL: MISSING REQUIRED DEPENDENCY         *", 10  
                db "* timesync requires toolbridge.kmod module  *", 10
                db "* Execution cannot continue!                 *", 10
                db "**********************************************", 10, 0

; Help messages
help_load_module:    db 10, "To fix this issue:", 10, 0
help_insmod_cmd:     db "  Run: insmod toolbridge.kmod", 10, 0
help_no_module_file: db "  ERROR: toolbridge.kmod file not found!", 10, 0

; File paths
proc_modules_path:   db "/proc/modules", 0
module_file_path:    db "/lib/modules/toolbridge.kmod", 0
dev_repl_path:       db "/dev/repl0", 0
dev_web_path:        db "/dev/web0", 0
dev_art_path:        db "/dev/art0", 0
timesync_ident:      db "timesync", 0

; Search patterns
toolbridge_pattern:  db "toolbridge", 0
loaded_pattern:      db "Live", 0

; Command line arguments
arg_force:      db "--force", 0
arg_dry_run:    db "--dry-run", 0
arg_broadcast:  db "--broadcast", 0
arg_threshold:  db "--threshold=", 0

; REPL script parts
repl_time_script_p1:
    db "const now = new Date();", 10
    db "const ucvm_time = ", 0

repl_time_script_p2:
    db ";", 10
    db "const result = {", 10
    db "  iso: now.toISOString(),", 10
    db "  unix: now.getTime(),", 10
    db "  drift: now.getTime() - ucvm_time", 10
    db "};", 10
    db "console.log(JSON.stringify(result));", 0

; JSON keys
unix_key:   db "unix", 0
iso_key:    db "iso", 0

; Error messages
err_privilege:       db "ERROR: requires KERNEL ring privileges", 10, 0
err_sync_failed:     db "ERROR: time synchronization failed", 10, 0
err_repl_permission: db "ERROR: REPL access denied", 10, 0
err_rate_limit:      db "ERROR: Rate limited by toolbridge", 10, 0
err_parse_failed:    db "ERROR: Failed to parse time response", 10, 0
err_invalid_time:    db "ERROR: Invalid timestamp received", 10, 0

; Info messages
info_no_update:     db "INFO: Time drift within threshold, no update needed", 10, 0
info_dry_run:       db "INFO: Dry run - would adjust time by %d ms", 10, 0
info_broadcast:     db "INFO: Time update broadcast to %d nodes", 10, 0
warn_unknown_arg:   db "WARNING: Unknown argument: %s", 10, 0

; Report format
report_header:      db 10, "=== TIME SYNC REPORT ===", 10, 0
report_old_time:    db "UCVM Time:    t=%d", 10, 0
report_new_time:    db "Host Unix:    %d ms", 10, 0
report_iso_time:    db "Host ISO:     %s", 10, 0
report_drift:       db "Time Drift:   %d ms", 10, 0
report_success_msg: db "Status:       TIME SYNCHRONIZED", 10, 0
report_no_change_msg: db "Status:       NO CHANGE NEEDED", 10, 0
report_dry_run_msg: db "Status:       DRY RUN COMPLETE", 10, 0
report_failed_msg:  db "Status:       FAILED (error %d)", 10, 0

; Message structure
time_update_msg:
    db MSG_TIME_SYNC
    db 0, 0, 0, 0, 0, 0, 0      ; Padding
    dq 0                         ; new_timestamp
    dq 0                         ; drift_ms

; Flags
FLAG_FORCE      equ 0x01
FLAG_DRY_RUN    equ 0x02
FLAG_BROADCAST  equ 0x04

; Sync results
SYNC_SUCCESS    equ 0
SYNC_NO_CHANGE  equ 1
SYNC_DRY_RUN    equ 2
SYNC_FAILED     equ 3

; Constants
O_RDONLY        equ 0
O_RDWR          equ 2
S_IFMT          equ 0xF000
S_IFCHR         equ 0x2000
MSG_TIME_SYNC   equ 0x54
EPERM           equ 1
EAGAIN          equ 11  
EINVAL          equ 22
ENOSYS          equ 38
EBYZANTINE      equ 133
st_mode         equ 16          ; Offset in struct stat

.bss:
module_buffer:      resb 4096
repl_buffer:        resb 512
repl_fd:            resq 1
flags:              resb 1
sync_result:        resb 1
sync_threshold:     resq 1      
old_time:           resq 1
new_timestamp:      resq 1
calculated_drift:   resq 1
iso_time_buffer:    resb 64
last_error:         resq 1
