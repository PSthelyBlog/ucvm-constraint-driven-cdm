# CIDW Runtime - Claude-Integrated Development Workflow Runtime

## Overview

CIDW Runtime is a specialized UCVM (Universal Computing Virtual Machine) application that implements the Claude-Integrated Development Workflow (CIDW) framework. It orchestrates complex development tasks across Claude's web and command-line interfaces, managing tool execution, artifact creation, and context transfer between different development phases.

## Features

- **Workflow Orchestration**: Manages multi-phase development workflows from research to deployment
- **Tool Integration**: Seamlessly integrates with Claude's toolset (web search, REPL, artifacts)
- **Context Management**: Maintains project state across Claude-Web and Claude-Code-CLI sessions
- **Real Tool Execution**: Leverages UCVM's toolbridge kernel module for actual tool invocations
- **Artifact Registry**: Tracks and manages all project artifacts with version control
- **Automated Handoffs**: Generates standardized handoff documents for CLI implementation phases

## System Requirements

- UCVM v2.0.0 or higher
- toolbridge.kmod kernel module loaded
- Ring level: USER (with kernel module access)
- Memory: 64KB minimum
- Dependencies: UCVM core libraries

## Installation

### 1. Load the toolbridge kernel module
```bash
insmod toolbridge
```

### 2. Install CIDW Runtime
```bash
# Copy the cidw binary to system path
cp cidw /usr/bin/cidw
chmod +x /usr/bin/cidw

# Create configuration directory
mkdir -p /etc/cidw
```

### 3. Verify installation
```bash
cidw --version
# Output: CIDW Runtime v1.0.0
```

## Usage

### Basic Command Structure
```bash
cidw [options] --workflow <workflow-file> --start
```

### Options
- `--workflow <file>`: Path to workflow YAML file (required)
- `--start`: Begin workflow execution
- `--resume <phase>`: Resume from specific phase
- `--dry-run`: Validate workflow without execution
- `--verbose`: Enable detailed logging
- `--export <dir>`: Export all artifacts to directory

### Example Usage

#### 1. Create a workflow file
```yaml
# my-project.yaml
name: my-webapp
version: 1.0.0
goal: "Build a task management application"

phases:
  - name: requirements
    tool: claude-web
    actions:
      - type: search
        query: "best practices 2025"
      - type: artifact
        command: create
        name: requirements_doc
```

#### 2. Execute the workflow
```bash
cidw --workflow my-project.yaml --start
```

#### 3. Monitor execution
```bash
# View current phase
cidw --workflow my-project.yaml --status

# List all artifacts
cidw --workflow my-project.yaml --list-artifacts
```

## Workflow File Format

### Structure
```yaml
name: <project-name>
version: <version>
goal: <project-description>

phases:
  - name: <phase-name>
    tool: <claude-web|claude-code-cli|mixed>
    actions:
      - type: <search|artifact|repl|implement|test>
        # Action-specific parameters
```

### Tool Types
- `claude-web`: Research, planning, documentation phases
- `claude-code-cli`: Implementation and local execution phases
- `mixed`: Phases requiring both tools

### Action Types

#### Web Search
```yaml
- type: search
  query: "search terms"
  max_results: 10  # optional, default: 5
```

#### Artifact Creation
```yaml
- type: artifact
  command: <create|update|delete>
  name: artifact_id
  type: <markdown|svg|sql|code>
  template: <optional-template>
```

#### REPL Analysis
```yaml
- type: repl
  code: |
    // JavaScript code for analysis
    console.log("Analysis results");
```

#### Implementation (CLI)
```yaml
- type: implement
  tasks:
    - setup_project
    - implement_backend
    - write_tests
```

## Architecture

### Components

1. **Workflow Parser**
   - Reads and validates YAML workflow files
   - Constructs execution plan

2. **Tool Dispatcher**
   - Routes actions to appropriate Claude tools
   - Handles tool-specific parameters

3. **Artifact Registry**
   - Tracks all created artifacts
   - Manages artifact metadata and versions

4. **Context Manager**
   - Maintains workflow state
   - Handles phase transitions
   - Manages handoff documents

5. **Toolbridge Integration**
   - Interfaces with UCVM kernel module
   - Executes real tool calls via system calls

### System Calls

CIDW Runtime uses three primary system calls:

- `SYS_COMPUTE (0x80)`: REPL execution
- `SYS_WEBSEARCH (0x81)`: Web search operations
- `SYS_ARTIFACT (0x82)`: Artifact management

## Error Handling

### Common Error Codes
- `-EPERM (1)`: Permission denied
- `-EAGAIN (11)`: Rate limit exceeded
- `-EINVAL (22)`: Invalid parameters
- `-EBYZANTINE (133)`: Byzantine node detected

### Error Recovery
```bash
# Resume from last successful phase
cidw --workflow my-project.yaml --resume

# Export partial results
cidw --workflow my-project.yaml --export ./backup
```

## Advanced Features

### Parallel Execution
```yaml
phases:
  - name: parallel_tasks
    parallel: true
    tasks:
      - name: frontend_research
        tool: claude-web
      - name: backend_research
        tool: claude-web
```

### Conditional Phases
```yaml
phases:
  - name: optimization
    condition: "performance_test_failed"
    tool: claude-web
    actions:
      - type: search
        query: "performance optimization techniques"
```

### Custom Templates
```yaml
templates:
  handoff:
    path: /etc/cidw/templates/custom-handoff.md
  artifact:
    path: /etc/cidw/templates/custom-artifact.md
```

## Integration with UCVM

### Memory Layout
```
0xE000 - Stack pointer initialization
0x0A00 - Toolbridge module base address
```

### Resource Limits
- Max workflow phases: 256
- Max artifacts per project: 1024
- Max parallel actions: 10
- Request queue size: 8192 bytes

## Troubleshooting

### Toolbridge not loaded
```bash
# Check if module is loaded
lsmod | grep toolbridge

# Load module if missing
insmod toolbridge
```

### Rate limiting issues
```bash
# Check current limits
cidw --show-limits

# Wait for rate limit reset
cidw --workflow my-project.yaml --resume --wait
```

### Artifact conflicts
```bash
# List all artifacts
cidw --list-artifacts --verbose

# Force update
cidw --workflow my-project.yaml --force-update
```

## Examples

### Web Application Project
See `/etc/cidw/example-workflow.yaml` for a complete web application workflow example.

### API Development
```bash
cidw --workflow /etc/cidw/examples/api-project.yaml --start
```

### Documentation Project
```bash
cidw --workflow /etc/cidw/examples/docs-project.yaml --start
```

## Best Practices

1. **Workflow Design**
   - Keep phases focused and single-purpose
   - Use descriptive phase names
   - Include validation steps

2. **Artifact Management**
   - Use consistent naming conventions
   - Version artifacts when updating
   - Document artifact dependencies

3. **Error Handling**
   - Always specify error recovery strategies
   - Export artifacts regularly
   - Use dry-run for workflow validation

4. **Performance**
   - Batch related searches
   - Cache REPL results when possible
   - Minimize artifact updates

## Contributing

CIDW Runtime is part of the UCVM ecosystem. To contribute:

1. Fork the UCVM repository
2. Create a feature branch
3. Implement changes in `/usr/bin/cidw`
4. Test with various workflows
5. Submit pull request

## License

CIDW Runtime is licensed under the same terms as UCVM. See UCVM documentation for details.

## Support

- **Documentation**: `/docs/cidw/`
- **Examples**: `/etc/cidw/examples/`
- **Issues**: UCVM issue tracker
- **Community**: UCVM forums

## Version History

### v1.0.0 (Current)
- Initial release
- Full CIDW specification implementation
- Toolbridge integration
- Basic workflow orchestration

### Roadmap
- v1.1.0: Enhanced parallel execution
- v1.2.0: Workflow debugging tools
- v2.0.0: Distributed workflow execution

---

**CIDW Runtime** - Orchestrating Claude's capabilities for complex development workflows  
*Part of the UCVM ecosystem*