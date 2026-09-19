#!/usr/bin/env bash
set -euo pipefail

panic() {
    echo "FATAL: $*" >&2
    exit 1
}

get_tag() {
    ./blarg --version | sed 's/^blarg version /v/'
}

main() {
    tag="$(get_tag)" || panic "Unable to determine version"
    gh release create --generate-notes --draft "${tag}" ./blarg
}

main
