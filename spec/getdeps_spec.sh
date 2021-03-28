Describe "getdeps.sh"
  Include ./lib/getdeps/getdeps.sh

  Describe "getdeps--help"
    It "should show expected output when called"
      # and "should return OK when called"

      result() {
        %text # NOTE: It does not screw up indentation.
        #|Installs dependencies for a package.
        #|usage: bpkg-getdeps [-h|--help]
        #|   or: bpkg-getdeps
      }

      When call bpkg_getdeps --help
      The output should eq "$(result)"
      The status should be success # It can be omitted.
    End
  End

  Describe "getdeps"
    It "should complain when called without package.json being present"
      setup() { cd /tmp; }
      BeforeCall setup

      When call bpkg_getdeps
      The status should be failure
      The output should include 'error: Unable to find `package.json'
      # NOTE: Bug, it should be output to stderr
    End

    It "should complain when called without package.json being present"
      # and "should not exit with error status when called without bpkg-json being present"

      BeforeCall "LANG=C" # NOTE: Error messages are locale dependent

      When call bpkg_getdeps
      The error should include 'bpkg-json: command not found'
      The status should be success # NOTE: It should be the error, IMO
    End

    It "should call bpkg-install when called with bpkg-json present"
      # and "should return OK when called"

      bpkg-json() { echo '["dependencies","mock-dependency"'; }
      bpkg() { echo "$@"; }

      When call bpkg_getdeps
      The output should eq 'install mock-dependency'
    End

    It "should call bpkg-install for each dependency when called for multiple dependencies"

      bpkg-json() {
        %text
        #|["dependencies","mock-dependency"
        #|["dependencies","mock-dependency-1"
        #|["dependencies","mock-dependency-2"
        #|["dependencies","mock-dependency-3"
      }

      bpkg() { %puts "$@ "; }
      # NOTE: Using `%puts` instead of `echo -n`. Because, it is not portable.
      # In /bin/sh (modified bash) on macOS, `echo -n` will be output "-n".
      # This is important when complying with the POSIX shell.

      When call bpkg_getdeps
      The output should eq 'install mock-dependency install mock-dependency-1 install mock-dependency-2 install mock-dependency-3 '
    End
  End
End
