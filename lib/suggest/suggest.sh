#!/usr/bin/env bash

if ! type -f bpkg-utils &>/dev/null; then
  echo "error: bpkg-utils not found, aborting"
  exit 1
else
  # shellcheck disable=SC2230
  # shellcheck source=lib/utils/utils.sh
  source "$(which bpkg-utils)"
fi

## output usage
usage () {
  echo "usage: bpkg-suggest [-h|--help] <query>"
}

count_lines () {
  local -i count=0
  while read -r line; do
    echo "$line"
    (( count++ ))
  done
  return "$count"
}

prefix_lines_with_length () {
  while read -r line; do
    echo "$(echo -n "$line" | wc -c | tr -d ' ')" "$line"
  done
  return $?
}

sort_lines () {
  prefix_lines_with_length | sort -n | awk '{ $1=""; print $0 }'
  return $?
}

suggest () {
  local count=0
  local query="$1"

  case "$query" in
    -h|--help)
      usage
      return 0
      ;;

    *)
      if [ "-" = "${query:0:1}" ]; then
        echo >&2 "error: Unknown argument \`$query'"
        return 1
      fi
      ;;
  esac

  find_suggestions "$@" | sort_lines | count_lines
  count=$? ## count is stored in last return value

  if (( count > 0 )); then
    if (( count == 1 )); then
      {
        echo
        bpkg_message "green" "  suggest"  "1 result found"
      } >&2
    else
      {
        echo
        bpkg_message "green" "  suggest"  "$count result(s) found"
      } >&2
    fi
  else
    {
      echo
      bpkg_message "red" "  suggest"  "Couldn't find anything to match \`$query'"
    } >&2
    return 1
  fi
  return 0
}

## main
find_suggestions () {
  local paths seen find_supports_maxdepth
  declare -a paths=()
  declare -a seen=()
  local query="$1"

  case "$query" in
    -h|--help)
      usage
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
      # echo find "$path" -name "$query*" -prune -print -maxdepth 1 >&2
      find "$path" -name "$query*" -prune -print -maxdepth 1 2>/dev/null
    else
      echo >&2 " warn: Using 'find' command with '-maxdepth' option. Results may appear slowly"
      find "$path" -name "$query*" -prune -print -maxdepth 1 2>/dev/null
    fi
  done

  return $?
}

## export or run
if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  export -f suggest
else
  suggest "$@"
fi
