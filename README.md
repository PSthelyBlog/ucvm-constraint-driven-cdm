# Unified Claude-Mediated Virtual Machine (UCVM)

## Overview

UCVM is a specification for a distributed virtual machine system that operates through natural language interaction. The system implements a simplified computational model with distributed consensus, process management, and memory protection.

## Quick Start with recommended settings

1. Open Claude Web interface https://claude.ai/new
2. Disable extended thinking
3. Load the ucvm-cdm-spec.md document in the context
4. Load the timesync and terminal programs repositories (or the entire programs repository)
5. Write the initial prompt "start ucvm"
6. Send to Claude

## System Architecture

### Core Components

- **Virtual Machine**: 64KB memory space with segmented protection
- **Process Management**: Multi-process support with state lifecycle
- **Distributed Nodes**: Up to 10 nodes with Byzantine fault tolerance
- **Consensus Protocol**: PBFT-based consensus with leader election
- **Natural Language Interface**: Commands interpreted as system instructions

### Technical Specifications

- Memory: 16-bit address space (64KB total)
- Maximum processes: 256
- Maximum nodes: 10
- Byzantine fault tolerance: ⌊(n-1)/3⌋ nodes
- Protection rings: Kernel (0) and User (1)

## System State Model

The system maintains state through a JSON representation containing:

```
{
  "version": "string",
  "time": number,
  "memory": {...},
  "processes": {...},
  "nodes": {...},
  "network": {...}
}
```

## Instruction Set

### Basic Operations
- `MOV`, `ADD`, `SUB`, `MUL`, `DIV`, `MOD` - Arithmetic operations
- `JMP`, `JZ`, `JNZ`, `CALL`, `RET` - Control flow
- `LOAD`, `STORE` - Memory operations
- `PUSH`, `POP` - Stack operations

### System Operations
- `SYSCALL` - System calls for I/O and process management
- `HALT` - Stop execution
- `TICK` - Advance system time

### Distributed Operations
- `SEND` - Send message to node
- `RECV` - Receive message from node
- `PROPOSE` - Initiate consensus
- `ACCEPT` - Accept consensus proposal

## Natural Language Commands

The system accepts natural language commands that map to system operations:

- `echo [text]` - Output text
- `run [program]` - Execute a program
- `ls [path]` - List directory contents
- `consensus [value]` - Propose value for consensus
- `send [node] [message]` - Send message to specified node

## Memory Layout

```
0x0000 - 0x0FFF: Kernel space (protected)
0x1000 - 0x7FFF: Text segment (program code)
0x8000 - 0xBFFF: Heap segment (dynamic allocation)
0xC000 - 0xFFFF: Stack segment (function calls)
```

## Process States

Processes transition through the following states:
- `NEW` - Process created but not yet ready
- `READY` - Ready to execute
- `RUNNING` - Currently executing
- `BLOCKED` - Waiting for I/O or resource
- `ZOMBIE` - Terminated but not yet cleaned up
- `TERMINATED` - Fully cleaned up

## Distributed Consensus

The system implements Byzantine fault-tolerant consensus:
- Requires 3f+1 nodes to tolerate f Byzantine failures
- Uses view-based protocol with leader election
- Guarantees safety with up to ⌊(n-1)/3⌋ Byzantine nodes

## Error Handling

System errors include:
- `INVALID_ADDR` - Memory address out of bounds
- `SEGMENTATION_FAULT` - Memory protection violation
- `CONSENSUS_FAIL` - Unable to reach consensus
- `BYZANTINE_NODE_DETECTED` - Detected conflicting messages

## Usage

1. Initialize system with desired configuration
2. Issue natural language commands
3. System responds with state changes and output
4. State persists across commands within session

## Implementation Notes

- The system operates as a simulation within conversational context
- State transitions follow formal specification constraints
- Byzantine behavior is simulated for testing fault tolerance
- All operations respect memory protection boundaries

## Limitations

- Fixed memory size of 64KB
- Maximum of 10 distributed nodes
- Simplified instruction set
- No persistent storage across sessions
- Simulated network delays and failures

## References

Based on formal specification version 6.0 incorporating:
- Process lifecycle management
- Memory protection rings
- Byzantine fault tolerance (PBFT)
- Leader election protocols
- Message ordering guarantees
