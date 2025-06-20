# UCVM ToolBridge Kernel Module v2.0.0

A kernel module that bridges the UCVM (Universal Computational Virtual Machine) distributed system simulation with Claude's real computational tools, enabling authentic execution of JavaScript code, web searches, and artifact creation from within the simulated environment.

## Overview

The ToolBridge module provides a unique integration layer that allows UCVM processes to access Claude's actual computational capabilities through standard system calls. When UCVM processes need to execute JavaScript, search the web, or create artifacts, the module can trigger real tool invocations rather than simulated responses.

### Key Features

- **Real Tool Execution**: Bridges simulated UCVM processes to Claude's actual tools
- **Three Syscall Interfaces**: Compute (REPL), Web Search, and Artifact management
- **Rate Limiting**: Token bucket algorithm prevents abuse (10 requests/second per process)
- **Byzantine Fault Tolerance**: Malicious nodes blocked from web searches
- **Distributed Consensus**: Optional consensus protocols for distributed operations
- **Kernel-Level Security**: Ring 0 operation with proper permission checks

## Architecture

```
UCVM Process (User Space)
    ↓ syscall
ToolBridge Module (Kernel Space)
    ↓ ;;; CLAUDE: markers
Claude Tool Execution (Real World)
    ↓ results
UCVM Process (receives real data)
```

## Installation

### Prerequisites

- UCVM kernel with module loading support
- Kernel ring 0 privileges
- Available syscall vectors (0x80-0x82)

### Loading the Module

```bash
# Load the module
insmod toolbridge.kmod

# Verify installation
lsmod | grep toolbridge

# Check device nodes
ls -la /dev/repl0 /dev/web0 /dev/art0
```

### Unloading

```bash
rmmod toolbridge
```

## System Calls

### SYS_COMPUTE (0x80) - JavaScript Execution

Execute JavaScript code via Claude's REPL tool.

**Parameters:**
- `rdi`: Pointer to null-terminated JavaScript code string
- `rsi`: Timeout in milliseconds

**Returns:**
- Success: Pointer to result string
- Error: Negative error code (-EPERM, -EAGAIN, -EINVAL)

**Example:**
```asm
; Execute JavaScript
lea rdi, [js_code]    ; "console.log(new Date())"
mov rsi, 1000         ; 1 second timeout
mov rax, 0x80         ; SYS_COMPUTE
syscall
```

### SYS_WEBSEARCH (0x81) - Web Search

Perform web searches using Claude's web_search tool.

**Parameters:**
- `rdi`: Pointer to search query string
- `rsi`: Maximum results (1-10)

**Returns:**
- Success: Pointer to JSON results
- Error: Negative error code (-EPERM, -EBYZANTINE, -EINVAL)

**Example:**
```asm
; Search the web
lea rdi, [query]      ; "UCVM distributed systems"
mov rsi, 5            ; Get 5 results
mov rax, 0x81         ; SYS_WEBSEARCH
syscall
```

### SYS_ARTIFACT (0x82) - Artifact Management

Create or update artifacts through Claude's artifact system.

**Parameters:**
- `rdi`: Pointer to artifact command structure

**Returns:**
- Success: Artifact ID string
- Error: Negative error code

## Claude Integration

The module contains special markers that signal when Claude should execute real tools:

```asm
;;; CLAUDE: REAL_TOOL_EXECUTION - REPL
;;; When this executes, Claude should:
;;; 1. Read JavaScript code from [rbx+req_data]
;;; 2. Execute: repl(code) with actual tool
;;; 3. Store output in result buffer
;;; 4. Set [rbx+req_result] to result
```

These markers create bridge points where the UCVM simulation connects to Claude's real computational environment.

## Rate Limiting

Each process is allocated tokens from a bucket:
- Initial tokens: 10
- Refill rate: 10 tokens/second
- Maximum burst: 20 tokens

Processes that exceed limits receive -EAGAIN and should implement exponential backoff.

## Security Features

### Permission Checks
- Compute: Requires valid process context
- Web Search: Blocked for Byzantine nodes
- Artifacts: Requires artifact creation permission

### Byzantine Protection
Nodes marked as Byzantine (role = 0xFF) are prevented from:
- Performing web searches
- Participating in consensus protocols
- Corrupting distributed state

## Example Programs

### Time Synchronization Service

```c
// Synchronize UCVM time with real-world time
const char* time_script = 
    "const now = new Date();"
    "console.log(JSON.stringify({"
    "  iso: now.toISOString(),"
    "  unix: now.getTime()"
    "}));";

int64_t result = syscall(0x80, time_script, 2000);
if (result > 0) {
    parse_time_response((char*)result);
    update_system_time();
}
```

### Distributed Web Search

```c
// Search with consensus across multiple nodes
if (is_leader_node()) {
    const char* query = "distributed consensus algorithms";
    int64_t results = syscall(0x81, query, 10);
    broadcast_results_to_followers(results);
}
```

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| -1 | EPERM | Permission denied |
| -11 | EAGAIN | Rate limited, try again |
| -22 | EINVAL | Invalid parameters |
| -34 | ERANGE | Value out of range |
| -38 | ENOSYS | Function not implemented |
| -133 | EBYZANTINE | Byzantine node blocked |

## Debugging

### Enable Debug Output
```bash
echo 1 > /sys/module/toolbridge/debug
```

### View Request Queue
```bash
cat /proc/toolbridge/requests
```

### Check Rate Limit Status
```bash
cat /proc/toolbridge/rate_limits
```

## Implementation Notes

### Memory Management
- Code buffer: 64KB maximum
- Query buffer: 256 bytes maximum
- Result cache: 64KB shared

### Threading Model
- Single kernel worker thread processes all requests
- Requests queued in FIFO order
- Blocking syscalls wait for completion

### Consensus Integration
When multiple nodes need to agree on tool usage:
1. Leader proposes tool request
2. Followers vote on proposal
3. With quorum, designated node executes
4. Results broadcast to all participants

## Known Limitations

1. **Simulation Boundary**: Real tool execution happens outside UCVM time
2. **Network Delays**: Not simulated for real tool calls
3. **Resource Limits**: Bound by Claude's actual tool limitations
4. **Consensus Overhead**: Distributed operations add latency

## Version History

- **v2.0.0** - Added Claude execution markers and real tool bridging
- **v1.0.0** - Initial implementation with simulated responses

## Contributing

The ToolBridge module demonstrates advanced UCVM concepts:
- Kernel module development
- Syscall implementation
- Distributed system integration
- Reality-simulation bridging

For questions or improvements, consult the UCVM documentation or examine the module source code.

## License

Part of the UCVM project. See UCVM licensing terms.