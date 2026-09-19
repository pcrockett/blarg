#!/usr/bin/env bats

source tests/util.sh

blarg_ssh() {
    # the `</dev/null` causes ssh to properly forward stderr and stdout to the right
    # places in the right way. without it, the pty setup dumps everything to stdout,
    # adds `\r` linefeed characters, etc.
    blarg --ssh test-ssh-server "$@" </dev/null
}

@test 'ssh - successful target - success' {
    use_target simple_apply
    capture_output blarg_ssh targets/simple_apply.bash
    assert_no_stderr
    assert_stdout '^hi$'
    assert_exit_code 0
}

@test 'ssh - failed target - fails' {
    use_target panic
    capture_output blarg_ssh targets/panic.bash
    assert_stderr '^FATAL: OMG panic!
FATAL: panic\.apply\(\) returned with code 1\.$'
    assert_no_stdout
    assert_exit_code 1
}

@test 'ssh - with verbose flag - verbose output' {
    use_target simple_apply
    capture_output blarg_ssh --verbose targets/simple_apply.bash
    assert_exit_code 0
    assert_stdout '^--> simple_apply \[running\.\.\.\]
hi
--> simple_apply \[done\]$'
    assert_no_stderr
}

@test 'ssh - with dry-run flag - no apply' {
    use_target simple_apply
    capture_output blarg_ssh --dry-run targets/simple_apply.bash
    assert_exit_code 1
    assert_stdout '^dry-run: would apply simple_apply$'
    assert_no_stderr
}

@test 'ssh - invalid target path - error' {
    capture_output blarg_ssh /etc/hosts
    assert_exit_code 1
    assert_stderr 'outside the project directory'
    assert_no_stdout
}

@test 'ssh - crazy target name - uses proper shell quoting' {
    use_target simple_apply
    mv targets/simple_apply.bash 'targets/simple;apply.bash'
    capture_output blarg_ssh 'targets/simple;apply.bash'
    assert_no_stderr
    assert_stdout '^hi$'
    assert_exit_code 0
}

@test 'ssh - successful run - removes temp dir' {
    use_target pwd
    working_dir="$(blarg_ssh targets/pwd.bash)"
    capture_output ssh test-ssh-server test -d "${working_dir}"
    assert_no_stdout
    assert_no_stderr
    assert_exit_code 1
}

@test 'ssh - failed run - removes temp dir' {
    use_target pwd_then_panic
    working_dir="$(blarg_ssh targets/pwd_then_panic.bash)" || true
    capture_output ssh test-ssh-server test -d "${working_dir}"
    assert_no_stdout
    assert_no_stderr
    assert_exit_code 1
}

@test 'ssh - external module - resolves locally' {
    use_target simple_apply

    # Create a simple target that uses an external module
    cat >targets/use_external.bash <<'EOF'
#!/usr/bin/env blarg

depends_on @some_module:external_target

apply() {
    echo "main target done"
}
EOF
    chmod +x targets/*.bash

    # important: the external module is in TEST_HOME, not TEST_CWD. this ensures the
    # module source
    #
    # - remains on the local machine
    # - is never accessible by the remote machine.
    # - is cloned locally and transferred to the remote machine via the .blarg directory
    #
    module_path="${TEST_HOME}/some_module"
    init_git_repo "${module_path}"
    mkdir "${module_path}/targets"
    cat >"${module_path}/targets/external_target.bash" <<'EOF'
#!/usr/bin/env blarg
apply() {
    echo "external target output"
}
EOF
    chmod +x "${module_path}/targets/"*.bash
    git -C "${module_path}" add .
    git -C "${module_path}" commit -m "initial commit"
    git -C "${module_path}" tag v1

    cat >blarg.conf <<EOF
[module.some_module]
location = file://${module_path}/.git
ref = v1
EOF
    capture_output blarg_ssh targets/use_external.bash

    assert_stderr 'Cloning into'
    assert_stdout '^external target output
main target done$'
    assert_exit_code 0
}
