# Dotbot Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade dotbot to 1.24.x, make the installer self-bootstrapping via the Brewfile, adopt link `backup`, and remove footguns/redundancy from `install.conf.yaml`.

**Architecture:** dotbot is a shell/config tool, not an app with a test suite. "Verification" here means `./install --dry-run` (added in dotbot 1.23) plus `dotbot --version` and `which` checks — never a real `./install` while iterating, to avoid mutating the live home dir. Changes are small, independent edits to three files; each is committed separately.

**Tech Stack:** dotbot (Homebrew formula, 1.24.1), zsh installer scripts, generated Brewfile from `profiles/*.Brewfile`.

## Global Constraints

- dotbot minimum target version: **1.24.x** (Homebrew `dotbot` formula).
- `Brewfile` at repo root is **generated** by `setup_homebrew.zsh` from `profiles/base.Brewfile` + `profiles/{profile}.Brewfile`. Never hand-edit the root `Brewfile`; edit the profile source.
- Commit messages: imperative summary ≤72 chars, body explains why, no AI attribution (repo `commit-msg` hook enforces this).
- Work happens on branch `chore/dotbot-modernization`.
- Never run a real `./install` during iteration; use `./install --dry-run` only.

---

### Task 1: Pin and install dotbot via Homebrew

**Files:**
- Modify: `profiles/base.Brewfile` (add one `brew` line in the CORE DEVELOPMENT TOOLS section)

**Interfaces:**
- Produces: `dotbot` present in `profiles/base.Brewfile`, so `brew bundle` (run by `setup_homebrew.zsh`) installs it on any machine. This closes the bootstrap loop consumed by Task 2's `install` script.

- [ ] **Step 1: Observe the current gap**

Run: `grep -n dotbot profiles/base.Brewfile; dotbot --version; which -a dotbot`
Expected: no match in base.Brewfile; version reports `1.21.0`; `which -a` may show a non-Homebrew path (e.g. a pipx/pip shim).

- [ ] **Step 2: Add dotbot to the base profile**

In `profiles/base.Brewfile`, under the `# CORE DEVELOPMENT TOOLS` section, add:

```ruby
brew "dotbot"                        # Dotfiles bootstrapper (manages symlinks)
```

- [ ] **Step 3: Install/upgrade dotbot on this machine**

Run: `brew install dotbot`
Expected: installs `1.24.1` (or newer). If already tapped, `brew upgrade dotbot`.

- [ ] **Step 4: Verify the Homebrew build wins on PATH**

Run: `hash -r; which dotbot; dotbot --version`
Expected: path is the Homebrew prefix (`/opt/homebrew/bin/dotbot` on Apple Silicon) and version is `1.24.x`.
If a pip/pipx dotbot still shadows it, remove that one (`pipx uninstall dotbot` or `pip uninstall dotbot`) and re-run this step until Homebrew's build wins.

- [ ] **Step 5: Commit**

```bash
git add profiles/base.Brewfile
git commit -m "Add dotbot to base Brewfile for reproducible bootstrap

Pin dotbot as a Homebrew package so a clean machine installs it via
brew bundle before install runs dotbot, closing the bootstrap loop."
```

---

### Task 2: Forward CLI args from the installer to dotbot

**Files:**
- Modify: `install` (the `dotbot -c …` invocation, currently line 30)

**Interfaces:**
- Consumes: dotbot 1.24.x from Task 1 (needs the `--dry-run` flag, added in 1.23).
- Produces: `./install <flags>` passes flags straight to dotbot, enabling `./install --dry-run` used as the verification harness in Task 3.

- [ ] **Step 1: Observe current behavior**

Run: `grep -n 'dotbot -c' install`
Expected: `dotbot -c "$DOTFILES_DIR/install.conf.yaml"` with no argument forwarding.

- [ ] **Step 2: Forward arguments**

Change that line to:

```bash
dotbot -c "$DOTFILES_DIR/install.conf.yaml" "$@"
```

- [ ] **Step 3: Verify dry-run flows through**

Run: `./install --dry-run`
Expected: dotbot runs in dry-run mode (reports intended link/clean actions, makes no changes). The wrapper's Homebrew bootstrap block is skipped because dotbot is already on PATH.

- [ ] **Step 4: Commit**

```bash
git add install
git commit -m "Forward installer args to dotbot

Pass through flags so ./install --dry-run and other dotbot options work
without editing the wrapper."
```

---

### Task 3: Modernize install.conf.yaml (backup default, drop footguns/redundancy)

**Files:**
- Modify: `install.conf.yaml` (`defaults` block ~L10-13; `clean` block ~L18-22; `link` entries throughout)

**Interfaces:**
- Consumes: `./install --dry-run` from Task 2 as the verification harness; `backup` option from dotbot 1.24 (Task 1).

- [ ] **Step 1: Capture the baseline dry-run**

Run: `./install --dry-run | tee /tmp/dotbot-before.txt`
Expected: current intended actions recorded. Note any `clean` removals it reports.

- [ ] **Step 2: Add a global backup default**

In the `defaults` block, change:

```yaml
- defaults:
    link:
      relink: true
      create: true
```

to:

```yaml
- defaults:
    link:
      relink: true
      create: true
      backup: true
```

- [ ] **Step 3: Remove the clean footgun**

Change:

```yaml
- clean:
    ~/:
      force: true
    ~/.config:
      recursive: true
```

to:

```yaml
- clean:
    ~/:
    ~/.config:
      recursive: true
```

(`force` on `~/` deletes dead symlinks pointing *outside* the dotfiles dir; the default only removes links into the dotfiles dir.)

- [ ] **Step 4: Remove redundant per-entry `create: true`**

`create` is now inherited from `defaults.link`. In every `link:` entry that uses the expanded form, delete the `create: true` line while keeping `path:`. Affected entries: `~/.config/opencode/opencode.json`, `~/.config/zellij/config.kdl`, `~/.config/tmux/tmux.conf`, `~/.config/musikcube/hotkeys.json`. Example — change:

```yaml
    ~/.config/tmux/tmux.conf:
      path: config/tmux/tmux.conf
      create: true
```

to:

```yaml
    ~/.config/tmux/tmux.conf:
      path: config/tmux/tmux.conf
```

Leave `force: true` on `~/.zshrc` and `~/.gitconfig` untouched (they overwrite real pre-existing files on first install; global `backup` now preserves whatever they replace).

- [ ] **Step 5: Verify the dry-run diff is intentional**

Run: `./install --dry-run | tee /tmp/dotbot-after.txt; diff /tmp/dotbot-before.txt /tmp/dotbot-after.txt`
Expected: the only differences are (a) no forced clean removals of external symlinks, and (b) links now report a backup step. No unexpected removals of managed links. If anything surprising appears, stop and reconcile before committing.

- [ ] **Step 6: Confirm idempotent real run**

Run: `./install`
Expected: completes cleanly on this already-linked machine; no destructive actions; `dotbot --version` in the summary confirms 1.24.x. Any file it had to overwrite leaves a `.dotbot-backup.{timestamp}` sibling.

- [ ] **Step 7: Commit**

```bash
git add install.conf.yaml
git commit -m "Modernize dotbot config: backup default, drop clean force

Add link backup as a safety net, remove force from clean ~/ so external
symlinks are not deleted, and drop create options now inherited from
defaults. Keep force only on zshrc and gitconfig."
```

---

## Self-Review

- **Spec coverage:** Bootstrapping/pin → Task 1; arg forwarding/`--dry-run` → Task 2; `backup` default + clean-force removal + redundant `create` removal + force kept on zshrc/gitconfig → Task 3; validation via before/after dry-run + idempotent real run → Task 3 Steps 1/5/6. Machine upgrade 1.21→1.24 and PATH-shadow check → Task 1 Steps 3-4. All spec sections mapped.
- **Placeholder scan:** none — every edit shows exact before/after content.
- **Type consistency:** n/a (config/shell); file paths and dotbot option names (`backup`, `force`, `relink`, `create`, `--dry-run`) match dotbot 1.24 docs and the spec.
- Note: the design spec lives at `docs/superpowers/specs/2026-07-24-dotbot-modernization-design.md` but is git-ignored (`~/.gitignore_global` ignores `specs/`), so it stays on-disk only — intentional, not a gap.
