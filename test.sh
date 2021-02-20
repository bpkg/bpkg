#!/bin/bash

rm -rf deps/

./bpkg-update
./bpkg-list
./bpkg-show bpkg/github
./bpkg-install bpkg/term

rm -rf deps/

mkdir -p tmp/bin

PREFIX=$CWD/tmp bpkg-install bpkg/github -g

test -f tmp/bin/github || exit 1

rm -rf tmp
