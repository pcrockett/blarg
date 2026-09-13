#!/usr/bin/env bats

source tests/util.sh

@test 'ssh - basic execution - success' {
    use_target simple_apply
    capture_output blarg --ssh test-ssh-server targets/simple_apply.bash
    assert_exit_code 0
    assert_stdout '^hi$'
    assert_no_stderr
}
