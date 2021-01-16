#!/bin/bash

## output usage
usage () {
  echo "usage: bpkg-package [-h|--help]"
  echo "   or: bpkg-package <prop>"
  echo "   or: bpkg-package"
}

## Read a package property
bpkg_package () {
  local cwd pkg prop

  prop="${1}"
  cwd="$(pwd)"
  pkg="${cwd}/package.json"

  if ! test -f "${pkg}"; then
    pkg="${cwd}/package.json"
  fi

  ## parse flags
  case "${prop}" in
    -h|--help)
      usage
      return 0
      ;;
  esac

  ## ensure there is a package to read
  if ! test -f "${pkg}"; then
    echo 2>&1 "error: Unable to find 'bpkg.json' or 'package.json' in $(pwd)"
    return 1
  fi

  if [ -z "${prop}" ]; then
    ## output all propertyies if property
    ## is ommited
    {
      # shellcheck disable=SC2002
      cat "${pkg}" | bpkg-json -b
    }
  else
    ## show value for a specific property
    ## in 'bpkg.json' or 'package.json'
    {
      # shellcheck disable=SC2002
      cat "${pkg}" | bpkg-json -b | grep "${prop}" | awk '{ $1=""; printf $0 }'
      echo
    }
  fi

  return 0
}

if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  export -f bpkg_package
else
  bpkg_package "${@}"
  exit $?
fi
