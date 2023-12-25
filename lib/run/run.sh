#!/usr/bin/env bash

if ! type -f bpkg-utils &>/dev/null; then
  echo "error: bpkg-utils not found, aborting"
  exit 1
fi

# shellcheck source=lib/utils/utils.sh
source "$(which bpkg-utils)"

# shellcheck source=lib/realpath/realpath.sh
bpkg_exec_or_exit bpkg-realpath &&
  source "$(which bpkg-realpath)"

# shellcheck source=lib/install/install.sh
bpkg_exec_or_exit bpkg-install &&
  source "$(which bpkg-install)"

# shellcheck source=lib/package/package.sh
bpkg_exec_or_exit bpkg-package &&
  source "$(which bpkg-package)"

bpkg_initrc

## output usage
usage () {
  echo 'usage: bpkg-run [-h|--help]'
  echo '   or: bpkg-run [-l|--list]'
  echo '   or: bpkg-run [-s|--source] <package> [command]'
  echo '   or: bpkg-run [-s|--source] <user>/<package> [command]'
}

bpkg_list_commands () {
  local commands
  local col_len
  local description

  commands="$(bpkg_package 2>/dev/null | grep '\["commands"' | sed 's/\["commands","\([^"]*\).*/\1/')"

  col_len="$(wc -L <<< "${commands}")"

  if [ "${col_len}" -eq 0 ]; then
    bpkg_error "No commands provided in BPKG package file."
    return 1
  fi

  for command in ${commands}; do
    description="$(bpkg_package commands-description "${command}")"

    if [ -z "${description}" ]; then
      description="Runs the ${command} command as defined in BPKG configuration"
    fi
    printf "  "

    bpkg_exec_exist bpkg-term &&
      bpkg-term color cyan

    printf "%-${col_len}s  " "${command}"

    bpkg_exec_exist bpkg-term && {
      bpkg-term reset
      bpkg-term bright
    }

    printf "%s\n" "${description}"

    bpkg_exec_exist bpkg-term &&
      bpkg-term reset
  done

  return 0
}

bpkg_runner () {
  local cmd="$1"
  shift

  if [ "${cmd:0:1}" = "\"" ]; then
    cmd="${cmd:1}"
  fi

  if [ "${cmd:-1}" = "\"" ]; then
    cmd="${cmd:0:${#cmd}-1}"
  fi

  eval "$cmd"

  return $?
}

bpkg_run () {
  local should_emit_source=0
  local should_source=0
  local should_clean=0
  local needs_name=0
  local dest=''
  local name=''

  for opt in "$@"; do
    case "$opt" in
      -h|--help)
        usage
        return 0
        ;;

      -l|--list)
        bpkg_list_commands
        return $?
        ;;

      -s|--source)
        should_source=1
        shift
        ;;

      --emit-source)
        should_emit_source=1
        shift
        ;;

      -c|--clean)
        should_clean=1
        shift
        ;;

      -t|--target|--name)
        needs_name=1
        shift
        ;;

      *)
        if (( 1 == needs_name )); then
          name="$opt"
          shift
        fi

        break
        ;;
    esac
  done

  if [ -n "$1" ]; then
    local cmd="$(bpkg_package commands "$1" 2>/dev/null)"

    if [ -n "$cmd" ]; then
      local root="$(dirname "$(bpkg_package --path)")"
      cd "$root" || return 1
      # shellcheck disable=SC2230
      # shellcheck source=lib/env/env.sh
      source "$(which bpkg-env)"

      local parts=()
      # shellcheck disable=SC2086
      read -r -a parts <<< $cmd
      local args=()
      local prefix="${parts[0]}"

      for (( i = 1; i < ${#parts[@]}; i++ )); do
        if [[ "${parts[$i]}" =~ \*.\* ]]; then
          local found=($(find . -path "${parts[$i]}"))
          if (( ${#found[@]} > 0 )); then
            args+=("${found[@]}")
          else
            # shellcheck disable=SC2086
            args+=($($(which ls) ${parts[$i]} 2>/dev/null))
          fi
        else
          args+=("${parts[$i]}")
        fi
      done

      shift
      bpkg_runner "$prefix ${args[*]}" "$@"
      return $?
    fi
  fi

  if which "$name" 2>/dev/null; then
    return 0
  fi

  if ! pushd . >/dev/null; then
    bpkg_error "Failed to 'pushd' to current working directory."
    return 1
  fi

  if (( 0 == should_clean )); then
    dest=$(bpkg_install --no-prune -g "${name:-$1}" | grep 'Cloning' | sed 's/.* to //g' | xargs echo)
  else
    dest=$(bpkg_install -g "${name:-$1}" | grep 'Cloning' | sed 's/.* to //g' | xargs echo)
  fi

  if [ -z "$dest" ]; then
    if (( 1 == should_emit_source )); then
      bpkg_error "The source '${name:-1}' was not found locally in a 'bpkg.json' or published as a package."
    else
      bpkg_error "The command '$1' was not found locally in a 'bpkg.json' or published as a package."
    fi
    return 1
  fi

  if ! cd "$dest" >/dev/null; then
    bpkg_error "Failed to change directory to package: '$dest'."
    return 1
  fi

  local pkg_name="$(bpkg_package name 2>/dev/null)"
  if [ -n "$pkg_name" ]; then
    name="$pkg_name"
  fi

  if (( 1 == should_emit_source )); then
    if which "$name" 2>/dev/null; then
      :
    elif test -f "$1"; then
      bpkg_realpath "$1"
    elif [ -n "$1" ] && which "$1" 2>/dev/null; then
      :
    fi
  else
    shift

    if (( 1 == should_source )); then
      # shellcheck disable=SC1090
      source "$(which "$name")"
    else
      # shellcheck disable=SC2230
      # shellcheck source=lib/env/env.sh
      source "$(which bpkg-env)"

      cmd="$(bpkg_package commands "$1" 2>/dev/null)"

      if [ -n "$cmd" ]; then
        local parts=()
        # shellcheck disable=SC2086
        read -r -a parts <<< $cmd
        local args=()
        local prefix="${parts[0]}"

        for (( i = 1; i < ${#parts[@]}; i++ )); do
          if [[ "${parts[$i]}" =~ \*.\* ]]; then
            local found=($(find . -path "${parts[$i]}"))
            if (( ${#found[@]} > 0 )); then
              args+=("${found[@]}")
            else
              # shellcheck disable=SC2086
              args+=($($(which ls) ${parts[$i]} 2>/dev/null))
            fi
          fi
        done

        shift
        bpkg_runner "$prefix ${args[*]}" "$@"
      fi

      # shellcheck disable=SC2068
      "$(which "$name")" $@
    fi
  fi

  if ! popd >/dev/null; then
    bpkg_error "Failed to 'popd' to previous working directory."
    return 1
  fi

  return $?
}

## Use as lib or perform install
if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  export -f bpkg_run
else
  bpkg_run "$@"
  exit $?
fi
