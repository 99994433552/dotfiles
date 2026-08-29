#!/usr/bin/env zsh
# ============================================================================
# ZSH Configuration
# ============================================================================

# ============================================================================
# Environment Variables
# ============================================================================

export DOTFILES_DIR="${HOME}/.dotfiles"

# Ensure Screenshots directory exists and set as default location
if [[ ! -d ~/Downloads/Screenshots ]]; then
  mkdir -p ~/Downloads/Screenshots
  defaults write com.apple.screencapture location ~/Downloads/Screenshots
fi
export FUNCTIONS_CORE_TOOLS_TELEMETRY_OPTOUT=1
export PATH="/Applications/Docker.app/Contents/Resources/bin:$HOME/.local/bin:$HOME/.opencode/bin:$PATH"
export EDITOR=nvim
export MANPAGER="sh -c 'sed -u -e \"s/\\x1B\[[0-9;]*m//g; s/.\\x08//g\" | bat -p -lman'"
export HOMEBREW_CASK_OPTS="--no-quarantine"

# FZF Moonfly theme
export FZF_DEFAULT_OPTS="
  --color=fg:#bdbdbd,bg:#080808,hl:#80a0ff
  --color=fg+:#eeeeee,bg+:#1c1c1c,hl+:#80a0ff
  --color=info:#de935f,prompt:#80a0ff,pointer:#ff5189
  --color=marker:#8cc85f,spinner:#80a0ff,header:#8cc85f
  --color=gutter:#080808,border:#1c1c1c"

# ============================================================================
# Initialization
# ============================================================================

# Add homebrew completions to fpath
if [[ -d /opt/homebrew/share/zsh/site-functions ]]; then
  fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
fi

# Add docker completions to fpath
fpath=($HOME/.docker/completions $fpath)

# Optimized completion initialization
autoload -Uz compinit
if [[ $(($(date +%s) - $(stat -f %m ~/.zcompdump 2>/dev/null || echo 0))) -gt 86400 ]]; then
  compinit
else
  compinit -C
fi

# Enable emacs mode
bindkey -e

# Initialize starship prompt
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi

# Initialize direnv
if command -v direnv &>/dev/null; then
  eval "$(direnv hook zsh)"
fi

# Initialize zoxide (replaces cd with smarter version)
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh --cmd cd)"
fi

# ============================================================================
# Aliases
# ============================================================================

# Navigation & Files
alias ls="eza -la --icons=auto --git"
alias l="eza -l --icons --git -a"
alias cat="bat --style=plain --paging=never"

# Editor
alias ze="nvim ~/.dotfiles/zshrc"
alias lazyvim="NVIM_APPNAME=lazyvim nvim"

# SSH with kitty terminfo (only in kitty terminal, not inside Zellij where mux sockets conflict)
if [[ -n "$KITTY_WINDOW_ID" && -z "$ZELLIJ" ]]; then
  alias ssh="kitten ssh"
fi

# Python
alias pvd="deactivate"

# Claude Code
alias claude='claude --append-system-prompt-file "$DOTFILES_DIR/.claude/system-prompts/sr-opus-5.md"'

# Media
alias scdl='yt-dlp -x --audio-format mp3 --audio-quality 0 --embed-thumbnail --add-metadata --downloader aria2c --downloader-args "aria2c:-x 16 -s 16" -o "%(playlist_index)02d - %(title)s.%(ext)s"'
alias naviclean='env $(cat ~/.dotfiles/.env | xargs) ~/.dotfiles/scripts/clean-navidrome-ratings.py --execute'

# ============================================================================
# Completions
# ============================================================================

# Custom completion for uv run command
_uv_run_mod() {
  if [[ "$words[2]" == "run" && "$words[CURRENT]" != -* ]]; then
    _arguments '*:filename:_files'
  else
    _uv "$@"
  fi
}
compdef _uv_run_mod uv

# ============================================================================
# Utility Functions
# ============================================================================

# Load modular functions and their shared helpers (lib first, then functions)
for _zf in "$DOTFILES_DIR"/config/zsh/lib/*.zsh(N) "$DOTFILES_DIR"/config/zsh/functions/*.zsh(N); do
  source "$_zf"
done
unset _zf
