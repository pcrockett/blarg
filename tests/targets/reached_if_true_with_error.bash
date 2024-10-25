#!/usr/bin/env blarg

reached_if() {
    false  # this should halt the function and return 1, causing apply() to run
    true   # this should never run, but if it DID, it would prevent apply() from running
}

apply() {
    echo "You should see this."
}
