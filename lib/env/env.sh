#!/usr/bin/env bash

if ! type -f bpkg-utils &>/dev/null; then
  echo "error: bpkg-utils not found, aborting"
  exit 1
else
  # shellcheck disable=SC2230
  # shellcheck source=lib/utils/utils.sh
  source "$(which bpkg-utils)"
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

# Include config rc file if found
BPKG_USER_CONFIG_FILE="$HOME/.bpkgrc"

# Include config rc file if found
BPKG_LOCAL_CONFIG_FILE="$(pwd)/.bpkgrc"

## meta
export BPKG_DATE="$(date)"
export BPKG_HOME="${BPKG_HOME:-$HOME}"
export BPKG_INDEX="$BPKG_INDEX"

## os
export BPKG_OS="$(uname)"
export BPKG_CWD="$(pwd)"
export BPKG_BIN="$(which bpkg)"
export BPKG_USER="$USER"

## package
export BPKG_PACKAGE_USER
export BPKG_PACKAGE_NAME="$(bpkg_package name 2>/dev/null)"
export BPKG_PACKAGE_REPO="$(bpkg_package repo 2>/dev/null)"
export BPKG_PACKAGE_DEPS="${BPKG_PACKAGE_DEPS:-deps}"
export BPKG_PACKAGE_VERSION="$(bpkg_package version 2>/dev/null)"
export BPKG_PACKAGE_DESCRIPTION="$(bpkg_package description 2>/dev/null)"

## remote
export BPKG_REMOTE="$BPKG_REMOTE"
# shellcheck disable=SC2178
export BPKG_REMOTES="${BPKG_REMOTE[*]}"
export BPKG_REMOTE_RAW_PATH="$BPKG_REMOTE_RAW_PATH"

if test -f bpkg.json || test -f package.json; then
  declare -a BPKG_SCRIPT_SOURCES=()
  BPKG_SCRIPT_SOURCES+=($(find . -name '*.sh'))
  BPKG_SCRIPT_SOURCES+=($(find . -name '*.zsh'))
  BPKG_SCRIPT_SOURCES+=($(find . -name '*.bash'))
  export BPKG_SCRIPT_SOURCES
fi

## output usage
usage () {
  echo 'usage: bpkg-env [-h|--help]'
  echo '   or: bpkg-env <key|pattern> [--value]'
  echo
  echo 'example:'
  echo '$ bpkg-env BPKG_PACKAGE*'
  echo 'BPKG_PACKAGE_DEPS="deps"'
  echo 'BPKG_PACKAGE_DESCRIPTION="Lightweight bash package manager"'
  echo 'BPKG_PACKAGE_NAME="bpkg"'
  echo 'BPKG_PACKAGE_REPO="bpkg/bpkg"'
  echo 'BPKG_PACKAGE_USER="bpkg"'
  echo 'BPKG_PACKAGE_VERSION="1.0.7"'
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
    echo BPKG_SCRIPT_SOURCES=\""${BPKG_SCRIPT_SOURCES[*]}"\"
  }                      |   \
    grep '^\s*BPKG_'     |   \
    sed 's/^\s*//g'      |   \
    sort                 |   \
    {
      did_emit=0

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

        l=${#kv[1]}
        lm1=$(( l - 1 ))
        lm2=$(( l - 2 ))

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

## Use as lib or perform install
if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  export -f bpkg_env
else
  bpkg_env "$@"
  exit $?
fi
