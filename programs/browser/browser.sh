#!/ucvm/bin/sh
# UCVM Web Browser v0.2
# Ring: USER
# Size: 4KB
#
# Simple text-based browser that interfaces with Claude's web_search
# (Brave Search) and web_fetch tools through the UCVM network daemon

.text:
browser_main:
    mov sp, 0x9000      ; Stack for browser
    call init_browser
    
main_loop:
    call print_prompt
    call read_command
    call parse_command
    call execute_command
    jmp main_loop

init_browser:
    ; Initialize browser state
    mov dword [history_ptr], 0
    mov dword [current_page], 0
    ret

execute_command:
    ; Command dispatch
    cmp ax, CMD_SEARCH
    je do_search
    cmp ax, CMD_FETCH
    je do_fetch
    cmp ax, CMD_BACK
    je do_back
    cmp ax, CMD_HELP
    je show_help
    cmp ax, CMD_QUIT
    je browser_exit
    ret

do_search:
    ; Check ring permissions
    call check_ring_level
    cmp ax, USER
    jl permission_denied
    
    ; Send search request via network daemon
    mov si, search_query
    mov di, network_buffer
    call prepare_search_request
    
    ; System call to network daemon (uses Brave Search)
    mov ax, SYS_NET_SEND
    mov bx, NODE_NETWORK
    int 0x80
    
    ; Wait for response
    call wait_for_response
    call display_results
    ret

do_fetch:
    ; Similar to search but for specific URLs
    call check_ring_level
    mov si, url_buffer
    mov di, network_buffer
    call prepare_fetch_request
    mov ax, SYS_NET_SEND
    mov bx, NODE_NETWORK
    int 0x80
    call wait_for_response
    call display_page
    ret

.data:
prompt_str: .asciz "browser> "
history_buffer: .space 1024
network_buffer: .space 4096
search_query: .space 256
url_buffer: .space 256
history_ptr: .dword 0
current_page: .dword 0

help_text:
    .asciz "Commands:\n"
    .asciz "  search <query>  - Search the web (via Brave Search)\n"
    .asciz "  fetch <url>     - Fetch webpage content\n"
    .asciz "  back           - Go back in history\n"
    .asciz "  history        - Show browsing history\n"
    .asciz "  quit          - Exit browser\n"
    .asciz "\n"
    .asciz "Note: All searches use Brave Search API\n"

.bss:
result_cache: .space 16384  ; 16KB for caching results