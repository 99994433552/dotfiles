# Skills — maintenance & vetting

Skills live in `.claude/skills/`, symlinked whole-directory into
`~/.claude/skills/`. Single source of truth: `skills.manifest.json`.

## Commands
- `scripts/sync-skills.sh sync` — refresh vendored skills to their pinned refs;
  leaves changes unstaged for review, then `git diff` + commit.
- `scripts/sync-skills.sh --check` — report upstream refs newer than pinned.
- `scripts/sync-skills.sh bootstrap` — install declared plugins, warn on
  missing tools. Run after a fresh `git pull`.

## Bumping a vendored skill
1. `scripts/sync-skills.sh --check` to see what is stale.
2. Edit `ref` in `skills.manifest.json`.
3. `scripts/sync-skills.sh sync`.
4. **Vet the diff** (see checklist) before committing.

## Vetting checklist (run before adding or bumping any vendored skill)
- Read the full `SKILL.md` and every bundled file (`references/`, `scripts/`).
- Flag network calls, `!`-backtick shell lines, and any executed `scripts/`.
- Check `allowed-tools` — it pre-approves tools; pair with deny rules if broad.
- Prefer pure-Markdown skills. Pin to a tag or commit SHA, never a branch.
- Source only from trusted authors or the official/screened marketplaces.

`disableSkillShellExecution` is intentionally OFF; the control is disciplined
vetting plus ref pinning.
