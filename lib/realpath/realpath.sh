#!/usr/bin/env bash

function bpkg_realpath () {
  local target="$1"

  if [ -n "$(which realpath 2>/dev/null)" ]; then
    realpath "$@"
    return $?
  fi

  if test -d "$target"; then
    cd "$target" || return $?
    pwd
  elif test -f "$target"; then
    # file
    if [[ $target = /* ]]; then
      echo "$target"
    elif [[ $target == */* ]]; then
      cd "${1%/*}" || return $?
      echo "$(pwd)/${1##*/}"
    else
      echo "$(pwd)/$target"
    fi
  fi

  return 0
}

if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  export -f bpkg_realpath
else
  bpkg_realpath "$@"
  exit $?
fi
