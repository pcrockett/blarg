#!/usr/bin/env blarg

apply() {
    env | grep --perl-regexp '^BLARG_' | python_sort
}

python_sort() {
    # the `sort` command is not consistent. so we use this hack instead:
    python3 -c '
import sys
print(
    "".join(
        sorted(
            sys.stdin.readlines()
        )
    )
)'
}
