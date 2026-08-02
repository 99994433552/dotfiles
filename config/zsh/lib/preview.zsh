# _preview <max> <item>... — print up to <max> items, then a remainder line.
_preview() {
  local max="$1"; shift
  local total=$#
  local shown=$(( total < max ? total : max ))
  local i
  for (( i = 1; i <= shown; i++ )); do
    print -r -- "   ${@[i]}"
  done
  (( total > max )) && print -r -- "   ... and $(( total - max )) more"
  return 0
}
