#!/usr/bin/env bats

source tests/util.sh

@test 'simple apply - always - executes apply' {
    usecase simple_apply
    capture_output ./targets/simple_apply.bl
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^hi$'
}

@test 'empty script - always - does nothing' {
    usecase empty
    capture_output ./targets/empty.bl
    assert_no_stderr
    assert_exit_code 0
    assert_no_stdout
}

@test 'reached_if - returns false - executes apply' {
    usecase reached_if_false
    capture_output ./targets/reached_if_false.bl
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^hi$'
}

@test 'reached_if - returns true - does not execute apply' {
    usecase reached_if_true
    capture_output ./targets/reached_if_true.bl
    assert_no_stderr
    assert_exit_code 0
    assert_no_stdout
}

@test 'depends_on - no apply or reached_if - executes dependencies' {
    usecase depends_on_only dependency_a dependency_b
    capture_output ./targets/depends_on_only.bl
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^A!
B!$'
}

@test 'panic - always - crashes script' {
    usecase panic
    capture_output ./targets/panic.bl
    assert_stderr '^FATAL: OMG panic!$'
    assert_exit_code 1
    assert_no_stdout
}

@test 'depends_on - circular deps - fails' {
    usecase circular_dep_a circular_dep_b
    capture_output ./targets/circular_dep_a.bl
    # shellcheck disable=SC2016  # intentionally not expanding backticks
    assert_stderr '^FATAL: Circular dependency detected at `.+/targets/circular_dep_a\.bl`:
.+/targets/circular_dep_a\.bl
-> .+/targets/circular_dep_b\.bl
-> .+/targets/circular_dep_a\.bl$'
    assert_exit_code 1
    assert_no_stdout
}

@test 'lib.d - exists - is used' {
    usecase lib_d
    use_lib
    capture_output ./targets/lib_d.bl
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^function A was called!
function B was called!
function C was called!$'
}
