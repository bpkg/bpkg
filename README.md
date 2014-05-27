bpkg
====

Lightweight bash package manager

## install

**Install script:**

```sh
$ curl -Lo- https://raw.githubusercontent.com/bpkg/bpkg/master/install.sh | bash
```

**[clib](https://github.com/clibs/clib):**

```sh
$ clib install bpkg/bpkg
```

**source:**

```sh
$ git clone https://github.com/bpkg/bpkg.git
$ cd bpkg
$ make install
```

## usage

### installing package

*global:*

```sh
$ bpkg install term -g
```

*project:* (installs into `deps/`)

```sh
$ bpkg install term
```

*versioned:*

```sh
$ bpkg install jwerle/suggest.sh@0.0.1 -g
```

**note:** Versioned packages must be tagged releases by the author.

*installing packages without a `package.json`:*

As long as there is a `Makefile` in the repository it will try to invoke
`make install` so long as the `-g` or `--global` flags are set when
invoking `bpkg install`.

One could install
[git-standup](https://github.com/stephenmathieson/git-standup) with an
omitted `package.json` because of the `Makefile` and the `install`
target found in it.

```sh
$ bpkg install stephenmathieson/git-standup -g

    info: Using latest (master)
    warn: Package doesn't exist
    warn: Mssing build script
    warn: Trying `make install'...
    info: install: `make install'
cp -f git-standup /usr/local/bin
```

### package info

From the root of a package directory:

```sh
$ bpkg package name
 "bpkg"
```

```sh
$ bpkg package version
 "0.0.5"
```

```sh
$ bpkg package
["name"]        "bpkg"
["version"]     "0.0.5"
["description"] "Lightweight bash package manager"
["global"]      true
["install"]     "make install"
```

## package.json

### name

The `name` attribute is required as it is used to tell `bpkg` where to
put it in the `deps/` directory in you project.

```json
  "name": "my-script"
```

### version

The `version` attribute is not required but can be useful. It should
correspond to the version that is associated with the installed package.

```json
  "version": "0.0.1"
```

### description

A human readable description of what the package offers for
functionality.

```json
  "description": "This script makes monkeys jump out of your keyboard"
```

### global

Indicates that the package is only intended to be install as a script.
This allows the ommition of the `-g` or `--global` flag during
installation.

```json
  "global": "true"
```

### install

Shell script used to invoke in the install script. This is required if
the `global` attribute is set to `true` or if the `-g` or `--global`
flags are provided.

```json
  "install": "make install"
```

### scripts

This is an array of scripts that will be installed into a project.

```json
  "scripts": ["script.sh"]
```

## best practices

### package exports

Its nice to have a bash package that can be used in the terminal and
also be invoked as a command line function. To achieve this the
exporting of your functionality *should* follow this pattern:

```sh
if [[ ${BASH_SOURCE[0]} != $0 ]]; then
  export -f my_script
else
  my_script "${@}"
  exit $?
fi
```

This allows a user to `source` your script or invoke as a script.

```sh
$ ./my_script.sh some args --blah
```

or

```sh
$ source my_script.sh
$ my_script some more args --blah
```

## license

MIT
