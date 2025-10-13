#!/usr/bin/env blarg

TEMP_FILE="$(mktemp)"

func_a

satisfied_if() {
    func_b >"${TEMP_FILE}"
}

apply() {
    cat "${TEMP_FILE}"
    func_c
    rm -f "${TEMP_FILE}"
}
