# UCVM Terminal - Interactive Command Line Interface

## Overview

The UCVM Terminal is the primary interactive shell for the UCVM operating system. It provides a command-line interface for users to interact with the system, execute programs, manage processes, and navigate the file system. The terminal runs in USER ring with 8KB of allocated memory.

## Features

- **Interactive Shell**: Command prompt with input/output handling
- **Built-in Commands**: Native commands executed directly by the terminal
- **Program Execution**: Fork/exec model for launching external programs
- **Process Management**: Support for background processes and job control
- **I/O Redirection**: Pipe and redirect support for command chaining
- **Session Management**: Terminal state preservation and signal handling

## Architecture

### Memory Layout

```
0xF000 - Stack pointer (grows downward)
0xE000 - Terminal code segment
0xE800 - Input buffer (256 bytes)
0xE900 - Command history
0xEA00 - Environment variables
0xEB00 - Signal handlers
```

### Execution Model

1. **Initialization**: Sets up terminal state and I/O streams
2. **Command Loop**: Continuously reads, parses, and executes commands
3. **Process Creation**: Uses fork/exec for external programs
4. **Resource Management**: Handles process cleanup and memory

## Built-in Commands

### Core Commands

- `cd <directory>` - Change current directory
- `exit` - Terminate terminal session
- `help` - Display available commands
- `clear` - Clear terminal screen

### Extended Commands (via bin/)

- `ps` - List running processes
- `fork` - Create child process
- `exec <program>` - Execute program
- `kill <pid>` - Terminate process
- `tick [n]` - Advance system time
- `snapshot` - Display system state
- `consensus <value>` - Initiate distributed consensus
- `elect` - Start leader election

## Usage Examples

### Basic Navigation
```bash
kernel@ucvm:~$ cd bin
kernel@ucvm:~/bin$ ls
fork exec ps kill malloc free send recv consensus elect tick snapshot help clear
```

### Process Management
```bash
kernel@ucvm:~$ fork
Forking process...
Parent process: 5 (terminal)
Child process: 6 created

kernel@ucvm:~$ ps
PID  PPID  STATE     RING    PC      COMMAND
1    0     RUNNING   KERNEL  0x1000  init
2    1     READY     KERNEL  0x2000  scheduler
3    1     READY     KERNEL  0x3000  memory_manager
4    1     BLOCKED   KERNEL  0x4000  network_daemon
5    1     RUNNING   USER    0x5000  terminal
6    5     READY     USER    0x6000  [child]
```

### Program Execution
```bash
kernel@ucvm:~$ exec browser
Loading browser into PID 6...
=== UCVM Web Browser v0.1 ===
browser> 
```

## Terminal Behavior

### Prompt Format
```
<ring>@ucvm:<path>$ 
```
- `ring`: Current privilege level (kernel/user)
- `path`: Current working directory
- `$`: Regular user, `#`: Root/kernel mode

### Signal Handling

- `SIGINT` (Ctrl+C): Interrupt current process
- `SIGTERM`: Graceful termination
- `SIGCHLD`: Child process status change
- `SIGSTOP/SIGCONT`: Process suspension/resumption

### Process States

When executing commands, processes transition through:
1. `NEW` - Just created
2. `READY` - Waiting to run
3. `RUNNING` - Currently executing
4. `BLOCKED` - Waiting for I/O
5. `ZOMBIE` - Terminated, awaiting reap
6. `TERMINATED` - Fully cleaned up

## Implementation Details

### Command Parsing

The terminal uses a simple parser that:
1. Tokenizes input by whitespace
2. Identifies built-in vs external commands
3. Handles special characters (|, <, >, &)
4. Expands environment variables

### Fork/Exec Model

For external programs:
```assembly
fork:
    mov ax, SYS_FORK
    int 0x80
    test ax, ax
    jz child_process
    ; parent continues
    
child_process:
    mov ax, SYS_EXEC
    mov bx, program_path
    int 0x80
```

### Terminal Mode Flag

The special `terminal_mode` flag signals to the UCVM behavioral system that terminal simulation is active, ensuring all output remains within the terminal context.

## Security Considerations

- Runs in USER ring by default
- Cannot directly access kernel memory
- Privilege escalation requires explicit kernel transition
- Input validation prevents buffer overflows
- Signal masks protect against interruption attacks

## Behavioral Directive

**Important**: When the terminal is running, the UCVM system suppresses all meta-level messages and maintains immersive terminal simulation. All output appears as if from a real terminal session.

## Troubleshooting

### Common Issues

1. **Command not found**: Check if program exists in PATH
2. **Permission denied**: Verify ring level for privileged operations
3. **Segmentation fault**: Program attempted illegal memory access
4. **Process won't terminate**: Use `kill -9 <pid>` for forced termination

### Debug Mode

Enable verbose output:
```bash
kernel@ucvm:~$ set DEBUG=1
kernel@ucvm:~$ your_command  # Shows syscall trace
```

## Future Enhancements

- [ ] Tab completion for commands and paths
- [ ] Command history with arrow key navigation
- [ ] Shell scripting support
- [ ] Job control (fg/bg commands)
- [ ] Customizable prompt (PS1)
- [ ] Alias support
- [ ] Built-in text editor

## Related Documentation

- [UCVM System Architecture](../ucvm-cdm-spec.md)
- [Process Management](../docs/processes.md)
- [Memory Model](../docs/memory.md)
- [Distributed Operations](../docs/distributed.md)

## License

Part of the UCVM operating system. See LICENSE for details.