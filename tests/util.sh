# shellcheck shell=bash

setup() {
    set -Eeuo pipefail
    TEST_CWD="$(mktemp --directory --tmpdir=/tmp blarg-test.XXXXXX)"
    TEST_HOME="$(mktemp --directory --tmpdir=/tmp blarg-home.XXXXXX)"
    REPO_HOME="$(pwd)"
    mkdir -p "${TEST_HOME}/.local/bin"
    cp blarg "${TEST_HOME}/.local/bin"
    cp .tool-versions "${TEST_CWD}"
    cd "${TEST_CWD}"
    PATH="${TEST_HOME}/.local/bin:${PATH}"
    export HOME="${TEST_HOME}"
}

teardown() {
    rm -rf "${TEST_CWD}"
    rm -rf "${TEST_HOME}"
}

fail() {
    echo "${*}"
    exit 1
}

usecase() {
    mkdir --parent "${TEST_CWD}/targets"
    for t in "${@}"; do
        cp "${REPO_HOME}/tests/cases/${t}.bash" "${TEST_CWD}/targets"
    done
}

use_lib() {
    cp -r "${REPO_HOME}/tests/cases/lib.d" "${TEST_CWD}"
}

# shellcheck disable=SC2034  # this function returns data via variables
capture_output() {
    local stderr_file stdout_file
    stderr_file="$(mktemp)"
    stdout_file="$(mktemp)"
    capture_exit_code "${@}" \
        > "${stdout_file}" \
        2> "${stderr_file}"
    TEST_STDOUT="$(cat "${stdout_file}")"
    TEST_STDERR="$(cat "${stderr_file}")"
    rm -f "${stdout_file}" "${stderr_file}"
}

# shellcheck disable=SC2034  # this function returns data via variables
capture_exit_code() {
    if "${@}"; then
        TEST_EXIT_CODE=0
    else
        TEST_EXIT_CODE=$?
    fi
}

assert_exit_code() {
    test "${TEST_EXIT_CODE}" -eq "${1}" \
        || fail "Expected exit code ${1}; got ${TEST_EXIT_CODE}"
}

assert_stdout() {
    if ! [[ "${TEST_STDOUT}" =~ ${1} ]]; then
        printf "******STDOUT:******\n%s\n*******************\n" "${TEST_STDOUT}"
        printf "*****EXPECTED:*****\n%s\n*******************\n" "${1}"
        fail "stdout didn't match expected."
    fi
}

assert_no_stdout() {
    if [ "${TEST_STDOUT}" != "" ]; then
        printf "******STDOUT:******\n%s\n*******************\n" "${TEST_STDOUT}"
        fail "stdout is expected to be empty."
    fi
}

assert_stderr() {
    if ! [[ "${TEST_STDERR}" =~ ${1} ]]; then
        printf "******STDERR:******\n%s\n*******************\n" "${TEST_STDERR}"
        printf "*****EXPECTED:*****\n%s\n*******************\n" "${1}"
        fail "stderr didn't match expected."
    fi
}

assert_no_stderr() {
    if [ "${TEST_STDERR}" != "" ]; then
        printf "******STDERR:******\n%s\n*******************\n" "${TEST_STDERR}"
        fail "stderr is expected to be empty."
    fi
}
