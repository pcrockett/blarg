# blarg

Imagine you have the following repository structure:

```plaintext
|- targets/
|  |- apt_updated.bl
|  |- cowsay_installed.bl
|  |- moo.bl
```

In `apt_updated.bl`:

```bash
#!/usr/bin/env blarg

apply() {
  sudo apt-get update
}
```

In `cowsay_installed.bl`:

```bash
#!/usr/bin/env blarg

depends_on apt_updated

reached_if() {
  command -v cowsay
}

apply() {
  sudo apt-get install --yes cowsay
}
```

And in `moo.bl`:

```bash
#!/usr/bin/env blarg

depends_on cowsay_installed

apply() {
  cowsay "MOOO!"
}
```

Assuming all these files are executable, you can then run:

```bash
./targets/moo.bl
```

This will automatically detect if you need to install `cowsay`, and if so, will run
`apt-get update`, then `apt-get install`, and then finally say _MOOO!_ And of course, if `cowsay`
is already installed, it'll skip all that `apt` stuff and just jump right to saying _MOOO!_
