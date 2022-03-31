#!/usr/bin/env bash

BPKG_JSON="$(which bpkg-json)"

if [ -z "$BPKG_JSON" ]; then
  BPKG_JSON="$(realpath "$0/../JSON/JSON.sh")"
else
  BPKG_JSON="$(realpath "$BPKG_JSON")"
fi

## output usage
usage () {
  echo "usage: bpkg-package [-h|--help]"
  echo "   or: bpkg-package [-p|--path]"
  echo "   or: bpkg-package <prop>"
  echo "   or: bpkg-package"
}

expand_grep_args () {
  local strict_ending=$(echo "$@" | grep '\-\-strict')

  if [ -n "$strict_ending" ]; then
    shift
  fi

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
    if [ -n "$strict_ending" ]; then
      printf '\]'
    else
      printf '\]?'
    fi
  fi

  return 0
}

find_file () {
  local path="$(pwd)"
  local file="$1"

  ## check if file exists at given path
  if test -f "$file"; then
    realpath "$file"
    return 0
  fi

  ## check if file exists joined with currrent path (cwd)
  if test -f "$path/$file"; then
    realpath "$path/$file"
    return 0
  fi

  ## check if file exists in paths stopping at $HOME and '/'
  while [[ "$path" != "$HOME" && "$path" != "/" && "$path" != "" ]]; do
    if test -f "$path/$file"; then
      realpath "$path/$file"
      return 0
    fi

    path="$(dirname "$path")"
  done

  return 1
}

bpkg_package_path () {
  local cwd="$(pwd)"
  ## search up for 'bpkg.json', but only in CWD for 'package.json'
  local pkgs=("bpkg.json"  "$cwd/package.json")

  for (( i = 0; i < ${#pkgs[@]}; i++ )); do
    if find_file "${pkgs[$i]}"; then
      return 0
    fi
  done

  return 1
}

## Read a package property
bpkg_package () {
  local cwd="$(pwd)"
  ## search up for 'bpkg.json', but only in CWD for 'package.json'
  local pkgs=("bpkg.json"  "$cwd/package.json")
  local npkgs="${#pkgs[@]}"

  ## parse flags
  case "$1" in
    -h|--help)
      usage
      return 0
      ;;

    -p|--path)
      bpkg_package_path
      return $?
      ;;
  esac

  ## attempt to find JSON manifest and query it
  for (( i = 0; i < npkgs; i++ )); do
    local pkg="$(find_file "${pkgs[$i]}")"

    if test -f "$pkg"; then
      if [ -z "$1" ]; then
        ## output all propertyies if property
        ## is ommited
        cat < "$pkg" | "$BPKG_JSON" -b
      else
        ## show value for a specific property
        ## in 'bpkg.json' or 'package.json'
        declare -a results
        declare -a peek

        # shellcheck disable=SC2068
        IFS=$'\n' read -r -d '' -a peek <<< "$(cat < "$pkg" | "$BPKG_JSON" -b | grep -E "$(expand_grep_args --strict "$@")")"

        # shellcheck disable=SC2068
        IFS=$'\n' read -r -d '' -a results <<< "$(cat < "$pkg" | "$BPKG_JSON" -b | grep -E "$(expand_grep_args $@)")"

        if (( ${#results[@]} == 1 )); then
          if (( ${#peek[@]} > 0 )); then
            echo "${results[@]}"        |
              awk '{ $1=""; print $0 }' | ## print value
              sed 's/^\s*//g'           | ## remove leading whitespace
              sed 's/\s*$//g'           | ## remove trailing whitespace
              sed 's/^"//g'             | ## remove leading quote from JSON value
              sed 's/"$//g'             | ## remove trailing quote from JSON value
              sed 's/^ *//;s/ *$//'
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

  echo 1>&2 "error: Unable to find \`bpkg.json' or \`package.json' in $cwd"
  return 1
}

if [ -z "$BPKG_JSON" ]; then
  echo 1>&2 "error: Failed to load 'bpkg-json'"
else
  if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
    export -f bpkg_package
    export -f bpkg_package_path
  else
    bpkg_package "${@}"
    exit $?
  fi
fi
