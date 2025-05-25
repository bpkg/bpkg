# shellcheck disable=SC2317,SC2148

Describe 'url.sh'
  Include lib/utils/url.sh

  Describe 'internal resolution'
    It 'solves Gitlab'
      When call bpkg_resolve_uri 'https://gitlab.com' bb cc dd
      The output should equal 'bb/cc/-/raw/dd'
    End
    
    It 'solves Github'
      When call bpkg_resolve_uri 'https://github.com' bb cc dd
      The output should equal 'bb/cc/dd'
    End

    It 'solves everything else'
      When call bpkg_resolve_uri 'https://my-git-domain.pe' bb cc dd
      The output should equal 'bb/cc/dd'
    End 
  End

  Describe 'user defined resolution'

    bpkg_resolve_uri_pathspec() {
      echo "$4/$3/my-branch/$2"
      return 0
    }

    It 'solves other services'
      When call bpkg_resolve_uri 'https://any-url' bb cc dd
      The output should equal 'dd/cc/my-branch/bb'
    End


    bpkg_resolve_uri_pathspec() {
      return 1
    }

    It 'other services does not resolve use default resolution'
      When call bpkg_resolve_uri 'https://github.com' bb cc dd
      The output should equal 'bb/cc/dd'
    End 
  End
End
