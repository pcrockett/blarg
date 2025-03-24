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

@test 'satisfied_if - returns false - executes apply' {
    use_target satisfied_if_false
    capture_output ./targets/satisfied_if_false.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^hi$'
}

@test 'satisfied_if - returns true - does not execute apply' {
    use_target satisfied_if_true
    capture_output ./targets/satisfied_if_true.bash
    assert_no_stderr
    assert_exit_code 0
    assert_no_stdout
}

@test 'depends_on - no apply or satisfied_if - executes dependencies' {
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
    assert_stderr '^FATAL: OMG panic!
FATAL: panic\.apply\(\) returned with code 1\.$'
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
    assert_no_stdout
    assert_exit_code 1
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
    assert_stdout '^--> verbose \[running\.\.\.\]
BLARG_VERBOSE: True
--> verbose \[done\]$'
}

@test 'verbose - always - inherited from parent target' {
    use_target verbose verbose_parent
    capture_output blarg --verbose ./targets/verbose_parent.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^--> verbose_parent \[dependencies\.\.\.\]
 --> verbose \[running\.\.\.\]
BLARG_VERBOSE: True
 --> verbose \[done\]
--> verbose_parent \[running\.\.\.\]
BLARG_VERBOSE: True
--> verbose_parent \[done\]$'
}

@test 'verbose - targets not reached - shows running' {
    use_target basic foobar
    capture_output blarg --verbose targets/basic.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^--> basic \[dependencies\.\.\.\]
 --> foobar \[running\.\.\.\]
foobar!
 --> foobar \[done\]
--> basic \[running\.\.\.\]
hello, there\.\.\.
--> basic \[done\]$'
}

@test 'verbose - targets already reached - not silent' {
    use_target satisfied_if_true
    capture_output blarg --verbose targets/satisfied_if_true.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^--> satisfied_if_true \[running\.\.\.\]
--> satisfied_if_true \[already satisfied\]$'
}

@test 'environment - always - populated' {
    use_target print_env
    capture_output ./targets/print_env.bash
    assert_no_stderr
    assert_exit_code 0
    stdout_regex="$(cat <<EOF
^BLARG_CWD=/tmp/blarg-test\.[[:alnum:]]+
BLARG_INDENT=-->[[:space:]]
BLARG_RUNNING_TARGETS=\["/tmp/blarg-test\.[[:alnum:]]+/targets/print_env\.bash"]
BLARG_RUN_DIR=/tmp/[[:print:]]+
BLARG_TARGETS_DIR=/tmp/blarg-test\.[[:alnum:]]+/targets
BLARG_TARGET_NAME=print_env
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
    assert_stdout '^some-usecase/dependency
some-usecase/main$'
}

@test 'verbose - no apply defined - shows during dependencies' {
    use_target depends_on_only dependency_a dependency_b
    export BLARG_VERBOSE=1
    capture_output ./targets/depends_on_only.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^--> depends_on_only \[dependencies\.\.\.\]
 --> dependency_a \[running\.\.\.\]
A!
 --> dependency_a \[done\]
 --> dependency_b \[running\.\.\.\]
B!
 --> dependency_b \[done\]
--> depends_on_only \[running\.\.\.\]
--> depends_on_only \[done\]$'
}

@test 'satisfy - always - applies other targets' {
    use_target satisfy satisfied_if_true satisfied_if_false panic
    export BLARG_VERBOSE=1
    capture_output ./targets/satisfy.bash
    assert_exit_code 1
    assert_stdout '^--> satisfy \[running\.\.\.\]
 --> satisfied_if_true \[running\.\.\.\]
 --> satisfied_if_true \[already satisfied\]
 --> satisfied_if_false \[running\.\.\.\]
hi
 --> satisfied_if_false \[done\]
 --> panic \[running\.\.\.\]$'
    assert_stderr '^FATAL: OMG panic!
FATAL: panic\.apply\(\) returned with code 1\.
FATAL: satisfy\.apply\(\) returned with code 1\.$'
}

@test 'satisfy - target doesnt exist - fails' {
    use_target satisfy_does_not_exist
    capture_output ./targets/satisfy_does_not_exist.bash
    assert_exit_code 1
    assert_stderr '^FATAL: Target does not exist: this_target_does_not_exist_kdhgaqeikfkgggg'
    assert_no_stdout
}

@test 'satisfy - target fails - fails' {
    use_target panic satisfy_fails
    capture_output ./targets/satisfy_fails.bash
    assert_no_stdout
    assert_exit_code 1
    assert_stderr '^FATAL: OMG panic!
FATAL: panic\.apply\(\) returned with code 1\.
FATAL: satisfy_fails\.apply\(\) returned with code 1\.$'
}

@test 'dump-src - always - begins with shebang' {
    use_target foobar
    capture_output blarg --dump-src targets/foobar.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^#!/usr/bin/env bash'
}

@test 'dump-src - always - passes shellcheck' {
    local targets=(
        complete
        basic
        simple_apply
        empty
        nested_deps
    )
    use_target "${targets[@]}"
    for t in "${targets[@]}"; do
        blarg --dump-src "targets/${t}.bash" > "${t}_dump.sh"
    done
    shellcheck ./*_dump.sh
}

@test 'satisfied_if - returns true - still applies dependencies' {
    use_target satisfied_if_true_with_deps foobar
    capture_output blarg --verbose ./targets/satisfied_if_true_with_deps.bash
    assert_no_stderr
    assert_exit_code 0
    assert_stdout '^--> satisfied_if_true_with_deps \[dependencies\.\.\.\]
 --> foobar \[running\.\.\.\]
foobar!
 --> foobar \[done\]
--> satisfied_if_true_with_deps \[running\.\.\.\]
--> satisfied_if_true_with_deps \[already satisfied\]$'
}

@test 'satisfied_if - encounters error - returns early' {
    use_target satisfied_if_true_with_error
    capture_output blarg ./targets/satisfied_if_true_with_error.bash
    assert_no_stderr
    assert_stdout '^You should see this\.$'
    assert_exit_code 0
}

@test 'indent - deeply-nested dependencies - indents appropriately' {
    use_target nested_deps nested_dep_1 nested_dep_2 nested_dep_3
    capture_output blarg --verbose ./targets/nested_deps.bash
    assert_no_stderr
    assert_stdout '^--> nested_deps \[dependencies\.\.\.\]
 --> nested_dep_1 \[dependencies\.\.\.\]
  --> nested_dep_2 \[dependencies\.\.\.\]
   --> nested_dep_3 \[running\.\.\.\]
hi
   --> nested_dep_3 \[done\]
  --> nested_dep_2 \[running\.\.\.\]
  --> nested_dep_2 \[done\]
 --> nested_dep_1 \[running\.\.\.\]
 --> nested_dep_1 \[done\]
--> nested_deps \[running\.\.\.\]
--> nested_deps \[done\]$'
    assert_exit_code 0
}

@test 'depends_on and satisfy - relative dependency - calculates path correctly' {
    use_target some-usecase foobar simple_apply
    capture_output blarg ./targets/some-usecase/relative_dependency.bash
    assert_no_stderr
    assert_stdout '^foobar!
hi$'
    assert_exit_code 0
}

@test 'targets_dir - trailing slash - doesnt matter' {
    use_target foobar
    BLARG_TARGETS_DIR="targets/" \
        capture_output blarg --verbose ./targets/foobar.bash
    assert_no_stderr
    assert_stdout '^--> foobar \[running\.\.\.\]
foobar!
--> foobar \[done\]$'
    assert_exit_code 0
}

@test 'targets_dir - target outside of dir - prints full path' {
    use_target basic foobar
    mv targets/basic.bash .
    capture_output blarg --verbose ./basic.bash
    assert_no_stderr
    assert_stdout '^--> /tmp/blarg-test\.[[:alnum:]]+/basic \[dependencies\.\.\.\]
 --> foobar \[running\.\.\.\]
foobar!
 --> foobar \[done\]
--> /tmp/blarg-test\.[[:alnum:]]+/basic \[running\.\.\.\]
hello, there\.\.\.
--> /tmp/blarg-test\.[[:alnum:]]+/basic \[done\]'
    assert_exit_code 0
}

@test 'dry_run - targets need apply - avoids executing apply' {
    use_target should_run_once run_once_a run_once_b
    capture_output blarg --dry-run ./targets/run_once_b.bash
    assert_no_stderr
    assert_exit_code 1
    assert_stdout '^dry-run: would apply should_run_once
dry-run: would apply run_once_a
dry-run: would apply run_once_b$'
}

@test 'dry_run - targets satisfied - exit code 0' {
    use_target satisfied_if_true
    capture_output blarg --dry-run ./targets/satisfied_if_true.bash
    assert_no_stderr
    assert_exit_code 0
    assert_no_stdout
}

@test 'apply - non-zero command exit - exits immediately' {
    use_target apply_non_zero_exit
    capture_output blarg ./targets/apply_non_zero_exit.bash
    assert_no_stdout
    assert_stderr '^FATAL: apply_non_zero_exit\.apply\(\) returned with code 1\.$'
    assert_exit_code 1
}
