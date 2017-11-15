#!/bin/bash

## log levels
# 0 OFF
# 1 DEBUG
# 2 INFO 
# 3 WARN
# 4 ERROR
LOG_LEVEL="${LOG_LEVEL:-2}"

## format and output message
_message () {
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
bpkg_error () {
  if (( LOG_LEVEL <= 4 )); then
    {
      _message 'red' 'error' "${@}"
    } >&2
  fi
}

## output warning
bpkg_warn () {
  if (( LOG_LEVEL <= 3 )); then
    {
      _message 'yellow' 'warn' "${@}"
    } >&2
  fi
}

## output info
bpkg_info () {
  local title='info'
  if (( "${#}" > 1 )); then
    title="${1}"
    shift
  fi

  if (( LOG_LEVEL <= 2 )); then
    _message 'cyan' "${title}" "${@}"
  fi  
}

## output debug
bpkg_debug () {
  local title='info'
  if (( "${#}" > 1 )); then
    title="${1}"
    shift
  fi

  if (( LOG_LEVEL <= 1 )); then
    _message 'green' "${title}" "${@}"
  fi
}

export -f bpkg_debug
export -f bpkg_info
export -f bpkg_warn
export -f bpkg_error