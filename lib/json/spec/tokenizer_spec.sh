# shellcheck shell=sh

Describe "JSON.sh"
  Include ./JSON.sh

  Describe "tokenize tests"
    Parameters
      '"dah"'       '"dah"'
      '""'          '""'
      '["dah"]'     '[' '"dah"' ']'
      '"   "'       '"   "'
      '" \"  "' '" \"  "'

      '["dah"]' '[' '"dah"' ']'

      '123'       '123'
      '123.142'   '123.142'
      '-123'        '-123'

      '1e23'      '1e23'
      '0.1'       '0.1'
      '-110'       '-110'
      '-110.10'    '-110.10'
      '-110e10'    '-110e10'
      'null'       'null'
      'true'       'true'
      'false'      'false'
      '[ null   ,  -110e10, "null" ]' \
      '[' 'null' ',' '-110e10' ',' '"null"' ']'
      '{"e": false}'     '{' '"e"' ':' 'false' '}'
      '{"e": "string"}'  '{' '"e"' ':' '"string"' '}'
    End
    Data "$1" # NOTE: Treat a string as stdin data

    It "tokenize JSON ($1)"
      When call tokenize
      The output should eq "$(shift; printf '%s\n' "$@")"

      # NOTE: I want named parameters. :-P
      # https://github.com/shellspec/shellspec/issues/176
    End
  End

  It "should be able to tokenize package.json"
    Data < ./package.json
    When call tokenize
    The status should be success
    The output should be present
  End
End
