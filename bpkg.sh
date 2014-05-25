#!/bin/bash

VERSION="0.0.6"

## output error to stderr
error () {
  printf >&2 "error: %s\n" "${@}"
}

## output usage
usage () {
  echo ""
  echo "  usage: bpkg [-hV] <command> [args]"
  echo ""
}

## feature tests
features () {
  declare -a local features=(bpkg-json)
  for ((i = 0; i < ${#features[@]}; ++i)); do
    local f="${features[$i]}"
    if ! type "${f}"  > /dev/null 2>&1; then
      error "Missing "${f}" dependency"
      return 1
    fi
  done
}

bpkg () {
  local arg="$1"
  local cmd=""
  shift

  ## test for required features
  features || return $?

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
  usage
}

## export or run
if [[ ${BASH_SOURCE[0]} != $0 ]]; then
  export -f bpkg
else
  bpkg "${@}"
  exit $?
fi
