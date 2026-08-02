Describe 'file functions'
  Include config/zsh/lib/confirm.zsh
  Include config/zsh/lib/preview.zsh
  Include config/zsh/functions/files.zsh

  It 'cleanmusic deletes nothing when the user declines'
    setup() { cd "$SHELLSPEC_TMPBASE" && mkdir -p cm && cd cm && : > junk.log; }
    BeforeCall setup
    Data 'n'
    When call cleanmusic
    The output should include 'junk.log'
    The path "$SHELLSPEC_TMPBASE/cm/junk.log" should be exist
  End
End
