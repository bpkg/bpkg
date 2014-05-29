#!/bin/bash

## sets optional variable from environment
opt () { eval "if [ -z "\${$1}" ]; then ${1}=${2}; fi";  }

## output usage
usage () {
  echo ""
  echo "  usage: bpkg-init [-hV]"
  echo ""
}

## prompt with question and store result in variable
prompt () {
  local var="$1"
  local q="$2"
  local value=""
  printf "%s" "${q}"

  {
    trap "exit -1" SIGINT SIGTERM
    read -r value;
    value="${value//\"/\'}";
  } > /dev/null 2>&1
  if [ ! -z "${value}" ]; then
    eval "${var}"=\"${value}\"
  fi
}

## alert user of hint
hint () {
  {
    echo
    printf "  hint: %s\n" "$@"
    echo
  } >&2
}

## output error
error () {
  {
    printf "error: %s\n" "${@}"
  } >&2
}

## append line to buffer
append () {
  appendf '%s' "${@}"
  buf+=$'\n'
}

## append formatted string to buffer
appendf () {
  local fmt="$1"
  shift
  buf+="`printf "${fmt}" "${@}"`"
}

## wraps each argument in quotes
wrap () {
  printf '"%s" ' "${@}";
  echo "";
}

intro () {
  echo
  echo "This will walk you through initialzing the bpkg \`package.json' file."
  echo "It will prompt you for the bare minimum that is needed and provide"
  echo "defaults."
  echo
  echo "See github.com/bpkg/bpkg for more information on defining the bpkg"
  echo "\`package.json' file."
  echo
  echo "You can press ^C anytime to quit this prompt. The \`package.json' file"
  echo "will only be written upon completion."
  echo
}

options () {
  opt NAME "$(basename `pwd`)"
  opt VERSION "0.0.1"
  opt DESCRIPTION ""
  opt GLOBAL ""
  opt INSTALL ""
  opt SCRIPTS "${NAME}.sh"
}

prompts () {
  prompt NAME "name: (${NAME}) "
  prompt VERSION "version: (${VERSION}) "
  prompt DESCRIPTION "description: "
  prompt GLOBAL "global: "
  prompt INSTALL "install: "
  prompt SCRIPTS "scripts: (${SCRIPTS}) "
}

## handle required fields
required () {
  for key in  \
    "NAME"    \
    "SCRIPTS"
  do
    eval local val="\${${key}}"
    [ -z "${val}" ] && error "Missing \`${key}' property"
  done
}

## convert scripts to quoted csv
csv () {
  if [ ! -z "${SCRIPTS}" ]; then
    {
      local TMP=""
      SCRIPTS="${SCRIPTS//,/ }"
      SCRIPTS="${SCRIPTS//\"/}"
      SCRIPTS="${SCRIPTS//\'/}"
      SCRIPTS=($(wrap ${SCRIPTS}))
      let len=${#SCRIPTS[@]}
      for (( i = 0; i < len; i++ )); do
        word=${SCRIPTS[$i]}
        if (( i + 1 != len )); then
          TMP+="${word}, "
        else
          TMP+="${word}"
        fi
      done
      SCRIPTS="${TMP}"
    }
  fi
}

## delimit object and key-value pairs
delimit () {
  append "{"

  for key in      \
    "NAME"        \
    "VERSION"     \
    "DESCRIPTION" \
    "GLOBAL"      \
    "INSTALL"     \
    "SCRIPTS"
  do
    local lowercase="$(echo ${key} | tr '[:upper:]' '[:lower:]')"

    eval local val="\${${key}}"
    if [ ! -z "${val}" ]; then

      ## swap leading/trailing quotes for brackets in arrays
      local before="\""
      local after="\""
      [ "$key" == "SCRIPTS" ] && before="[ " && after=" ]"

      appendf "  \"${lowercase}\": ${before}%s${after}" "${val}"
      append ","
    fi
  done

  ## remove final trailing newline and comma
  buf="${buf%?}"
  buf="${buf%?}"

  append ""
  append "}"
}

## validate completed contents with user
validate () {
  prompt ANSWER "${buf}(yes) ? "
  if [ "n" = "${ANSWER:0:1}" ]; then
    exit 1
  fi
}

## if package file already exists, ensure user wants to clobber
clobber () {
  if test -f "${file}"; then
    prompt ANSWER "A \`package.json' already exists. Would you like to replace it? (yes): "
    if [ "n" = "${ANSWER:0:1}" ]; then
      exit 1
    else
      rm -f "${file}"
    fi
  fi
}

## main
bpkg_init () {
  local version="0.0.1"
  local cwd="`pwd`"
  local buf="" ## output buffer
  local file="${cwd}/package.json" ## output file
  local arg="$1"
  shift

  case "${arg}" in

    ## flags
    -V|--version)
      echo "${version}"
      exit 0
      ;;

    -h|--help)
      usage
      exit 0
      ;;

    *)
      if [ ! -z "${arg}" ]; then
        error "Unknown option: \`${arg}'"
        usage
        exit 1
      fi
      ;;
  esac

  ## set up package file
  intro
  options
  prompts
  required
  csv
  delimit
  validate
  clobber

  ## create and write package file
  touch "${file}"
  echo "${buf}" > "${file}"
  return 0
}

## export or run
if [[ ${BASH_SOURCE[0]} != $0 ]]; then
  export -f bpkg-init
else
  bpkg_init "${@}"
  exit $?
fi

