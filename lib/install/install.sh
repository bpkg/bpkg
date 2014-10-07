#!/bin/bash

# Include config rc file if found
CONFIG_FILE="$HOME/.bpkgrc"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

## set defaults
if [ ${#BPKG_REMOTES[@]} -eq 0 ]; then
  BPKG_REMOTES[0]=${BPKG_REMOTE-https://raw.githubusercontent.com}
  BPKG_GIT_REMOTES[0]=${BPKG_GIT_REMOTE-https://github.com}
fi
BPKG_USER="${BPKG_USER:-"bpkg"}"

## check parameter consistency
validate_parameters () {
  if [ ${#BPKG_GIT_REMOTES[@]} -ne ${#BPKG_REMOTES[@]} ]; then
    mesg='BPKG_GIT_REMOTES[%d] differs in size from BPKG_REMOTES[%d] array'
    fmesg=$(printf "$mesg" "${#BPKG_GIT_REMOTES[@]}" "${#BPKG_REMOTES[@]}")
    error "$fmesg"
    return 1
  fi
  return 0
}

## outut usage
usage () {
  echo "usage: bpkg-install [-h|--help]"
  echo "   or: bpkg-install [-g|--global] <package>"
  echo "   or: bpkg-install [-g|--global] <user>/<package>"
}

## format and output message
message () {
  if type -f bpkg-term > /dev/null 2>&1; then
    bpkg-term color "${1}"
  fi

  shift
  printf "    ${1}"
  shift

  if type -f bpkg-term > /dev/null 2>&1; then
    bpkg-term reset
  fi

  printf ": "

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
error () {
  {
    message "red" "error" "${@}"
  } >&2
}

## output warning
warn () {
  {
    message "yellow" "warn" "${@}"
  } >&2
}

## output info
info () {
  local title="info"
  if (( "${#}" > 1 )); then
    title="${1}"
    shift
  fi
  message "cyan" "${title}" "${@}"
}

## Install a bash package
bpkg_install () {
  local pkg=""
  local let needs_global=0
  declare -a args=( "${@}" )

  for opt in "${@}"; do
    if [ "-" = "${opt:0:1}" ]; then
      continue
    fi
    pkg="${opt}"
    break
  done

  for opt in "${@}"; do
    case "${opt}" in
      -h|--help)
        usage
        return 0
        ;;

      -g|--global)
        shift
        needs_global=1
        ;;

      *)
        if [ "-" = "${opt:0:1}" ]; then
          echo 2>&1 "error: Unknown argument \`${1}'"
          usage
          return 1
        fi
        ;;
    esac
  done

  ## ensure there is a package to install
  if [ -z "${pkg}" ]; then
    usage
    return 1
  fi

  echo

  ## Check each remote in order
  local let i=0
  for remote in "${BPKG_REMOTES[@]}"; do
    local git_remote=${BPKG_GIT_REMOTES[$i]}
    bpkg_install_from_remote "$pkg" "$remote" "$git_remote" $needs_global
    if [ "$?" == "0" ]; then
      return 0
    elif [ "$?" == "2" ]; then
      error "fatal error occurred during install"
      return 1
    fi
    i=$((i+1))
  done
  error "package not found on any remote"
  return 1
}

## try to install a package from a specific remote
## returns values:
##   0: success
##   1: the package was not found on the remote
##   2: a fatal error occurred
bpkg_install_from_remote () {
  local pkg=$1
  local remote=$2
  local git_remote=$3
  local let needs_global=$4

  local cwd=$(pwd)
  local url=""
  local uri=""
  local test_uri=""
  local version=""
  local status=""
  local json=""
  local user=""
  local name=""
  local version=""
  local auth_param=""
  local let has_pkg_json=1
  declare -a local pkg_parts=()
  declare -a local remote_parts=()
  declare -a local scripts=()

  ## get version if available
  {
    OLDIFS="${IFS}"
    IFS="@"
    pkg_parts=(${pkg})
    IFS="${OLDIFS}"
  }

  if [ ${#pkg_parts[@]} -eq 1 ]; then
    version="master"
    #info "Using latest (master)"
  elif [ ${#pkg_parts[@]} -eq 2 ]; then
    name="${pkg_parts[0]}"
    version="${pkg_parts[1]}"
  else
     error "Error parsing package version"
    return 1
  fi

  ## split by user name and repo
  {
    OLDIFS="${IFS}"
    IFS='/'
    pkg_parts=(${pkg})
    IFS="${OLDIFS}"
  }

  if [ ${#pkg_parts[@]} -eq 1 ]; then
    user="${BPKG_USER}"
    name="${pkg_parts[0]}"
  elif [ ${#pkg_parts[@]} -eq 2 ]; then
    user="${pkg_parts[0]}"
    name="${pkg_parts[1]}"
  else
    error "Unable to determine package name"
    return 1
  fi

  ## clean up name of weird trailing
  ## versions and slashes
  name=${name/@*//}
  name=${name////}


  ## check to see if remote is raw with oauth (GHE)
  if [ "${remote:0:10}" == "raw-oauth|" ]; then
    info "Using OAUTH basic with content requests"
    OLDIFS="${IFS}"
    IFS="|"
    local remote_parts=($remote)
    IFS="${OLDIFS}"
    local token=${remote_parts[1]}
    remote=${remote_parts[2]}
    auth_param="-u $token:x-oauth-basic"
    uri="/${user}/${name}/raw/${version}"
    ## If git remote is a URL, and doesn't contain token information, we
    ## inject it into the <user>@host field
    if [[ "$git_remote" == https://* ]] && [[ "$git_remote" != *x-oauth-basic* ]] && [[ "$git_remote" != *${token}* ]]; then
      git_remote=${git_remote/https:\/\//https:\/\/$token:x-oauth-basic@}
    fi
  else
    uri="/${user}/${name}/${version}"
  fi

  ## clean up extra slashes in uri
  uri=${uri/\/\///}
  info "Install $uri from remote $remote [$git_remote]"

  ## Ensure remote is reachable
  ## If a remote is totally down, this will be considered a fatal
  ## error since the user may have intended to install the package
  ## from the broken remote.
  {
    status=$(curl $auth_param -s "${remote}" -w '%{http_code}' -o /dev/null)
    if [ "0" != "$?" ] || (( status >= 400 )); then
      error "Remote unreachable: $remote"
      return 2
    fi
  }

  ## build url
  url="${remote}${uri}"
  repo_url=$git_remote/$user/$name.git

  ## determine if `package.json' exists at url
  {
    status=$(curl $auth_param -sL "${url}/package.json?`date +%s`" -w '%{http_code}' -o /dev/null)
    if [ "0" != "$?" ] || (( status >= 400 )); then
      warn "package.json doesn't exist"
      has_pkg_json=0
      # check to see if there's a Makefile. If not, this is not a valid package
      status=$(curl $auth_param -sL "${url}/Makefile?`date +%s`" -w '%{http_code}' -o /dev/null)
      if [ "0" != "$?" ] || (( status >= 400 )); then
        warn "Makefile not found, skipping remote: $url"
        return 1
      fi
    fi
  }

  ## read package.json
  json=$(curl $auth_param -sL "${url}/package.json?`date +%s`")

  if (( 1 == $has_pkg_json )); then
    ## check if forced global
    if [ ! -z $(echo -n $json | bpkg-json -b | grep '\["global"\]' | awk '{ print $2 }' | tr -d '"') ]; then
      needs_global=1
    fi

    ## construct scripts array
    {
      scripts=$(echo -n $json | bpkg-json -b | grep '\["scripts' | awk '{$1=""; print $0 }' | tr -d '"')
      OLDIFS="${IFS}"

      ## comma to space
      IFS=','
      scripts=($(echo ${scripts[@]}))
      IFS="${OLDIFS}"

      ## account for existing space
      scripts=($(echo ${scripts[@]}))
    }
  fi

  ## build global if needed
  if (( 1 == $needs_global )); then
    if (( 1 == $has_pkg_json )); then
      ## install bin if needed
      build="$(echo -n ${json} | bpkg-json -b | grep '\["install"\]' | awk '{$1=""; print $0 }' | tr -d '\"')"
      build="$(echo -n ${build} | sed -e 's/^ *//' -e 's/ *$//')"
    fi

    if [ -z "${build}" ]; then
      warn "Missing build script"
      warn "Trying \`make install'..."
      build="make install"
    fi

    {(
      ## go to tmp dir
      cd $( [ ! -z $TMPDIR ] && echo $TMPDIR || echo /tmp) &&
        ## prune existing
      rm -rf ${name}-${version} &&
        ## shallow clone
      info "Cloning $repo_url to $name-$version"
      git clone $repo_url ${name}-${version} &&
        (
      ## move into directory
      cd ${name}-${version} &&
        ## build
      info "Performing install: \`${build}'"
      build_output=$(eval "${build}")
      echo "$build_output"
      ) &&
        ## clean up
      rm -rf ${name}-${version}
    )}
  elif [ "${#scripts[@]}" -gt "0" ]; then
    ## get package name from `package.json'
    name="$(
      echo -n ${json} |
      bpkg-json -b |
      grep 'name' |
      awk '{ $1=""; print $0 }' |
      tr -d '\"' |
      tr -d ' '
    )"

    ## make `deps/' directory if possible
    mkdir -p "${cwd}/deps/${name}"

    ## copy package.json over
    curl $auth_param -sL "${url}/package.json" -o "${cwd}/deps/${name}/package.json"

    ## grab each script and place in deps directory
    for (( i = 0; i < ${#scripts[@]} ; ++i )); do
      (
        local script="$(echo ${scripts[$i]} | xargs basename )"
        info "fetch" "${url}/${script}"
        info "write" "${cwd}/deps/${name}/${script}"
        curl $auth_param -sL "${url}/${script}" -o "${cwd}/deps/${name}/${script}"
      )
    done
  fi

  return 0
}

## Use as lib or perform install
if [[ ${BASH_SOURCE[0]} != $0 ]]; then
  export -f bpkg_install
elif validate_parameters; then
  bpkg_install "${@}"
fi
exit $?
