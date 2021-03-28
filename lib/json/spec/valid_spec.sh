# shellcheck shell=sh

Describe "JSON.sh"
  # NOTE: Generating test cases dynamically from files
  Parameters:dynamic
    for input in test/valid/*.json
    do
      %data "$input" "${input%.json}.parsed"
    done
  End
  Data < "$1" # NOTE: Treat a file as stdin data

  It "succeeds with valid JSON ($1)"
    When run script ./JSON.sh
    The status should be success
    The output should eq "$(cat "$2")"

    # A matcher for file comparison will be implemented in the future.
    # https://github.com/shellspec/shellspec/pull/138
  End
End
