#!/usr/bin/env bash

# Load test dependencies
load "${PROJECT_ROOT}/vendor/bats-support/load.bash"
load "${PROJECT_ROOT}/vendor/bats-assert/load.bash"

setup() {
    # File descriptor 9 is used in mock functions to store input in
    # After the file descriptor has been created, the assigned file needs to be
    # deleted so that `/dev/fd/9` can be used for reading elsewhere without the
    # need to know which file was originally used.
    local -r sFileDescriptor="$(mktemp --tmpdir="${BATS_TMPDIR}" bats-mock.XXXXXX)"
    exec 9<> "${sFileDescriptor}"
    rm "${sFileDescriptor}"

    getMockContent() {
        cat /dev/fd/9
    }

    local -r sStderrPath="$(mktemp --tmpdir="${BATS_TMPDIR}" bats-stderr.XXXXXX)"
    exec 8<> "${sStderrPath}"
    rm "${sStderrPath}"

    getStderrContent() {
        cat /dev/fd/8
    }

    local -r sStdoutPath="$(mktemp --tmpdir="${BATS_TMPDIR}" bats-stdout.XXXXXX)"
    exec 7<> "${sStdoutPath}"
    rm "${sStdoutPath}"

    getStdoutContent() {
        cat /dev/fd/7
    }

    export -f getMockContent
    export -f getStderrContent
    export -f getStdoutContent
}

teardown() {
    # close file descriptor
    exec 7>&-
    exec 8>&-
    exec 9>&-
}
