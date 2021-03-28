# shellcheck shell=sh

Describe "JSON.sh"
  Include ./JSON.sh

  ptest() {
    tokenize | parse >/dev/null
  }

  Describe "parse tests"
    Parameters
      '"oooo"  '
      '[true, 1, [0, {}]]  '
      '{"true": 1}'
    End
    Data "$1" # NOTE: Treat a string as stdin data

    It "parses JSON ($1)"
      When call ptest
      The status should be success
    End
  End

  It "should be able to parse package.json"
    Data < ./package.json
    When call ptest
    The status should be success
  End
End
