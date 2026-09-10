# SSH Remote Execution Support

## Overview

Add support for executing blarg targets on remote machines via SSH. The local blarg project directory is packaged as a tar archive, streamed to the remote machine over SSH, and executed there.

## Goals

- Execute blarg targets on remote machines via SSH
- Respect existing SSH configuration (`~/.ssh/config`)
- Reuse SSH connections for cleanup commands
- No external dependencies beyond what blarg already requires
- Minimal changes to existing blarg codebase

## Usage

```bash
# Basic usage
blarg --ssh user@host my-target.bash

# With SSH alias from ~/.ssh/config
blarg --ssh production my-target.bash

# Keep remote temp directory for debugging
blarg --ssh user@host my-target.bash --no-cleanup
```

## Implementation

### CLI Changes

Add two new command-line arguments:

- `--ssh SSH_TARGET`: Execute on remote machine via SSH
- `--no-cleanup`: Keep remote temp directory after execution (for debugging)

These are mutually exclusive with `--dump-src`.

### Execution Flow

1. **Validation**: Ensure target path is within the current working directory
2. **Packaging**: Create a tar archive of the current directory, excluding `.git` and `.blarg`
3. **SSH Connection**:
   - Use `ControlPath`, `ControlMaster=yes`, and `ControlPersist=10` to enable connection sharing
   - Respect `$TMPDIR` on both local and remote systems
   - SSH generates unique session IDs via `%C` token
4. **Remote Execution**:
   - Extract tar archive to remote temp directory (`${TMPDIR:-/tmp}/blarg-$$`)
   - Execute `python3 ./blarg <target>` in the extracted directory
5. **Cleanup**:
   - Remove remote temp directory via same SSH connection (no reconnect)
   - Remove local control socket

### SSH Options

| Option | Value | Purpose |
|--------|-------|---------|
| `ControlPath` | `{$TMPDIR}/ssh-control/%C` | Path for SSH control socket; `%C` is SSH-generated hash |
| `ControlMaster` | `yes` | This connection is the master |
| `ControlPersist` | `10` | Keep connection alive for 10 seconds after last client disconnects |

### Remote Temp Directory

- Uses `${TMPDIR:-/tmp}/blarg-$$` to respect remote system's temp directory
- `$$` gives a unique PID-based name on the remote

### Local Control Socket

- Uses `os.environ.get("TMPDIR", "/tmp") / "ssh-control"` on local system
- Directory is created if it doesn't exist

### Exclusions

The tar archive excludes:
- `.git/` - Git repository metadata
- `.blarg/` - blarg state/cache directory

## Code Structure

```python
def execute_via_ssh(ssh_target: str, working_dir: Path, script_path: Path, cleanup: bool = True) -> int:
    # 1. Validate target is within working_dir
    # 2. Build SSH command with ControlPath/ControlMaster/ControlPersist
    # 3. Pipe tar to SSH
    # 4. Execute remote command
    # 5. Cleanup (remote temp dir + local socket)
    # 6. Return exit code
```

## Error Handling

| Error | Behavior |
|-------|----------|
| Target outside project directory | Print error, return 1 |
| `ssh` not found | Print error, return 1 |
| `tar` not found | Print error, return 1 |
| Remote `python3` not found | blarg fails with its own error |
| SSH connection failure | Propagate SSH error |
| Cleanup failure | Still return main command's exit code |

## Testing

The implementation should be tested with:

1. Basic SSH execution
2. SSH aliases from `~/.ssh/config`
3. Custom `$TMPDIR` on local and remote
4. Multiple concurrent blarg runs to different hosts
5. Cleanup verification (remote temp dir removed)
6. Error cases (missing ssh, missing tar, invalid target path)

## Future Enhancements

- Support for SSH port specification via `~/.ssh/config` (already works)
- Support for SSH key authentication via `~/.ssh/config` (already works)
- Streaming approach without temp directories (more complex)
- Caching of blarg binary on remote to avoid re-transfer
