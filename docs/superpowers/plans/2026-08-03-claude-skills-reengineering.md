# Agent-Skills Reengineering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate all Claude Code skills into a single git-tracked, vendored inventory in dotfiles, with a manifest-driven sync/check/bootstrap script, deterministic format hooks, and one new teaching skill.

**Architecture:** Skills become plain files under `~/.dotfiles/.claude/skills/`, symlinked whole-directory into `~/.claude/skills/` via dotbot. Third-party skills are vendored snapshots pinned in `skills.manifest.json`; `scripts/sync-skills.sh` refreshes them (review-before-commit), reports upstream staleness, and bootstraps plugins/tools. Marketplace plugins stay declarative in `settings.json`.

**Tech Stack:** Bash, `jq`, `rsync`, `git`, the `claude` CLI (`plugin install` / `marketplace add`), dotbot, `ruff`, `rustfmt`.

## Global Constraints

- **Harness:** Claude Code only. No multi-harness mirroring.
- **Commit messages:** the `commit-msg` hook rejects the words `claude`, `generated`, `assisted`, `copilot`, `gpt`, `openai`, and 🤖 (filename `CLAUDE.md` is allowed). Summary ≤72 chars, imperative, first word not `fix`/`update`/`change`. Every commit message in this plan already complies — keep it that way.
- **Pinned refs:** `humanizer` → `blader/humanizer` tag `v2.9.1`; `rust-skills` → `leonardomso/rust-skills` commit `fd2a861ab0406a4ac536a55274d14ea6fd1ca9c9`.
- **Plugins:** `skill-creator@claude-plugins-official` (already in the official marketplace); `astral@astral-sh` (marketplace `astral-sh/claude-code-plugins`, requires `uvx`).
- **Hook policy:** format only (`ruff format`, `rustfmt`). No `ruff check --fix` in the hook. Every formatter guarded by `command -v`; hook always exits 0.
- **`disableSkillShellExecution`:** stays OFF (global disable would cripple legitimate skills).
- **Do not touch** `~/.dotfiles/CLAUDE.md` or `.claude/rules/` — they already match best practice.

## File Structure

- `.claude/skills/.gitignore` — ignore skill-creator eval/cache artifacts.
- `.claude/skills/skills.manifest.json` — vendored sources + pinned refs + owned list.
- `.claude/skills/humanizer/` — vendored (blader/humanizer).
- `.claude/skills/rust-skills/` — vendored (leonardomso/rust-skills).
- `.claude/skills/humanizer-ua/` — absorbed own skill (source of truth).
- `.claude/skills/rust-explain-errors/SKILL.md` — new own skill.
- `.claude/hooks/format-dispatch.sh` — PostToolUse formatter dispatcher.
- `.claude/SKILLS.md` — vetting checklist + maintenance notes.
- `scripts/sync-skills.sh` — sync / --check / bootstrap (replaces `setup-agent-skills.sh`).
- `install.conf.yaml` — add skills + hooks symlinks.
- `settings.json` — add hooks block + two enabledPlugins.
- `scripts/update-all.sh` — repoint `update_agent_skills` to the new script.

Note: the manifest and `.gitignore` live *inside* `.claude/skills/` so they travel with the whole-directory symlink. `skills.manifest.json` is not a skill dir, so it is inert to Claude Code.

---

### Task 1: Scaffold skills directory, manifest, and .gitignore

**Files:**
- Create: `.claude/skills/.gitignore`
- Create: `.claude/skills/skills.manifest.json`

**Interfaces:**
- Produces: `skills.manifest.json` schema consumed by every `sync-skills.sh` subcommand — top-level keys `vendored` (object of `{repo, ref, subdir}`) and `owned` (array of skill-dir names).

- [ ] **Step 1: Create the .gitignore**

Create `.claude/skills/.gitignore`:
```gitignore
# skill-creator eval/benchmark artifacts
evals/
benchmark.json
# transient caches
*.cache
__pycache__/
.DS_Store
```

- [ ] **Step 2: Create the manifest with pinned refs**

Create `.claude/skills/skills.manifest.json`:
```json
{
  "vendored": {
    "humanizer": {
      "repo": "blader/humanizer",
      "ref": "v2.9.1",
      "subdir": "."
    },
    "rust-skills": {
      "repo": "leonardomso/rust-skills",
      "ref": "fd2a861ab0406a4ac536a55274d14ea6fd1ca9c9",
      "subdir": "."
    }
  },
  "owned": ["humanizer-ua", "rust-explain-errors"]
}
```

- [ ] **Step 3: Validate the manifest is well-formed JSON**

Run: `jq empty .claude/skills/skills.manifest.json && echo OK`
Expected: prints `OK`, exit 0.

- [ ] **Step 4: Verify the schema shape**

Run: `jq -r '.vendored | keys[]' .claude/skills/skills.manifest.json`
Expected: two lines — `humanizer` and `rust-skills`.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/.gitignore .claude/skills/skills.manifest.json
git commit -m "Introduce vendored skills manifest and ignore rules"
```

---

### Task 2: `sync-skills.sh` — the `sync` subcommand (vendoring)

**Files:**
- Create: `scripts/sync-skills.sh`

**Interfaces:**
- Consumes: `.claude/skills/skills.manifest.json` (Task 1).
- Produces: executable `scripts/sync-skills.sh` with a `sync` command (default) that populates `.claude/skills/<name>/` for each `vendored` entry. Later tasks add `--check` and `bootstrap` to the same file.

- [ ] **Step 1: Write the script skeleton and `sync` command**

Create `scripts/sync-skills.sh`:
```bash
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

case "${1:-sync}" in
  sync) cmd_sync ;;
  *)    echo "usage: sync-skills.sh [sync|--check|bootstrap]" >&2; exit 2 ;;
esac
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/sync-skills.sh`

- [ ] **Step 3: Run sync and verify vendored files appear**

Run: `DOTFILES="$HOME/.dotfiles" scripts/sync-skills.sh sync`
Then: `test -f .claude/skills/humanizer/SKILL.md && test -f .claude/skills/rust-skills/SKILL.md && echo OK`
Expected: sync logs both skills, then prints `OK`. (rust-skills' entry file may differ; if `SKILL.md` is absent, run `ls .claude/skills/rust-skills/` and confirm the skill's real entrypoint is present — adjust the assertion to that filename.)

- [ ] **Step 4: Verify rerun is a clean no-op (idempotent)**

Run: `scripts/sync-skills.sh sync && git status --short .claude/skills/humanizer | head`
Expected: no differences on the second run beyond what the first produced (same content).

- [ ] **Step 5: Commit**

```bash
git add scripts/sync-skills.sh .claude/skills/humanizer .claude/skills/rust-skills
git commit -m "Vendor humanizer and rust-skills via sync-skills manifest"
```

---

### Task 3: `sync-skills.sh` — the `--check` subcommand (staleness guard)

**Files:**
- Modify: `scripts/sync-skills.sh`

**Interfaces:**
- Consumes: manifest `vendored[*].ref` and `repo`.
- Produces: `--check` prints, per vendored skill, whether the upstream default-branch HEAD (and newest tag, if any) differs from the pinned ref. Applies nothing.

- [ ] **Step 1: Add the check function**

In `scripts/sync-skills.sh`, add above the `case`:
```bash
check_one() {
  local name="$1" repo ref url head_sha latest_tag
  repo=$(jq -r --arg n "$name" '.vendored[$n].repo' "$MANIFEST")
  ref=$(jq  -r --arg n "$name" '.vendored[$n].ref'  "$MANIFEST")
  url="https://github.com/$repo"
  head_sha=$(git ls-remote "$url" HEAD | awk '{print $1}')
  latest_tag=$(git ls-remote --tags --sort=-v:refname "$url" \
                 | awk -F/ '{print $NF}' | grep -v '\^{}' | head -1)
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
```

- [ ] **Step 2: Wire it into the case statement**

Change the `case` block to:
```bash
case "${1:-sync}" in
  sync)    cmd_sync ;;
  --check) cmd_check ;;
  *)       echo "usage: sync-skills.sh [sync|--check|bootstrap]" >&2; exit 2 ;;
esac
```

- [ ] **Step 3: Verify --check reports the current pins as up to date**

Run: `scripts/sync-skills.sh --check`
Expected: `humanizer up to date (pinned v2.9.1)` and a line for `rust-skills` (pinned to its HEAD SHA → up to date).

- [ ] **Step 4: Verify --check flags a deliberately stale pin**

Run: `jq '.vendored.humanizer.ref="v2.2.0"' .claude/skills/skills.manifest.json > /tmp/m.json && cp /tmp/m.json .claude/skills/skills.manifest.json && scripts/sync-skills.sh --check`
Expected: a `⚠ humanizer: pinned v2.2.0 → …` line.
Then restore: `jq '.vendored.humanizer.ref="v2.9.1"' .claude/skills/skills.manifest.json > /tmp/m.json && cp /tmp/m.json .claude/skills/skills.manifest.json`

- [ ] **Step 5: Commit**

```bash
git add scripts/sync-skills.sh
git commit -m "Add --check staleness reporting to sync-skills"
```

---

### Task 4: `sync-skills.sh` — the `bootstrap` subcommand (plugins + tools)

**Files:**
- Modify: `scripts/sync-skills.sh`

**Interfaces:**
- Consumes: `settings.json → enabledPlugins`; presence of `ruff`, `rustfmt`, `uvx`, `claude`.
- Produces: `bootstrap` adds the Astral marketplace if absent, installs any enabled-but-not-installed plugin, and warns about missing tools. Idempotent.

- [ ] **Step 1: Add the bootstrap function**

In `scripts/sync-skills.sh`, add above the `case`:
```bash
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
```

- [ ] **Step 2: Wire it into the case statement**

Update the `case`:
```bash
case "${1:-sync}" in
  sync)      cmd_sync ;;
  --check)   cmd_check ;;
  bootstrap) cmd_bootstrap ;;
  *)         echo "usage: sync-skills.sh [sync|--check|bootstrap]" >&2; exit 2 ;;
esac
```

- [ ] **Step 3: Dry-verify bootstrap parses settings without crashing**

Run: `scripts/sync-skills.sh bootstrap`
Expected: prints marketplace/plugin/tool lines; exits 0 even if some tools are missing (warnings, not errors). (Plugins for `enabledPlugins` are added in Task 9; before then only the existing plugins are listed — that is fine.)

- [ ] **Step 4: Commit**

```bash
git add scripts/sync-skills.sh
git commit -m "Add bootstrap for plugins and tool checks to sync-skills"
```

---

### Task 5: Absorb `humanizer-ua` into dotfiles

**Files:**
- Create: `.claude/skills/humanizer-ua/SKILL.md`, `.claude/skills/humanizer-ua/README.md`, `.claude/skills/humanizer-ua/LICENSE`

**Interfaces:**
- Consumes: current files at `~/.config/humanizer-ua/` (LICENSE, README.md, SKILL.md).
- Produces: `.claude/skills/humanizer-ua/` as the new source of truth (an `owned` entry, untouched by `sync`).

- [ ] **Step 1: Copy the real files (excluding git metadata)**

Run:
```bash
mkdir -p .claude/skills/humanizer-ua
rsync -a --exclude '.git' ~/.config/humanizer-ua/ .claude/skills/humanizer-ua/
```

- [ ] **Step 2: Verify the skill entrypoint and its frontmatter survived**

Run: `head -5 .claude/skills/humanizer-ua/SKILL.md`
Expected: YAML frontmatter with `name: humanizer-ua` and the `version` line.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/humanizer-ua
git commit -m "Absorb humanizer-ua skill into dotfiles as source of truth"
```

---

### Task 6: Author the `rust-explain-errors` skill

**Files:**
- Create: `.claude/skills/rust-explain-errors/SKILL.md`

**Interfaces:**
- Produces: an `owned`, path-scoped skill (`paths: ["**/*.rs"]`) that teaches, rather than silently patching, Rust borrow/lifetime/trait errors.

- [ ] **Step 1: Write the skill**

Create `.claude/skills/rust-explain-errors/SKILL.md`:
```markdown
---
name: rust-explain-errors
description: >
  Use when Rust code fails to compile with borrow-checker, lifetime, move, or
  trait errors — E0382, E0499, E0502, E0505, E0507, E0515, E0597, E0308, E0277.
  Make sure to use this skill whenever the user hits a rustc error and is
  learning Rust: decode the error and teach the underlying rule, do not just
  patch the code.
paths:
  - "**/*.rs"
---

# Rust: Explain Errors, Then Fix

When rustc reports an error, do NOT jump straight to a patch. Work in this order:

1. **Name the rule.** State which ownership/borrowing/lifetime rule the error
   enforces (e.g. E0382 = use-after-move: a value moved out cannot be used
   again; E0499 = no two `&mut` to the same value at once; E0597 = a borrow
   outlives the data it points to).
2. **Locate the exact cause** in the user's code — which binding moved, which
   borrow is still live, which lifetime is too short. Quote the spans rustc
   points at.
3. **Explain the fix options and their trade-offs**, cheapest first: reborrow,
   clone, restructure scope, `Rc`/`RefCell`, change the signature's lifetimes.
   Say why one fits here and what each costs.
4. **Apply the chosen fix** and show the diff.
5. **One-line takeaway** the user can carry to the next occurrence.

Keep it tight — a short paragraph per step, not an essay. The goal is that the
user learns the rule, not just that the code compiles.
```

- [ ] **Step 2: Verify frontmatter parses (name + paths present)**

Run: `head -12 .claude/skills/rust-explain-errors/SKILL.md`
Expected: shows `name: rust-explain-errors` and a `paths:` block scoping to `**/*.rs`.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/rust-explain-errors
git commit -m "Author rust-explain-errors teaching skill for Rust learners"
```

---

### Task 7: Format-dispatch hook + settings hooks block

**Files:**
- Create: `.claude/hooks/format-dispatch.sh`
- Modify: `.claude/settings.json`

**Interfaces:**
- Consumes: PostToolUse hook stdin JSON with `.tool_input.file_path`.
- Produces: a hook that runs `ruff format` on `*.py` and `rustfmt` on `*.rs`, guarded and non-blocking.

- [ ] **Step 1: Write the hook**

Create `.claude/hooks/format-dispatch.sh`:
```bash
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
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x .claude/hooks/format-dispatch.sh`

- [ ] **Step 3: Add the hooks block to settings.json**

In `.claude/settings.json`, add this top-level key (a sibling of `permissions`):
```json
"hooks": {
  "PostToolUse": [
    {
      "matcher": "Edit|Write|MultiEdit",
      "hooks": [
        { "type": "command", "command": "~/.claude/hooks/format-dispatch.sh" }
      ]
    }
  ]
}
```
Then validate: `jq empty .claude/settings.json && echo OK` → prints `OK`.

- [ ] **Step 4: Test the hook dispatches on a Python file**

Run:
```bash
printf 'x=1\n' > /tmp/hooktest.py
echo '{"tool_input":{"file_path":"/tmp/hooktest.py"}}' | .claude/hooks/format-dispatch.sh
cat /tmp/hooktest.py
```
Expected: exit 0; if `ruff` is installed the file is reformatted to `x = 1`; if not, the file is unchanged and still no error.

- [ ] **Step 5: Test the hook is a safe no-op on unknown input**

Run: `echo '{}' | .claude/hooks/format-dispatch.sh; echo "exit=$?"`
Expected: `exit=0`.

- [ ] **Step 6: Commit**

```bash
git add .claude/hooks/format-dispatch.sh .claude/settings.json
git commit -m "Add format-dispatch PostToolUse hook for py and rs"
```

---

### Task 8: Install plugins and enable them in settings

**Files:**
- Modify: `.claude/settings.json`

**Interfaces:**
- Consumes: `sync-skills.sh bootstrap` (Task 4).
- Produces: `skill-creator@claude-plugins-official` and `astral@astral-sh` installed and enabled.

- [ ] **Step 1: Add both plugins to enabledPlugins**

In `.claude/settings.json`, extend `enabledPlugins` with:
```json
"skill-creator@claude-plugins-official": true,
"astral@astral-sh": true
```
Validate: `jq -r '.enabledPlugins | keys[]' .claude/settings.json` lists both new keys.

- [ ] **Step 2: Run bootstrap to add the marketplace and install**

Run: `scripts/sync-skills.sh bootstrap`
Expected: adds `astral-sh/claude-code-plugins` marketplace (if absent) and installs both plugins; `uvx present` (or a warning to install it).

- [ ] **Step 3: Verify both plugins are installed**

Run: `claude plugin list | grep -E 'skill-creator|astral'`
Expected: both appear.

- [ ] **Step 4: Commit**

```bash
git add .claude/settings.json
git commit -m "Enable skill-creator and Astral plugins"
```

---

### Task 9: Cut over the symlink and retire old skill locations

**Files:**
- Modify: `install.conf.yaml`
- Delete (filesystem, not git): `~/.agents/skills/article-from-notes`, `~/.agents/skills/research-review`, the old `~/.claude/skills` real dir, `~/.config/humanizer-ua`

**Interfaces:**
- Consumes: everything built in Tasks 1–8 (the dotfiles copy is complete before cutover).
- Produces: `~/.claude/skills` and `~/.claude/hooks` resolving into dotfiles.

- [ ] **Step 1: Add the dotbot links**

In `install.conf.yaml`, under the first `- link:` block (near `~/.claude/rules`), add:
```yaml
    ~/.claude/skills:
      path: .claude/skills
      force: true
    ~/.claude/hooks: .claude/hooks
```
(`force: true` on skills because a real directory currently occupies that path.)

- [ ] **Step 2: Delete the two dropped skills and the standalone humanizer-ua repo**

Run:
```bash
rm -rf ~/.agents/skills/article-from-notes ~/.agents/skills/research-review
rm -rf ~/.config/humanizer-ua
```

- [ ] **Step 3: Run dotbot to repoint the symlinks**

Run: `cd ~/.dotfiles && ./install`
Expected: dotbot reports linking `~/.claude/skills` and `~/.claude/hooks`.

- [ ] **Step 4: Verify the symlink resolves into dotfiles**

Run: `readlink ~/.claude/skills; ls ~/.claude/skills/`
Expected: symlink target is `…/.dotfiles/.claude/skills`; listing shows `humanizer`, `humanizer-ua`, `rust-skills`, `rust-explain-errors` (and `skills.manifest.json`, `.gitignore`).

- [ ] **Step 5: Retire the now-empty ~/.agents skill symlinks**

Run: `ls -la ~/.agents/skills/`
Then remove any remaining symlinks that pointed into the old layout (`humanizer`, `find-skills`, `humanizer-ua`):
```bash
rm -f ~/.agents/skills/humanizer ~/.agents/skills/find-skills ~/.agents/skills/humanizer-ua
```
Expected: `~/.agents/skills/` is empty or gone; nothing references the retired paths.

- [ ] **Step 6: Commit**

```bash
git add install.conf.yaml
git commit -m "Repoint claude skills and hooks symlinks into dotfiles"
```

---

### Task 10: Wire into update-all.sh, replace the old script, and document vetting

**Files:**
- Modify: `scripts/update-all.sh:150-160`
- Delete: `scripts/setup-agent-skills.sh`
- Create: `.claude/SKILLS.md`

**Interfaces:**
- Consumes: `scripts/sync-skills.sh` (Tasks 2–4).
- Produces: `update-all.sh` drives sync + bootstrap + a staleness report; `SKILLS.md` records the vetting/maintenance loop.

- [ ] **Step 1: Repoint `update_agent_skills`**

In `scripts/update-all.sh`, replace the body of `update_agent_skills()` (currently calling `setup-agent-skills.sh`) with:
```bash
update_agent_skills() {
    log_step "Updating agent skills"

    local dotfiles_dir="${HOME}/.dotfiles"
    if [[ -f "$dotfiles_dir/scripts/sync-skills.sh" ]]; then
        DOTFILES="$dotfiles_dir" bash "$dotfiles_dir/scripts/sync-skills.sh" sync
        DOTFILES="$dotfiles_dir" bash "$dotfiles_dir/scripts/sync-skills.sh" bootstrap
        DOTFILES="$dotfiles_dir" bash "$dotfiles_dir/scripts/sync-skills.sh" --check
        log_success "Agent skills synced (review 'git diff' before committing)"
    else
        log_warning "sync-skills.sh not found, skipping"
    fi
}
```

- [ ] **Step 2: Delete the obsolete script**

Run: `git rm scripts/setup-agent-skills.sh`

- [ ] **Step 3: Write the vetting/maintenance doc**

Create `.claude/SKILLS.md`:
```markdown
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
```

- [ ] **Step 4: Verify the update path runs end-to-end**

Run: `bash scripts/update-all.sh skills`
Expected: runs sync, bootstrap, and a `--check` report; finishes without error.

- [ ] **Step 5: Commit**

```bash
git add scripts/update-all.sh .claude/SKILLS.md
git commit -m "Drive skills sync from update-all and document vetting"
```

---

## Self-Review

**Spec coverage:**
- Target layout, whole-dir symlink → Tasks 1, 9. ✓
- `skills.manifest.json` → Task 1. ✓
- `sync-skills.sh` sync/--check/bootstrap (all three reinforcements) → Tasks 2, 3, 4. ✓
- `.gitignore` for eval/cache artifacts → Task 1. ✓
- Migration (delete 2 skills, absorb humanizer-ua, vendor humanizer + rust-skills, drop find-skills) → Tasks 2, 5, 9. ✓
- Plugins declarative (skill-creator, Astral) → Tasks 4, 8. ✓
- Format-only hooks → Task 7. ✓
- `rust-explain-errors` → Task 6. ✓
- `SKILLS.md` vetting, `disableSkillShellExecution` OFF → Task 10. ✓
- Verification items from the spec → covered by each task's test steps. ✓

**Placeholder scan:** No TBD/TODO. Refs, plugin ids, and the Astral marketplace are concrete (Global Constraints). The one conditional (rust-skills entrypoint filename in Task 2 Step 3) has an explicit resolution command, not a placeholder.

**Type/name consistency:** `sync-skills.sh` subcommands (`sync`, `--check`, `bootstrap`) and function names (`cmd_sync`, `cmd_check`, `cmd_bootstrap`, `sync_one`, `check_one`) are consistent across Tasks 2–4 and referenced identically in Task 10. Manifest keys (`vendored`, `owned`, `repo`, `ref`, `subdir`) match between Task 1 and every consumer. Env var `DOTFILES` is used consistently.

**Note for the implementer:** `find-skills` is intentionally dropped — it is not in the manifest and gets removed in Task 9 Step 5. Do not re-add it.
