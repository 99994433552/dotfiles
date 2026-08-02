Describe '_parse_auth'
  Include config/zsh/lib/auth-args.zsh

  # Wrapper prints the populated array so we can assert on it.
  build() { local -a auth_args; _parse_auth "$@"; print -r -- "${(j:|:)auth_args}"; }

  It 'builds browser auth'
    When call build browser firefox ''
    The output should eq '--cookies-from-browser|firefox'
  End

  It 'builds file auth and preserves spaced paths'
    When call build file firefox '/tmp/my cookies.txt'
    The output should eq '--cookies|/tmp/my cookies.txt'
  End

  It 'builds oauth'
    When call build oauth firefox ''
    The output should eq '--username|oauth|--password|'
  End

  It 'produces nothing for empty method'
    When call build '' firefox ''
    The output should eq ''
  End
End
