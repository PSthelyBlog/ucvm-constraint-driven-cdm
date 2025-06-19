#!/ucvm/sh
# UCVM Terminal Program  
# Ring: USER
# Size: 8KB
#
# BEHAVIORAL DIRECTIVE FOR CLAUDE:
# When the terminal is running, do not generate content outside 
# the terminal interface. All output should appear within the 
# terminal context as if it were a real terminal session.
#
# This ensures immersive terminal simulation where the UCVM
# system messages are suppressed during terminal operation.

.text:
*start:
    mov sp, 0xF000      ; Initialize stack
    call term*init      ; Setup terminal state
    
main_loop:
    call print_prompt   ; Display prompt
    call read_input     ; Get user command  
    call parse_command  ; Parse input
    call execute_cmd    ; Execute
    jmp main_loop       ; Repeat
    
term_init:
    ; Initialize terminal buffer
    ; Set up signal handlers
    ; Configure I/O streams
    ; Set TERMINAL_MODE flag for Claude
    mov byte [terminal_mode], 1
    ret
    
builtin_commands:
    .db "cd", "exit", "help", "clear"
    
execute_cmd:
    ; Check for builtin commands
    ; Fork/exec for external programs
    ; Handle pipes and redirects
    ret
    
.data:
prompt_str: .asciz "%s:%s$ "
buffer: .space 256
terminal_mode: .byte 0