# _crop_x <pos> — ffmpeg crop-x expression for left/center/right/0-100.
_crop_x() {
  case "$1" in
    left)  print -r -- '0' ;;
    center) print -r -- '(iw-ow)/2' ;;
    right) print -r -- 'iw-ow' ;;
    *)
      if [[ "$1" =~ '^[0-9]+$' ]] && (( $1 >= 0 && $1 <= 100 )); then
        print -r -- "(iw-ow)*$1/100"
      else
        return 1
      fi ;;
  esac
}

# _sticker_bitrate <max_kb> <duration> — target kbit/s, rounded.
_sticker_bitrate() {
  print -r -- "$1 $2" | awk '{printf "%.0f", ($1 * 8 * 0.95) / $2}'
}

# _duration_min <a> <b> — numeric minimum.
_duration_min() {
  print -r -- "$1 $2" | awk '{print ($1 < $2) ? $1 : $2}'
}

# _channel_name <url> — extract the @handle from a YouTube URL.
_channel_name() {
  print -r -- "$1" | sed -E 's|.*/@@?([^/]+).*|\1|'
}
