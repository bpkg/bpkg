#!/bin/bash

BPKG_JSON="$(which bpkg-json)"

if [ -z "$BPKG_JSON" ]; then
  BPKG_JSON="$(realpath "$0/../JSON/JSON.sh")"
else
  BPKG_JSON="$(realpath "$BPKG_JSON")"
fi

## output usage
usage () {
  echo "usage: bpkg-package [-h|--help]"
  echo "   or: bpkg-package <prop>"
  echo "   or: bpkg-package"
}

expand_grep_args () {
  local n=$#

	if (( n > 0 )); then
    printf '\['
  fi

  while (( $# > 0 )); do
    if [[ "$1" =~ ^[0-9]+$ ]]; then
      printf '%s' "$1"
    else
      printf '"%s"' "$1"
    fi
    shift
    if (( $# > 0)); then
      printf ','
    fi
  done

	if (( n > 0 )); then
    printf '\]?'
  fi

  return 0
}

## Read a package property
bpkg_package () {
  local cwd="$(pwd)"
  local pkgs=("$cwd/bpkg.json"  "${cwd}/package.json")
  local npkgs="${#pkgs[@]}"

  ## parse flags
  case "$1" in
    -h|--help)
      usage
      return 0
      ;;
  esac

  ## attempt to find JSON manifest and query it
  for (( i = 0; i < npkgs; i++ )); do
    local pkg="${pkgs[$i]}"

    if test -f "$pkg"; then
      if [ -z "$1" ]; then
        ## output all propertyies if property
        ## is ommited
        cat < "$pkg" | "$BPKG_JSON" -b
      else
        ## show value for a specific property
        ## in 'bpkg.json' or 'package.json'
        declare -a results
        # shellcheck disable=SC2068
        IFS=$'\n' read -r -d '' -a results <<< "$(cat < "$pkg" | "$BPKG_JSON" -b | grep -E "$(expand_grep_args $@)")"

        if (( ${#results[@]} == 1 )); then
          if (( $# > 1 )); then
            echo "${results[@]}" | awk '{ $1=""; printf $0 }' | tr -d '"' | sed 's/^ *//;s/ *$//'
          else
            echo "${results[@]}"
          fi
        else
          for (( j = 0; j < ${#results[@]}; j++ )); do
            echo "${results[j]}"
          done
        fi
        shift
      fi

      return 0
    fi
  done

  echo 2>&1 "error: Unable to find \`bpkg.json' or \`package.json' in $cwd"
  return 1
}

if [ -z "$BPKG_JSON" ]; then
  echo 1>&2 "error: Failed to load 'bpkg-json'"
else
  if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
    export -f bpkg_package
  else
    bpkg_package "${@}"
    exit $?
  fi
fi
