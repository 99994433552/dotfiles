Describe '_preview'
  Include config/zsh/lib/preview.zsh

  It 'lists all when under the cap'
    When call _preview 3 a b
    The line 1 should eq '   a'
    The line 2 should eq '   b'
  End

  It 'truncates and reports the remainder'
    When call _preview 2 a b c d
    The line 1 should eq '   a'
    The line 2 should eq '   b'
    The line 3 should eq '   ... and 2 more'
  End
End
