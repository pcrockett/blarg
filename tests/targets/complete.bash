#!/usr/bin/env blarg
# an example usage of all built-in features

depends_on foobar

reached_if() {
    false
}

apply() {
    log_verbose "applying..."
    apply_target basic
    this_command_doesnt_exist_934hfnn || panic "Oops!"
}
