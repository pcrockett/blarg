# Agent Instructions for blarg

## Commands

- **Test**: `bats ./tests` or `make test`
- **Lint**: `make lint` (runs pre-commit hooks)
- **Full CI**: `make ci` (Docker-based, tests across Python 3.7–3.14)

## Project Structure

- `blarg`: Main executable (Python script, ~500 lines)
- `tests/`: BATS test suite; each test uses `tests/util.sh` helpers (`use_target`, `use_lib`, `capture_output`)
- `bin/`: CI helper scripts

## Target Files

- Targets are `.bash` files with shebang `#!/usr/bin/env blarg`
- Required functions: `depends_on`, `satisfied_if`, `apply`
- Shared code lives in `lib.d/` directory
- External modules: reference as `@module:target` (requires `BLARG_MODULE_<name>` env var)
- State cache lives in `.blarg/` (gitignored)

## Toolchain

- Tools managed via `mise.toml`; install with `mise install`
- shellcheck config: `external-sources=true`, `shell=bash`
- Pre-commit uses both repo hooks and local tools (shellcheck, shfmt, yamllint, yamlfmt, actionlint, hadolint)

## CI Quirks

- CI runs in Docker; `make ci` builds `blarg-ci:<version>` images for each Python version
- `bin/python-version-test.sh` orchestrates multi-version testing
- GitHub Actions workflow runs `make ci`
