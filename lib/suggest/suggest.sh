#!/usr/bin/env bash

## suggest version
VERSION="0.1.0"

## output usage
usage () {
  echo "usage: suggest [-hV] <query>"
}

## main
suggest () {
  local found paths seen find_supports_maxdepth
  declare -a paths=()
  declare -a seen=()
  declare -a found=()
  local query="$1"

  case "$query" in
    -h|--help)
      usage
      return 0
      ;;

    -V|--version)
      echo "$VERSION"
      return 0
      ;;

    *)
      if [ "-" = "${query:0:1}" ]; then
        echo >&2 "error: Unknown argument \`$query'"
        return 1
      fi
      ;;
  esac

  if find --help 2>/dev/null | grep 'maxdepth' >/dev/null 2>&1; then
    find_supports_maxdepth=1
  else
    find_supports_maxdepth=0
  fi

  ## search path
  {
    local res=""
    IFS=':' read -r -a paths <<< "$PATH"
    for (( i = 0; i < ${#paths[@]}; ++i )); do
      local path="${paths[$i]}"
      local skip=0

      ## omit non existent paths
      if ! test -d "$path"; then
        continue
      else
        for (( n = 0; n < "${#seen[@]}"; ++n )); do
          if [ "$path" = "${seen[$n]}" ]; then
            skip=1;
            break;
          fi
        done

        ## check if skip needed
        if [ "1" = "$skip" ]; then
          continue
        fi
      fi

      ## mark seen
      seen+=("$path")

      if (( find_supports_maxdepth == 1 )); then
        res=$(find "$path" -name "$query*" -prune -print -maxdepth 1 2>/dev/null | tr '\n' ' ');
      else
        res=$(find "$path" -name "$query*" -prune -print >/dev/null | tr '\n' ' ');
      fi

      ## find in path
      if [ -z "$res" ]; then
        continue
      fi

      ## add to found count
      # shellcheck disable=SC2207
      found+=($(echo -n "$res"))
    done
  }

  ## get total
  count="${#found[@]}"

  if (( count == 1 )); then
    echo "${found[0]}"
  elif (( count > 0 )); then
    printf "suggest: found %d result(s)\n" "$count"
    echo
    for (( i = 0; i < count; ++i )); do
      printf "%d %s\n" "$(echo -n "${found[$i]}" | wc -c | tr -d ' ')" "${found[$i]}"
    done | sort -n | awk '{ print $2 }' | xargs printf '  %s\n'
  else
    echo "suggest: Couldn't anything to match \`$query'"
    return 1
  fi
  return 0
}

## export or run
if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  export -f suggest
else
  suggest "$@"
fi
