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

Describe 'download functions'
  Include config/zsh/lib/auth-args.zsh
  Include config/zsh/lib/media-helpers.zsh
  Include config/zsh/functions/media.zsh

  It 'dlref errors without a url'
    When call dlref
    The status should be failure
    The output should include 'Usage'
  End

  It 'ytmp3 errors without a url'
    When call ytmp3
    The status should be failure
    The output should include 'Usage'
  End
End
