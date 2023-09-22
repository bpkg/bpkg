# shellcheck shell=sh

Describe "JSON.sh"
  # NOTE: Generating test cases dynamically from files
  Parameters:dynamic
    for input in test/invalid/*
    do
      %data "$input"
    done
  End
  Data < "$1" # NOTE: Treat a file as stdin data

  It "fails with invalid JSON ($1)"
    When run script ./JSON.sh
    The status should be failure
    The error should be present
    The output should be defined # Ignore output for some tests

    # NTOE: Currently, There is no logging feature like below other than jUnit XML.
    #   echo "#" `cat /tmp/JSON.sh_errlog`
    # It will be implemented in the future.
    # https://github.com/shellspec/shellspec/issues/184
  End
End
