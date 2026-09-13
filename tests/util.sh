# shellcheck shell=bash

setup() {
    set -Eeuo pipefail
    TEST_CWD="$(mktemp --directory --tmpdir=/tmp blarg-test.XXXXXX)"
    TEST_HOME="$(mktemp --directory --tmpdir=/tmp blarg-home.XXXXXX)"
    REPO_HOME="$(pwd)"
    TEST_BIN="${TEST_HOME}/.local/bin"
    mkdir -p "${TEST_BIN}"
    cp blarg "${TEST_BIN}"

    cd "${TEST_CWD}"
    export PATH="${TEST_BIN}:${PATH}"
    export HOME="${TEST_HOME}"

    mkdir -p "${TEST_HOME}/.ssh"
    cat >"${TEST_HOME}/.ssh/config" <<EOF
Host test-ssh-server
  HostName ${BLARG_SSH_TEST_HOST:-localhost}
  Port ${BLARG_SSH_TEST_PORT:-2222}
  User ${BLARG_SSH_TEST_USER:-testuser}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  IdentityFile ${TEST_HOME}/.ssh/id_ed25519
  LogLevel ERROR
EOF
    chmod 600 "${TEST_HOME}/.ssh/config"
    cp "${REPO_HOME}/tests/ssh/test_key" "${TEST_HOME}/.ssh/id_ed25519"
    chmod 600 "${TEST_HOME}/.ssh/id_ed25519"

    cp "${REPO_HOME}/tests/ssh/ssh_wrapper.bash" "${TEST_BIN}/ssh"
}

teardown() {
    rm -rf "${TEST_CWD}"
    rm -rf "${TEST_HOME}"
}

fail() {
    echo "${*}"
    exit 1
}

use_target() {
    mkdir --parent "${TEST_CWD}/targets"
    for t in "${@}"; do
        local src_path="${REPO_HOME}/tests/targets/${t}"
        if [ -d "${src_path}" ]; then
            cp -r "${src_path}" "${TEST_CWD}/targets"
        else
            cp "${src_path}.bash" "${TEST_CWD}/targets"
        fi
    done
}

use_lib() {
    cp -r "${REPO_HOME}/tests/lib.d" "${TEST_CWD}"
}

init_git_repo() {
    repo_path="${1}"
    git config --global init.defaultBranch main
    git config --global advice.detachedHead false
    git config --global user.email "nope@example.com"
    git config --global user.name "nope"
    git init "${repo_path}"
}

# shellcheck disable=SC2034  # this function returns data via variables
capture_output() {
    local stderr_file stdout_file
    stderr_file="$(mktemp)"
    stdout_file="$(mktemp)"
    capture_exit_code "${@}" \
        >"${stdout_file}" \
        2>"${stderr_file}"
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
