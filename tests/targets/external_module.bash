#!/usr/bin/env blarg

depends_on @some_module:foobar

apply() {
    satisfy @some_module:print_env
    echo "Done!"
}
