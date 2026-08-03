#!/usr/bin/env bash
# ============================================================================
# sync-skills.sh — manage vendored Claude Code skills + plugin/tool bootstrap
# ============================================================================
# Single source of truth: .claude/skills/skills.manifest.json
#   sync        (default) vendor each pinned skill; leaves changes UNSTAGED
#   --check     report upstream refs newer than the pinned ones; changes nothing
#   bootstrap   install declared plugins; warn on missing tools
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
SKILLS_DIR="$DOTFILES/.claude/skills"
MANIFEST="$SKILLS_DIR/skills.manifest.json"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-skills"

log()  { printf '\033[0;34m▶\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m⚠\033[0m  %s\n' "$*"; }
ok()   { printf '\033[0;32m✓\033[0m %s\n' "$*"; }

sync_one() {
  local name="$1" repo ref subdir url src
  repo=$(jq -r --arg n "$name" '.vendored[$n].repo'   "$MANIFEST")
  ref=$(jq  -r --arg n "$name" '.vendored[$n].ref'    "$MANIFEST")
  subdir=$(jq -r --arg n "$name" '.vendored[$n].subdir' "$MANIFEST")
  url="https://github.com/$repo"
  src="$CACHE/$name"

  log "Vendoring $name ($repo@$ref)"
  rm -rf "$src"
  git clone --quiet --depth 1 "$url" "$src"
  git -C "$src" fetch --quiet --depth 1 origin "$ref"
  git -C "$src" checkout --quiet FETCH_HEAD
  rm -rf "${SKILLS_DIR:?}/$name"
  mkdir -p "$SKILLS_DIR/$name"
  rsync -a --delete --exclude '.git' "$src/$subdir/" "$SKILLS_DIR/$name/"
}

cmd_sync() {
  local names; names=$(jq -r '.vendored | keys[]' "$MANIFEST")
  for name in $names; do sync_one "$name"; done
  ok "Vendored skills synced. Review and commit:"
  git -C "$DOTFILES" --no-pager diff --stat -- .claude/skills || true
}

check_one() {
  local name="$1" repo ref url head_sha latest_tag
  repo=$(jq -r --arg n "$name" '.vendored[$n].repo' "$MANIFEST")
  ref=$(jq  -r --arg n "$name" '.vendored[$n].ref'  "$MANIFEST")
  url="https://github.com/$repo"
  head_sha=$(git ls-remote "$url" HEAD | awk '{print $1}')
  latest_tag=$(git ls-remote --tags --sort=-v:refname "$url" \
                 | awk -F/ '{print $NF}' \
                 | { grep -v '\^{}' || true; } \
                 | head -1)
  if [ "$ref" = "$head_sha" ] || { [ -n "$latest_tag" ] && [ "$ref" = "$latest_tag" ]; }; then
    ok "$name up to date (pinned $ref)"
  else
    warn "$name: pinned $ref → upstream HEAD ${head_sha:0:12}${latest_tag:+, latest tag $latest_tag}"
  fi
}

cmd_check() {
  local names; names=$(jq -r '.vendored | keys[]' "$MANIFEST")
  for name in $names; do check_one "$name"; done
}

SETTINGS="$DOTFILES/.claude/settings.json"

cmd_bootstrap() {
  command -v claude >/dev/null || { warn "claude CLI missing; skipping plugin bootstrap"; return 0; }

  # Ensure the Astral marketplace is present (idempotent).
  if ! claude plugin marketplace list 2>/dev/null | grep -q 'astral-sh/claude-code-plugins'; then
    log "Adding Astral marketplace"
    claude plugin marketplace add astral-sh/claude-code-plugins || warn "could not add Astral marketplace"
  fi

  # Install any enabled-but-not-installed plugin.
  local installed; installed=$(claude plugin list 2>/dev/null || true)
  while IFS= read -r plugin; do
    [ -n "$plugin" ] || continue
    if ! grep -qF "$plugin" <<<"$installed"; then
      log "Installing plugin $plugin"
      claude plugin install "$plugin" || warn "could not install $plugin"
    fi
  done < <(jq -r '.enabledPlugins | keys[]' "$SETTINGS")

  # Warn on missing formatter/runtime tools (never fatal).
  for tool in ruff rustfmt uvx; do
    command -v "$tool" >/dev/null && ok "$tool present" || warn "$tool NOT found (needed by hooks/plugins)"
  done
}

case "${1:-sync}" in
  sync)      cmd_sync ;;
  --check)   cmd_check ;;
  bootstrap) cmd_bootstrap ;;
  *)         echo "usage: sync-skills.sh [sync|--check|bootstrap]" >&2; exit 2 ;;
esac
