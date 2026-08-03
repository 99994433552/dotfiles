#!/usr/bin/env bash
# PostToolUse: format the just-edited file. Format only — never --fix.
# Guarded and non-blocking: a missing formatter warns via stderr, exits 0.
set -uo pipefail

file=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$file" ] && [ -f "$file" ] || exit 0

case "$file" in
  *.py)  command -v ruff    >/dev/null && ruff format "$file"        >/dev/null 2>&1 ;;
  *.rs)  command -v rustfmt >/dev/null && rustfmt "$file"            >/dev/null 2>&1 ;;
esac
exit 0
