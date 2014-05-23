#!/bin/bash

VERSION="0.0.2"

## output error to stderr
error () {
  printf >&2 "error: %s\n" "${@}"
}

## output usage
usage () {
  echo "usage: bpkg [-hV] <command> [args]"
}

## feature tests
features () {
  if ! type bpkg-json > /dev/null 2>&1; then
    error "Missing json parser dependency"
    exit 1
  fi
}

bpkg () {
  local arg="$1"
  local cmd=""
  shift

  case "${arg}" in

    ## flags
    -V|--version)
      echo "${VERSION}"
      return 0
      ;;

    -h|--help)
      usage
      return 0
      ;;

    *)
      cmd="bpkg-${arg}"
      if type -f "${cmd}" > /dev/null 2>&1; then
        "${cmd}" "${@}"
        return $?
      fi
      ;;

  esac
}

## test for required features
features

if [[ ${BASH_SOURCE[0]} != $0 ]]; then
  export -f bpkg
else
  bpkg "${@}"
  exit $?
fi
