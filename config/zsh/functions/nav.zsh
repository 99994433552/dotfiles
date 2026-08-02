# Smart nvim launcher
unalias v 2>/dev/null || true
v() {
  if [[ $# -eq 0 ]]; then
    nvim .
  else
    nvim "$@"
  fi
}

# Open Obsidian vault in nvim
notes() {
  cd ~/Documents/obsidian/nostromo && nvim .
}

# Python virtual environment activation
pva() {
  local venv_paths=("venv" ".venv" "env" ".env")

  for venv_path in "${venv_paths[@]}"; do
    if [[ -f "${venv_path}/bin/activate" ]]; then
      source "${venv_path}/bin/activate"
      echo "✅ Activated: ${venv_path}"
      return 0
    fi
  done

  echo "🚫 No virtual environment found"
  echo "💡 Checked: ${venv_paths[*]}"
  return 1
}
