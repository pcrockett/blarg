#!/usr/bin/env blarg

apply() {
    env | grep --perl-regexp '^BLARG_' | sort
}
