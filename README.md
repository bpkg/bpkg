# bpkg

_JavaScript has npm, Ruby has Gems, Python has pip and now Shell has bpkg!_

`bpkg` is a lightweight bash package manager. It takes care of fetching the shell scripts, installing them appropriately, setting the execution permission and more.

You can install shell scripts globally (on `/usr/local/bin`) or use them on a _per-project basis_ (on `./deps/`), as a lazy-man "copy and paste".

<!-- BEGIN-MARKDOWN-TOC -->
* [Install](#install)
	* [0. Dependencies](#0-dependencies)
	* [1. Install script](#1-install-script)
	* [2. clib](#2-clib)
	* [3. Source Code](#3-source-code)
* [Usage](#usage)
	* [Installing packages](#installing-packages)
	* [Packages With Dependencies](#packages-with-dependencies)
	* [Retrieving package info](#retrieving-package-info)
* [Package details](#package-details)
* [package.json](#packagejson)
	* [name](#name)
	* [version (optional)](#version-optional)
	* [description](#description)
	* [global](#global)
	* [install](#install-1)
	* [scripts](#scripts)
	* [files](#files)
	* [dependencies (optional)](#dependencies-optional)
* [Packaging best practices](#packaging-best-practices)
	* [Package exports](#package-exports)
* [Sponsors](#sponsors)
* [License](#license)

<!-- END-MARKDOWN-TOC -->

## Install

You can install `bpkg` from three distinct ways:

### 0. Dependencies

* [curl](http://curl.haxx.se/)
* [coreutils](https://www.gnu.org/software/coreutils/)

### 1. Install script

Our install script is the simplest way. It takes care of everything for you, placing `bpkg` and related scripts on `/usr/local/bin`.

Paste the following on your shell and you're good to go:

```sh
$ curl -Lo- http://get.bpkg.io | bash
```

### 2. clib

[clib][clib] is a package manager for C projects. If you already have it, installing `bpkg` is a simple matter of:

```sh
$ clib install bpkg/bpkg
```

### 3. Source Code

To directly install `bpkg` from it's source code you have to clone it's repository and run the `setup.sh` script:

```sh
$ git clone https://github.com/bpkg/bpkg.git
$ cd bpkg
$ ./setup.sh
```

Or in a directory with user write permission, like `$HOME/opt/bin`

```sh
$ git clone https://github.com/bpkg/bpkg.git
$ cd bpkg
$ PREFIX=$HOME/opt ./setup.sh
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

After a local install the `term.sh` script is copied as `term` to the `deps/bin` directory, you can add this directory to the `PATH` with

```sh
export PATH=$PATH:/path_to_bkpg/deps/bin
```

As a bonus, you can specify a **specific version**:

```sh
$ bpkg install jwerle/suggest.sh@0.0.1 -g
```

**Note:** to do that the packages **must be tagged releases** on the repository.

You can also *install packages without a `package.json`*.
As long as there is a `Makefile` in the repository it will try to invoke `make install` as long as the `-g` or `--global` flags are set when invoking `bpkg install`.

For example you could install [git-standup](https://github.com/stephenmathieson/git-standup) with an omitted `package.json` because of the `Makefile` and the `install` target found in it.

```sh
$ bpkg install stephenmathieson/git-standup -g

    info: Using latest (master)
    warn: Package doesn't exist
    warn: Mssing build script
    warn: Trying `make install'...
    info: install: `make install'
cp -f git-standup /usr/local/bin
```

### Packages With Dependencies

You can install a packages dependencies with the `bpkg getdeps` command. These will recursively install in `deps/` sub-folders to resolve all dependencies.

_Note: There is no protection against circular dependencies, so be careful!_


### Retrieving package info

After installing a package, you can obtain info from it using `bpkg`.

Supposing you're on the root of a package directory, the following commands show that package metadata:

```sh
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

```json
  "name": "my-script"
```

### version (optional)

The `version` attribute is not required but can be useful. It should correspond to the version that is associated with the installed package.

```json
  "version": "0.0.1"
```

### description

A human readable description of what the package offers for functionality.

```json
  "description": "This script makes monkeys jump out of your keyboard"
```

### global

Indicates that the package is only intended to be install as a script. This allows the ommition of the `-g` or `--global` flag during installation.

```json
  "global": "true"
```

### install

Shell script used to invoke in the install script. This is required if the `global` attribute is set to `true` or if the `-g` or `--global` flags are provided.

```json
  "install": "make install"
```

### scripts

This is an array of scripts that will be installed into a project.

```json
  "scripts": ["script.sh"]
```

### files

This is an array of files that will be installed into a project.

```json
  "files": ["bar.txt", "foo.txt"]
```

### dependencies (optional)

This is a hash of dependencies. The keys are the package names, and the values are the version specifiers. If you want the latest code use `'master'` in the version specifier. Otherwise, use a tagged release identifier. This works the same as `bpkg install`'s package/version specifiers.

```json
  "dependencies": {
    "term": "0.0.1"
  }
```


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

## Sponsors

**bpkg** wouldn't be where it is today without the help of its authors, contributors, and sponsors:

* [@littlstar](https://github.com/littlstar) ([littlstar.com](https://littlstar.com))
* [@spotify](https://github.com/spotify) ([spotify.com](https://spotify.com))

## License

`bpkg` is released under the **MIT license**.

See file `LICENSE` for a more detailed description of it's terms.

[clib]: https://github.com/clibs/clib
[term]: https://github.com/bpkg/term
[json]: http://json.org/example
