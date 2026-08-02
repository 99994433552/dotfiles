Describe '_confirm'
  Include config/zsh/lib/confirm.zsh

  It 'returns success on y'
    Data 'y'
    When call _confirm 'Continue?'
    The status should be success
    The output should include 'Continue?'
  End

  It 'returns failure on empty (default No)'
    Data ''
    When call _confirm 'Continue?'
    The status should be failure
  End

  It 'returns failure on n'
    Data 'n'
    When call _confirm 'Continue?'
    The status should be failure
  End
End
