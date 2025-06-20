# TIMESYNC - UCVM Time Synchronization Utility

A kernel-level time synchronization utility for the Universal Constraint Virtual Machine (UCVM) that bridges virtual machine time with real-world host system time using the toolbridge kernel module.

## Overview

TIMESYNC is a one-shot utility that synchronizes UCVM's internal clock with the host system's real time. It uses the toolbridge kernel module to execute JavaScript code via Claude's REPL interface, fetching accurate timestamps and correcting any time drift.

## Features

- **One-shot execution**: Runs once and exits (no daemon mode)
- **Strict dependency checking**: Won't run without required kernel modules
- **Configurable drift threshold**: Only syncs when drift exceeds threshold
- **Dry-run mode**: Preview changes without applying them
- **Multi-node support**: Can broadcast time updates to distributed nodes
- **Comprehensive error handling**: Clear error messages and recovery suggestions

## Requirements

### System Requirements
- UCVM kernel with Ring 0 (kernel mode) execution privileges
- toolbridge.kmod kernel module loaded and active
- Access to `/dev/repl0` device node

### Dependencies
- **toolbridge.kmod** (MANDATORY) - Provides syscall interface to Claude's tools
- Standard UCVM kernel APIs (kernel_log, kernel_print, etc.)

## Installation

1. Ensure toolbridge.kmod is loaded:
```bash
insmod toolbridge.kmod
```

2. Compile timesync (if not pre-compiled):
```bash
ucvm-as timesync.asm -o timesync
```

3. Install to system path:
```bash
cp timesync /sbin/timesync
chmod +x /sbin/timesync
```

## Usage

### Basic Usage
```bash
# Simple time synchronization
timesync

# Check time drift without updating
timesync --dry-run

# Force sync even if drift is minimal
timesync --force

# Sync and notify all nodes in cluster
timesync --broadcast

# Set custom drift threshold (5 seconds)
timesync --threshold=5000
```

### Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--dry-run` | Show what would be changed without applying | Off |
| `--force` | Sync regardless of drift threshold | Off |
| `--broadcast` | Send time update to all nodes in cluster | Off |
| `--threshold=N` | Set minimum drift in milliseconds to trigger sync | 1000ms |

### Exit Codes

| Code | Meaning | Description |
|------|---------|-------------|
| 0 | Success | Time synchronized or no update needed |
| 1 | General Error | Unspecified error occurred |
| 2 | Permission Denied | Not running with kernel privileges |
| 3 | Sync Failed | Time synchronization operation failed |
| 127 | Missing Dependency | toolbridge.kmod not loaded |

## How It Works

### 1. Dependency Verification
TIMESYNC performs four independent checks to ensure toolbridge is available:
- Checks `/proc/modules` for loaded module
- Verifies syscalls 0x80-0x82 are registered
- Confirms `/dev/repl0`, `/dev/web0`, `/dev/art0` exist
- Attempts to open `/dev/repl0` for access

### 2. Time Fetching
Constructs and executes JavaScript code via toolbridge:
```javascript
const now = new Date();
const ucvm_time = [current_ucvm_time];
const result = {
  iso: now.toISOString(),
  unix: now.getTime(),
  drift: now.getTime() - ucvm_time
};
console.log(JSON.stringify(result));
```

### 3. Drift Calculation
- Compares UCVM ticks (converted to milliseconds) with host time
- Calculates absolute drift value
- Checks against configured threshold

### 4. Time Update
If drift exceeds threshold:
- Updates system time via `set_system_ticks()`
- Optionally broadcasts `MSG_TIME_SYNC` to all nodes
- Reports results to console

## Example Output

### Successful Sync
```
=== TIME SYNC REPORT ===
UCVM Time:    t=1750431177
Host Unix:    1750431180074 ms
Host ISO:     2025-06-20T14:52:57.074Z
Time Drift:   3074 ms
Status:       TIME SYNCHRONIZED
```

### No Update Needed
```
=== TIME SYNC REPORT ===
UCVM Time:    t=1750431177
Host Unix:    1750431177523 ms
Host ISO:     2025-06-20T14:52:57.523Z
Time Drift:   523 ms
Status:       NO CHANGE NEEDED
```

### Dry Run
```
INFO: Dry run - would adjust time by 3074 ms

=== TIME SYNC REPORT ===
UCVM Time:    t=1750431177
Host Unix:    1750431180074 ms
Host ISO:     2025-06-20T14:52:57.074Z
Time Drift:   3074 ms
Status:       DRY RUN COMPLETE
```

### Missing Dependency
```
**********************************************
* FATAL: MISSING REQUIRED DEPENDENCY         *
* timesync requires toolbridge.kmod module  *
* Execution cannot continue!                 *
**********************************************

To fix this issue:
  Run: insmod toolbridge.kmod
```

## Troubleshooting

### "FATAL: MISSING REQUIRED DEPENDENCY"
The toolbridge kernel module is not loaded. Solution:
```bash
insmod toolbridge.kmod
```

### "ERROR: requires KERNEL ring privileges"
TIMESYNC must run with kernel privileges. Ensure you're running as a kernel process or with appropriate privileges.

### "ERROR: Rate limited by toolbridge"
Too many requests to toolbridge. The module enforces a 10 req/sec limit per process. Wait and retry.

### "ERROR: Failed to parse time response"
The JSON response from the REPL was malformed. This may indicate a toolbridge communication issue.

## Technical Details

### Memory Layout
- Stack: 0x9000
- Code size: ~3KB
- BSS: ~5KB for buffers

### System Calls Used
- `0x80` (SYS_COMPUTE) - Execute JavaScript via REPL
- Standard UCVM kernel calls (kernel_log, kernel_print, etc.)

### Message Format
Time sync broadcast message (24 bytes):
```
Offset  Size  Description
0       1     Message type (MSG_TIME_SYNC = 0x54)
1       7     Padding
8       8     New timestamp (milliseconds)
16      8     Drift value (milliseconds)
```

## Security Considerations

- Runs only in kernel mode (Ring 0)
- Validates all inputs and responses
- Implements rate limiting via toolbridge
- Byzantine nodes cannot use web search features

## Future Enhancements

Potential improvements for future versions:
- NTP-style continuous drift adjustment
- Historical drift tracking
- Automatic periodic synchronization service
- Support for multiple time sources
- Leap second handling

## License

Part of the UCVM system. See UCVM license for details.

## Author

UCVM Development Team

## See Also

- `toolbridge.kmod` - Kernel module providing tool access
- `ucvm-cdm-spec.md` - UCVM Constraint-Driven Model specification
- UCVM kernel documentation
