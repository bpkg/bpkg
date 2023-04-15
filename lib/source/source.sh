#!/usr/bin/env bash

if ! type -f bpkg-utils &>/dev/null; then
  echo "error: bpkg-utils not found, aborting"
  exit 1
fi

# shellcheck source=lib/utils/utils.sh
source "$(which bpkg-utils)"

# shellcheck source=lib/run/run.sh
bpkg_exec_or_exit bpkg-run &&
  source "$(which bpkg-run)"


bpkg_source () {
  # shellcheck disable=SC2068
  bpkg_run --emit-source --target "$1" ${@:2}
  return $?
}

## Use as lib or perform install
if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  export -f bpkg_source
else
  bpkg_source "$@"
  exit $?
fi
