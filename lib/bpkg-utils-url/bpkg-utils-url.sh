#!/bin/bash

bpkg_is_coding_net () {
  local remote="$1"

  if [[ "$(echo ${remote} | grep 'coding.net')" ]]; then
    return 0
  else
    return 1
  fi
}

bpkg_is_github_raw () {
  local remote="$1"

  if [[ "$(echo ${remote} | grep raw.githubusercontent.com)" ]]; then
    return 0
  else
    return 1
  fi
}

bpkg_is_local_path () {
  local url="$1"
  if [[ "$(echo \"${url}\" | grep 'file://.*')" != "" ]] || [[ -e "${url}" ]]; then
    return 0
  else
    return 1
  fi
}

bpkg_is_full_url () {
  local url=$1
  if [[ "$(echo \"${url}\" | egrep '[^/]+:\/\/\/?.*')" != "" ]]; then
    return 0
  else
    return 1
  fi
}

bpkg_parse_proto () {
  local url="$1"
  echo "${url}" | bpkg_esed "s|([^\/""]+):\/\/\/?([^\/]+)(\/.*)|\1|"
}

bpkg_parse_host () {
  local url="$1"
  echo "${url}" | bpkg_esed "s|([^\/]+):\/\/\/?([^\/]+)(\/.*)|\2|"
}

bpkg_parse_path () {
  local url="$1"
  echo "${url}" | bpkg_esed "s|([^\/]+):\/\/\/?([^\/]+)(\/.*)|\3|"
}

bpkg_save_remote_file () {
  local auth_param path url

  url="${1}"
  path="${2}"
  auth_param="${3:-}"
  
  bpkg_debug "fetch" "${url}"
  bpkg_debug "write" "${path}"
  
  local filedir="$(dirname ${path})"
  if [[ ! -d "${filedir}" ]]; then
    mkdir -p "${filedir}"
  fi

  if [[ "${auth_param}" ]];then
    curl --silent -L -o "${path}" -u "${auth_param}" "${url}"
  else
    curl --silent -L -o "${path}" "${url}"
  fi
}

bpkg_url_exists () {
    local auth_param exists url

    url="${1}"
    auth_param="${2:-}"
    exists=0

    bpkg_debug "check" "${url}"

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

bpkg_read_package_json () {
  local auth_param url

  url="${1}"
  auth_param="${2:-}"
  
  if [[ "${auth_param}" ]];then
    curl --silent -L -u "${auth_param}" "${url}"
  else
    curl --silent -L "${url}"
  fi
}

export -f bpkg_is_coding_net
export -f bpkg_is_github_raw
export -f bpkg_is_local_path
export -f bpkg_is_full_url
export -f bpkg_parse_proto
export -f bpkg_parse_host
export -f bpkg_parse_path

export -f bpkg_save_remote_file
export -f bpkg_url_exists
export -f bpkg_read_package_json

