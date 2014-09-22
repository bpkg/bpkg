# bpkg

_JavaScript has npm, Ruby has Gems, Python has pip and now Shell has bpkg!_

`bpkg` is a lightweight bash package manager. It takes care of fetching the shell scripts, installing them appropriately, setting the execution permission and more.

You can install shell scripts globally (on `/usr/local/bin`) or use them on a _per-project basis_ (on `./deps/`), as a lazy-man "copy and paste".

## Install

You can install `bpkg` from three distinct ways:

### 1. Install script

Our install script is the simplest way. It takes care of everything for you, placing `bpkg` and related scripts on `/usr/local/bin`.

Paste the following on your shell and you're good to go:

```sh
$ curl -Lo- http://get.bpkg.io| bash
```

### 2. clib

[clib][clib] is a package manager for C projects. If you already have it, installing `bpkg` is a simple matter of:

```sh
$ clib install bpkg/bpkg
```

### 3. Source Code

To directly install `bpkg` from it's source code you have to clone it's repository and install with `make`:

```sh
$ git clone https://github.com/bpkg/bpkg.git
$ cd bpkg
$ make install
```

## Usage

You use `bpkg` by simply sending commands, pretty much like `npm` or `pip`.

### Installing packages

Packages can either be global (on `/usr/local/bin`) or local (under `./deps`).

For example, here's a **global install** of the [term package][term]:

```sh
$ bpkg install term -g
$ term
```

And the same package as a **local install**:

```sh
$ bpkg install term
$ ./deps/term/term.sh
```

As a bonus, you can specify a **specific version**:

```sh
$ bpkg install jwerle/suggest.sh@0.0.1 -g
```

**Note:** to do that the packages **must be tagged releases** on the repository.

You can also *installing packages without a `package.json`*.
As long as there is a `Makefile` in the repository it will try to invoke `make install` so long as the `-g` or `--global` flags are set when invoking `bpkg install`.

For example you could install [git-standup](https://github.com/stephenmathieson/git-standup) with an omitted `package.json` because of the `Makefile` and the `install` target found in it.

```
$ bpkg install stephenmathieson/git-standup -g

    info: Using latest (master)
    warn: Package doesn't exist
    warn: Mssing build script
    warn: Trying `make install'...
    info: install: `make install'
cp -f git-standup /usr/local/bin
```

### Retrieving package info

After installing a package, you can obtain info from it using `bpkg`.

Supposing you're on the root of a package directory, the following commands show that package metadata:

```
# Asking for single information
$ bpkg package name
 "bpkg"
$ bpkg package version
 "0.0.5"
# Dumping all the metadata
$ bpkg package
["name"]        "bpkg"
["version"]     "0.0.5"
["description"] "Lightweight bash package manager"
["global"]      true
["install"]     "make install"
```

## Package details

Here we lay down some info on the structure of a package.

## package.json

Every package must have a file called `package.json`; it specifies package metadata on the [JSON format][json].

Here's an example of a well-formed `package.json`:

```json
{
  "name": "term",
  "version": "0.0.1",
  "description": "Terminal utility functions",
  "scripts": [ "term.sh" ],
  "install": "make install"
}
```

All fields are mandatory except when noted.
Here's a detailed explanation on all fields:

### name

The `name` attribute is required as it is used to tell `bpkg` where to put it in the `deps/` directory in you project.

    "name": "my-script"

### version (optional)

The `version` attribute is not required but can be useful. It should correspond to the version that is associated with the installed package.

    "version": "0.0.1"

### description

A human readable description of what the package offers for functionality.

    "description": "This script makes monkeys jump out of your keyboard"

### global

Indicates that the package is only intended to be install as a script. This allows the ommition of the `-g` or `--global` flag during installation.

    "global": "true"

### install

Shell script used to invoke in the install script. This is required if the `global` attribute is set to `true` or if the `-g` or `--global` flags are provided.

    "install": "make install"

### scripts

This is an array of scripts that will be installed into a project.

    "scripts": ["script.sh"]

## Packaging best practices

These are guidelines that we strongly encourage developers to follow.

### Package exports

It's nice to have a bash package that can be used in the terminal and also be invoked as a command line function. To achieve this the exporting of your functionality *should* follow this pattern:

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
# Running as a script
$ ./my_script.sh some args --blah
# Sourcing the script
$ source my_script.sh
$ my_script some more args --blah
```

## License

`bpkg` is released under the **MIT license**.

See file `LICENSE` for a more detailed description of it's terms.


[clib]: https://github.com/clibs/clib
[term]: https://github.com/bpkg/term
[json]: http://json.org/example
