#!/bin/bash

if ! type -f bpkg-logging &>/dev/null; then
  echo "error: bpkg-logging not found, aborting"
  exit 1
else
  source $(which bpkg-logging)
fi

if ! type -f bpkg-utils &>/dev/null; then
  echo "error: bpkg-utils not found, aborting"
  exit 1
else
  source $(which bpkg-utils)
fi

if ! type -f bpkg-utils-url &>/dev/null; then
  echo "error: bpkg-utils-url not found, aborting"
  exit 1
else
  source $(which bpkg-utils-url)
fi

bpkg_initrc

## try to uninstall a package from a specific remote
## returns values:
##   0: success
##   1: the package was not found on the remote
##   2: a fatal error occurred
_bpkg_uninstall_of_remote () {
  local pkg="$1"
  local remote="$2"
  local git_remote="$3"
  local needs_global=$4
  local break_mode=$5
  local dry_run=$6
  local needs_quiet=$7
  local auth_info="$8"

  local cwd=$(pwd)
  local url=''
  local uri=''
  local version=''
  local status=''
  local json=''
  local user=''
  local name=''
  local version=''
  local auth_param=''
  local has_pkg_json=1
  declare -a local pkg_parts=()
  declare -a local remote_parts=()
  declare -a local scripts=()
  declare -a local files=()
  local package_json_url makefile_url
  local install_basedir install_bindir install_sharedir

  ## get version if available
  pkg_parts=(${pkg/@/ })
  bpkg_debug "pkg_parts" "${pkg_parts[@]}"

  if [[ ${#pkg_parts[@]} -eq 1 ]]; then
    version='master'
    #bpkg_info "Using latest (master)"
  elif [[ ${#pkg_parts[@]} -eq 2 ]]; then
    name="${pkg_parts[0]}"
    version="${pkg_parts[1]}"
  else
     bpkg_error 'Error parsing package version'
    return 1
  fi

  ## split by user name and repo
  pkg_parts=(${pkg//\// })
  bpkg_debug "pkg_parts" "${pkg_parts[@]}"

  if [[ ${#pkg_parts[@]} -eq 0 ]]; then
    bpkg_error 'Unable to determine package name'
    return 1
  elif [[ ${#pkg_parts[@]} -eq 1 ]]; then
    user="${BPKG_USER}"
    name="${pkg_parts[0]}"
  else
    name="${pkg_parts[${#pkg_parts[@]}-1]}"
    unset pkg_parts[${#pkg_parts[@]}-1]
    pkg_parts=( "${pkg_parts[@]}" )
    user="$(IFS='/' ; echo "${pkg_parts[*]}")"
  fi

  ## clean up name of weird trailing
  ## versions and slashes
  name=${name/@*//}
  name=${name////}

  bpkg_debug "user" "${user}"
  bpkg_debug "name" "${name}"

  ## Adapter to different kind of git hosting services
  if bpkg_is_coding_net "${remote}"; then
    uri="/u/${user}/p/${name}/git/raw/${version}"
  elif bpkg_is_github_raw "${remote}"; then
    uri="/${user}/${name}/${version}"
  elif bpkg_is_local_path "${remote}"; then
    uri="/${user}/${name}"
  else
    uri="/${user}/${name}/raw/${version}"
  fi

  ## check to see if remote is raw with oauth (GHE) or access token
  if [[ ! -z "${auth_info}" ]]; then
    OLDIFS="${IFS}"
    IFS="'|'"
    local auth_info_parts=($auth_info)
    IFS="${OLDIFS}"
    local token=${auth_info_parts[1]}

    if [[ "${auth_info:0:10}" == "raw-oauth|" ]]; then
      bpkg_info 'Using OAUTH basic with content requests'
      auth_param="-u \"$token:x-oauth-basic\""

      ## If git remote is a URL, and doesn't contain token information, we
      ## inject it into the <user>@host field
      if [[ "$git_remote" == https://* ]] && [[ "$git_remote" != *x-oauth-basic* ]] && [[ "$git_remote" != *${token}* ]]; then
        git_remote="${git_remote/https:\/\//https:\/\/$token:x-oauth-basic@}"
      fi
    elif [[ "${auth_info:0:11}" == "raw-access|" ]]; then
      auth_param="--header 'PRIVATE-TOKEN: $token'"
    fi
  fi

  ## clean up extra slashes in uri
  uri=${uri/\/\///}
  bpkg_info "Uninstall $uri of remote $remote [$git_remote]"

  ## Ensure remote is reachable
  ## If a remote is totally down, this will be considered a fatal
  ## error since the user may have intended to uninstall the package
  ## from the broken remote.
  {
    if ! bpkg_url_exists "${remote}" "${auth_param}"; then
      bpkg_error "Remote unreachable: ${remote}"
      return 2
    fi
  }

  ## build url
  url="${remote}${uri}"

  if bpkg_is_coding_net "${remote}"; then
    repo_url="${git_remote}/u/${user}/p/${name}/git"
  elif bpkg_is_local_path "${remote}"; then
    repo_url="${git_remote}/${user}/${name}"
  else
    repo_url="${git_remote}/${user}/${name}.git"
  fi

  ## determine if 'package.json' exists at url
  package_json_url="${url}/package.json?$(date +%s)"
  makefile_url="${url}/Makefile?$(date +%s)"

  if bpkg_is_local_path "${url}"; then
    package_json_url="${url}/package.json"
    makefile_url="${url}/Makefile"
  fi

  {
    if ! bpkg_url_exists "${package_json_url}" "${auth_param}"; then
      bpkg_warn 'package.json doesn`t exist'
      has_pkg_json=0
      # check to see if there's a Makefile. If not, this is not a valid package
      if ! bpkg_url_exists "${makefile_url}" "${auth_param}"; then
        local makefile_missing_msg
        makefile_missing_msg="Makefile not found, skipping remote: $url"
        if (( 0 == break_mode )); then
          bpkg_error "${makefile_missing_msg}"
          return 1
        else
          bpkg_warn "${makefile_missing_msg}"
        fi
      fi
    fi
  }

  ## read package.json
  json=$(bpkg_read_package_json "${package_json_url}" "${auth_param}")

  if (( 1 == has_pkg_json )); then
    ## get package name from 'package.json'
    name="$(
      echo -n "${json}" |
      bpkg-json -b |
      grep 'name' |
      awk '{ $1=""; print $0 }' |
      tr -d '\"' |
      tr -d ' '
    )"

    ## check if forced global
    if [[ ! -z "$(echo -n "${json}" | bpkg-json -b | grep '\["global"\]' | awk '{ print $2 }' | tr -d '"')" ]]; then
      needs_global=1
    fi

    ## construct scripts array
    {
      scripts=$(echo -n "${json}" | bpkg-json -b | grep '\["scripts' | awk '{$1=""; print $0 }' | tr -d '"')
      OLDIFS="${IFS}"

      ## multilines to array
      new_scripts=()
      while read -r script; do
        new_scripts+=("${script}")
      done <<< "${scripts}"

      ## account for existing space
      scripts=("${new_scripts[@]}")
    }

    ## construct files array
    {
      files=$(echo -n "${json}" | bpkg-json -b | grep '\["files' | awk '{$1=""; print $0 }' | tr -d '"')
      OLDIFS="${IFS}"

      ## multilines to array
      new_files=()
      while read -r file; do
        new_files+=("${file}")
      done <<< "${files}"

      ## account for existing space
      files=("${new_files[@]}")
    }

  fi

  if (( 1 == needs_global )); then
    bpkg_info "Uninstall ${url} globally"
  fi

  if (( 1 == break_mode )); then
    bpkg_warn "Uninstall ${url} in break mode"
  fi

  ## build global in legacy mode if needed
  if (( 1 == needs_global )) && (( 0 == break_mode )); then
    if (( 1 == has_pkg_json )); then
      ## uninstall bin if needed
      build="$(echo -n "${json}" | bpkg-json -b | grep '\["uninstall"\]' | awk '{$1=""; print $0 }' | tr -d '\"')"
      build="$(echo -n "${build}" | sed -e 's/^ *//' -e 's/ *$//')"
    fi

    if [[ -z "${build}" ]]; then
      bpkg_warn "Missing build script"
      bpkg_warn "Trying \`make uninstall\`..."
      build="make uninstall"
    fi

    { (
      ## go to tmp dir
      cd "$( [[ ! -z "${TMPDIR}" ]] && echo "${TMPDIR}" || echo /tmp)" &&
      ## prune existing
      rm -rf "${name}-${version}" &&
      ## shallow clone
      bpkg_info "Cloning ${repo_url} to ${name}-${version}" &&
      git clone "${repo_url}" "${name}-${version}" &&
      (
        ## move into directory
        cd "${name}-${version}" &&
        git checkout ${version} &&
        ## build
        bpkg_info "Performing uninstall: \`${build}'" &&
        eval "${build}"
      ) &&
      ## clean up
      rm -rf "${name}-${version}"
    ) }
  fi

  if (( 1 == needs_global )) && (( 1 == break_mode )); then
    install_basedir="/usr/local"
    install_bindir="${install_basedir}/bin"
    install_sharedir="${install_basedir}/share/${name}"
  elif (( 0 == needs_global )) && (( 0 == break_mode )); then
    install_basedir="${cwd}/deps"
    install_bindir="${install_basedir}/bin"
    install_sharedir="${install_basedir}/${name}"
  elif (( 0 == needs_global )) && (( 1 == break_mode )); then
    install_basedir="${cwd}/deps"
    install_bindir="${install_basedir}/bin"
    install_sharedir="${install_basedir}/share/${name}"
  fi

  ## perform local uninstall otherwise
  if (( 0 == needs_global )) || (( 1 == break_mode )); then
    if [[ "${#scripts[@]}" -gt '0' ]]; then
      ## remove scripts in bin dir
      bpkg_debug "uninstall_scripts" "Uninstall scripts '${scripts[*]}'"

      for (( i = 0; i < ${#scripts[@]} ; ++i )); do
        (
          local script="${scripts[$i]}"
          script="$(basename "${script}")"

          if [[ "${script}" ]]; then
            local scriptname="${script%.*}"

            if (( 0 == dry_run )); then
              if (( 0 == needs_quiet )); then
                bpkg_debug "Remove '${install_bindir}/${scriptname}' quietly"
                rm -rf "${install_bindir}/${scriptname}"
              else
                bpkg_debug "Remove '${install_bindir}/${scriptname}'"
                rm -rfv "${install_bindir}/${scriptname}"
              fi
            else
              bpkg_debug "'${install_bindir}/${scriptname}' will be removed"
            fi
          fi
        )
      done
    else
      bpkg_warn "uninstal_scripts" "No scripts to be uninstalled"
    fi

    ## remove share content
    if [[ "${#files[@]}" -gt '0' ]]; then
      bpkg_debug "uninstall_files" "Uninstall files '${files[*]}'"
      if (( 0 == dry_run )); then
        if (( 0 == needs_quiet )); then
          bpkg_debug "Remove '${install_bindir}' quietly"
          rm -rf "${install_sharedir}"
        else
          bpkg_debug "Remove '${install_bindir}'"
          rm -rfv "${install_sharedir}"
        fi
      else
        find "${install_sharedir}" -mindepth 1 | bpkg_esed "s|^\./|${install_sharedir}/|" | xargs -I {} bpkg_debug "'{}' will be removed"
      fi
    fi
  fi
  return 0
}

## outut usage
_usage () {
  echo 'usage: bpkg-uninstall [-h|--help]'
  echo '   or: bpkg-uninstall [-g|--global] [-b|--break-mode] [-d|--dry-run] [-q|--quiet] <package>'
  echo '   or: bpkg-uninstall [-g|--global] [-b|--break-mode] [-d|--dry-run] [-q|--quiet] <user>/<package>'
}

## check parameter consistency
_validate_parameters () {
  if [[ ${#BPKG_GIT_REMOTES[@]} -ne ${#BPKG_REMOTES[@]} ]]; then
    mesg='BPKG_GIT_REMOTES[%d] differs in size from BPKG_REMOTES[%d] array'
    fmesg=$(printf "$mesg" "${#BPKG_GIT_REMOTES[@]}" "${#BPKG_REMOTES[@]}")
    bpkg_error "$fmesg"
    return 1
  fi
  return 0
}

## Uninstall a bash package
bpkg_uninstall () {
  local pkg=''
  local needs_global=0
  local break_mode=0
  local dry_run=0
  local needs_quiet=1
  local auth_info=''

  for opt in "${@}"; do
    if [[ '-' = "${opt:0:1}" ]]; then
      continue
    fi
    pkg="${opt}"
    break
  done

  for opt in "${@}"; do
    case "${opt}" in
      -h|--help)
        _usage
        return 0
        ;;

      -g|--global)
        shift
        needs_global=1
        ;;

      -b|--break-mode)
        shift
        break_mode=1
        ;;

      -d|--dry-run)
        shift
        dry_run=1
        ;;

      -q|--quiet)
        shift
        needs_quiet=0
        ;;

      *)
        if [[ '-' = "${opt:0:1}" ]]; then
          echo 2>&1 "error: Unknown argument \`${1}'"
          _usage
          return 1
        fi
        ;;
    esac
  done

  ## ensure there is a package to uninstall
  if [[ -z "${pkg}" ]]; then
    _usage
    return 1
  fi

  echo

  if bpkg_is_local_path "${pkg}"; then
    pkg="file://$(cd ${pkg}; pwd)"
  fi

  if bpkg_has_auth_info "${pkg}"; then
    auth_info="$(bpkg_parse_auth_info "${pkg}")"
    bpkg_debug "auth_info" "${auth_info}"

    pkg="$(bpkg_remove_auth_info "${pkg}")"
    bpkg_debug "pkg" "${pkg}"
  fi

  if bpkg_is_full_url "${pkg}"; then
    bpkg_debug "parse" "${pkg}"

    local bpkg_remote_proto bpkg_remote_host bpkg_remote_path bpkg_remote_uri

    bpkg_remote_proto="$(bpkg_parse_proto "${pkg}")"

    if bpkg_is_local_path "${pkg}"; then
      bpkg_remote_host="/$(bpkg_parse_host "${pkg}")"
    else
      bpkg_remote_host="$(bpkg_parse_host "${pkg}")"
    fi

    bpkg_remote_path=$(bpkg_parse_path "${pkg}")
    bpkg_remote_uri="${bpkg_remote_proto}://${bpkg_remote_host}"

    bpkg_debug "proto" "${bpkg_remote_proto}"
    bpkg_debug "host" "${bpkg_remote_host}"
    bpkg_debug "path" "${bpkg_remote_path}"

    BPKG_REMOTES=("${bpkg_remote_uri}" "${BPKG_REMOTES[@]}")
    BPKG_GIT_REMOTES=("${bpkg_remote_uri}" "${BPKG_GIT_REMOTES[@]}")
    pkg="$(echo "${bpkg_remote_path}" | bpkg_esed "s|^\/(.*)|\1|")"

    if bpkg_is_coding_net "${bpkg_remote_host}"; then
      # update /u/{username}/p/{project} to {username}/{project}
      bpkg_debug "reset pkg for coding.net"
      pkg="$(echo "${pkg}" | bpkg_esed "s|\/?u\/([^\/]+)\/p\/(.+)|\1/\2|")"
    fi

    bpkg_debug "pkg" "${pkg}"
  fi

  ## Check each remote in order
  local i=0
  for remote in "${BPKG_REMOTES[@]}"; do
    local git_remote=${BPKG_GIT_REMOTES[$i]}
    _bpkg_uninstall_of_remote "$pkg" "$remote" "$git_remote" $needs_global $break_mode $dry_run $needs_quiet "$auth_info"
    if [[ "$?" == '0' ]]; then
      return 0
    elif [[ "$?" == '2' ]]; then
      bpkg_error 'fatal error occurred during uninstall'
      return 1
    fi
    i=$((i+1))
  done
  bpkg_error 'package not found on any remote'
  return 1
}

## Use as lib or perform uninstall
if [[ ${BASH_SOURCE[0]} != $0 ]]; then
  export -f bpkg_uninstall
elif _validate_parameters; then
  bpkg_uninstall "${@}"
  exit $?
else
  #param validation failed
  exit $?
fi
