#!/bin/bash
#
# #             #
# #mmm   mmmm   #   m   mmmm
# #" "#  #" "#  # m"   #" "#
# #   #  #   #  #"#    #   #
# ##m#"  ##m#"  #  "m  "#m"#
#        #              m  #
#        "               ""
#        bash package manager

REMOTE=${REMOTE:-https://github.com/bpkg/bpkg.git}
TMPDIR=${TMPDIR:-/tmp}
DEST=${DEST:-${TMPDIR}/bpkg-master}

## test if command exists
ftest () {
  echo "  info: Checking for ${1}..."
  if ! type -f "${1}" > /dev/null 2>&1; then
    return 1
  else
    return 0
  fi
}

## feature tests
features () {
  for f in "${@}"; do
    ftest "${f}" || {
      echo >&2 "  error: Missing \`${f}'! Make sure it exists and try again."
      return 1
    }
  done
  return 0
}

## main setup
setup () {
  echo "  info: Welcome to the 'bpkg' installer!"
  ## test for require features
  features git || return $?

  ## build
  {
    echo
    cd "${TMPDIR}"
    echo "  info: Creating temporary files..."
    test -d "${DEST}" && { echo "  warn: Already exists: '${DEST}'"; }
    rm -rf "${DEST}"
    echo "  info: Fetching latest 'bpkg'..."
    git clone --depth=1 "${REMOTE}" "${DEST}" > /dev/null 2>&1
    cd "${DEST}"
    echo "  info: Installing..."
    echo
    make install
    echo "  info: Done!"
  } >&2
  return $?
}

## go
setup
exit $?

