# blarg

Target-based configuration management with Bash.

## "Target-based"

In the context of build systems or installer frameworks, a **target** is a specific,
desired end-state or result that a tool aims to achieve. It represents a named
objective, like creating an executable file, installing a software package, or
generating documentation. The tool then figures out the steps needed to reach that
target, handling dependencies and executing commands in the correct order.

With `blarg` you can easily define targets using plain Bash.

## Features

* simple target format (plain Bash)
* no installation required
* no configuration required
* no dependencies required (beyond what comes in a "normal" Linux distribution)
* easy code sharing between targets via an optional `lib.d` directory

## Example

Imagine we have a file called `cowsay_installed.bash`:

```bash
#!/usr/bin/env blarg

depends_on apt_updated

satisfied_if() {
  command -v cowsay
}

apply() {
  apt-get install -y cowsay
}
```

This is a `blarg` target, and it has one dependency: `apt_updated`. When `blarg`
executes this target, it will first check to see if the `apt_updated.bash` target has
been satisfied. If not, it will first go apply that target.

When `apt_updated` is satisfied, `blarg` will come back to the `cowsay_installed` target
and see if it has been satisfied by running the `satisfied_if` function. If not, it will
then run the `apply` function.

## Real-world example

The above example was a bit contrived, however one can see how it could be expanded
by constructing an entire dependency tree of targets. `blarg` will navigate as much of
the dependency tree as it needs to, and execute the `apply` functions in each target in
the correct order. It also has the ability to generate an error when there are circular
dependencies, and it can avoid applying a target more than once.

For a real-world example involving a much larger dependency tree, see
[my tinkering laptop configuration repository](https://github.com/pcrockett/lappy).

## Minimalism

`blarg` is a single Python script with less than 400 lines of code. It has three
dependencies (which are found on almost every Linux distribution out-of-the-box):

* Python 3.7 or newer
* Bash
* GNU Coreutils

`blarg` has three design goals:

1. It should be small and simple enough for one relatively Linux-experienced developer
   to understand in an afternoon.
2. It should have zero dependencies that aren't already available on most Linux machines
   out of the box.
3. It should be feature-complete, yet allow developers to add whatever additional
   features they need via Bash (or by creating a fork). Creating and maintaining a fork
   all by yourself should be simple.
