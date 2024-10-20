# blarg

_Work in progress, still experimenting._

A blunt instrument for automating configuration with Bash.

## Example

Imagine you have the following repository structure:

```plaintext
|- targets/
|  |- apt_updated.bash
|  |- cowsay_installed.bash
|  |- moo.bash
```

In `apt_updated.bash`:

```bash
#!/usr/bin/env blarg

apply() {
  sudo apt-get update
}
```

In `cowsay_installed.bash`:

```bash
#!/usr/bin/env blarg

reached_if() {
  command -v cowsay
}

apply() {
  apply_target apt_updated
  sudo apt-get install --yes cowsay
}
```

And in `moo.bash`:

```bash
#!/usr/bin/env blarg

depends_on cowsay_installed

apply() {
  cowsay "MOOO!"
}
```

Assuming all these files are executable, you can then run:

```bash
./targets/moo.bash
```

This will automatically detect if you need to install `cowsay`, and if so, will run
`apt-get update`, then `apt-get install`, and then finally say _MOOO!_ And of course, if `cowsay`
is already installed, it'll skip all that `apt` stuff and just jump right to saying _MOOO!_
