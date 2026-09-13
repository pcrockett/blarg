#!/usr/bin/env bats

source tests/util.sh

@test 'ssh - echo hi - prints hi' {
    capture_output ssh test-ssh-server echo hi
    assert_exit_code 0
    assert_stdout '^hi$'
    assert_no_stderr
}
