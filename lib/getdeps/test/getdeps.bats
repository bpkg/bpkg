#!/usr/bin/env bats

readonly sSourceFile="${BATS_TMPDIR}/bats.$$.src"

# Load test dependencies
load "${PROJECT_ROOT}/vendor/bats-assert/load.bash"

setup() {
    # Load file under test
    load "$(dirname "${BATS_TEST_DIRNAME}")/$(basename ${BATS_TEST_FILENAME} '.bats').sh"

    # File descriptor 9 is used in mock functions to store input in
    # After the file descriptor has been created, the assigned file needs to be
    # deleted so that `/dev/fd/9` can be used for reading elsewhere without the
    # need to know which file was originally used.
    local -r sFileDescriptor="$(mktemp bats-mock.XXXXXX)"
    exec 9<> "${sFileDescriptor}"
    rm "${sFileDescriptor}"

    getMockContent() {
        cat /dev/fd/9
    }

    export -f getMockContent
}

teardown() {
    exec 9>&- # close file descriptor
}

@test "getdeps--help should return OK when called" {
    run bpkg_getdeps --help

    assert_success
}

@test "getdeps--help should show expected output when called" {
    run bpkg_getdeps --help

    assert_output <<OUTPUT
    Installs dependencies for a package.
    usage: bpkg-getdeps [-h|--help]
        or: bpkg-getdeps'
OUTPUT
}

@test "getdeps should complain when called without package.json being present" {
    cd /tmp

    run bpkg_getdeps

    assert_output --partial 'error: Unable to find `package.json'
}

@test "getdeps should complain when called without bpkg-json being present" {
    run bpkg_getdeps

    assert_output --partial  'bpkg-json: command not found'
}

@test "getdeps should not exit with error status when called without bpkg-json being present" {
    run bpkg_getdeps

    assert_success
}

@test "getdeps should return OK when called" {
    bpkg-json() { echo '["dependencies","mock-dependency"'; }

    run bpkg_getdeps

    assert_success
}


@test "getdeps should call bpkg-install when called with bpkg-json present" {

    # arrange
    bpkg-json() { echo '["dependencies","mock-dependency"'; }

    bpkg() { echo "$@" >&9; }

    # act
    run bpkg_getdeps

    # assert
    assert_equal "$(getMockContent)" 'install mock-dependency'
}

@test "getdeps should call bpkg-install for each dependency when called for multiple dependencies" {

    # arrange
    bpkg-json() { echo '\
["dependencies","mock-dependency"
["dependencies","mock-dependency-1"
["dependencies","mock-dependency-2"
["dependencies","mock-dependency-3"
'
    }

    bpkg() { echo -n "$@ " >&9; }

    # act
    run bpkg_getdeps

    # assert
    assert_equal "$(getMockContent)" 'install mock-dependency install mock-dependency-1 install mock-dependency-2 install mock-dependency-3 '
}

# echo "# : ${status}" >&3
# echo "# : ${output}" >&3
# echo -e "# : ${lines[@]}" >&3

# arrange
# act
# assert
