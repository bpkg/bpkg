#!/usr/local/bin/bash

# Include config rc file if found
CONFIG_FILE="$HOME/.bpkgrc"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

## set defaults
if [[ ${#BPKG_REMOTES[@]} -eq 0 ]]; then
  BPKG_REMOTES[0]=${BPKG_REMOTE-https://raw.githubusercontent.com}
  BPKG_GIT_REMOTES[0]=${BPKG_GIT_REMOTE-https://github.com}
fi
BPKG_USER="${BPKG_USER:-bpkg}"

## log levels
# 0 OFF
# 1 DEBUG
# 2 INFO 
# 3 WARN
# 4 ERROR
LOG_LEVEL="${LOG_LEVEL:-2}"

function _is_osx(){
  if [[ "$(uname -a | grep "Darwin")" != "" ]] ; then
    return 0
  else
    return 1
  fi
}

function _esed(){
  if _is_osx; then
    sed -E "$@"
  else
    sed -r "$@"
  fi
}

## check parameter consistency
validate_parameters () {
  if [[ ${#BPKG_GIT_REMOTES[@]} -ne ${#BPKG_REMOTES[@]} ]]; then
    mesg='BPKG_GIT_REMOTES[%d] differs in size from BPKG_REMOTES[%d] array'
    fmesg=$(printf "$mesg" "${#BPKG_GIT_REMOTES[@]}" "${#BPKG_REMOTES[@]}")
    error "$fmesg"
    return 1
  fi
  return 0
}

## outut usage
usage () {
  echo 'usage: bpkg-install [-h|--help]'
  echo '   or: bpkg-install [-g|--global] <package>'
  echo '   or: bpkg-install [-g|--global] <user>/<package>'
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

  printf ': '

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
  if (( LOG_LEVEL <= 4 )); then
    {
      message 'red' 'error' "${@}"
    } >&2
  fi
}

## output warning
warn () {
  if (( LOG_LEVEL <= 3 )); then
    {
      message 'yellow' 'warn' "${@}"
    } >&2
  fi
}

## output info
info () {
  local title='info'
  if (( "${#}" > 1 )); then
    title="${1}"
    shift
  fi

  if (( LOG_LEVEL <= 2 )); then
    message 'cyan' "${title}" "${@}"
  fi  
}

## output debug
debug () {
  local title='info'
  if (( "${#}" > 1 )); then
    title="${1}"
    shift
  fi

  if (( LOG_LEVEL <= 1 )); then
    message 'green' "${title}" "${@}"
  fi
}


save_remote_file () {
  local auth_param path url

  url="${1}"
  path="${2}"
  auth_param="${3:-}"
  
  debug "fetch" "${url}"
  debug "write" "${path}"
  
  local filedir="$(dirname ${path})"
  if [[ ! -d "${filedir}" ]]; then
    mkdir -p "${filedir}"
  fi

  local dirname="$(dirname "${path}")"

  # Make sure directory exists
  if [[ ! -d "${dirname}" ]];then
    mkdir -p  "${dirname}"
  fi

  if [[ "${auth_param}" ]];then
    curl --silent -L -o "${path}" -u "${auth_param}" "${url}"
  else
    curl --silent -L -o "${path}" "${url}"
  fi
}


url_exists () {
    local auth_param exists url

    url="${1}"
    auth_param="${2:-}"
    exists=0

    debug "check" "${url}"

    if [[ "${auth_param}" ]];then
      status=$(curl --silent -L -w '%{http_code}' -o '/dev/null' -u "${auth_param}" "${url}")
      result="$?"
    else
      status=$(curl --silent -L -w '%{http_code}' -o '/dev/null' "${url}")
      result="$?"
    fi

    # In some rare cases, curl will return CURLE_WRITE_ERROR (23) when writing
    # to `/dev/null`. In such a case we do not care that such an error occured.
    # We are only interested in the status, which *will* be available regardless.
    if [[ '0' != "${result}" && '23' != "${result}" ]] || (( status >= 400 )); then
      exists=1
    fi

    return "${exists}"
}

read_package_json () {
  local auth_param url

  url="${1}"
  auth_param="${2:-}"
  
  if [[ "${auth_param}" ]];then
    curl --silent -L -u "${auth_param}" "${url}"
  else
    curl --silent -L "${url}"
  fi
}

_is_coding_net () {
  local remote="$1"

  if [[ "$(echo ${remote} | grep 'coding.net')" ]]; then
    return 0
  else
    return 1
  fi
}

_is_github_raw () {
  local remote="$1"

  if [[ "$(echo ${remote} | grep raw.githubusercontent.com)" ]]; then
    return 0
  else
    return 1
  fi
}

_is_local_path () {
  local url="$1"
  if [[ "$(echo \"${url}\" | grep 'file://.*')" != "" ]] || [[ -e "${url}" ]]; then
    return 0
  else
    return 1
  fi
}

_is_full_url () {
  local url=$1
  if [[ "$(echo \"${url}\" | egrep '[^/]+:\/\/\/?.*')" != "" ]]; then
    return 0
  else
    return 1
  fi
}

_parse_proto () {
  local url="$1"
  echo "${url}" | _esed "s|([^\/""]+):\/\/\/?([^\/]+)(\/.*)|\1|"
}

_parse_host () {
  local url="$1"
  echo "${url}" | _esed "s|([^\/]+):\/\/\/?([^\/]+)(\/.*)|\2|"
}

_parse_path () {
  local url="$1"
  echo "${url}" | _esed "s|([^\/]+):\/\/\/?([^\/]+)(\/.*)|\3|"
}

_wrap_script () {
  local src dest src_content src_shabang tmp_script_file dest_name break_mode pkg_prefix
  
  src="$1"
  dest="$2"
  break_mode="$3"
  src_content=$(cat ${src})
  dest_name=$(basename ${dest})  

  if [[ "$(cat ${src} | head -n 1 | grep '#!')" ]]; then
    src_shabang=$(cat ${src} | head -n 1)
    src_content=$(cat ${src} | tail -n +2)
  else
    src_shabang="#!/usr/local/bin/bash"
  fi

  if (( 1 == break_mode )); then
    pkg_prefix="deps/share"
  else
    pkg_prefix="deps"
  fi

  readonly tmp_script_file=$(mktemp "/tmp/bpkg.wrapper.XXXXXXXXXX")
  echo "${src_shabang}" | tee -a "${tmp_script_file}" > /dev/null

  cat <<EOF | tee -a "${tmp_script_file}" > /dev/null

#########################################
# THIS SECTION !!SHOULD NOT!! BE MODIFIED BY
# DEVELOPERS AS IT PROVIDES COMMON FUNCTIONS
# FOR ALL KINDS OF SCRIPTS
#
# Maintainer: Edison Guo <hydra1983@gmail.com>
#########################################

# Load package
function __load () {
  local package_file script_file script_dir script_name
    
  script_file="\$1"
  package_file="\$2"  
  
  if [[ -L \${script_file} ]] ; then
      script_dir=\$(cd \$(dirname \$(readlink -f \${script_file})); pwd)
  else
      script_dir=\$(cd \$(dirname \${script_file}); pwd)
  fi

  script_name="\$(basename \${script_file})"

  if [[ -d "\${script_dir}/../share/\${script_name}" ]]; then
      script_dir="\$(cd "\${script_dir}/../share/\${script_name}"; pwd)"
  fi

  source "\${script_dir}/${pkg_prefix}/\${package_file}/\${package_file}"
}
#########################################
EOF

  echo "${src_content}" | tee -a "${tmp_script_file}" > /dev/null

  cp -f "${tmp_script_file}" "${dest}"
  chmod +x "${dest}"

  rm -f "${tmp_script_file}"
}

## Install a bash package
bpkg_install () {
  local pkg=''
  local needs_global=0 
  local break_mode=0

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
        usage
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

      *)
        if [[ '-' = "${opt:0:1}" ]]; then
          echo 2>&1 "error: Unknown argument \`${1}'"
          usage
          return 1
        fi
        ;;
    esac
  done

  ## ensure there is a package to install
  if [[ -z "${pkg}" ]]; then
    usage
    return 1
  fi

  echo

  if _is_local_path "${pkg}"; then
    pkg="file://$(cd ${pkg}; pwd)"
  fi

  if _is_full_url "${pkg}"; then
    debug "parse" "${pkg}"

    local bpkg_remote_proto bpkg_remote_host bpkg_remote_path bpkg_remote_uri
    
    bpkg_remote_proto="$(_parse_proto "${pkg}")"

    if _is_local_path "${pkg}"; then
      bpkg_remote_host="/$(_parse_host "${pkg}")"      
    else      
      bpkg_remote_host="$(_parse_host "${pkg}")"
    fi

    bpkg_remote_path=$(_parse_path "${pkg}") 
    bpkg_remote_uri="${bpkg_remote_proto}://${bpkg_remote_host}" 
    
    debug "proto" "${bpkg_remote_proto}"
    debug "host" "${bpkg_remote_host}"
    debug "path" "${bpkg_remote_path}"

    BPKG_REMOTES=("${bpkg_remote_uri}" "${BPKG_REMOTES[@]}")
    BPKG_GIT_REMOTES=("${bpkg_remote_uri}" "${BPKG_GIT_REMOTES[@]}")
    pkg="$(echo "${bpkg_remote_path}" | _esed "s|^\/(.*)|\1|")"

    if _is_coding_net "${bpkg_remote_host}"; then
      # update /u/{username}/p/{project} to {username}/{project}
      debug "reset pkg for coding.net"
      pkg="$(echo "${pkg}" | _esed "s|\/?u\/([^\/]+)\/p\/(.+)|\1/\2|")"      
    fi

    debug "pkg" "${pkg}"  
  fi

  ## Check each remote in order
  local i=0
  for remote in "${BPKG_REMOTES[@]}"; do
    local git_remote=${BPKG_GIT_REMOTES[$i]}
    bpkg_install_from_remote "$pkg" "$remote" "$git_remote" $needs_global $break_mode
    if [[ "$?" == '0' ]]; then
      return 0
    elif [[ "$?" == '2' ]]; then
      error 'fatal error occurred during install'
      return 1
    fi
    i=$((i+1))
  done
  error 'package not found on any remote'
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
  local needs_global=$4
  local break_mode=$5

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
  debug "pkg_parts" "${pkg_parts[@]}"

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
  pkg_parts=(${pkg//\// })
  debug "pkg_parts" "${pkg_parts[@]}"

  if [[ ${#pkg_parts[@]} -eq 0 ]]; then
    error 'Unable to determine package name'
    return 1
  elif [[ ${#pkg_parts[@]} -eq 1 ]]; then
    user="${BPKG_USER}"
    name="${pkg_parts[0]}"
  else    
    name="${pkg_parts[-1]}"
    unset pkg_parts[${#pkg_parts[@]}-1]
    pkg_parts=( "${pkg_parts[@]}" )
    user="$(IFS='/' ; echo "${pkg_parts[*]}")"
  fi

  debug "user" "${user}"
  debug "name" "${name}"

  ## clean up name of weird trailing
  ## versions and slashes
  name=${name/@*//}
  name=${name////}

  ## check to see if remote is raw with oauth (GHE)
  if [[ "${remote:0:10}" == "raw-oauth|" ]]; then
    info 'Using OAUTH basic with content requests'
    OLDIFS="${IFS}"
    IFS="'|'"
    local remote_parts=($remote)
    IFS="${OLDIFS}"
    local token=${remote_parts[1]}
    remote=${remote_parts[2]}
    auth_param="$token:x-oauth-basic"
    uri="/${user}/${name}/raw/${version}"
    ## If git remote is a URL, and doesn't contain token information, we
    ## inject it into the <user>@host field
    if [[ "$git_remote" == https://* ]] && [[ "$git_remote" != *x-oauth-basic* ]] && [[ "$git_remote" != *${token}* ]]; then
      git_remote=${git_remote/https:\/\//https:\/\/$token:x-oauth-basic@}
    fi
  elif _is_coding_net "${remote}"; then
    uri="/u/${user}/p/${name}/git/raw/${version}"
  elif _is_github_raw "${remote}"; then
    uri="/${user}/${name}/${version}"
  elif _is_local_path "${remote}"; then
    uri="/${user}/${name}"
  else 
    uri="/${user}/${name}/raw/${version}"    
  fi

  ## clean up extra slashes in uri
  uri=${uri/\/\///}
  info "Install $uri from remote $remote [$git_remote]"

  ## Ensure remote is reachable
  ## If a remote is totally down, this will be considered a fatal
  ## error since the user may have intended to install the package
  ## from the broken remote.
  {
    if ! url_exists "${remote}" "${auth_param}"; then
      error "Remote unreachable: ${remote}"
      return 2
    fi
  }

  ## build url
  url="${remote}${uri}"
  
  if _is_coding_net "${remote}"; then
    repo_url="${git_remote}/u/${user}/p/${name}/git"
  elif _is_local_path "${remote}"; then
    repo_url="${git_remote}/${user}/${name}"
  else
    repo_url="${git_remote}/${user}/${name}.git"
  fi
  
  ## determine if 'package.json' exists at url
  package_json_url="${url}/package.json?$(date +%s)"
  makefile_url="${url}/Makefile?$(date +%s)"

  if _is_local_path "${url}"; then
    package_json_url="${url}/package.json"
    makefile_url="${url}/Makefile"
  fi

  {
    if ! url_exists "${package_json_url}" "${auth_param}"; then
      warn 'package.json doesn`t exist'
      has_pkg_json=0
      # check to see if there's a Makefile. If not, this is not a valid package
      if ! url_exists "${makefile_url}" "${auth_param}"; then
        warn "Makefile not found, skipping remote: $url"
        return 1
      fi
    fi
  }

  ## read package.json
  json=$(read_package_json "${package_json_url}" "${auth_param}")

  if (( 1 == has_pkg_json )); then
    ## get package name from 'package.json'
    name="$(
      echo -n "${json}" |
      bpkg-json -b |
      grep -m 1 '"name"' |
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
      scripts=$(echo -n "${json}" | bpkg-json -b | grep '\["scripts' | awk '{ print $2 }' | tr -d '"')

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
      files=$(echo -n "${json}" | bpkg-json -b | grep '\["files' | awk '{ print $2 }' | tr -d '"')

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
    info "Install ${url} globally"
  fi

  if (( 1 == break_mode )); then
    warn "Install ${url} in break mode"
  fi

  ## build global in legacy mode if needed
  if (( 1 == needs_global )) && (( 0 == break_mode )); then
    if (( 1 == has_pkg_json )); then
      ## install bin if needed
      build="$(echo -n "${json}" | bpkg-json -b | grep '\["install"\]' | awk '{$1=""; print $0 }' | tr -d '\"')"
      build="$(echo -n "${build}" | sed -e 's/^ *//' -e 's/ *$//')"
    fi

    if [[ -z "${build}" ]]; then
      warn "Missing build script"
      warn "Trying \`make install\`..."
      build="make install"
    fi

    { (
      ## go to tmp dir
      cd "$( [[ ! -z "${TMPDIR}" ]] && echo "${TMPDIR}" || echo /tmp)" &&
      ## prune existing
      rm -rf "${name}-${version}" &&
      ## shallow clone
      info "Cloning ${repo_url} to ${name}-${version}" &&
      git clone "${repo_url}" "${name}-${version}" &&
      (
        ## move into directory
        cd "${name}-${version}" &&
        git checkout ${version} &&
        ## wrap
        for script in $scripts; do (
            local script="$(echo $script | xargs basename )"

            if [[ "${script}" ]]; then
              cp -f "$(pwd)/${script}" "$(pwd)/${script}.orig"
              _wrap_script "$(pwd)/${script}.orig" "$(pwd)/${script}" "${break_mode}"
            fi
        ) done &&
        ## build
        info "Performing install: \`${build}'" &&
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

  ## perform local install otherwise
  if (( 0 == needs_global )) || (( 1 == break_mode )); then
    ## copy package.json over    
    save_remote_file "${url}/package.json" "${install_sharedir}/package.json" "${auth_param}"

    ## make 'deps/bin' directory if possible
    mkdir -p "${install_bindir}"

    ## make 'deps/share' directory if possible
    mkdir -p "${install_sharedir}"    

    # install package dependencies
    if (( 1 == break_mode )); then
      (cd "${install_sharedir}" && bpkg getdeps -b)
    else
      (cd "${install_sharedir}" && bpkg getdeps)
    fi

    ## grab each script and place in deps directory    
    for script in $scripts; do
      (
        local script="$(echo $script | xargs basename )"

        if [[ "${script}" ]];then          
          save_remote_file "${url}/${script}" "${install_sharedir}/${script}" "${auth_param}"
          local scriptname="${script%.*}"
          debug "${scriptname} to PATH" "${install_bindir}/${scriptname}"
          cp -f "${install_sharedir}/${script}" "${install_sharedir}/${script}.orig"
          _wrap_script "${install_sharedir}/${script}.orig" "${install_sharedir}/${script}" "${break_mode}"
          ln -sf "${install_sharedir}/${script}" "${install_bindir}/${scriptname}"          
          chmod u+x "${install_bindir}/${scriptname}"
        fi
      )
    done

    if [[ "${#files[@]}" -gt '0' ]]; then
      ## grab each file and place in correct directory
      for file in "${files[@]}"; do
      (
          if [[ "${file}" ]];then
            local filedir="$(dirname "${install_sharedir}/${file}")"
            local filename="$(basename "${file}")"            
            save_remote_file "${url}/${file}" "${filedir}/${filename}" "${auth_param}"
          fi
        )
      done
    fi
  fi  
  return 0
}

## Use as lib or perform install
if [[ ${BASH_SOURCE[0]} != $0 ]]; then
  export -f bpkg_install
elif validate_parameters; then
  bpkg_install "${@}"
  exit $?
else
  #param validation failed
  exit $?
fi
