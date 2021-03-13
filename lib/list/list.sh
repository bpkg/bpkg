#!/bin/bash

VERSION="0.0.1"

if ! type -f bpkg-utils &>/dev/null; then
  echo "error: bpkg-utils not found, aborting"
  exit 1
else
  # shellcheck disable=SC2230
  # shellcheck source=lib/utils/utils.sh
  source "$(which bpkg-utils)"
fi

bpkg_initrc

usage () {
  echo "bpkg-list [-h|--help] [-V|--version] [-d|--details]"
  echo
  echo "List all known bash packages from the repo.  You first must run \`bpkg update' to sync the repo locally."

  echo "Options:"
  echo "  --help|-h     Print this help dialogue"
  echo "  --version|-V  Print version and exit"
  echo "  --details|-d  More verbose output"
}

bpkg_list () {
  local verbose=0
  for opt in "${@}"; do
    case "$opt" in 
      -V|--version)
        echo "${VERSION}"
        return 0
        ;;
      -h|--help)
        usage
        return 0
        ;;
      -d|--details)
        verbose=1
        ;;
      *)
        if [ "${opt:0:1}" == "-" ]; then
          bpkg_error "unknown option: $opt"
          return 1
        fi
    esac
  done

  local i=0
  for remote in "${BPKG_REMOTES[@]}"; do
    local git_remote="${BPKG_GIT_REMOTES[$i]}"
    bpkg_select_remote "$remote" "$git_remote"
    if [ ! -f "$BPKG_REMOTE_INDEX_FILE" ]; then
      bpkg_warn "no index file found for remote: ${remote}"
      bpkg_warn "You should run \`bpkg update' before running this command."
      continue
    fi
    OLDIFS="$IFS"
    IFS=$'\n'
    local line
    while read -r line; do
      local desc name
      name=$(echo "$line" | cut -d\| -f1 | tr -d ' ')
      desc=$(echo "$line" | cut -d\| -f2)
      local host=$BPKG_REMOTE_HOST
      if [ "$verbose" == "1" ]; then
        echo "$name [$host] - $desc"
      else
        echo "$name"
      fi
    done < "${BPKG_REMOTE_INDEX_FILE}"

    IFS="$OLDIFS"
    i=$((i+1))
  done
}


if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  export -f bpkg_list
elif bpkg_validate; then
  bpkg_list "${@}"
fi
