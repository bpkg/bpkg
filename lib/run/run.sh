#!/bin/bash

if ! type -f bpkg-utils &>/dev/null; then
  echo "error: bpkg-utils not found, aborting"
  exit 1
else
  # shellcheck disable=SC2230
  # shellcheck source=lib/utils/utils.sh
  source "$(which bpkg-utils)"
fi

if ! type -f bpkg-install &>/dev/null; then
  echo "error: bpkg-install not found, aborting"
  exit 1
else
  # shellcheck disable=SC2230
  # shellcheck source=lib/install/install.sh
  source "$(which bpkg-install)"
fi

if ! type -f bpkg-package &>/dev/null; then
  echo "error: bpkg-package not found, aborting"
  exit 1
else
  # shellcheck disable=SC2230
  # shellcheck source=lib/package/package.sh
  source "$(which bpkg-package)"
fi

bpkg_initrc

## outut usage
usage () {
  echo 'usage: bpkg-run [-h|--help]'
  echo '   or: bpkg-run [-s|--source] <package>'
  echo '   or: bpkg-run [-s|--source] <user>/<package>'
}

bpkg_run () {
  pushd . >/dev/null || return $?
  local ignore_args=0
  local needs_name=0
  local package=''
  local name=''

  for opt in "$@"; do
    case "$opt" in
      -h|--help)
        if (( 0 == ignore_args )); then
          usage
          return 0
        fi
        ;;

      -s|--source)
        if (( 0 == ignore_args )); then
          # shellcheck disable=SC1090
          source "$(which "$name")"
          return $?
        fi
        ;;

      -t|--target|--name)
        if (( 0 == ignore_args )); then
          shift
          needs_name=1
        fi
        ;;

      *)
        ignore_args=1
        if (( 1 == needs_name )); then
          name="$opt"
          shift
          needs_name=0
        fi
        ;;
    esac
  done

  local dest=$(bpkg_install --no-prune -g "$1" 2>/dev/null | grep 'info: Cloning' | sed 's/.* to //g' | xargs echo)

  if [ -z "$dest" ]; then return $?; fi

  cd "$dest" || return $?

  if [ -z "$name" ]; then
    name="$(bpkg_package name)"
  fi

  shift
  popd >/dev/null || return $?
  eval "$(which "$name")" $@
  return $?
}

## Use as lib or perform install
if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  export -f bpkg_run
elif validate_parameters; then
  bpkg_run "$@"
  exit $?
else
  #param validation failed
  exit $?
fi
