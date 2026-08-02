# Git commits

Format is enforced by the `commit-msg` hook (`~/.git-hooks/commit-msg`, active via
`core.hooksPath`). Write to pass it first try:

- Summary ≤72 chars, imperative, specific first word (not fix/update/change).
- Blank line, then a body explaining *why* (wrap ~72).
- No AI attribution — the hook rejects `claude|generated|assisted|copilot` and 🤖.
