bpkg-init
=========

Interactively generate a `package.json` for your [bpkg][bp]. Code, format,
and instructions based heavily on [jwerle's][jw] [clib-init][cb].

[bp]: https://github.com/bpkg/bpkg/
[jw]: https://github.com/jwerle/
[cb]: https://github.com/jwerle/clib-init/

install
-------

With [bpkg](https://github.com/bpkg/bpkg):

```sh
$ bpkg install benkogan/bpkg-init
```

From source:

```sh
$ git clone git@github.com:benkogan/bpkg-init.git /tmp/bpkg-init
$ cd /tmp/bpkg-init
$ make install
```

usage
-----

Simply invoke `bpkg init` and you wil be prompted with a series
of questions about the generation of your `package.json`. Most options
have sane defaults.

This will walk you through initializing the bpkg `package.json` file.
It will prompt you for the bare minimum that is needed and provide
defaults.

See github.com/bpkg/bpkg for more information on defining the bpkg
`package.json` file.

You can press `^C` anytime to quit this prompt. The `package.json` file
will only be written upon completion.

```sh
$ bpkg init

This will walk you through initializing the bpkg `package.json` file.
It will prompt you for the bare minimum that is needed and provide
defaults.

See github.com/bpkg/bpkg for more information on defining the bpkg
`package.json` file.

You can press ^C anytime to quit this prompt. The `package.json` file
will only be written upon completion.

name: (bpkg-init)

...
```

license
-------

MIT
