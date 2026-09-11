# SSH Remote Execution Support

## Overview

Add support for executing blarg targets on remote machines via SSH. The local blarg project directory is copied to the remote machine using `scp`, then executed there.

**Important:** `rsync` is NOT an option and will not be used. The implementation uses only `scp` and `ssh`.

## Design Philosophy

The remote execution should behave identically to local execution. Interactivity must be preserved - if a target prompts for input locally, it should prompt for input when run remotely via SSH.

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

# Pass through flags to remote blarg
blarg --ssh user@host my-target.bash --verbose
blarg --ssh user@host my-target.bash --dry-run
blarg --ssh user@host my-target.bash --verbose --dry-run
```

## Implementation

### CLI Changes

Add one new command-line argument:

- `--ssh SSH_TARGET`: Execute on remote machine via SSH

These are mutually exclusive with `--dump-src`.

#### Argument Forwarding

All non-SSH-specific arguments should be forwarded to the remote blarg process:
- `--verbose` / `-v`
- `--dry-run` / `-r`
- Any other existing or future flags that make sense in a remote context

The `--ssh` flag is consumed locally and not passed to the remote.

### Execution Flow

1. **Validation**: Ensure target path is within the current working directory
2. **External Module Resolution**: Resolve all external modules locally (from `blarg.conf`)
3. **Copy to Remote**: Use `scp` to copy the project directory to a temp directory on the remote machine
4. **SSH Connection**:
   - Use `ControlPath`, `ControlMaster=yes`, and `ControlPersist=10` to enable connection sharing
   - Use `-t` flag to allocate a pseudo-terminal, preserving interactivity
   - Respect `$TMPDIR` on both local and remote systems
   - SSH generates unique session IDs via `%C` token
5. **Remote Execution**:
   - Execute `python3 ./blarg <forwarded_args> <target>` in the remote temp directory
   - The `-t` flag ensures prompts (sudo, etc.) work as they would locally
6. **Cleanup**:
   - Always remove remote temp directory via same SSH connection (no reconnect)
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

### External Module Resolution

Before copying, all external modules referenced in `blarg.conf` must be resolved locally:

1. Parse `blarg.conf` for external modules
2. For each module, ensure it exists in `.blarg/modules/<id>/<ref>/`
3. If not present, clone it (same logic as current blarg module loading)

This ensures the remote machine doesn't need credentials or network access to external git repos.

### File Copy

The project directory is copied to the remote using `scp -r`:
- All project files (targets, lib.d, blarg.conf, etc.)
- `.blarg/modules/` - Pre-resolved external modules

Excludes:
- `.git/` - Git repository metadata
- `.blarg/.target-markers/` - Runtime state that shouldn't be reused

## Code Structure

```python
def execute_via_ssh(
    ssh_target: str,
    working_dir: Path,
    script_path: Path,
    verbose: bool = False,
    dry_run: bool = False,
) -> int:
    # 1. Validate target is within working_dir
    # 2. Resolve external modules (from blarg.conf)
    # 3. Build forwarded args list from verbose, dry_run, etc.
    # 4. Copy project to remote via scp -r
    # 5. Build SSH command with ControlPath/ControlMaster/ControlPersist and -t
    # 6. Execute remote command with forwarded args
    # 7. Cleanup (remote temp dir + local socket)
    # 8. Return exit code
```

## Error Handling

| Error | Behavior |
|-------|----------|
| Target outside project directory | Print error, return 1 |
| `ssh` not found | Print error, return 1 |
| `scp` not found | Print error, return 1 |
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
6. Error cases (missing ssh, missing scp, invalid target path)
7. **External modules**: Verify modules are resolved locally and included in copy
8. **Argument forwarding**: Verify `--verbose`, `--dry-run` work on remote
9. **Argument combinations**: Test multiple flags forwarded together
10. **Interactivity**: Verify sudo prompts and other interactive commands work via `-t` flag

## Future Enhancements

- Support for SSH port specification via `~/.ssh/config` (already works)
- Support for SSH key authentication via `~/.ssh/config` (already works)
- Streaming approach without temp directories (more complex)
- Caching of blarg binary on remote to avoid re-transfer
