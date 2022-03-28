#!/usr/bin/env bash

if ! type -f bpkg-utils &>/dev/null; then
  echo "error: bpkg-utils not found, aborting"
  exit 1
else
  # shellcheck disable=SC2230
  # shellcheck source=lib/utils/utils.sh
  source "$(which bpkg-utils)"
fi

if ! type -f bpkg-env &>/dev/null; then
  echo "error: bpkg-env not found, aborting"
  exit 1
else
  # shellcheck disable=SC2230
  # shellcheck source=lib/env/env.sh
  source "$(which bpkg-env)"
fi

if ! type -f bpkg-install &>/dev/null; then
  echo "error: bpkg-install not found, aborting"
  exit 1
else
  # shellcheck disable=SC2230
  # shellcheck source=lib/install/install.sh
  source "$(which bpkg-install)"
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

## output usage
usage () {
  echo 'usage: bpkg-run [-h|--help]'
  echo '   or: bpkg-run [-h|--help] [command]'
  echo '   or: bpkg-run [-s|--source] <package> [command]'
  echo '   or: bpkg-run [-s|--source] <user>/<package> [command]'
}

bpkg_run () {
  local should_emit_source=0
  local should_source=0
  local should_clean=0
  local ignore_args=0
  local needs_name=0
  local dest=''
  local name=''

  for opt in "$@"; do
    case "$opt" in
      -h|--help)
        if (( 0 == ignore_args )); then
          usage
          return 0
        fi
        ;;

      -s|--source)
        if (( 0 == ignore_args )); then
          should_source=1
          shift
        fi
        ;;

      --emit-source)
        if (( 0 == ignore_args )); then
          should_emit_source=1
          shift
        fi
        ;;

      -c|--clean)
        if (( 0 == ignore_args )); then
          should_clean=1
          shift
        fi
        ;;

      -t|--target|--name)
        if (( 0 == ignore_args )); then
          shift
          needs_name=1
        fi
        ;;

      *)
        ignore_args=1
        if (( 1 == needs_name )); then
          name="$opt"
          shift
          needs_name=0
        fi
        ;;
    esac
  done

  local cmd="$(bpkg_package commands "$1" 2>/dev/null)"

  if [ -n "$cmd" ]; then
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
        args+=($(find . -path "${parts[$i]}"))
      else
        args+=("${parts[$i]}")
      fi
    done

    shift
    # shellcheck disable=SC2068
    "$prefix" ${args[@]} $@
    return $?
  fi

  if ! pushd . >/dev/null; then
    bpkg_error "Failed to 'pushd' to current working directory."
    return 1
  fi

  if (( 0 == should_clean )); then
    dest=$(bpkg_install --no-prune -g "$1" 2>/dev/null | grep 'Cloning' | sed 's/.* to //g' | xargs echo)
  else
    dest=$(bpkg_install -g "$1" 2>/dev/null | grep 'Cloning' | sed 's/.* to //g' | xargs echo)
  fi

  if [ -z "$dest" ]; then
    bpkg_error "The command '$1' was not found locally in a 'bpkg.json' or published as a package."
    return 1
  fi

  if ! cd "$dest" >/dev/null; then
    bpkg_error "Failed to change directory to package: '$dest'."
    return 1
  fi

  if [ -z "$name" ]; then
    name="$(bpkg_package name 2>/dev/null)"
  fi

  cmd="$(bpkg_package commands "$1" 2>/dev/null)"
  shift

  if ! popd >/dev/null; then
    bpkg_error "Failed to 'popd' to previous working directory."
    return 1
  fi

  if (( 1 == should_emit_source )); then
    which "$name"
  else
    if (( 1 == should_source )); then
      # shellcheck disable=SC1090
      source "$(which "$name")"
    else
      # shellcheck disable=SC2230
      # shellcheck source=lib/env/env.sh
      source "$(which bpkg-env)"

      if [ -n "$cmd" ]; then
        local parts=()
        # shellcheck disable=SC2086
        read -r -a parts <<< $cmd
        local args=()
        local prefix="${parts[0]}"

        for (( i = 1; i < ${#parts[@]}; i++ )); do
          if [[ "${parts[$i]}" =~ \*.\* ]]; then
            args+=($(find . -wholename "${parts[$i]}"))
          fi
        done

        shift
        # shellcheck disable=SC2068
        "$prefix" ${args[@]} $@
      fi

      # shellcheck disable=SC2068
      "$(which "$name")" $@
    fi
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
