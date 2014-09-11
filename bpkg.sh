#!/bin/bash

## prevent sourcing
if [[ ${BASH_SOURCE[0]} != $0 ]]; then
  echo >&2 "error: \`bpkg' cannot be sourced"
  return 1
fi

## bpkg version
VERSION="0.2.6"

## output error to stderr
error () {
  printf >&2 "error: %s\n" "${@}"
}

## output usage
usage () {
  echo ""
  echo "  usage: bpkg [-hV] <command> [args]"
  echo ""
}

## commands
commands () {
  {
    declare -a local cmds=( $(
      bpkg-suggest 'bpkg-' |
      tail -n+2            |
      xargs basename -a    |
      sort -u              |
      sed 's/bpkg-//g'     |
      tr '\n' ' '
    ) )

    echo "${cmds[@]}"
  }
}

## feature tests
features () {
  declare -a local features=(bpkg-json bpkg-suggest)
  for ((i = 0; i < ${#features[@]}; ++i)); do
    local f="${features[$i]}"
    if ! type "${f}"  > /dev/null 2>&1; then
      error "Missing "${f}" dependency"
      return 1
    fi
  done
}

bpkg () {
  local arg="$1"
  local cmd=""
  shift

  ## test for required features
  features || return $?

  case "${arg}" in

    ## flags
    -V|--version)
      echo "${VERSION}"
      return 0
      ;;

    -h|--help)
      usage
      echo
      echo "Here are some commands available in your path:"
      echo
      local cmds=($(commands))
      for cmd in ${cmds[@]}; do
        echo "    ${cmd}"
      done
      return 0
      ;;

    *)
      if [ -z "${arg}" ]; then
        usage
        return 1
      fi
      cmd="bpkg-${arg}"
      if type -f "${cmd}" > /dev/null 2>&1; then
        "${cmd}" "${@}"
        return $?
      else
        echo >&2 "error: \`${arg}' is not a bpkg command."
        {
          declare -a local res=($(commands))

          if [ ! -z "${res}" ]; then
            echo
            echo  >&2 "Did you mean one of these?"
            for r in ${res[@]}; do
              if [[ "$r" == *"${arg}"* ]]; then
                echo "     $ bpkg ${r}"
              fi
            done
            return 1
          else
            usage
            return 1
          fi
        }
      fi
      ;;

  esac
  usage
  return 1
}

bpkg "${@}"
exit $?
