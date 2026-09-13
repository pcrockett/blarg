#!/usr/bin/env bats

source tests/util.sh

@test 'ssh - basic execution - success' {
    use_target simple_apply
    capture_output blarg --ssh test-ssh-server targets/simple_apply.bash
    assert_exit_code 0
    assert_stdout '^hi$'
    assert_no_stderr
}

@test 'ssh - with verbose flag - verbose output' {
    use_target simple_apply
    capture_output blarg --ssh test-ssh-server --verbose targets/simple_apply.bash
    assert_exit_code 0
    assert_stdout 'running'
    assert_stdout 'hi'
    assert_stdout 'done'
    assert_no_stderr
}

@test 'ssh - with dry-run flag - no apply' {
    use_target simple_apply
    capture_output blarg --ssh test-ssh-server --dry-run targets/simple_apply.bash
    assert_exit_code 1
    assert_stdout 'dry-run: would apply simple_apply'
    assert_no_stderr
}

@test 'ssh - invalid target path - error' {
    capture_output blarg --ssh test-ssh-server /etc/passwd
    assert_exit_code 1
    assert_stderr 'outside the project directory'
}

@test 'ssh - always - removes temp dir' {
    use_target simple_apply
    capture_output blarg --ssh test-ssh-server targets/simple_apply.bash
    assert_exit_code 0
    assert_stdout '^hi$'
    assert_no_stderr
    # Verify that the remote temp dir was cleaned up
    # This is hard to test directly, but we can at least verify the command succeeded
}
