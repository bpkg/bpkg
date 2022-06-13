#!/usr/bin/env bash

if ! type -f bpkg-package &>/dev/null; then
  echo "error: bpkg-package not found, aborting"
  exit 1
else
  # shellcheck disable=SC2230
  # shellcheck source=lib/package/package.sh
  source "$(which bpkg-package)"
fi

if ! type -f bpkg-realpath &>/dev/null; then
  echo "error: bpkg-realpath not found, aborting"
  exit 1
else
  # shellcheck disable=SC2230
  # shellcheck source=lib/realpath/realpath.sh
  source "$(which bpkg-realpath)"
fi

# List of bash source files
declare -a BPKG_PACKAGE_SOURCES=()

# Include config rc file if found
declare BPKG_USER_CONFIG_FILE="$HOME/.bpkgrc"

# Include config rc file if found
declare BPKG_LOCAL_CONFIG_FILE="$(pwd)/.bpkgrc"

## meta
export BPKG_DATE="$(date)"
export BPKG_HOME="${BPKG_HOME:-$HOME}"
export BPKG_INDEX
export BPKG_FORCE_ACTIONS

## os
export BPKG_OS="$(uname)"
export BPKG_CWD="$(pwd)"
export BPKG_BIN="${BPKG_BIN:-$(which bpkg)}"
export BPKG_USER="${BPKG_USER:-$USER}"

## git
export BPKG_REMOTES
export BPKG_GIT_REMOTE
export BPKG_GIT_REMOTES

## package
export BPKG_PACKAGE_USER
export BPKG_PACKAGE_NAME="$(bpkg_package name 2>/dev/null)"
export BPKG_PACKAGE_REPO="$(bpkg_package repo 2>/dev/null)"
export BPKG_PACKAGE_PATH="$(bpkg_package_path)"
export BPKG_PACKAGE_ROOT="$(bpkg_realpath "$(dirname "$BPKG_PACKAGE_PATH")")"
export BPKG_PACKAGE_DEPS="$BPKG_PACKAGE_ROOT/deps"
export BPKG_PACKAGE_VERSION="$(bpkg_package version 2>/dev/null)"
export BPKG_PACKAGE_DESCRIPTION"$(bpkg_package description 2>/dev/null)"
export BPKG_PACKAGE_DEFAULT_USER="${BPKG_PACKAGE_DEFAULT_USER:-bpkg}"

## remote
# shellcheck disable=SC2178
export BPKG_REMOTE
export BPKG_REMOTES
export BPKG_REMOTE_RAW_PATH

if test -f "$BPKG_PACKAGE_PATH"; then
  BPKG_PACKAGE_SOURCES+=($(find "$BPKG_PACKAGE_ROOT" -name '*.sh' 2>/dev/null))
  BPKG_PACKAGE_SOURCES+=($(find "$BPKG_PACKAGE_ROOT" -name '*.zsh' 2>/dev/null))
  BPKG_PACKAGE_SOURCES+=($(find "$BPKG_PACKAGE_ROOT" -name '*.bash' 2>/dev/null))
  export BPKG_PACKAGE_SOURCES
fi

if test -d "$BPKG_PACKAGE_DEPS/bin"; then
  export PATH="$BPKG_PACKAGE_DEPS/bin:$PATH"
fi

## output usage
usage () {
  cat <<USAGE
usage: bpkg-env [-h|--help]
  or: bpkg-env <key|pattern> [--value]

example:

  $ bpkg-env BPKG_PACKAGE*
  BPKG_PACKAGE_DEPS="deps"
  BPKG_PACKAGE_NAME="bpkg"
  BPKG_PACKAGE_DESCRIPTION"Lightweight bash package manager"
  BPKG_PACKAGE_REPO="bpkg/bpkg"
  BPKG_PACKAGE_USER="bpkg"
  BPKG_PACKAGE_VERSION="1.1.0"
USAGE
}

bpkg_env () {
  local key=""
  local should_emit_value=0

  for opt in "$@"; do
    case "$opt" in
      -h|--help)
        usage
        return 0
        ;;

      --value)
        should_emit_value=1
        shift
        ;;
      -*)
        bpkg_error "Unknown option: \`$opt'"
        return 2
        ;;

      *)
        key="$1"
        shift
        ;;
    esac
  done

  {
    printenv
    echo BPKG_PACKAGE_SOURCES=\""${BPKG_PACKAGE_SOURCES[*]}"\"
  }                      |   \
    grep '^\s*BPKG_'     |   \
    sed 's/^\s*//g'      |   \
    sort                 |   \
    {
      local did_emit=0

      while read -r line; do
        local kv=("" "")
        local j=0

        for (( i = 0; i < ${#line}; ++i )); do
          if [ "${line:$i:1}" = "=" ] && (( j == 0 )); then
            (( j++ ))
            continue
          fi

          kv[$j]+=${line:$i:1}
        done

        if [ -n "$key" ]; then
          regex="^${key/'*'/'.*'}$"
          if ! [[ "${kv[0]}" =~ $regex ]]; then
            continue
          fi
        fi

        if [ -z "${kv[1]}" ]; then
          continue
        fi

        if [ "${kv[1]:0:1}" = "$" ] || [ "${kv[1]:1:1}" = "$" ]; then
          continue
        fi

        if [ "${kv[1]:0:1}" = ";" ]; then
          continue
        fi

        if [ "${kv[1]}" = '"";' ]; then
          continue
        fi

        if (( should_emit_value == 0 )); then
          printf '%s=' "${kv[0]}"
        fi

        if [ "${kv[1]:0:1}" != '"' ]; then
          printf '"'
        fi

        printf '%s' "${kv[1]}"

        local l=${#kv[1]}
        local lm1=$(( l - 1 ))
        local lm2=$(( l - 2 ))

        if [ "${kv[1]:$lm1:1}" != '"' ] && [ "${kv[1]:$lm2:1}" != '"' ] && [ "${kv[1]:$lm1:1}" != ';' ] ; then
          printf '"'
        fi

      # shellcheck disable=SC2030,SC2031
      did_emit=1
      echo
    done

    if (( did_emit == 1 )); then
      return 0
    fi

    return 1
  }

  return $?
}

if [[ -f "$BPKG_USER_CONFIG_FILE" ]] && [ -z "$BPKG_USER_CONFIG_FILE_LOADED" ]; then
  export BPKG_USER_CONFIG_FILE
  export BPKG_USER_CONFIG_FILE_LOADED="1"
  # shellcheck disable=SC1090
  source "$BPKG_USER_CONFIG_FILE_LOADED"
fi

if [[ -f "$BPKG_LOCAL_CONFIG_FILE" ]] && [ -z "$BPKG_LOCAL_CONFIG_FILE_LOADED" ]; then
  export BPKG_LOCAL_CONFIG_FILE
  export BPKG_LOCAL_CONFIG_FILE_LOADED="1"
  # shellcheck disable=SC1090
  source "$BPKG_LOCAL_CONFIG_FILE"
fi

if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  export -f bpkg_env
else
  bpkg_env "$@"
  exit $?
fi
