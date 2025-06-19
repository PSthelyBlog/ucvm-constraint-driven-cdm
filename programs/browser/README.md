# UCVM Web Browser v0.2 - Text-Based Web Search and Fetch Tool

## Overview

The UCVM Web Browser is a lightweight, text-based browser that provides web search and page fetching capabilities within the UCVM operating system. It interfaces with Claude's web_search and web_fetch tools through the UCVM network daemon, enabling users to access web content from within the simulated environment.

## Features

- **Web Search**: Search the internet using natural language queries
- **URL Fetching**: Retrieve and display content from specific web pages
- **History Navigation**: Browse through previously visited pages
- **Minimal Memory Footprint**: Only 4KB allocated memory
- **Ring Protection**: Operates safely in USER ring with proper permission checks

## Technical Specifications

- **Program Size**: 4KB
- **Ring Level**: USER
- **Memory Allocation**: 
  - Stack: 0x9000
  - History Buffer: 1KB
  - Network Buffer: 4KB
  - Result Cache: 16KB
- **Dependencies**: Network daemon for external communication

## Commands

### search `<query>`
Performs a web search using the provided query string.
```bash
browser> search quantum computing latest advances
```
- Uses Brave Search API (via Claude's web_search tool)
- Returns summarized results with source citations
- Results are cached for the session

### fetch `<url>`
Retrieves the full content of a specific webpage.
```bash
browser> fetch https://example.com/article
```
- Must be a complete URL with protocol (https://)
- Displays formatted page content
- Useful for reading full articles after search

### back
Returns to the previously viewed content.
```bash
browser> back
```
- Navigates through history buffer
- Maintains last 10 pages in memory

### history
Shows browsing history for the current session.
```bash
browser> history
```
- Lists recent searches and fetched URLs
- History is cleared when browser exits

### help
Displays available commands and usage information.
```bash
browser> help
```

### quit
Exits the browser and returns to UCVM terminal.
```bash
browser> quit
```

## Usage Examples

### Basic Web Search
```bash
kernel@ucvm:~$ fork && exec browser
Loading browser into PID 6...

=== UCVM Web Browser v0.2 ===
Ring: USER
Memory: 4KB allocated
Network: Connected via node1

browser> search climate change 2025
Initiating web search...
[Results displayed with source citations]

browser> fetch https://climate.gov/news/latest
Fetching webpage...
[Full article content displayed]
```

### Research Workflow
```bash
browser> search RISC-V processor implementations
[Browse results]

browser> fetch https://riscv.org/technical/specifications/
[Read specifications]

browser> back
[Return to search results]

browser> search RISC-V vs ARM comparison
[Continue research]
```

## Implementation Details

### Network Communication

The browser communicates with external services through a layered approach:

1. **User Input** → Browser command parser
2. **Browser** → UCVM network daemon (via system calls)
3. **Network Daemon** → Claude's web tools
4. **Web Tools** → Brave Search API / Web fetch
5. **Results** → Returned through the same chain

### Memory Management

```assembly
.data:
prompt_str: .asciz "browser> "
history_buffer: .space 1024      ; Stores navigation history
network_buffer: .space 4096      ; For network communication
search_query: .space 256         ; Current search query
url_buffer: .space 256           ; Current URL
history_ptr: .dword 0            ; History position
current_page: .dword 0           ; Current page index

.bss:
result_cache: .space 16384       ; 16KB cache for results
```

### Permission Model

- Runs in USER ring by default
- Cannot access kernel memory or privileged operations
- Network access mediated through system calls
- All external communication goes through network daemon

## Limitations

1. **Search Engine**: All searches use Brave Search (not configurable)
2. **No JavaScript**: Cannot execute dynamic web content
3. **Text Only**: No image or media rendering capabilities
4. **Limited Cache**: 16KB result cache may truncate large pages
5. **Session Only**: No persistent storage between sessions

## Security Considerations

- **Ring Protection**: Operates in USER ring, preventing system-level access
- **Mediated Access**: All web access goes through UCVM network daemon
- **No Direct Network**: Cannot bypass the system's network controls
- **Input Validation**: Commands are parsed and validated before execution
- **Memory Bounds**: Fixed buffers prevent overflow attacks

## Error Handling

### Common Errors

1. **Permission Denied**: Attempting privileged operations
   ```
   Error: Operation requires KERNEL ring
   ```

2. **Network Timeout**: Connection issues
   ```
   Error: Network request timed out
   ```

3. **Invalid URL**: Malformed URL in fetch command
   ```
   Error: Invalid URL format
   ```

4. **Memory Full**: Result cache exceeded
   ```
   Error: Result too large for cache
   ```

## Future Enhancements

- [ ] Bookmarks system for saving favorite sites
- [ ] Simple HTML parsing for better formatting
- [ ] Download capability for saving content
- [ ] Multiple tabs/windows support
- [ ] Search within fetched pages
- [ ] Cookie/session management (privacy-focused)
- [ ] Offline mode with cached content

## Comparison with Traditional Browsers

| Feature | UCVM Browser | Traditional Browser |
|---------|--------------|-------------------|
| Memory Usage | 4KB + cache | 100MB+ |
| JavaScript | No | Yes |
| Images | No | Yes |
| Search Engine | Brave only | Configurable |
| Security Model | Ring-based | Process isolation |
| Network Access | Mediated | Direct |

## Troubleshooting

### Browser Won't Start
- Ensure sufficient memory available
- Check process limits with `ps`
- Verify network daemon is running

### Search Returns No Results
- Check network connectivity with `ping`
- Verify search query syntax
- Try simpler search terms

### Fetch Fails
- Ensure URL includes https:// protocol
- Check if site requires authentication
- Try alternative URLs

## Version History

- **v0.2** (Current): Removed non-functional search engine configuration
- **v0.1**: Initial release with simulated engine selection

## See Also

- [UCVM Network Daemon](../network/README.md)
- [Ring Protection Model](../security/rings.md)
- [Memory Management](../memory/README.md)

## License

Part of the UCVM operating system. See LICENSE for details.