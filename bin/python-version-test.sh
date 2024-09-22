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
    for v in "${versions[@]}"; do
        docker build --build-arg "PYTHON_VERSION=${v}" --tag "blarg-ci:${v}" .

        echo "--> Testing Python ${v}..."
        docker run --rm --mount "type=bind,source=.,target=/app,readonly" "blarg-ci:${v}"
    done
}

main "${@}"
