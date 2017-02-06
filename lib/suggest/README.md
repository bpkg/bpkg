suggest.sh
==========

Suggests commands based on a query found in $PATH. Kinda like `which`
but with queries

## install

[bpkg](https://github.com/bpkg/bpkg)

```sh
$ bpkg install -g jwerle/suggest.sh
```

source:

```sh
$ git clone https://github.com/jwerle/suggest.sh.git
$ make install -C suggest/
```

## usage

```
usage: suggest [-hV] <query>
```

## example

```sh
$ suggest git
suggest: found 42 result(s)

  /usr/local/bin/git-alias
  /usr/local/bin/git-archive-file
  /usr/local/bin/git-back
  /usr/local/bin/git-bug
  /usr/local/bin/git-changelog
  /usr/local/bin/git-commits-since
  /usr/local/bin/git-contrib
  /usr/local/bin/git-count
  /usr/local/bin/git-create-branch
  /usr/local/bin/git-delete-branch
  /usr/local/bin/git-delete-merged-branches
  /usr/local/bin/git-delete-submodule
  /usr/local/bin/git-delete-tag
  /usr/local/bin/git-effort
  /usr/local/bin/git-extras

...
```

## license

MIT
