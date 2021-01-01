#!/bin/bash

if ! type -f bpkg-logging &>/dev/null; then
  echo "error: bpkg-logging not found, aborting"
  exit 1
else
  source $(which bpkg-logging)
fi

## output usage
usage () {
  echo "Installs dependencies for a package."
  echo "usage: bpkg-getdeps [-h|--help] [-b|--break-mode]"
  echo "   or: bpkg-getdeps"
}

## Read a package property
bpkg_getdeps () {
  local cwd="$(pwd)"
  local pkg="${cwd}/package.json"
  local break_mode=0
  
  ## parse flags
  case "$1" in
    -h|--help)
      usage
      return 0
      ;;
    -b|--break-mode)
      break_mode=1
      ;;
  esac

  if (( 1 == break_mode )); then
    bpkg_warn "Get dependencies in break mode"
  fi

  ## ensure there is a package to read
  if ! test -f "${pkg}"; then
    echo 2>&1 "error: Unable to find \`package.json' in $(pwd)"
    return 1
  fi

  dependencies=$(cat "${pkg}" | bpkg-json -b | grep '\[\"dependencies' | sed "s/\[\"dependencies\",//" | sed "s/\"\]$(printf '\t')\"/@/" | tr -d '"')
  dependencies=($(echo "${dependencies[@]}"))

  ## run bpkg install for each dependency
  for (( i = 0; i < ${#dependencies[@]} ; ++i )); do
    local package=${dependencies[$i]}    

    if (( 1 == break_mode )); then
      bpkg install "${package}" -b
    else
      bpkg install "${package}"
    fi
  done
  return 0
}

if [[ ${BASH_SOURCE[0]} != $0 ]]; then
  export -f bpkg_getdeps
else
  bpkg_getdeps "${@}"
  exit $?
fi
