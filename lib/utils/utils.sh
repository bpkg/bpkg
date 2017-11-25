#!/bin/bash

## Collection of shared bpkg functions
## Init local config and set environmental defaults
bpkg_initrc() {
  local global_config=${BPKG_GLOBAL_CONFIG:-"/etc/bpkgrc"}
  [ -f "$global_config" ] && source "$global_config"
  
  local user_config="$HOME/.bpkgrc"
  [[ -f "$user_config" ]] && source "$user_config"

  local dir_config="$(pwd)/.bpkgrc"
  [[ -f "$dir_config" ]] && source "$dir_config"

  ## set defaults
  if [[ ${#BPKG_REMOTES[@]} -eq 0 ]]; then
    BPKG_REMOTES[0]=${BPKG_REMOTE-https://raw.githubusercontent.com}
    BPKG_GIT_REMOTES[0]=${BPKG_GIT_REMOTE-https://github.com}
  fi

  BPKG_USER="${BPKG_USER:-"bpkg"}"
  BPKG_INDEX=${BPKG_INDEX:-"$HOME/.bpkg/index"}
}

## check parameter consistency
bpkg_validate () {
  bpkg_initrc

  if [ ${#BPKG_GIT_REMOTES[@]} -ne ${#BPKG_REMOTES[@]} ]; then
    mesg='BPKG_GIT_REMOTES[%d] differs in size from BPKG_REMOTES[%d] array'
    fmesg=$(printf "$mesg" "${#BPKG_GIT_REMOTES[@]}" "${#BPKG_REMOTES[@]}")
    error "$fmesg"
    return 1
  fi
  return 0
}

## takes a remote and git-remote and sets the globals:
##  BPKG_REMOTE: raw remote URI
##  BPKG_GIT_REMOTE: git remote for cloning
##  BPKG_AUTH_GIT_REMOTE: git remote with oauth info embedded,
##  BPKG_OAUTH_TOKEN: token for x-oauth-basic
##  BPKG_CURL_AUTH_PARAM: auth arguments for raw curl requests
##  BPKG_REMOTE_INDEX: location of local index for remote
bpkg_select_remote () {
  local remote=$1
  local git_remote=$2
  BPKG_REMOTE_HOST=$(echo "$git_remote" | sed 's/.*:\/\///' | sed 's/\/$//' | tr '/' '_')
  BPKG_REMOTE_INDEX="$BPKG_INDEX/$BPKG_REMOTE_HOST"
  BPKG_REMOTE_INDEX_FILE="$BPKG_REMOTE_INDEX/index.txt"
  BPKG_OAUTH_TOKEN=""
  BPKG_CURL_AUTH_PARAM=""
  BPKG_GIT_REMOTE=$git_remote
  BPKG_AUTH_GIT_REMOTE=$git_remote
  if [ "${remote:0:10}" == "raw-oauth|" ]; then
    OLDIFS="${IFS}"
    IFS="|"
    local remote_parts=($remote)
    IFS="${OLDIFS}"
    BPKG_OAUTH_TOKEN=${remote_parts[1]}
    BPKG_CURL_AUTH_PARAM="-u $BPKG_OAUTH_TOKEN:x-oauth-basic"
    BPKG_REMOTE=${remote_parts[2]}
    if [[ "$git_remote" == https://* ]] && [[ "$git_remote" != *x-oauth-basic* ]] && [[ "$git_remote" != *${BPKG_OAUTH_TOKEN}* ]]; then
      BPKG_AUTH_GIT_REMOTE=${git_remote/https:\/\//https:\/\/$BPKG_OAUTH_TOKEN:x-oauth-basic@}
    fi
  else
    BPKG_REMOTE=$remote
  fi
}

## given a user and name, sets BPKG_RAW_PATH using the available
## BPKG_REMOTE and BPKG_OAUTH_TOKEN details
bpkg_select_raw_path() {
  local user=$1
  local name=$2
  if [ "$BPKG_OAUTH_TOKEN" == "" ]; then
    BPKG_RAW_PATH="$BPKG_REMOTE/$user/$name"
  else
    BPKG_RAW_PATH="$BPKG_REMOTE/$user/$name/raw"
  fi
  return 0
}

function bpkg_is_osx(){
  if [[ "$(uname -a | grep "Darwin")" != "" ]] ; then
    return 0
  else
    return 1
  fi
}

function bpkg_esed(){
  if bpkg_is_osx; then
    sed -E "$@"
  else
    sed -r "$@"
  fi
}

export -f bpkg_initrc
export -f bpkg_validate

export -f bpkg_select_remote
export -f bpkg_select_raw_path

export -f bpkg_is_osx
export -f bpkg_esed