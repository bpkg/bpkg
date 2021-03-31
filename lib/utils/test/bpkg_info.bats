#!/usr/bin/env bats

load "${PROJECT_ROOT}/test/test_setup.bash"

# Load file under test
load "$(dirname "${BATS_TEST_DIRNAME}")/utils.sh"

@test "bpkg_info should call bpkg_message for a cyan info when called" {
    # arrange
    bpkg_message() { echo -n "$@" >&9; }

    # act
    bpkg_info

    # assert
    assert_equal "$(getMockContent)" 'cyan info'
}

@test "bpkg_info should pass the parameter on to  bpkg_message when called with one parameter" {
    # arrange
    bpkg_message() { echo -n "$@" >&9; }

    # act
    bpkg_info 'foo bar baz'

    # assert
    assert_equal "$(getMockContent)" 'cyan info foo bar baz'
}

@test "bpkg_info should pass its parameters on to bpkg_message when called with multiple parameters" {
    # arrange
    bpkg_message() { echo -n "$@" >&9; }

    # act
    bpkg_info 'foo' 'bar' 'baz'

    # assert
    assert_equal "$(getMockContent)" 'cyan foo bar baz'
}

@test "bpkg_info should use the first parameter as title bpkg_message when called with multiple parameters" {
    # arrange
    bpkg_message() { echo -n "$@" >&9; }

    # act
    bpkg_info 'foo' 'bar' 'baz'

    # assert
    assert_equal "$(getMockContent)" 'cyan foo bar baz'
}

@test "bpkg_info should output to stdout when called" {
    # arrange
    bpkg_message() {
        echo 'foo bar baz'
    }

    # act
    bpkg_info 1>&7 2>&8

    # assert
    assert_equal "$(getStdoutContent)" 'foo bar baz'
}

@test "bpkg_info should not output to stderr when called" {
    # arrange
    bpkg_message() {
        echo 'foo bar baz'
    }

    # act
    bpkg_info 1>&7 2>&8

    # assert
    assert_equal "$(getStderrContent)" ''
}
