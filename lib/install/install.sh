#!/usr/bin/env bash

if ! type -f bpkg-realpath &>/dev/null; then
  echo "error: bpkg-realpath not found, aborting"
  exit 1
else
  # shellcheck disable=SC2230
  # shellcheck source=lib/realpath/realpath.sh
  source "$(which bpkg-realpath)"
fi

if ! type -f bpkg-utils &>/dev/null; then
  echo "error: bpkg-utils not found, aborting"
  exit 1
else
  # shellcheck disable=SC2230
  # shellcheck source=lib/utils/utils.sh
  source "$(which bpkg-utils)"
fi

if ! type -f bpkg-getdeps &>/dev/null; then
  echo "error: bpkg-getdeps not found, aborting"
  exit 1
else
  # shellcheck disable=SC2230
  # shellcheck source=lib/getdeps/getdeps.sh
  source "$(which bpkg-getdeps)"
fi

bpkg_initrc

let prevent_prune=0
let force_actions=${BPKG_FORCE_ACTIONS:-0}
let needs_global=0

## check parameter consistency
validate_parameters () {
  if [[ ${#BPKG_GIT_REMOTES[@]} -ne ${#BPKG_REMOTES[@]} ]]; then
    error "$(printf 'BPKG_GIT_REMOTES[%d] differs in size from BPKG_REMOTES[%d] array' "${#BPKG_GIT_REMOTES[@]}" "${#BPKG_REMOTES[@]}")"
    return 1
  fi
  return 0
}

## outut usage
usage () {
  echo 'usage: bpkg-install [directory]'
  echo '   or: bpkg-install [-h|--help]'
  echo '   or: bpkg-install [-g|--global] [-f|--force] ...<package>'
  echo '   or: bpkg-install [-g|--global] [-f|--force] ...<user>/<package>'
}

## format and output message
message () {
  if type -f bpkg-term > /dev/null 2>&1; then
    bpkg-term color "$1"
  fi

  shift
  echo -n "    $1"
  shift

  if type -f bpkg-term > /dev/null 2>&1; then
    bpkg-term reset
  fi

  printf ': '

  if type -f bpkg-term > /dev/null 2>&1; then
    bpkg-term reset
    bpkg-term bright
  fi

  printf "%s\n" "$@"

  if type -f bpkg-term > /dev/null 2>&1; then
    bpkg-term reset
  fi
}

## output error
error () {
  message 'red' 'error' "$@" >&2

  return 0
}

## output warning
warn () {
  message 'yellow' 'warn' "$@" >&2

  return 0
}

## output info
info () {
  local title='info'

  if (( "$#" > 1 )); then
    title="$1"
    shift
  fi

  message 'cyan' "$title" "$@"

  return 0
}

save_remote_file () {
  local auth_param dirname path url

  url="$1"
  path="$2"
  auth_param="${3:-}"

  dirname="$(dirname "$path")"

  # Make sure directory exists
  if [[ ! -d "$dirname" ]];then
    mkdir -p  "$dirname"
  fi

  if [[ "$auth_param" ]];then
    curl --silent -L -o "$path" -u "$auth_param" "$url"
  else
    curl --silent -L -o "$path" "$url"
  fi

  return $?
}

url_exists () {
  local auth_param exists status url

  url="$1"
  auth_param="${2:-}"

  exists=0

  if [[ "$auth_param" ]];then
    status=$(curl --silent -L -w '%{http_code}' -o '/dev/null' -u "$auth_param" "$url")
    result="$?"
  else
    status=$(curl --silent -L -w '%{http_code}' -o '/dev/null' "$url")
    result="$?"
  fi

  # In some rare cases, curl will return CURLE_WRITE_ERROR (23) when writing
  # to `/dev/null`. In such a case we do not care that such an error occured.
  # We are only interested in the status, which *will* be available regardless.
  if [[ '0' != "$result" && '23' != "$result" ]] || (( status >= 400 )); then
    exists=1
  fi

  return "$exists"
}

fetch () {
  local auth_param url

  url="$1"
  auth_param="${2:-}"

  if [[ "$auth_param" ]];then
    curl --silent -L -u "$auth_param" "$url"
  else
    curl --silent -L "$url"
  fi

  return $?
}

## Install a bash package
bpkg_install () {
  local pkgs=()
  local did_fail=1

  for opt in "$@"; do
    case "$opt" in
      -h|--help)
        usage
        return 0
        ;;

      -g|--global)
        shift
        needs_global=1
        ;;

      -f|--force)
        shift
        force_actions=1
        ;;

      --no-prune)
        shift
        prevent_prune=1
        ;;

      *)
        if [[ '-' != "${opt:0:1}" ]]; then
          pkgs+=("$opt")
          shift
        else
          error "Unknown option \`$opt'"
          return 1
        fi
        ;;
    esac
  done

  export BPKG_FORCE_ACTIONS=$force_actions

  ## ensure there is a package to install
  if (( ${#pkgs[@]} == 0 )); then
    bpkg_getdeps
    return $?
  fi

  echo

  for pkg in "${pkgs[@]}"; do
    if test -d "$(bpkg_realpath "$pkg" 2>/dev/null)"; then
      if ! (cd "$pkg" && bpkg_getdeps); then
        return 1
      fi

      did_fail=0
      continue
    fi

    ## Check each remote in order
    local i=0
    for remote in "${BPKG_REMOTES[@]}"; do
      local git_remote=${BPKG_GIT_REMOTES[$i]}
      if bpkg_install_from_remote "$pkg" "$remote" "$git_remote" $needs_global; then
        did_fail=0
        break
      elif [[ "$?" == '2' ]]; then
        error 'fatal error occurred during install'
        return 1
      fi
      i=$((i+1))
    done
  done

  if (( did_fail == 1 )); then
    error 'package not found on any remote'
    return 1
  fi

  return 0
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
  local needs_global=$4

  local url=''
  local uri=''
  local version=''
  local json=''
  local user=''
  local name=''
  local repo=''
  local version=''
  local auth_param=''
  local has_pkg_json=0
  local package_file=''

  declare -a pkg_parts=()
  declare -a remote_parts=()
  declare -a scripts=()
  declare -a files=()

  ## get version if available
  {
    OLDIFS="$IFS"
    IFS="@"
    # shellcheck disable=SC2206
    pkg_parts=($pkg)
    IFS="$OLDIFS"
  }

  if [[ ${#pkg_parts[@]} -eq 1 ]]; then
    version='master'
    #info "Using latest (master)"
  elif [[ ${#pkg_parts[@]} -eq 2 ]]; then
    name="${pkg_parts[0]}"
    version="${pkg_parts[1]}"
  else
    error 'Error parsing package version'
    return 1
  fi

  ## split by user name and repo
  {
    OLDIFS="$IFS"
    IFS='/'
    # shellcheck disable=SC2206
    pkg_parts=($pkg)
    IFS="$OLDIFS"
  }

  if [[ ${#pkg_parts[@]} -eq 1 ]]; then
    user="$BPKG_PACKAGE_DEFAULT_USER"
    name="${pkg_parts[0]}"
  elif [[ ${#pkg_parts[@]} -eq 2 ]]; then
    user="${pkg_parts[0]}"
    name="${pkg_parts[1]}"
  else
    error 'Unable to determine package name'
    return 1
  fi

  ## clean up name of weird trailing
  ## versions and slashes
  name=${name/@*//}
  name=${name////}

  ## check to see if remote is raw with oauth (GHE)
  if [[ "${remote:0:10}" == "raw-oauth|" ]]; then
    info 'Using OAUTH basic with content requests'
    OLDIFS="$IFS"
    IFS="'|'"
    local remote_parts=("$remote")
    IFS="$OLDIFS"
    local token=${remote_parts[1]}
    remote=${remote_parts[2]}
    auth_param="$token:x-oauth-basic"
    uri="/$user/$name/raw/$version"
    ## If git remote is a URL, and doesn't contain token information, we
    ## inject it into the <user>@host field
    if [[ "$git_remote" == https://* ]] && [[ "$git_remote" != *x-oauth-basic* ]] && [[ "$git_remote" != *$token* ]]; then
      git_remote=${git_remote/https:\/\//https:\/\/$token:x-oauth-basic@}
    fi
  else
    uri="/$user/$name/$version"
  fi

  ## clean up extra slashes in uri
  uri=${uri/\/\///}
  info "Install $uri from remote $remote [$git_remote]"

  ## Ensure remote is reachable
  ## If a remote is totally down, this will be considered a fatal
  ## error since the user may have intended to install the package
  ## from the broken remote.
  {
    if ! url_exists "$remote" "$auth_param"; then
      error "Remote unreachable: $remote"
      return 2
    fi
  }

  ## build url
  url="$remote/$uri"
  local nonce="$(date +%s)"

  if url_exists "$url/bpkg.json?$nonce" "$auth_param"; then
    ## read 'bpkg.json'
    json=$(fetch "$url/bpkg.json?$nonce" "$auth_param")
    package_file='bpkg.json'
    has_pkg_json=1
  elif url_exists "$url/package.json?$nonce" "$auth_param"; then
    ## read 'package.json'
    json=$(fetch "$url/package.json?$nonce" "$auth_param")
    package_file='package.json'
    has_pkg_json=1
  fi

  if (( 0 == has_pkg_json )); then
    ## check to see if there's a Makefile. If not, this is not a valid package
    if ! url_exists "$url/Makefile?$nonce" "$auth_param"; then
      warn "Makefile not found, skipping remote: $url"
      return 1
    fi
  fi

  if (( 1 == has_pkg_json )); then
    ## get package name from 'bpkg.json' or 'package.json'
    name="$(
      echo -n "$json" |
      bpkg-json -b |
      grep -m 1 '"name"' |
      awk '{ $1=""; print $0 }' |
      tr -d '\"' |
      tr -d ' '
    )"

    ## get package name from 'bpkg.json' or 'package.json'
    repo="$(
      echo -n "$json" |
      bpkg-json -b |
      grep -m 1 '"repo"' |
      awk '{ $1=""; print $0 }' |
      tr -d '\"' |
      tr -d ' '
    )"

    ## check if forced global
    if [[ "$(echo -n "$json" | bpkg-json -b | grep '\["global"\]' | awk '{ print $2 }' | tr -d '"')" == 'true' ]]; then
      needs_global=1
    fi

    ## construct scripts array
    {
      scripts=($(echo -n "$json" | bpkg-json -b | grep '\["scripts' | awk '{ print $2 }' | tr -d '"'))

      ## create array by splitting on newline
      OLDIFS="$IFS"
      IFS=$'\n'
      # shellcheck disable=SC2206
      scripts=(${scripts[@]})
      IFS="$OLDIFS"
    }

    ## construct files array
    {
      files=($(echo -n "$json" | bpkg-json -b | grep '\["files' | awk '{ print $2 }' | tr -d '"'))

      ## create array by splitting on newline
      OLDIFS="$IFS"
      IFS=$'\n'
      files=("${files[@]}")
      IFS="$OLDIFS"
    }
  fi

  if [ -n "$repo" ]; then
    repo_url="$git_remote/$repo.git"
  else
    repo_url="$git_remote/$user/$name.git"
  fi

  ## build global if needed
  if (( 1 == needs_global )); then
    if (( has_pkg_json > 0 )); then
      ## install bin if needed
      build="$(echo -n "$json" | bpkg-json -b | grep '\["install"\]' | awk '{$1=""; print $0 }' | tr -d '\"')"
      build="$(echo -n "$build" | sed -e 's/^ *//' -e 's/ *$//')"
    fi

    if [[ -z "$build" ]]; then
      warn 'Missing build script'
      warn 'Trying "make install"...'
      build='make install'
    fi

    if [ -z "$PREFIX" ]; then
      if [ "$USER" == "root" ]; then
        PREFIX="/usr/local"
      else
        PREFIX="$HOME/.local"
      fi
      build="env PREFIX=$PREFIX $build"
    fi

    {(
      ## go to tmp dir
      cd "$([[ -n "$TMPDIR" ]] && echo "$TMPDIR" || echo /tmp)" || return $?
      ## prune existing
      ( (( 0 == prevent_prune )) && rm -rf "$name-$version")

      ## shallow clone
      info "Cloning $repo_url to $(pwd)/$name-$version"
      (test -d "$name-$version" || git clone "$repo_url" "$name-$version" 2>/dev/null) && (
          ## move into directory
          cd "$name-$version" && (
            ## checkout to branch version or checkout into
            ## branch 'main' just in case 'master' was renamed
            git checkout "$version" 2>/dev/null ||
              ([ "$version" = "master" ] && git checkout main 2>/dev/null) ||
              (git checkout master 2>/dev/null)
          )

          ## build
          info "Performing install: \`$build'"
          mkdir -p "$PREFIX"/{bin,lib}
          build_output=$(eval "$build")
          echo "$build_output"
      )

      ## clean up
      if (( 0 == prevent_prune )); then
        rm -rf "$name-$version"
      fi
    )}
  ## perform local install otherwise
  else
    ## copy 'bpkg.json' or 'package.json' over
    save_remote_file "$url/$package_file" "$BPKG_PACKAGE_DEPS/$name/$package_file" "$auth_param"

    ## make '$BPKG_PACKAGE_DEPS/' directory if possible
    mkdir -p "$BPKG_PACKAGE_DEPS/$name"

    ## make '$BPKG_PACKAGE_DEPS/bin' directory if possible
    mkdir -p "$BPKG_PACKAGE_DEPS/bin"

    # install package dependencies
    info "Install dependencies for $name"
    (cd "$BPKG_PACKAGE_DEPS/$name" && bpkg_getdeps)

    ## grab each script and place in deps directory
    for script in "${scripts[@]}"; do
      (
        if [[ "$script" ]];then
          local scriptname="$(echo "$script" | xargs basename )"

          info "fetch" "$url/$script"
          warn "BPKG_PACKAGE_DEPS is '$BPKG_PACKAGE_DEPS'"
          info "write" "$BPKG_PACKAGE_DEPS/$name/$script"
          save_remote_file "$url/$script" "$BPKG_PACKAGE_DEPS/$name/$script" "$auth_param"

          scriptname="${scriptname%.*}"
          info "$scriptname to PATH" "$BPKG_PACKAGE_DEPS/bin/$scriptname"

          if (( force_actions == 1 )); then
            ln -sf "$BPKG_PACKAGE_DEPS/$name/$script" "$BPKG_PACKAGE_DEPS/bin/$scriptname"
          else
            if test -f "$BPKG_PACKAGE_DEPS/bin/$scriptname"; then
              warn "'$BPKG_PACKAGE_DEPS/bin/$scriptname' already exists. Overwrite? (yN)"
              read -r yn
              case $yn in
                Yy) rm -f "$BPKG_PACKAGE_DEPS/bin/$scriptname" ;;
                *) return 1;
              esac
            fi

            ln -s "$BPKG_PACKAGE_DEPS/$name/$script" "$BPKG_PACKAGE_DEPS/bin/$scriptname"
          fi
          chmod u+x "$BPKG_PACKAGE_DEPS/bin/$scriptname"
        fi
      )
    done

    if [[ "${#files[@]}" -gt '0' ]]; then
      ## grab each file and place in correct directory
      for file in "${files[@]}"; do
      (
          if [[ "$file" ]];then
            info "fetch" "$url/$file"
            warn "BPKG_PACKAGE_DEPS is '$BPKG_PACKAGE_DEPS'"
            info "write" "$BPKG_PACKAGE_DEPS/$name/$file"
            save_remote_file "$url/$file" "$BPKG_PACKAGE_DEPS/$name/$file" "$auth_param"
          fi
        )
      done
    fi
  fi
  return 0
}

## Use as lib or perform install
if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  export -f bpkg_install
elif validate_parameters; then
  bpkg_install "$@"
  exit $?
else
  #param validation failed
  exit $?
fi
