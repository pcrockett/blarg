#!/usr/bin/env blarg

apply() {
    test ! -f ".has-run" || panic "This target has already been run"
    touch ".has-run"
    echo "Created .has-run file."
}
