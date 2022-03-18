#!/bin/bash

if ! type -f bpkg-run &>/dev/null; then
  echo "error: bpkg-run not found, aborting"
  exit 1
else
  # shellcheck disable=SC2230
  # shellcheck source=lib/run/run.sh
  source "$(which bpkg-run)"
fi

bpkg_source () {
  bpkg_run --emit-source $@
  return $?
}

## Use as lib or perform install
if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  export -f bpkg_source
elif validate_parameters; then
  bpkg_source "$@"
  exit $?
else
  #param validation failed
  exit $?
fi
