Describe "utils.sh"
  Include ./lib/utils/utils.sh

  Describe "bpkg_error"
    bpkg_message() { %puts "$@"; }

    It "should call bpkg_message for a red error when called"
      When call bpkg_error
      The error should eq 'red error'
    End

    It "should pass the parameter on to bpkg_message when called with one parameter"
      When call bpkg_error 'foo bar baz'
      The error should eq 'red error foo bar baz'
    End

    It "should pass all parameters on to bpkg_message when called with multiple parameters"
      When call bpkg_error 'foo' 'bar' 'baz'
      The error should eq 'red error foo bar baz'
    End

    It "should output to stderr when called"
      # and "should not output to stdout when called"
      bpkg_message() { echo 'foo bar baz'; }
      # NOTE: Function redefines are only effective within current (It) block

      When call bpkg_error
      The output should eq ''
      The error should eq 'foo bar baz'
    End
  End

  Describe "bpkg_info"
    bpkg_message() { %puts "$@"; }

    It "should call bpkg_message for a cyan info when called"
      When call bpkg_info
      The output should eq 'cyan info'
    End

    It "should pass the parameter on to  bpkg_message when called with one parameter"
      When call bpkg_info 'foo bar baz'
      The output should eq 'cyan info foo bar baz'
    End

    It "should use the first parameter as title bpkg_message when called with multiple parameters"
      When call bpkg_info 'foo' 'bar' 'baz'
      The output should eq 'cyan foo bar baz'
    End

    It "should output to stdout when called"
      # and "should not output to stdout when called"
      bpkg_message() { echo 'foo bar baz'; }
      When call bpkg_info
      The output should eq 'foo bar baz'
      The error should eq ''
    End
  End

  Describe "bpkg_warn"
    bpkg_message() { %puts "$@"; }

    It "should call bpkg_message for a yellow warning when called"
      When call bpkg_warn
      The error should eq 'yellow warn'
    End

    It "should pass the parameter on to  bpkg_message when called with one parameter"
      When call bpkg_warn 'foo bar baz'
      The error should eq 'yellow warn foo bar baz'
    End

    It "should pass all parameters on to bpkg_message when called with multiple parameters"
      When call bpkg_warn 'foo' 'bar' 'baz'
      The error should eq 'yellow warn foo bar baz'
    End

    It "should output to stderr when called"
      # and "should not output to stdout when called"
      bpkg_message() { echo 'foo bar baz'; }
      When call bpkg_warn
      The error should eq 'foo bar baz'
      The output should eq ''
    End
  End
End
