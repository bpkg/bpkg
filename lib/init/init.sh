#!/usr/bin/env bash

## sets optional variable from environment
opt () { eval "if [ -z \"\$$1\" ]; then $1='$2'; fi";  }

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

  {
    trap "exit -1" SIGINT SIGTERM
    read -p "$q" -r -e value;

    value="${value//\"/\'}";
  } 2>&1
  if [ -n "$value" ]; then
    eval "$var=\"$value\""
  fi
}

prompt_if () {
  local mesg="$1"
  local func="$2"
  prompt ANSWER "$mesg [y/n]: "
  case "$ANSWER" in
    y|Y|yes|YES|Yes)
      shift
      shift
      # shellcheck disable=SC2068
      $func $@
      return 0
  esac
  return 1
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
  # shellcheck disable=SC2059
 buf+="$(printf "${fmt}" "${@}")"
}

## wraps each argument in quotes
wrap () {
  printf '"%s" ' "${@}";
  echo "";
}

intro () {
  echo
  echo "This will walk you through initializing the 'bpkg.json' file."
  echo "It will prompt you for the bare minimum that is needed and provide"
  echo "defaults."
  echo
  echo "See github.com/bpkg/bpkg for more information on defining the bpkg"
  echo "'bpkg.json' file."
  echo
  echo "You can press ^C anytime to quit this prompt. The 'bpkg.json' file"
  echo "will only be written upon completion."
  echo
}

options () {
  opt NAME "$(basename "$(pwd)")"
  opt VERSION "0.1.0"
  opt DESCRIPTION ""
  opt GLOBAL ""
  opt INSTALL "install -b ${NAME}.sh \${PREFIX:-/usr/local}/bin/${NAME}"
  opt SCRIPTS "${NAME}.sh"
}

set_global () {
  # shellcheck disable=SC2034
  GLOBAL=1
}

prompts () {
  prompt NAME "name: (${NAME}) "
  # shellcheck disable=SC2153
  prompt VERSION "version: (${VERSION}) "
  prompt DESCRIPTION "description: "
  prompt INSTALL "install: (${INSTALL})"
  prompt SCRIPTS "scripts: (${SCRIPTS}) "
  prompt USER "Github username: (${USER}) "
  prompt_if "Force global install?" set_global
}

## handle required fields
required () {
  for key in  \
    "NAME"    \
    "SCRIPTS"
  do
    eval local val="\${${key}}"
    # shellcheck disable=SC2154
    [ -z "${val}" ] && error "Missing \`
    ${key}' property"
  done
}

## convert scripts to quoted csv
csv () {
  if [ -n "${SCRIPTS}" ]; then
    RAW_SCRIPTS=${SCRIPTS}
    {
      local TMP=""
      SCRIPTS="${SCRIPTS//,/ }"
      SCRIPTS="${SCRIPTS//\"/}"
      SCRIPTS="${SCRIPTS//\'/}"
      SCRIPTS=($(wrap "${SCRIPTS}"))
      # shellcheck disable=2219
      let len=${#SCRIPTS[@]}
      for (( i = 0; i < len; i++ )); do
        word=${SCRIPTS[$i]}
        if (( i + 1 != len )); then
          TMP+="${word}, "
        else
          TMP+="${word}"
        fi
      done
      SCRIPTS=("${TMP}")
    }
  fi
}

## delimit object and key-value pairs
delimit () {
  local lowercase

  append "{"

  for key in      \
    "NAME"        \
    "VERSION"     \
    "DESCRIPTION" \
    "GLOBAL"      \
    "INSTALL"     \
    "SCRIPTS"
  do
    lowercase="$(echo ${key} | tr '[:upper:]' '[:lower:]')"

    eval local val="\${${key}}"
    if [ -n "${val}" ]; then

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
  prompt ANSWER "${buf} Does this look OK? (type 'n' to cancel) "
  if [ "n" = "${ANSWER:0:1}" ]; then
    exit 1
  fi
}

## if package file already exists, ensure user wants to clobber
clobber () {
  if test -f "${file}"; then
    prompt_if "A 'bpkg.json' already exists. Would you like to replace it?" rm -f "${file}"
  fi
}

create_shell_file () {
  if [ "${NAME}.sh" == "${RAW_SCRIPTS}" ] && [ ! -f "${NAME}.sh" ]; then
      cat << EOF > "${NAME}.sh"
#!/bin/bash

VERSION=${VERSION}

usage () {
  echo "${NAME} [-hV]"
  echo
  echo "Options:"
  echo "  -h|--help      Print this help dialogue and exit"
  echo "  -V|--version   Print the current version and exit"
}

${NAME} () {
  for opt in "\${@}"; do
    case "\${opt}" in
      -h|--help)
        usage
        return 0
        ;;
      -V|--version)
        echo "\${VERSION}"
        return 0
        ;;
    esac
  done

  ## your code here
}

if [[ \${BASH_SOURCE[0]} != "\$0" ]]; then
  export -f ${NAME}
else
  ${NAME} "\${@}"
  exit $?
fi

EOF
    chmod 755 "${NAME}.sh"
  fi
}

create_readme () {
  if [ ! -f "README.md" ]; then
    {
      echo "# $NAME"
      echo
      echo "$DESCRIPTION"
      echo
      echo "# Install"
      echo
      echo "Available as a [bpkg](http://www.bpkg.sh/)"
      echo '```sh'
      echo "bpkg install [-g] ${USER:-bpkg}/$NAME"
      echo '```'
    } > "README.md"
  fi
}

create_repo () {
  if git status &>/dev/null; then
    echo "Repo already exists"
  else
    git init
  fi
}

## main
bpkg_init () {
  local cwd

  local version="0.1.0"
  cwd="$(pwd)"
  local buf="" ## output buffer
  local file="${cwd}/bpkg.json" ## output file
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
      if [ -n "${arg}" ]; then
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

  create_shell_file
  create_readme

  # initialize a git repo if one does not exist
  if [ ! -d '.git' ]; then
    git init
  fi

  return 0
}

## export or run
if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
  export -f bpkg_init
else
  bpkg_init "${@}"
  exit $?
fi
