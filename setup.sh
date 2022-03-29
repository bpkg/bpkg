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

VERSION=1.0.0
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
    cd "${TMPDIR}" || exit
    echo "  info: Creating temporary files..."
    test -d "${DEST}" && { echo "  warn: Already exists: '${DEST}'"; }
    rm -rf "${DEST}"
    echo "  info: Fetching latest 'bpkg'..."
    git clone --depth=1 --branch "${VERSION}" "${REMOTE}" "${DEST}" > /dev/null 2>&1
    cd "${DEST}" || exit
    echo "  info: Installing..."
    echo
    make_install
    echo "  info: Done!"
  } >&2
  return $?
}

## make targets
BIN="bpkg"
if [ -z "$PREFIX" ]; then
  if [ "$USER" == "root" ]; then
    PREFIX="/usr/local"
  else
    PREFIX="$HOME/.local"
  fi
fi

# All 'bpkg' supported commands
CMDS="json install package term suggest init utils update list show getdeps run source"

make_install () {
  local source

  ## do 'make uninstall'
  make_uninstall

  echo "  info: Installing $PREFIX/bin/$BIN..."
  install -d "$PREFIX/bin"
  source=$(<$BIN)

  if [ -f "$source" ]; then
    install "$source" "$PREFIX/bin/$BIN"
    else
      install "$BIN" "$PREFIX/bin"
  fi

  for cmd in $CMDS; do
    source=$(<"$BIN-$cmd")

    if [ -f "$source" ]; then
      install "$source" "$PREFIX/bin/$BIN-$cmd"
    else
      install "$BIN-$cmd" "$PREFIX/bin"
    fi

  done
  return $?
}

make_uninstall () {
  echo "  info: Uninstalling $PREFIX/bin/$BIN..."
  rm -f "$PREFIX/bin/$BIN"
  for cmd in $CMDS; do
    rm -f "$PREFIX/bin/$BIN-$cmd"
  done
  return $?
}

make_link () {
  make_uninstall
  echo "  info: Linking $PREFIX/bin/$BIN..."
  ln -s "$PWD/$BIN" "$PREFIX/bin/$BIN"
  for cmd in $CMDS; do
    ln -s "$PWD/$BIN-$cmd" "$PREFIX/bin"
  done
  return $?
}

make_unlink () {
  make_uninstall
}

## do setup or `make_{install|uninstall|link|unlink}` command
if [ $# -eq 0 ]; then
  setup
else
  "make_$1"
fi

exit $?
