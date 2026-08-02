# _confirm <prompt> — ask a y/N question. Returns 0 only on y/Y.
_confirm() {
  local prompt="$1" response
  print -n -- "${prompt} [y/N] "
  read -r response
  [[ "$response" =~ ^[Yy]$ ]]
}
