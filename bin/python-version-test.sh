#!/usr/bin/env bash

set -Eeuo pipefail

versions=(
    3.8
    3.9
    3.10
    3.11
    3.12
)

main() {
    if [ "${#}" -gt 0 ]; then
        versions=("${@}")
    fi
    for v in "${versions[@]}"; do
        if [ "${BLARG_SKIP_BUILD:-}" == "" ]; then
            docker build --build-arg "PYTHON_VERSION=${v}" --tag "blarg-ci:${v}" .
        fi
        docker run --rm --mount "type=bind,source=.,target=/app,readonly" "blarg-ci:${v}"
    done
}

main "${@}"
