apply() {
    false # this is different from calling `panic` because `panic` calls `exit` explicitly
    echo "You shouldn't see this"
}
