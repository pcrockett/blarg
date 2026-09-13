#!/usr/bin/env bash
exec /usr/bin/scp -F "${HOME}/.ssh/config" "$@"
