#!/usr/bin/env bash
# ============================================================================
# Agent Skills Setup
# ============================================================================
# Installs and updates agent skills via the `skills` CLI (github.com/obra/skills).
# Skills are stored in ~/.agents/skills and symlinked into each supported
# harness (e.g. Claude Code at ~/.claude/skills/<name>), so a single install
# serves every agent. Idempotent: installs missing skills, updates existing ones.

set -euo pipefail

# List of skills to manage: "<github-owner/repo> <installed-skill-name>"
SKILLS=(
    "blader/humanizer humanizer"
)

if ! command -v npx >/dev/null 2>&1; then
    echo "⚠️  npx (Node.js) not found; skipping agent skills setup"
    exit 0
fi

for entry in "${SKILLS[@]}"; do
    read -r repo name <<< "$entry"
    if [[ -d "$HOME/.agents/skills/$name" ]]; then
        echo "🔄 Updating agent skill: $name"
        npx -y skills update "$name" --global || echo "⚠️  Failed to update $name"
    else
        echo "📥 Installing agent skill: $name ($repo)"
        npx -y skills add "$repo" --global || echo "⚠️  Failed to install $name"
    fi
done

echo "✅ Agent skills setup complete"
