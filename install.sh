#!/bin/bash

VERSION="0.0.1"
REMOTE=${REMOTE:-https://github.com/bpkg/bpkg.git}
TMPDIR=${TMPDIR:-/tmp}
DEST=${DEST:-${TMPDIR}/bpkg-master}

## test if command exists
ftest () {
  if ! type -f "${1}" > /dev/null 2>&1; then
    return 1
  else
    return 0
  fi
}

## feature tests
features () {
  for f in "${@}"; do
    ftest "${f}" || {
      echo >&2 "  error: Missing \`${f}'"
      return 1
    }
  done
  return 0
}

## main setup
setup () {
  ## test for require features
  features git || return $?

  ## build
  {
    echo
    cd ${TMPDIR}
    echo "  info: pruning..."
    test -d ${DEST} && { echo "  warn: exists: \`${DEST}'"; }
    rm -rf ${DEST}
    echo "  info: fetching..."
    git clone --depth=1 ${REMOTE} ${DEST} > /dev/null 2>&1
    cd ${DEST}
    echo "  info: installing..."
    echo
    make install
  } >&2
  return $?
}

## go
setup
exit $?

