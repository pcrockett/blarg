#!/usr/bin/env bats
#
# variable changes will be discarded. all tests run in subshells.
# shellcheck disable=SC2030
# shellcheck disable=SC2031
#

source tests/util.sh

@test 'version - long version - returns version' {
    capture_output blarg --version
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^blarg version [[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$'
}

@test 'no args - always - displays help' {
    capture_output blarg
    assert_exit_code 0
    assert_no_stderr
    assert_stdout '^usage: blarg'
}

@test 'simple apply - always - executes apply' {
    use_target simple_apply
    capture_output ./targets/simple_apply.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^hi$'
}

@test 'empty script - always - does nothing' {
    use_target empty
    capture_output ./targets/empty.bash
    assert_no_stderr
    assert_exit_code 0
    assert_no_stdout
}

@test 'reached_if - returns false - executes apply' {
    use_target reached_if_false
    capture_output ./targets/reached_if_false.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^hi$'
}

@test 'reached_if - returns true - does not execute apply' {
    use_target reached_if_true
    capture_output ./targets/reached_if_true.bash
    assert_no_stderr
    assert_exit_code 0
    assert_no_stdout
}

@test 'depends_on - no apply or reached_if - executes dependencies' {
    use_target depends_on_only dependency_a dependency_b
    capture_output ./targets/depends_on_only.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^A!
B!$'
}

@test 'panic - always - crashes script' {
    use_target panic
    capture_output ./targets/panic.bash
    assert_stderr '^FATAL: OMG panic!$'
    assert_exit_code 1
    assert_no_stdout
}

@test 'depends_on - circular deps - fails' {
    use_target circular_dep_a circular_dep_b
    capture_output ./targets/circular_dep_a.bash
    # shellcheck disable=SC2016  # intentionally not expanding backticks
    assert_stderr '^FATAL: Circular dependency detected at `.+/targets/circular_dep_a\.bash`:
.+/targets/circular_dep_a\.bash
-> .+/targets/circular_dep_b\.bash
-> .+/targets/circular_dep_a\.bash$'
    assert_exit_code 1
    assert_no_stdout
}

@test 'lib.d - exists - is used' {
    use_target lib_d
    use_lib
    capture_output ./targets/lib_d.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^function A was called!
function B was called!
function C was called!$'
}

@test 'depends_on - many targets depend on same target - dependency executed once' {
    use_target should_run_once run_once_a run_once_b
    capture_output ./targets/run_once_b.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^Created .has-run file.
A
B$'
}

@test 'verbose - always - sets env var in targets' {
    use_target verbose
    capture_output blarg --verbose ./targets/verbose.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^targets/verbose \[running\.\.\.\]
BLARG_VERBOSE: True
targets/verbose \[done\]$'
}

@test 'verbose - always - inherited from parent target' {
    use_target verbose verbose_parent
    capture_output blarg --verbose ./targets/verbose_parent.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^targets/verbose_parent \[running\.\.\.\]
targets/verbose \[running\.\.\.\]
BLARG_VERBOSE: True
targets/verbose \[done\]
BLARG_VERBOSE: True
targets/verbose_parent \[done\]$'
}

@test 'verbose - targets not reached - shows running' {
    use_target basic foobar
    capture_output blarg --verbose targets/basic.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^targets/basic \[running\.\.\.\]
targets/foobar \[running\.\.\.\]
foobar!
targets/foobar \[done\]
hello, there\.\.\.
targets/basic \[done\]$'
}

@test 'verbose - targets already reached - not silent' {
    use_target reached_if_true
    capture_output blarg --verbose targets/reached_if_true.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^targets/reached_if_true \[running\.\.\.\]
targets/reached_if_true \[done\]$'
}

@test 'environment - always - populated' {
    use_target print_env
    capture_output ./targets/print_env.bash
    assert_no_stderr
    assert_exit_code 0
    stdout_regex="$(cat <<EOF
^BLARG_CWD=/tmp/blarg-test\.[[:alnum:]]+
BLARG_RUNNING_TARGETS=\["/tmp/blarg-test\.[[:alnum:]]+/targets/print_env\.bash"]
BLARG_RUN_DIR=/tmp/[[:print:]]+
BLARG_TARGET_NAME=targets/print_env
BLARG_TARGET_PATH=/tmp/blarg-test\.[[:alnum:]]+/targets/print_env\.bash$
EOF
)"
    assert_stdout "${stdout_regex}"

}

@test 'usecase dir - always - executes main target' {
    use_target some-usecase
    capture_output blarg ./targets/some-usecase
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^targets/some-usecase/dependency
targets/some-usecase/main$'
}

@test 'verbose - no apply defined - shows during dependencies' {
    use_target depends_on_only dependency_a dependency_b
    export BLARG_VERBOSE=1
    capture_output ./targets/depends_on_only.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^targets/depends_on_only \[running\.\.\.\]
targets/dependency_a \[running\.\.\.\]
A!
targets/dependency_a \[done\]
targets/dependency_b \[running\.\.\.\]
B!
targets/dependency_b \[done\]
targets/depends_on_only \[done\]$'
}

@test 'apply_target - always - applies other targets' {
    use_target dynamic_apply reached_if_true reached_if_false panic
    export BLARG_VERBOSE=1
    capture_output ./targets/dynamic_apply.bash
    assert_exit_code 1
    assert_stdout '^targets/dynamic_apply \[running\.\.\.\]
targets/reached_if_true \[running\.\.\.\]
targets/reached_if_true \[done\]
targets/reached_if_false \[running\.\.\.\]
hi
targets/reached_if_false \[done\]
targets/panic \[running\.\.\.\]$'
    assert_stderr '^FATAL: OMG panic!$'
}

@test 'dump-src - always - begins with shebang' {
    use_target foobar
    capture_output blarg --dump-src targets/foobar.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^#!/usr/bin/env bash'
}

@test 'reached_if - returns true - still applies dependencies' {
    use_target reached_if_true_with_deps foobar
    capture_output blarg --verbose ./targets/reached_if_true_with_deps.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^targets/reached_if_true_with_deps \[running\.\.\.\]
targets/foobar \[running\.\.\.\]
foobar!
targets/foobar \[done\]
targets/reached_if_true_with_deps \[done\]$'
}
