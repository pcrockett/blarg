#!/usr/bin/env bash

set -euo pipefail

versions=(
    3.8
    3.9
    3.10
    3.11
    3.12
    3.13
    3.14
    3.15
)

main() {
    if [ "${#}" -gt 0 ]; then
        versions=("${@}")
    fi
    for v in "${versions[@]}"; do
        mise exec "python@${v}" -- make test
    done
}

main "${@}"
