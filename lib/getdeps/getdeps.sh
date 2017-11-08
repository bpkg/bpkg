#!/bin/bash

## output usage
usage () {
  echo "Installs dependencies for a package."
  echo "usage: bpkg-getdeps [-h|--help]"
  echo "   or: bpkg-getdeps"
}

## format and output message
message () {
  if type -f bpkg-term > /dev/null 2>&1; then
    bpkg-term color "${1}"
  fi

  shift
  printf "    ${1}"
  shift

  if type -f bpkg-term > /dev/null 2>&1; then
    bpkg-term reset
  fi

  printf ': '

  if type -f bpkg-term > /dev/null 2>&1; then
    bpkg-term reset
    bpkg-term bright
  fi

  printf "%s\n" "${@}"

  if type -f bpkg-term > /dev/null 2>&1; then
    bpkg-term reset
  fi
}

## output error
error () {
  if (( LOG_LEVEL <= 4 )); then
    {
      message 'red' 'error' "${@}"
    } >&2
  fi
}

## output warning
warn () {
  if (( LOG_LEVEL <= 3 )); then
    {
      message 'yellow' 'warn' "${@}"
    } >&2
  fi
}

## output info
info () {
  local title='info'
  if (( "${#}" > 1 )); then
    title="${1}"
    shift
  fi

  if (( LOG_LEVEL <= 2 )); then
    message 'cyan' "${title}" "${@}"
  fi  
}

## output debug
debug () {
  local title='info'
  if (( "${#}" > 1 )); then
    title="${1}"
    shift
  fi

  if (( LOG_LEVEL <= 1 )); then
    message 'green' "${title}" "${@}"
  fi
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
    warn "Get dependencies in break mode"
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
