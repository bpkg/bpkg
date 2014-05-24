#!/bin/bash

## version
VERSION="0.0.1"

## coords
let _x=0
let _y=0

## output error to stderr
error () {
  printf >&2 "error: %s\n" "${@}"
}

## output usage
usage () {
  echo "usage: term [-hV] <command> [args]"
}

## write code to terminal
term_write () {
  local let c="${1}"
  ## ensure
  if [ -z "${c}" ]; then
    return 1
  fi
  printf "\e[${c}"
  return 0
}

## cursor operations
term_cursor () {
  local op="$1"
  if [ -z "${op}" ]; then
    return 1
  fi
  case "${op}" in
    hide) term write "?25l" ;;
    show) term write "?25h" ;;
    *) return 1 ;;
  esac
  return 0
}

## move to (x, y)
term_move () {
  local let x="${1}"
  local let y="${2}"

  ## ensure
  if [ -z "${x}" ] || [ -z "${y}" ]; then
    return 1
  fi

  ## set state
  (( _x = ${x} ))
  (( _y = ${y} ))

  ## write
  printf "\e[%d;%d;f" ${y} ${x}
  return 0
}

term_transition () {
  local let x="${1}"
  local let y="${2}"
  if [ -z "${x}" ] || [ -z "${y}" ]; then
    return 1
  fi

  (( x = ${x} + ${_x} ))
  (( y = ${y} + ${_y} ))

  term move "${x}" "${y}"
  return 0
}

## set terminal color
term_color () {
  local color="${1}"
  local fmt="\e[3%dm"
  if [ -z "${color}" ]; then
    return 1
  fi
  case "${color}" in
    black) printf "${fmt}" "0" ;;
    red) printf "${fmt}" "1" ;;
    green) printf "${fmt}" "2" ;;
    yellow) printf "${fmt}" "3" ;;
    blue) printf "${fmt}" "4" ;;
    magenta) printf "${fmt}" "5" ;;
    cyan) printf "${fmt}" "6" ;;
    white) printf "${fmt}" "7" ;;
    gray|grey) printf "\e[90m" ;;
    *) return 1 ;;
  esac
  return 0
}

## set term background color
term_background () {
  local color="${1}"
  local fmt="\e[4%dm"
  if [ -z "${color}" ]; then
    return 1
  fi
  case "${color}" in
    black) printf "${fmt}" "0" ;;
    red) printf "${fmt}" "1" ;;
    green) printf "${fmt}" "2" ;;
    yellow) printf "${fmt}" "3" ;;
    blue) printf "${fmt}" "4" ;;
    magenta) printf "${fmt}" "5" ;;
    cyan) printf "${fmt}" "6" ;;
    white) printf "${fmt}" "7" ;;
    *) return 1 ;;
  esac
  return 0
}

## reset terminal escape sequence
term_reset () {
  term write "0m"
}

## make terminal bright
term_bright () {
  term write "1m"
}

## make terminal dim
term_dim () {
  term write "2m"
}

## make terminal underlined
term_underline () {
  term write "4m"
}

## make terminal blink
term_blink () {
  term write "5m"
}

## make terminal reverse
term_reverse () {
  term write "7m"
}

## make terminal hidden
term_hidden () {
  term write "8m"
}

## clear a terminal section by name
term_clear () {
  local section="${1}"
  local fmt="\e[%s"
  if [ -z "${section}" ]; then
    return 1
  fi
  case "${section}" in
    start) printf "${fmt}" "1K";;
    end) printf "${fmt}" "K";;
    line) printf "${fmt}" "2K";;
    screen|up) printf "${fmt}" "1J";;
    down) printf "${fmt}" "J";;
    *) return 1 ;;
  esac
  return 0
}

##
# Term functions
#
# usage: term [-hV] <command>
##

term () {
  local arg="$1"
  local cmd=""
  shift

  case "${arg}" in

    ## flags
    -V|--version)
      echo "${VERSION}"
      return 0
      ;;

    -h|--help)
      usage

      ## commands
      {
        echo
        echo "commands: "
        echo
        echo "  write <code>           Write a terminal escape code"
        echo "  cursor <op>            Perform operation to cursor"
        echo "  color <color>          Set terminal color by name (See colors)"
        echo "  background <color>     Set terminal background by name (See colors)"
        echo "  move <x> <y>           Move to (x, y)"
        echo "  transition <x> <y>     Transition to (x, y)"
        echo "  clear <section>        Clear terminal section by name (See sections)"
        echo "  reset                  Reset the terminal escape code sequence"
        echo "  bright                 Write bright escape code"
        echo "  dim                    Write dim escape code"
        echo "  underline              Write underline escape code"
        echo "  blink                  Write blink escape code"
        echo "  reverse                Write reverse escape code"
        echo "  hidden                 Write hidden escape code"
      }

      ## colors
      {
        echo
        echo "colors:"
        echo

        term color black
        echo "  black                  $ term color black"

        term color red
        echo "  red                    $ term color red"

        term color green
        echo "  green                  $ term color green"

        term color yellow
        echo "  yellow                 $ term color yellow"

        term color blue
        echo "  blue                   $ term color blue"

        term color magenta
        echo "  magenta                $ term color magenta"

        term color cyan
        echo "  cyan                   $ term color cyan"

        term color white
        echo "  white                  $ term color white"

        term color gray
        echo "  gray|grey              $ term color gray"

        term reset
      }

      ## sections
      {
        echo
        echo "sections:"
        echo
        echo "  start                  Start of line"
        echo "  end                    End of line"
        echo "  up                     Upper section"
        echo "  down                   Lower section"
        echo "  line                   Current line"
        echo "  screen                 Entire screen"
      }

      return 0
      ;;

    *)
      cmd="term_${arg}"
      if type "${cmd}" > /dev/null 2>&1; then
        "${cmd}" "${@}"
        return $?
      else
        if [ ! -z "${arg}" ]; then
          error "Unknown argument: \`${arg}'"
        fi
        usage
        return 1
      fi
      ;;
  esac
}


## detect if being sourced and
## export if so else execute
## main function with args
if [[ ${BASH_SOURCE[0]} != $0 ]]; then
  export -f term
else
  term "${@}"
fi
