#!/usr/bin/env bats

load "${PROJECT_ROOT}/test/test_setup.bash"

# Load file under test
load "$(dirname "${BATS_TEST_DIRNAME}")/utils.sh"

@test "bpkg_warn should call bpkg_message for a yellow warning when called" {
    # arrange
    bpkg_message() { echo -n "$@" >&9; }

    # act
    bpkg_warn

    # assert
    assert_equal "$(getMockContent)" 'yellow warn'
}

@test "bpkg_warn should pass the parameter on to  bpkg_message when called with one parameter" {
    # arrange
    bpkg_message() { echo -n "$@" >&9; }

    # act
    bpkg_warn 'foo bar baz'

    # assert
    assert_equal "$(getMockContent)" 'yellow warn foo bar baz'
}

@test "bpkg_warn should pass all parameters on to bpkg_message when called with multiple parameters" {
    # arrange
    bpkg_message() { echo -n "$@" >&9; }

    # act
    bpkg_warn 'foo' 'bar' 'baz'

    # assert
    assert_equal "$(getMockContent)" 'yellow warn foo bar baz'
}

@test "bpkg_warn should output to stderr when called" {
    # arrange
    bpkg_message() {
        echo 'foo bar baz'
    }

    # act
    bpkg_warn 1>&7 2>&8

    # assert
    assert_equal "$(getStderrContent)" 'foo bar baz'
}

@test "bpkg_warn should not output to stdout when called" {
    # arrange
    bpkg_message() {
        echo 'foo bar baz'
    }

    # act
    bpkg_warn 1>&7 2>&8

    # assert
    assert_equal "$(getStdoutContent)" ''
}
