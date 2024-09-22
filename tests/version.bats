#!/usr/bin/env bats

source tests/util.sh

@test 'version - long version - returns version' {
    capture_output blarg --version
    assert_stdout '^blarg version [[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$'
    assert_no_stderr
    assert_exit_code 0
}

@test 'version - short version - returns version' {
    capture_output blarg -v
    assert_stdout '^blarg version [[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$'
    assert_no_stderr
    assert_exit_code 0
}
