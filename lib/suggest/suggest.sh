#!/bin/bash

## suggest version
VERSION="0.0.2"

## output usage
usage () {
  echo "usage: suggest [-hV] <query>"
}

## main
suggest () {
  declare -a local paths=()
  declare -a local seen=()
  declare -a local found=()
  local query="${1}"

  case "${query}" in
    -h|--help)
      usage
      return 0
      ;;

    -V|--version)
      echo "${VERSION}"
      return 0
      ;;

    *)
      if [ "-" = "${query:0:1}" ]; then
        echo >&2 "error: Unknown argument \`${query}'"
        return 1
      fi
      ;;
  esac

  ## search path
  {
    local res=""
    IFS=':' read -a paths <<< "${PATH}"
    for (( i = 0; i < ${#paths[@]}; ++i )); do
      local path="${paths[$i]}"
      local let skip=0

      ## omit non existent paths
      if ! test -d "${path}"; then
        continue
      else
        for (( n = 0; n < "${#seen[@]}"; ++n )); do
          if [ "${path}" = "${seen[$n]}" ]; then
            skip=1;
            break;
          fi
        done

        ## check if skip needed
        if [ "1" = "${skip}" ]; then
          continue
        fi
      fi

      ## mark seen
      seen+=( "${path}" )

      ## find in path
      if res=$(find "${path}" -name "${query}*" -prune -print 2>/dev/null); then
        if [ -z "${res}" ]; then
          continue
        fi
        res="$(echo ${res} | tr '\n' ' ')"
        ## add to found count
        found+=( $(echo -n "${res}") )
      fi
    done
  }

  ## get total
  count="${#found[@]}"

  if (( ${count} == 1 )); then
    echo "${found[0]}"
  elif (( ${count} > 0 )); then
    printf "suggest: found %d result(s)\n" ${count}
    echo
    for (( i = 0; i < ${count}; ++i )); do
      printf "%d %s\n" $(echo -n ${found[$i]} | wc -c | tr -d ' ') "${found[$i]}"
    done | sort -n | awk '{ print $2 }' | xargs printf '  %s\n'
  else
    echo "suggest: Couldn't anything to match \`${query}'"
    return 1
  fi
  return 0
}

## export or run
if [[ ${BASH_SOURCE[0]} != $0 ]]; then
  export -f suggest
else
  suggest "$@"
fi
