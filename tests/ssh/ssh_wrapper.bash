#!/usr/bin/env bash
exec /usr/bin/ssh -F "${HOME}/.ssh/config" "$@"
