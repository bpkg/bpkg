#!/bin/bash

VERSION="0.1.0"

if ! type -f bpkg-utils &>/dev/null; then
  echo "error: bpkg-utils not found, aborting"
  exit 1
else
  # shellcheck source=../utils/utils.sh
  source "$(which bpkg-utils)"
fi

bpkg_initrc

usage () {
  mesg=$1
  if [ "$mesg" != "" ]; then
    echo "$mesg"
    echo
  fi
  echo "bpkg-show [-Vh]"
  echo "bpkg-show <user/package_name>"
  echo "bpkg-show readme <user/package_name>"
  echo "bpkg-show sources <user/package_name>"
  echo
  echo "Show bash package details.  You must first run \`bpkg update' to sync the repo locally."
  echo
  echo "Commands:"
  echo "  readme        Print package README.md file, if available, suppressing other output"
  echo "  sources       Print all sources listed in bpkg.json (or package.json) scripts, in "
  echo "                order. This option suppresses other output and prints executable bash."
  echo
  echo "Options:"
  echo "  --help|-h     Print this help dialogue"
  echo "  --version|-V  Print version and exit"
}

show_package () {
  local pkg=$1
  local desc=$2
  local show_readme=$3
  local show_sources=$4
  local host=$BPKG_REMOTE_HOST
  local remote=$BPKG_REMOTE
  local git_remote=$BPKG_GIT_REMOTE
  local auth=""
  local json=""
  local readme=""
  local uri=""

  if [ "$BPKG_OAUTH_TOKEN" != "" ]; then
    auth="-u $BPKG_OAUTH_TOKEN:x-oauth-basic"
  fi

  if [ "$auth" == "" ]; then
    uri=$BPKG_REMOTE/$pkg/master
  else
    uri=$BPKG_REMOTE/$pkg/raw/master
  fi

  json=$(eval "curl $auth -sL '$uri/bpkg.json?$(date +%s)'")
  if [ "${json}" = '404: Not Found' ];then
    json=$(eval "curl $auth -sL '$uri/package.json?$(date +%s)'")
  fi
  readme=$(eval "curl $auth -sL '$uri/README.md?$(date +%s)'")

  local readme_len=$(echo "$readme" | wc -l | tr -d ' ')

  local version=$(echo "$json" | bpkg-json -b | grep '"version"' | sed 's/.*version"\]\s*//' | tr -d '\t' | tr -d '"')
  local author=$(echo "$json" | bpkg-json -b | grep '"author"' | sed 's/.*author"\]\s*//' | tr -d '\t' | tr -d '"')
  local pkg_desc=$(echo "$json" | bpkg-json -b | grep '"description"' | sed 's/.*description"\]\s*//' | tr -d '\t' | tr -d '"')
  local sources=$(echo "$json" | bpkg-json -b | grep '"scripts"' | cut -f 2 | tr -d '"' )
  local description=$(echo "$json" | bpkg-json -b | grep '"description"')
  local install_sh=$(echo "$json" | bpkg-json -b | grep '"install"' | sed 's/.*install"\]\s*//' | tr -d '\t' | tr -d '"')

  if [ "$pkg_desc" != "" ]; then
    desc="$pkg_desc"
  fi

  if [ "$show_sources" == '0' ] && [ "$show_readme" == "0" ]; then
    echo "Name: $pkg"
    if [ "$author" != "" ]; then
      echo "Author: $author"
    fi
    echo "Description: $desc"
    echo "Current Version: $version"
    echo "Remote: $git_remote"
    if [ "$install_sh" != "" ]; then
      echo "Install: $install_sh"
    fi
    if [ "$readme" == "" ]; then
      echo "README.md: Not Available"
    else
      echo "README.md: ${readme_len} lines"
    fi
  elif [ "$show_readme" != '0' ]; then
    echo "$readme"
  else
    # Show Sources
    OLDIFS="$IFS"
    IFS=$'\n'
    for src in $(echo "$sources"); do
      local http_code=$(eval "curl $auth -sL '$uri/$src?$(date +%s)' -w '%{http_code}' -o /dev/null")
      if (( http_code < 400 )); then
        local content=$(eval "curl $auth -sL '$uri/$src?$(date +%s)'")
        echo "#[$src]"
        echo "$content"
        echo "#[/$src]"
      else
        bpkg_warn "source not found: $src"
      fi
    done
    IFS="$OLDIFS"
  fi
}


bpkg_show () {
  local readme=0
  local sources=0
  local pkg=""
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
      readme)
        readme=1
        if [ "$sources" == "1" ]; then
          usage "Error: readme and sources are mutually exclusive options"
          return 1
        fi
        ;;
      source|sources)
        sources=1
        if [ "$readme" == "1" ]; then
          usage "Error: readme and sources are mutually exclusive options"
          return 1
        fi
        ;;
      *)
        if [ "${opt:0:1}" == "-" ]; then
          bpkg_error "unknown option: $opt"
          return 1
        fi
        if [ "$pkg" == "" ]; then
          pkg=$opt
        fi
    esac
  done

  if [ "$pkg" == "" ]; then
    usage
    return 1
  fi

  local i=0
  for remote in "${BPKG_REMOTES[@]}"; do
    local git_remote="${BPKG_GIT_REMOTES[$i]}"
    bpkg_select_remote "$remote" "$git_remote"
    if [ ! -f "$BPKG_REMOTE_INDEX_FILE" ]; then
      bpkg_warn "no index file found for remote: ${remote}"
      bpkg_warn "You should run \`bpkg update' before running this command."
      i=$((i+1))
      continue
    fi

    OLDIFS="$IFS"
    IFS=$'\n'
    for line in $(cat $BPKG_REMOTE_INDEX_FILE); do
      local name=$(echo "$line" | cut -d\| -f1 | tr -d ' ')
      local desc=$(echo "$line" | cut -d\| -f2)
      if [ "$name" == "$pkg" ]; then
        IFS="$OLDIFS"
        show_package "$pkg" "$desc" "$readme" "$sources"
        IFS=$'\n'
        return 0
      fi
    done
    IFS="$OLDIFS"
    i=$((i+1))
  done

  bpkg_error "package not found: $pkg"
  return 1
}

if [[ ${BASH_SOURCE[0]} != $0 ]]; then
  export -f bpkg_show
elif bpkg_validate; then
  bpkg_show "${@}"
fi
