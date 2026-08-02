Describe 'media helpers'
  Include config/zsh/lib/media-helpers.zsh

  Describe '_crop_x'
    Parameters
      left   '0'
      center '(iw-ow)/2'
      right  'iw-ow'
      25     '(iw-ow)*25/100'
    End
    It "resolves $1"
      When call _crop_x "$1"
      The output should eq "$2"
      The status should be success
    End
    It 'rejects invalid position'
      When call _crop_x sideways
      The status should be failure
    End
  End

  Describe '_sticker_bitrate'
    It 'rounds (kb*8*0.95)/duration'
      When call _sticker_bitrate 256 3
      The output should eq '649'
    End
  End

  Describe '_duration_min'
    It 'returns the smaller value'
      When call _duration_min 5 3
      The output should eq '3'
    End
    It 'returns the input when below the cap'
      When call _duration_min 1.5 3
      The output should eq '1.5'
    End
  End

  Describe '_channel_name'
    It 'extracts the handle'
      When call _channel_name 'https://www.youtube.com/@somechannel/videos'
      The output should eq 'somechannel'
    End
  End
End
