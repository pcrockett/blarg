# SSH Remote Execution Support

## Overview

Add support for executing blarg targets on remote machines via SSH. The local blarg project directory is copied to the remote machine using `scp`, then executed there.

**Important:** `rsync` is NOT an option and will not be used. The implementation uses only `scp` and `ssh`.

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
3. **Copy to Remote**: Use `scp -r` to copy the project directory to a temp directory on the remote machine
4. **SSH Connection**:
   - Use `ControlPath`, `ControlMaster=yes`, and `ControlPersist=10` to enable connection sharing
   - Use `-t` flag to allocate a pseudo-terminal, preserving interactivity for real-world use
   - Respect `$TMPDIR` on both local and remote systems
   - SSH generates unique session IDs via `%C` token
5. **Remote Execution**:
   - Execute `python3 ./blarg <forwarded_args> <target>` in the remote temp directory
   - The `-t` flag ensures prompts (sudo, etc.) work as they would locally
6. **Cleanup**:
   - Always remove remote temp directory via same SSH connection (no reconnect)
   - Leave local control socket, no need to clean it up

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
    # 7. Cleanup (remote temp dir)
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

## Implementation Plan

### Phase 1: Test Infrastructure Setup

1. Create `tests/ssh/compose.yml` with a test SSH server
2. Add SSH config setup to `tests/util.sh`'s `setup()` function
3. Write a simple connectivity test that:
   - Starts the SSH container via docker compose
   - Asserts we can connect non-interactively
   - Asserts we can run a command that prints "hi"
4. Commit: "Add SSH test infrastructure"

### Phase 2: TDD Loop

From this point forward, use Test-Driven Development:

1. Write a failing test for the next piece of functionality
2. Implement just enough in blarg to make it pass
3. Commit when green
4. Repeat

## Testing

### Docker Compose Test Infrastructure

A `compose.yml` file provides a test SSH server for out-of-the-box testing:

```yaml
services:
  ssh-remote:
    image: linuxserver/openssh-server
    ports:
      - "127.0.0.1:2222:22"
    environment:
      - PUBLIC_KEY=ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... # test key
      - SUDO_ACCESS=true
      - PASSWORD_ACCESS=true
      - USER_NAME=testuser
    volumes:
      - ./tests/ssh/authorized_keys:/home/testuser/.ssh/authorized_keys:ro
```

### Test Naming Convention

Following the project's test naming convention (`<thing> - <scenario> - <expected result>`):

- `ssh - basic execution - success`
- `ssh - with verbose flag - verbose output`
- `ssh - with dry-run flag - no apply`
- `ssh - external module - resolves locally`
- `ssh - invalid target path - error`
- `ssh - always - removes temp dir`

### Test Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `BLARG_SSH_TEST_HOST` | Test SSH host | `localhost` |
| `BLARG_SSH_TEST_PORT` | Test SSH port | `2222` |
| `BLARG_SSH_TEST_USER` | Test SSH user | `testuser` |

### Out-of-the-Box Testing

Tests should work without any setup:

```bash
# Start test server (handled automatically by tests)
docker compose -f tests/ssh/compose.yml up -d

# Run SSH tests
bats tests/ssh_tests.bats

# Cleanup
docker compose -f tests/ssh/compose.yml down
```

### Test Implementation Pattern

Tests should use the existing `tests/util.sh` helpers (`capture_output`, `assert_*`) and follow the end-to-end style.

To avoid host key verification prompts during tests, the SSH config should be set up in `tests/util.sh`'s `setup()` function:

```bash
# In tests/util.sh setup()
mkdir -p "${TEST_HOME}/.ssh"
cat > "${TEST_HOME}/.ssh/config" <<EOF
Host test-ssh-server
  HostName ${BLARG_SSH_TEST_HOST}
  Port ${BLARG_SSH_TEST_PORT}
  User ${BLARG_SSH_TEST_USER}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
chmod 600 "${TEST_HOME}/.ssh/config"
```

This runs for all tests (not just SSH tests), but shouldn't hurt anything. Then use the SSH alias in tests:

```bats
@test 'ssh - connectivity - prints hi' {
    capture_output ssh test-ssh-server echo hi
    assert_exit_code 0
    assert_stdout '^hi$'
}

@test 'ssh - basic execution - success' {
    use_target simple_apply
    capture_output blarg --ssh test-ssh-server targets/simple_apply.bash
    assert_exit_code 0
    assert_stdout '^hi$'
}
```

This keeps host key bypass in test infrastructure (SSH config), not in blarg itself.

## Future Enhancements

- Support for SSH port specification via `~/.ssh/config` (already works)
- Support for SSH key authentication via `~/.ssh/config` (already works)
- Caching of blarg binary on remote to avoid re-transfer
