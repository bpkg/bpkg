#!/bin/bash

bpkg_has_auth_info () {
  local url=$1
  if [[ "$(echo "${url}" | grep -E '[^|]+[|][^|]+[|][^/]+:\/\/\/?.*')" != "" ]]; then
    return 0
  else
    return 1
  fi
}

bpkg_parse_auth_info () {
  local url="$1"
  echo "${url}" | bpkg_esed 's|([^|]+[|][^|]+)[|][^/]+:\/\/\/?.*|\1|'
}

bpkg_remove_auth_info () {
  local url="$1"
  echo "${url}" | bpkg_esed "s|[^|]+[|][^|]+[|]([^/]+:\/\/\/?.*)|\1|"
}

bpkg_is_coding_net () {
  local remote="$1"

  if [[ "$(echo "${remote}" | grep 'coding.net')" ]]; then
    return 0
  else
    return 1
  fi
}

bpkg_is_github_raw () {
  local remote="$1"

  if [[ "$(echo "${remote}" | grep raw.githubusercontent.com)" ]]; then
    return 0
  else
    return 1
  fi
}

bpkg_is_local_path () {
  local url="$1"
  if [[ "$(echo "${url}" | grep 'file://.*')" != "" ]] || [[ -e "${url}" ]]; then
    return 0
  else
    return 1
  fi
}

bpkg_is_full_url () {
  local url=$1
  if [[ "$(echo "${url}" | grep -E '[^/]+:\/\/\/?.*')" != "" ]]; then
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
  local auth_param path url filedir

  url="${1}"
  path="${2}"
  auth_param="${3:-}"
  
  bpkg_debug "fetch" "${url}"
  bpkg_debug "write" "${path}"
  
  filedir="$(dirname "${path}")"
  if [[ ! -d "${filedir}" ]]; then
    mkdir -p "${filedir}"
  fi

  bpkg_debug "save_remote_file" "from ${url} to ${filedir}"

  curl_cmd="curl --silent -L --output '${path}' ${auth_param} '${url}'"
  bpkg_debug "url_save_remote" "$curl_cmd"
  eval $curl_cmd
}

bpkg_url_exists () {
    local auth_param exists url

    url="${1}"
    auth_param="${2:-}"
    exists=0

    bpkg_debug "check" "${url}"

    curl_cmd="curl --silent -L -w '%{http_code}'  --output '/dev/null' ${auth_param} '${url}'"
    bpkg_debug "url_exists" "curl_cmd: $curl_cmd"
    eval "status=\$($curl_cmd)"
    result=$?

    bpkg_debug "url_exists" "curl status: $result"
    # shellcheck disable=SC2154
    bpkg_debug "url_exists" "http status: $status"

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

  curl_cmd="curl --silent -L ${auth_param} '${url}'"  
  eval "$curl_cmd"
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

