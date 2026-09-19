# Agent Instructions for blarg

## Commands

- **Test**: `bats ./tests` or `make test`
  - Run a specific set of tests: `bats ./tests/ssh_tests.bats`
- **Lint**: `make lint` (runs pre-commit hooks)
- **Full CI**: `make ci` (Docker-based, tests across Python 3.7–3.14)

## Project Structure

- `blarg`: Main executable (Python script, ~500 lines)
- `tests/`: BATS test suite; each test uses `tests/util.sh` helpers (`use_target`, `use_lib`, `capture_output`)
- `bin/`: CI helper scripts

## Structure of a typical blarg project

blarg is a target-based config tool. A typical blarg project exists in a git repository.
- Targets under a `targets` directory as `.bash` files with shebang `#!/usr/bin/env blarg`
- Most important functions in a target: `depends_on`, `satisfied_if`, `apply`
- Shared code lives in `lib.d/` directory
- External modules: reference as `@module:target` (requires entry in `blarg.conf`)
- State cache lives in `.blarg/` (gitignored)

## Process Model

blarg relies heavily on Unix process trees. A single `blarg` invocation spawns a tree of processes: the Python `blarg` process execs `bash` to run a target, which may call `depends_on` to trigger another `blarg` process for each dependency. Child processes inherit environment variables from their parent, which blarg uses extensively for state management (e.g., `BLARG_RUNNING_TARGETS` for circular dependency detection, `BLARG_MODULE_DIR`, `BLARG_TARGETS_DIR`). This recursive, process-based approach ensures clean isolation between target executions while maintaining shared context via the environment.

## Toolchain

- Tools managed via `mise.toml`; install with `mise install`
- shellcheck config: `external-sources=true`, `shell=bash`
- Pre-commit uses both repo hooks and local tools (shellcheck, shfmt, yamllint, yamlfmt, actionlint, hadolint)

## CI Quirks

- CI runs in Docker; `make ci` builds `blarg-ci:<version>` images for each Python version
- `bin/python-version-test.sh` orchestrates multi-version testing
- GitHub Actions workflow runs `make ci`

## Tests

Test naming convention is `<thing being tested> - <scenario> - <expected result>`. For
example, `depends_on - external module doesnt exist - error`.

Tests are end-to-end style, not unit tests. They don't adhere to many normal BATS
tests you may have seen elsewhere, but instead rely heavily on the functions defined
in `tests/util.sh`
