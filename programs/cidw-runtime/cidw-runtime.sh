#!/ucvm/bin/cidw-runtime
; CIDW - Claude-Integrated Development Workflow Manager
; Version: 1.0.0
; Ring: USER (with kernel module access via toolbridge)
; Size: 64KB

.text:
main:
    mov sp, 0xE000
    call parse_args
    call init_cidw
    call load_workflow
    call execute_workflow
    call cleanup
    ret

init_cidw:
    ; Initialize CIDW subsystems
    call init_artifact_registry
    call init_tool_dispatcher
    call init_context_manager
    call check_toolbridge
    ret

check_toolbridge:
    ; Verify toolbridge module is loaded
    mov ax, SYS_MODULE_CHECK
    mov bx, toolbridge_name
    int 0x80
    test ax, ax
    jz .no_toolbridge
    ret
.no_toolbridge:
    mov si, no_toolbridge_msg
    call print_error
    mov ax, 1
    ret

execute_workflow:
    mov si, [workflow_ptr]
.phase_loop:
    mov al, [si]
    test al, al
    jz .done
    
    ; Get phase details
    push si
    call get_phase_type
    cmp ax, PHASE_WEB
    je .execute_web_phase
    cmp ax, PHASE_CLI
    je .execute_cli_phase
    cmp ax, PHASE_MIXED
    je .execute_mixed_phase
    
.execute_web_phase:
    call execute_web_tools
    jmp .next_phase
    
.execute_cli_phase:
    call execute_cli_tools
    jmp .next_phase
    
.execute_mixed_phase:
    call execute_mixed_tools
    
.next_phase:
    pop si
    add si, PHASE_STRUCT_SIZE
    jmp .phase_loop
.done:
    ret

execute_web_tools:
    ; Handle Web-based tools
    push bp
    mov bp, sp
    
    ; Check action type
    mov bx, [current_phase]
    mov ax, [bx+phase_action]
    
    cmp ax, ACTION_SEARCH
    je .do_search
    cmp ax, ACTION_ARTIFACT
    je .do_artifact
    cmp ax, ACTION_REPL
    je .do_repl
    jmp .done

.do_search:
    ; Execute web search via toolbridge
    mov di, search_buffer
    mov si, [bx+phase_query]
    call copy_string
    
    ; System call to toolbridge
    mov ax, SYS_WEBSEARCH
    mov bx, search_buffer
    mov cx, 5  ; max results
    int 0x80
    
    ; Store results in artifact
    call create_search_artifact
    jmp .done

.do_artifact:
    ; Create or update artifact
    mov ax, SYS_ARTIFACT
    mov bx, [current_artifact_cmd]
    int 0x80
    
    ; Update registry
    call update_artifact_registry
    jmp .done

.do_repl:
    ; Execute REPL analysis
    mov ax, SYS_COMPUTE
    mov bx, [repl_code_ptr]
    mov cx, 5000  ; 5 second timeout
    int 0x80
    
    ; Store analysis results
    call create_analysis_artifact
    
.done:
    leave
    ret

create_handoff_document:
    ; Generate standardized handoff between Web and CLI
    push bp
    mov bp, sp
    
    ; Create handoff structure
    call allocate_artifact
    mov [handoff_artifact], ax
    
    ; Fill template
    mov di, ax
    mov si, handoff_template
    call copy_template
    
    ; Add task details
    call add_task_id
    call add_source_artifacts
    call add_objectives
    call add_requirements
    call add_test_criteria
    
    ; Register handoff
    call register_handoff
    
    leave
    ret

manage_artifacts:
    ; Artifact management system
    push bp
    mov bp, sp
    
    mov ax, [artifact_command]
    cmp ax, CMD_LIST
    je .list_artifacts
    cmp ax, CMD_CREATE
    je .create_artifact
    cmp ax, CMD_UPDATE
    je .update_artifact
    cmp ax, CMD_DELETE
    je .delete_artifact
    
.list_artifacts:
    mov si, artifact_registry
    call print_artifact_list
    jmp .done
    
.create_artifact:
    call allocate_artifact_slot
    call initialize_artifact
    jmp .done
    
.update_artifact:
    call find_artifact
    call update_artifact_content
    jmp .done
    
.delete_artifact:
    call find_artifact
    call remove_from_registry
    
.done:
    leave
    ret

workflow_state_machine:
    ; Manage workflow phases and transitions
    push bp
    mov bp, sp
    
    ; Get current state
    mov ax, [workflow_state]
    
    ; State dispatch table
    cmp ax, STATE_RESEARCH
    je .research_phase
    cmp ax, STATE_DESIGN
    je .design_phase
    cmp ax, STATE_IMPL_PLAN
    je .implementation_planning
    cmp ax, STATE_IMPLEMENT
    je .implementation_phase
    cmp ax, STATE_INTEGRATE
    je .integration_phase
    cmp ax, STATE_COMPLETE
    je .complete
    
.research_phase:
    call do_research_tasks
    mov [workflow_state], STATE_DESIGN
    jmp .done
    
.design_phase:
    call do_design_tasks
    mov [workflow_state], STATE_IMPL_PLAN
    jmp .done
    
.implementation_planning:
    call create_cli_tasks
    call validate_with_repl
    mov [workflow_state], STATE_IMPLEMENT
    jmp .done
    
.implementation_phase:
    call switch_to_cli_context
    call process_implementation
    mov [workflow_state], STATE_INTEGRATE
    jmp .done
    
.integration_phase:
    call merge_results
    call update_documentation
    mov [workflow_state], STATE_COMPLETE
    
.complete:
    call export_project_state
    
.done:
    leave
    ret

; Tool coordination functions
coordinate_tools:
    ; Orchestrate tool usage based on phase
    push bp
    mov bp, sp
    sub sp, 16
    
    ; Determine tool requirements
    call analyze_phase_needs
    mov [tool_mask], ax
    
    ; Execute in optimal order
    test ax, TOOL_SEARCH
    jz .skip_search
    call invoke_web_search
    
.skip_search:
    test ax, TOOL_REPL
    jz .skip_repl
    call invoke_repl_analysis
    
.skip_repl:
    test ax, TOOL_ARTIFACT
    jz .skip_artifact
    call manage_artifacts
    
.skip_artifact:
    test ax, TOOL_CLI
    jz .done
    call prepare_cli_handoff
    
.done:
    leave
    ret

.data:
; Workflow templates
research_template:
    .db PHASE_WEB
    .dw ACTION_SEARCH
    .asciz "best practices"
    .dw ACTION_ARTIFACT
    .asciz "research_summary"
    .db 0

design_template:
    .db PHASE_WEB
    .dw ACTION_ARTIFACT
    .asciz "architecture_diagram"
    .dw ACTION_ARTIFACT  
    .asciz "api_specification"
    .db 0

implementation_template:
    .db PHASE_CLI
    .dw ACTION_IMPLEMENT
    .asciz "backend_api"
    .dw ACTION_TEST
    .asciz "unit_tests"
    .db 0

; Handoff document template
handoff_template:
    .asciz "## CLI Implementation Task"
    .asciz "**Task ID:** %s"
    .asciz "**Source Artifacts:** %s"
    .asciz "**Objectives:**"
    .asciz "- %s"
    .asciz "**Technical Requirements:**"
    .asciz "- %s"
    .asciz "**Test Criteria:**"
    .asciz "- %s"
    .asciz "**Expected Outputs:**"
    .asciz "- %s"

; Messages
no_toolbridge_msg: .asciz "Error: toolbridge module not loaded\n"
phase_complete_msg: .asciz "[CIDW] Phase %s completed\n"
artifact_created_msg: .asciz "[CIDW] Artifact '%s' created (ID: %d)\n"
handoff_ready_msg: .asciz "[CIDW] Handoff document ready for CLI phase\n"

; Module name
toolbridge_name: .asciz "toolbridge"

; Workflow states
STATE_INIT          equ 0
STATE_RESEARCH      equ 1
STATE_DESIGN        equ 2
STATE_IMPL_PLAN     equ 3
STATE_IMPLEMENT     equ 4
STATE_INTEGRATE     equ 5
STATE_COMPLETE      equ 6

; Phase types
PHASE_WEB          equ 1
PHASE_CLI          equ 2
PHASE_MIXED        equ 3

; Action types
ACTION_SEARCH      equ 1
ACTION_ARTIFACT    equ 2
ACTION_REPL        equ 3
ACTION_IMPLEMENT   equ 4
ACTION_TEST        equ 5

; Tool flags
TOOL_SEARCH        equ 0x01
TOOL_REPL          equ 0x02
TOOL_ARTIFACT      equ 0x04
TOOL_CLI           equ 0x08

; Structure sizes
PHASE_STRUCT_SIZE  equ 32
ARTIFACT_SIZE      equ 1024

.bss:
workflow_ptr:       .quad 0
current_phase:      .quad 0
workflow_state:     .word 0
artifact_registry:  .space 4096
search_buffer:      .space 512
repl_code_buffer:   .space 8192
handoff_artifact:   .quad 0
artifact_count:     .word 0
tool_mask:          .word 0
current_artifact_cmd: .quad 0