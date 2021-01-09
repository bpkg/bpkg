#!/bin/bash

VERSION="0.0.1"

if ! type -f bpkg-utils &>/dev/null; then
  echo "error: bpkg-utils not found, aborting"
  exit 1
else
  # shellcheck source=../utils/utils.sh
  source "$(which bpkg-utils)"
fi

bpkg_initrc

usage () {
  echo "bpkg-update [-h] [-V]"
  echo
  echo "Update local bpkg index for listing and searching packages"
}

bpkg_update_remote() {
  local remote=$1
  local git_remote=$2
  local wiki_url=""
  local wiki=""

  bpkg_select_remote "$remote" "$git_remote"

  local index=$BPKG_REMOTE_INDEX
  mkdir -p "$index"

  local index_file="$index/index.txt"
  local auth=$BPKG_CURL_AUTH_PARAM

  if [ "$auth" == "" ]; then
    wiki_url="$BPKG_REMOTE/wiki/bpkg/bpkg/index.md"
  else
    # GHE wiki urls have a unique path structure
    wiki_url="$BPKG_REMOTE/raw/wiki/bpkg/bpkg/index.md"
  fi

  #echo "curl -slo- $auth '$wiki_url' | grep -o '\[.*\](.*).*'"
  repo_list=$(curl -sLo- $auth "$wiki_url" | grep -o '\[.*\](.*).*' | sed 's/\[\(.*\)\](.*)[ \-]*/\1|/' )

  num_repos=$(echo "$repo_list" | wc -l | tr -d ' ')
  bpkg_info "indexing ${num_repos} repos from $BPKG_REMOTE_HOST to $index_file"
  echo "$repo_list" > $index_file
}

bpkg_update () {
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
      *)
        if [ "${opt:0:1}" == '-' ]; then
          bpkg_error "unknown option: $opt"
          return 1
        fi
        ;;
    esac
  done

  local let i=0
  for remote in "${BPKG_REMOTES[@]}"; do
    local git_remote=${BPKG_GIT_REMOTES[$i]}
    bpkg_update_remote "$remote" "$git_remote"
    i=$((i+1))
  done
}

if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  export -f bpkg_update
elif bpkg_validate; then
  bpkg_update "${@}"
fi

