# UCVM TimeSync - Time Synchronization Service

## Overview

TimeSync is a privileged UCVM system utility that synchronizes the UCVM system clock with the host system's real-time clock. It leverages the REPL (Read-Eval-Print Loop) interface to query the host's current time and updates all distributed nodes in the UCVM cluster.

## Features

- **Host Time Retrieval**: Queries the host system's current date and time via JavaScript execution in the REPL environment
- **System Clock Update**: Updates UCVM's internal tick counter and RTC registers
- **Distributed Synchronization**: Broadcasts time updates to all nodes in the UCVM cluster
- **Vector Clock Maintenance**: Ensures causal consistency across distributed nodes
- **Privilege Protection**: Requires KERNEL ring execution to prevent unauthorized time modifications

## Requirements

- **Ring Level**: KERNEL (privileged operation)
- **Memory**: 4KB allocated memory
- **Dependencies**: 
  - REPL interface for host communication
  - Network daemon for node synchronization
  - Access to RTC hardware registers

## Usage

```bash
# From UCVM terminal (must be in KERNEL ring)
kernel@ucvm:~$ fork && exec timesync
```

## Technical Details

### Architecture

The program consists of several key components:

1. **Host Time Fetcher**: Executes JavaScript code via REPL to get current time
2. **Time Calculator**: Computes delta between old and new timestamps
3. **System Updater**: Modifies system tick counter and RTC registers
4. **Broadcast Manager**: Distributes time updates to all cluster nodes

### Time Format

- Internal format: Ticks since boot (1 tick = 1 second)
- External format: Unix timestamp (milliseconds since epoch)
- Display format: Standard UTC datetime string

### Node Synchronization Protocol

1. Leader node initiates time sync
2. New timestamp broadcasted with vector clock
3. Follower nodes update local clocks
4. Vector clocks adjusted to maintain causality

### Memory Layout

```
0x9000 - Stack pointer
0x8200 - Program code segment
0x8400 - REPL buffer (1KB)
0x8800 - Node list buffer
0x8900 - Time data structures
```

## Error Handling

- **Privilege Error**: Returns error if not running in KERNEL ring
- **REPL Timeout**: Falls back to last known good time
- **Node Unreachable**: Logs failure but continues with other nodes
- **Invalid Time**: Validates timestamp before applying update

## Security Considerations

- Time modification is a privileged operation
- Only KERNEL ring processes can execute timesync
- Prevents user processes from manipulating system time
- Maintains audit log of all time changes

## Example Output

```
=== UCVM Time Synchronization Service ===
Ring: KERNEL (privileged operation)
Fetching host system time...
Host time retrieved: Thu Jun 19 19:27:48 UTC 2025

Synchronizing UCVM system clock...
Old time: Thu Jun 19 00:00:00 UTC 2025
New time: Thu Jun 19 19:27:48 UTC 2025

Updating system tick counter...
System ticks advanced by 69768 (19h 27m 48s)

Broadcasting time update to all nodes...
- node1 (LEADER): clock updated
- node2 (FOLLOWER): vector clock synchronized  
- node3 (FOLLOWER): vector clock synchronized
- node4 (FOLLOWER): vector clock synchronized

Time synchronization complete!
```

## Implementation Notes

### REPL Integration

The program uses a simple JavaScript snippet executed in the host environment:

```javascript
const now = new Date();
const timestamp = now.getTime();
console.log(`${now.toISOString()}|${timestamp}`);
```

### Vector Clock Algorithm

Each node maintains a vector clock where:
- `VC[i]` = logical time at node i
- On time sync: `VC[self] = max(VC[self], new_time)`
- Ensures happened-before relationships preserved

### RTC Register Mapping

- `0x70`: Hours register (0-23)
- `0x71`: Minutes register (0-59)
- `0x72`: Seconds register (0-59)

## Future Enhancements

- [ ] NTP-style gradual time adjustment
- [ ] Automatic periodic synchronization
- [ ] Time drift detection and correction
- [ ] Support for different timezones
- [ ] Integration with consensus protocol for time agreement

## See Also

- `date` - Display current system time
- `tick` - Manually advance system time
- `consensus` - Distributed agreement protocol

## License

Part of the UCVM operating system. See LICENSE for details.