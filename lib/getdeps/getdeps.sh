#!/usr/bin/env bash

let install_dev=0

## output usage
usage () {
  echo "Installs dependencies for a package."
  echo "usage: bpkg-getdeps [-h|--help]"
  echo "   or: bpkg-getdeps [-d|--dev]"
  echo "   or: bpkg-getdeps"
}

## Read a package property
bpkg_getdeps () {
  local cwd="$(pwd)"
  local pkg="${cwd}/bpkg.json"

  ## parse flags
  case "$1" in
    -h|--help)
      usage
      return 0
      ;;

    -d|--dev)
      shift
      install_dev=1
      ;;
  esac

  ## ensure there is a package to read
  if ! test -f "${pkg}"; then
    pkg="${cwd}/package.json"
    if ! test -f "${pkg}"; then
      echo 1>&2 "error: Unable to find \`bpkg.json' or \`package.json' in $cwd"
      return 1
    fi
  fi

  # shellcheck disable=SC2002
  dependencies=$(cat "${pkg}" | bpkg-json -b | grep '\["dependencies"' | sed "s/\[\"dependencies\",//" | sed "s/\"\]$(printf '\t')\"/@/" | tr -d '"')
  # shellcheck disable=SC2206
  dependencies=(${dependencies[@]})

  if (( 1 == install_dev )); then
    # shellcheck disable=SC2002
    dependencies_dev=$(cat "${pkg}" | bpkg-json -b | grep '\["dependencies-dev"' | sed "s/\[\"dependencies-dev\",//" | sed "s/\"\]$(printf '\t')\"/@/" | tr -d '"')
    # shellcheck disable=SC2206
    dependencies=(${dependencies[@]} ${dependencies_dev[@]})
  fi

  ## run bpkg install for each dependency
  for (( i = 0; i < ${#dependencies[@]} ; ++i )); do
    (
      local package=${dependencies[$i]}
      bpkg install "${package}"
    )
  done
  return 0
}

if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  export -f bpkg_getdeps
else
  bpkg_getdeps "${@}"
  exit $?
fi
