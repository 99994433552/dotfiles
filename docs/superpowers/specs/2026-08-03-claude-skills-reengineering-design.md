# Claude Code Skills Reengineering — Design

**Date:** 2026-08-03
**Status:** Approved (brainstorming), ready for implementation plan
**Reference:** `~/Downloads/compass_artifact_wf-…_text_markdown.md`
("Claude Code Skills: A Must-Have Reference", Aug 2026)

## Problem

The current skills setup works but is fragmented and partly broken:

- **Three mechanisms, no source of truth.** Personal skills are managed via the
  obra `skills` CLI (`humanizer`, `find-skills`), as standalone GitHub repos
  (`article-from-notes`, `research-review`), and via a `~/.config` symlink
  (`humanizer-ua`). All are symlinked from `~/.agents/skills/` into
  `~/.claude/skills/`.
- **Auto-update covers 1 of 5 skills.** `scripts/setup-agent-skills.sh` only
  knows `blader/humanizer`. The three own-repo skills are never pulled.
- **No hooks.** Formatting/linting is not enforced deterministically.
- **Missing recommended pieces.** No `skill-creator`, no Rust knowledge skills
  (only the `rust-analyzer-lsp` plugin, which is an LSP, not knowledge), no
  documented vetting process for third-party skills.

What is already good and stays: `CLAUDE.md` is lean (facts only), and
`.claude/rules/python.md` is path-scoped — both already match the reference
document's guidance.

## Decisions

Locked during brainstorming:

1. **Scope:** full reengineering (not a report).
2. **Harness:** Claude Code only. This enables the simplest, most controlled
   model — **vendor skills directly into dotfiles under git**, no runtime CLI.
3. **Deletions:** remove `article-from-notes` and `research-review` local
   skills (the GitHub repos are untouched).
4. **Additions in scope:** `skill-creator` plugin; `ruff`/`rustfmt` hooks; Rust
   knowledge (`leonardomso/rust-skills` vendored + own `rust-explain-errors`);
   Python tooling (Astral plugin).
5. **`humanizer-ua`:** absorbed into dotfiles as the single source of truth;
   the standalone repo is retired.
6. **Architecture:** vendored monorepo in dotfiles (rejected: git submodules,
   and keeping the obra `skills` CLI).

## Target Architecture

```
~/.dotfiles/.claude/
├── skills/
│   ├── .gitignore            # ignores eval/cache artifacts (see §6)
│   ├── humanizer/            # vendored snapshot (blader/humanizer)
│   ├── humanizer-ua/         # absorbed — source of truth lives here
│   ├── rust-skills/          # vendored snapshot (leonardomso/rust-skills)
│   └── rust-explain-errors/  # new own skill
├── hooks/
│   └── format-dispatch.sh    # ruff for .py, rustfmt for .rs
├── skills.manifest.json      # declarative: vendored sources + pinned refs
├── settings.json             # + hooks block, + enabledPlugins additions
├── SKILLS.md                 # vetting checklist + maintenance notes
└── rules/                    # unchanged (git.md, python.md)
```

**Symlink:** `~/.claude/skills` → `~/.dotfiles/.claude/skills` (whole directory,
via dotbot). Retire `~/.agents/skills/` and `~/.config/humanizer-ua`.

Whole-directory symlink (not per-skill) means skills that `skill-creator`
generates in `~/.claude/skills/` land physically inside dotfiles, already under
git — no separate "move it in" step.

**Dropped:** `find-skills` (a discovery helper that assumed the multi-harness
`skills` CLI; low value under Claude-only vendoring, and it costs listing
budget).

## Components

Each component below states *what it does*, *how it is used*, and *what it
depends on*, so it can be built and tested in isolation.

### 1. `skills.manifest.json` — declarative inventory

**What:** the single source of truth for which third-party skills are vendored,
from where, and pinned to which ref.

**Shape:**
```json
{
  "vendored": {
    "humanizer":   { "repo": "blader/humanizer",      "ref": "v2.2.0", "subdir": "." },
    "rust-skills": { "repo": "leonardomso/rust-skills", "ref": "<sha>", "subdir": "." }
  },
  "owned": ["humanizer-ua", "rust-explain-errors"]
}
```

- `vendored` — third-party skills. `ref` is a tag or commit SHA (pinned);
  `subdir` is the path inside the source repo to copy from.
- `owned` — skills whose source is dotfiles itself; `sync-skills.sh` never
  touches these.

**Depends on:** nothing (plain data). Consumed by `sync-skills.sh`.

### 2. `scripts/sync-skills.sh` — sync + bootstrap (replaces `setup-agent-skills.sh`)

**What:** reconciles the on-disk state with the manifest and with
`settings.json`. Three subcommands:

- **`sync`** (default): for each `vendored` entry, shallow-clone `repo` at `ref`
  into a cache dir, `rsync` `subdir` into `.claude/skills/<name>` excluding
  `.git`, then print a `git diff --stat`. **Does not commit** — leaves staged
  changes for the user to review. Upgrading = edit `ref`, rerun.
- **`--check`** (reinforcement #1): for each `vendored` entry, query the
  upstream latest tag / default-branch HEAD and compare with the pinned `ref`.
  Print `N updates available` with the tag deltas. **Applies nothing.** This is
  the guard against silent staleness.
- **`bootstrap`** (reinforcement #3): idempotently ensure the environment is
  reproducible — install any `enabledPlugins` (§4) that are enabled but not
  installed, and `command -v` each required tool (`ruff`, `rustfmt`), loudly
  warning about anything missing. After `git pull`, `sync-skills.sh bootstrap`
  makes "one pull = everything" actually true.

**Depends on:** `git`, `rsync`, `jq` (parse manifest/settings), `claude` CLI
(plugin install). Idempotent; safe to rerun. Wired into `update-all.sh`
(replacing the `update_agent_skills` call).

### 3. Migration of existing skills

**What:** move the skill inventory into the vendored layout.

- Delete `article-from-notes`, `research-review` from `~/.agents/skills/`.
- Absorb `humanizer-ua`: copy real files into `.claude/skills/humanizer-ua/`,
  retire the `~/.config/humanizer-ua` repo and its symlink.
- Vendor `humanizer` and `rust-skills` via `sync-skills.sh sync` from a manifest
  seeded with their current pinned refs.
- Repoint the `~/.claude/skills` symlink through dotbot; remove
  `~/.agents/skills/` and its per-skill symlinks.

**Depends on:** §1, §2, dotbot config.

### 4. Plugins — declarative via `settings.json`

**What:** `enabledPlugins` remains the source of truth for marketplace plugins.
Additions:
```
"skill-creator@claude-plugins-official": true,
"astral@<marketplace>": true          # /astral:uv, /astral:ruff, /astral:ty
```
(The exact Astral marketplace identifier is resolved during implementation.)

Marketplace auto-updates the plugin bodies; we pin *intent*, not SHA.
`sync-skills.sh bootstrap` reconciles enabled-vs-installed.

**Depends on:** `claude` CLI, network (install only).

### 5. Hooks — deterministic formatting (reinforcement #2)

**What:** a `PostToolUse` hook that formats files after Claude edits them.

`settings.json`:
```json
"hooks": { "PostToolUse": [
  { "matcher": "Edit|Write", "hooks": [
    { "type": "command", "command": "~/.claude/hooks/format-dispatch.sh" }
  ]}
]}
```

`hooks/format-dispatch.sh` reads the edited file path from the hook's stdin
JSON and dispatches by extension:
- `*.py` → `ruff format` (line-length 80, per `rules/python.md`)
- `*.rs` → `rustfmt`

**Format only — no `ruff check --fix` in the hook.** Auto-fixing logical issues
after a write causes on-disk/expectation drift; linting with fixes stays a
deliberate manual/skill-driven step. The hook guards each formatter with
`command -v` and always `exit 0`, so a missing tool never blocks editing.

**Depends on:** `ruff`, `rustfmt` (guarded).

### 6. `.gitignore` inside `skills/`

**What:** keep the whole-directory symlink from dragging churn into commits.
Ignore `skill-creator` eval/benchmark artifacts and caches:
```
evals/
benchmark.json
*.cache
__pycache__/
```
Tune to what `skill-creator` actually emits during implementation.

### 7. `rust-explain-errors` — new own skill

**What:** a path-scoped teaching skill for a Rust learner.

Frontmatter: `paths: ["**/*.rs"]`. Body instructs: on borrow/lifetime/trait
errors (`E0382`, `E0499`, `E0502`, `E0597`, `E0308`, …) decode the error,
explain the ownership/lifetime rule behind it, and teach the fix *and why* —
rather than silently patching. Kept minimal; refined with `skill-creator`
evals if it under-triggers.

**Depends on:** nothing at runtime.

### 8. `SKILLS.md` + security posture

**What:** document the vetting checklist (reference §G) to run before adding any
vendored skill: read the full `SKILL.md` and every bundled file; flag network
calls and `!`-backtick shell lines; check `allowed-tools`; prefer pure-Markdown
skills; pin refs. Also record the maintenance loop (`sync --check` cadence).

`disableSkillShellExecution` is **not** enabled globally (it would cripple
legitimate skills); the control is disciplined vetting plus ref pinning.

## Migration Steps (execution order)

1. Delete `article-from-notes`, `research-review` from `~/.agents/skills/`.
2. Create `.claude/skills/` with `.gitignore`; absorb `humanizer-ua`; write
   `skills.manifest.json` seeded with `humanizer` + `rust-skills` refs.
3. Write `sync-skills.sh` (`sync` / `--check` / `bootstrap`); vendor `humanizer`
   and `rust-skills` via `sync`.
4. Write `rust-explain-errors`.
5. Repoint the `~/.claude/skills` symlink via dotbot; retire `~/.agents/skills/`
   and `~/.config/humanizer-ua`.
6. Add the hooks block + `format-dispatch.sh`.
7. Install `skill-creator` + Astral plugins; update `enabledPlugins`; run
   `sync-skills.sh bootstrap`.
8. Write `SKILLS.md`; wire `sync-skills.sh` into `update-all.sh`.

## Verification

- `sync-skills.sh sync` on a clean tree produces the expected vendored files and
  a reviewable diff; rerun is a no-op.
- `sync-skills.sh --check` reports available upstream updates without changing
  files.
- `sync-skills.sh bootstrap` installs missing plugins and warns on missing
  tools; rerun is a no-op.
- Editing a `.py` and a `.rs` file triggers `format-dispatch.sh`; a missing
  formatter warns but does not block.
- `~/.claude/skills` resolves into dotfiles; the three retired skills and stale
  symlinks are gone.
- Each skill (incl. `rust-explain-errors`) appears in `/doctor`'s listing and
  triggers on a representative prompt.

## Risks & Trade-offs (accepted)

- **Bespoke tooling.** `manifest` + `sync-skills.sh` is ~100 lines of bash we
  own, chosen over the external obra `skills` CLI for offline use, auditability,
  and supply-chain control. Transparent code over a black box — an accepted
  trade, not a free win.
- **Two update cadences.** Vendored skills update deliberately (`sync`);
  marketplace plugins update on their own. Deliberate: marketplace is screened;
  `--check` closes the visibility gap for vendored skills.
- **Full reproduction needs bootstrap.** `git pull` restores skills, but plugins
  and tool binaries need `sync-skills.sh bootstrap` + Homebrew/rustup — one
  extra idempotent step, not one command.
