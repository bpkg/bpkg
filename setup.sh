#!/usr/bin/env bash
#
# #             #
# #mmm   mmmm   #   m   mmmm
# #" "#  #" "#  # m"   #" "#
# #   #  #   #  #"#    #   #
# ##m#"  ##m#"  #  "m  "#m"#
#        #              m  #
#        "               ""
#        bash package manager

VERSION="1.0.9"
TAG=${TAG:-$VERSION}
BRANCH=${BRANCH:-$TAG}
REMOTE=${REMOTE:-https://github.com/bpkg/bpkg.git}
TMPDIR=${TMPDIR:-/tmp}
DEST=${DEST:-$TMPDIR/bpkg-$BRANCH}

## test if command exists
ftest () {
  echo "  info: Checking for $1..."
  if ! type -f "$1" > /dev/null 2>&1; then
    return 1
  else
    return 0
  fi
}

## feature tests
features () {
  for f in "${@}"; do
    ftest "$f" || {
      echo >&2 "  error: Missing \`$f'! Make sure it exists and try again."
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
    echo "  info: Creating temporary files..."
    cd "$TMPDIR" || exit
    test -d "$DEST" && { echo "  warn: Already exists: '$DEST'"; }
    rm -rf "$DEST"

    echo "  info: Fetching 'bpkg@$BRANCH'..."
    git clone --depth=1 --branch "$BRANCH" "$REMOTE" "$DEST" > /dev/null 2>&1
    cd "$DEST" || exit

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
  if [ "$(whoami)" == "root" ]; then
    PREFIX="/usr/local"
  else
    PREFIX="$HOME/.local"
  fi
fi

# All 'bpkg' supported commands
declare -a CMDS=()
CMDS+=("env")
CMDS+=("getdeps")
CMDS+=("init")
CMDS+=("install")
CMDS+=("json")
CMDS+=("list")
CMDS+=("package")
CMDS+=("run")
CMDS+=("show")
CMDS+=("source")
CMDS+=("suggest")
CMDS+=("term")
CMDS+=("update")
CMDS+=("utils")
CMDS+=("realpath")

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

  for cmd in "${CMDS[@]}"; do
    if test -f "$BIN-$cmd"; then
      source=$(<"$BIN-$cmd")

      if [ -f "$source" ]; then
        install "$source" "$PREFIX/bin/$BIN-$cmd"
      else
        install "$BIN-$cmd" "$PREFIX/bin"
      fi
    fi

  done
  return $?
}

make_uninstall () {
  echo "  info: Uninstalling $PREFIX/bin/$BIN*"
  echo "    rm: $PREFIX/bin/$BIN'"
  rm -f "$PREFIX/bin/$BIN"
  for cmd in "${CMDS[@]}"; do
    if test -f "$PREFIX/bin/$BIN-$cmd"; then
      echo "    rm: $PREFIX/bin/$BIN-$cmd'"
      rm -f "$PREFIX/bin/$BIN-$cmd"
    fi
  done
  return $?
}

make_link () {
  make_uninstall
  echo "  info: Linking $PREFIX/bin/$BIN*"
  echo "  link: '$PWD/$BIN' -> '$PREFIX/bin/$BIN'"
  ln -s "$PWD/$BIN" "$PREFIX/bin/$BIN"
  for cmd in "${CMDS[@]}"; do
    if test -f "$PWD/$BIN-$cmd"; then
      echo "  link: '$PWD/$BIN-$cmd' -> '$PREFIX/bin/$BIN-$cmd'"
      ln -s "$PWD/$BIN-$cmd" "$PREFIX/bin/$BIN-$cmd"
    fi
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
