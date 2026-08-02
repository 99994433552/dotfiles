# Shell Functions Refactor — Design

- **Date:** 2026-08-02
- **Status:** Approved, ready for planning
- **Scope:** Refactor the utility/media functions in `zshrc` for maintainability and testability. No rewrite to another language.

## Motivation

`zshrc` has grown to ~685 lines, with four large media functions (`vidcut`,
`storycut`, `ytmp3`, `makesticker`) inflating the main config. Three problems
make the code fragile:

1. **Duplication.** `--browser/--cookies` auth parsing is copy-pasted across
   `vidcut`, `storycut`, `ytmp3`. The `y/N` confirmation prompt appears in
   `prefix_dirname`, `unlockdir`, `cleanmusic`. File collection with preview is
   duplicated between `prefix_dirname` and `cleanmusic`.
2. **Silent failures.** Only `makesticker` checks `$?`. Other functions march on
   after a failed `yt-dlp`/`ffmpeg` step.
3. **Monolith.** All functions live in one file, so editing any of them means
   touching the central config.

### Non-goals

- **Performance.** These functions are thin wrappers around `yt-dlp`/`ffmpeg`;
  runtime is dominated by network and encoding. Orchestration cost is
  negligible. Speed is explicitly not a goal.
- **Rewrite to Rust/Python.** Considered and rejected: orchestration is exactly
  what shell is a DSL for, and a rewrite adds a build/deploy step for no
  robustness gain that a refactor doesn't already provide.

## Scope

**Refactored** (extracted, deduplicated, hardened): `ydl`, `vidcut`, `storycut`,
`makesticker`, `ytmp3`, `cleanmusic`, `prefix_dirname`, `unlockdir`, `v`,
`notes`, `pva`, `mkcd`, `dl_with_referer`/`skvotdl`.

Everything currently defined as a function moves out of `zshrc` into modules.
Aliases, completions (`_uv_run_mod`, `compdef`), prompt/tool init, and exports
stay in `zshrc`.

## Architecture

### Directory layout

```
config/zsh/
├── lib/                    # shared helpers, all prefixed with _
│   ├── confirm.zsh         # _confirm
│   ├── auth-args.zsh       # _parse_auth
│   └── collect-files.zsh   # _collect_files
└── functions/
    ├── media.zsh           # ydl, vidcut, storycut, makesticker, ytmp3, dlref, skvotdl
    ├── files.zsh           # prefix_dirname, cleanmusic, unlockdir, mkcd
    └── nav.zsh             # v, notes, pva
```

### Sourcing

`zshrc` sources every module in a loop, `lib/` before `functions/`:

```zsh
for _f in "$DOTFILES_DIR"/config/zsh/lib/*.zsh "$DOTFILES_DIR"/config/zsh/functions/*.zsh; do
  [[ -r "$_f" ]] && source "$_f"
done
unset _f
```

`DOTFILES_DIR` is already exported at the top of `zshrc`. Because the files are
sourced directly from the repo, **no dotbot symlink is needed** — they deploy
for free on any machine that has the dotfiles checked out.

## Shared library (`lib/`)

Each helper has one purpose and a defined interface. Consumers use them without
reading their internals.

- **`_confirm <prompt>`** — prints `<prompt> [y/N] `, reads a reply, returns 0
  for `y`/`Y`, non-zero otherwise. Replaces the three inline prompts.
- **`_parse_auth <method> <browser> <cookies_file>`** — prints the yt-dlp auth
  arguments (`--cookies-from-browser <b>`, `--cookies <f>`, or nothing) as a
  single line for the caller to split into an array. Replaces the duplicated
  `case "$auth_method"` blocks in `vidcut`/`storycut`/`ytmp3`.
- **`_collect_files <glob>...`** — collects matching regular files into the
  array `REPLY_FILES`, prints a numbered preview (first N + "… and M more").
  Shared by `prefix_dirname` and `cleanmusic`.

Helpers live in `lib/` and are sourced before the functions that call them.

## Safety conventions

Every non-trivial function opens with:

```zsh
setopt local_options no_unset pipe_fail err_return
```

`local_options` scopes the change to the function; `no_unset` turns unset-var
bugs into errors; `pipe_fail` propagates failures through pipes; `err_return`
makes the function return on the first failed command. This converts today's
silent failures into loud, early exits. Interactive-read functions keep their
existing explicit control flow where `err_return` would fight the `read` loop.

## Pure helpers and tests

Pure logic is extracted into small, side-effect-free helpers so it can be tested
without invoking `ffmpeg`/`yt-dlp`:

- **`_crop_x <pos> <iw> <ow>`** (from `storycut`) — resolves
  `left/center/right/0-100` to an ffmpeg crop-x expression; errors on invalid
  input.
- **`_sticker_bitrate <max_kb> <duration>`** (from `makesticker`) — the
  `(kb * 8 * 0.95) / duration` calculation.
- **`_duration_min <a> <b>`** (from `makesticker`) — numeric min of two values.
- **`_channel_name <url>`** (from `ytmp3`) — extracts the channel handle from a
  YouTube URL.

### Test suite

- **Framework:** `shellspec` (supports zsh). Added to `profiles/base.Brewfile`.
- **Location:** `config/zsh/spec/*_spec.sh`.
- **Covered:** the pure helpers above, plus `_confirm`/`_parse_auth` behavior
  (input → output), plus argument-validation error paths of the media functions
  (missing `-u/-s/-e` returns non-zero with a message).
- **Not covered:** the actual `ffmpeg`/`yt-dlp` invocations — only the real tools
  can validate a filter graph or a format selector, so asserting the constructed
  command string would be a change-detector test. Out of scope.

## Deployment

1. Add `brew "shellspec"` to `profiles/base.Brewfile` (and the mirrored
   `Brewfile`) so tests run on any machine. `shellspec` is a dev dependency only.
2. `zshrc` sources the modules directly from `$DOTFILES_DIR` — no symlink, no
   build step, no new-machine setup. This is the payoff of refactoring over
   rewriting: deployment is already solved.

## Migration approach

Incremental, verifiable at each step:

1. Create `lib/` helpers with tests; confirm they pass.
2. Extract simple functions (`nav.zsh`, `files.zsh`), sourcing from `zshrc`,
   removing the originals. Verify each still works.
3. Extract media functions (`media.zsh`) one at a time, wiring them to the new
   `lib/` helpers and adding safety options. Verify each after extraction.
4. Add pure-helper extraction and the remaining tests.
5. Add `shellspec` to the Brewfile.
6. Trim `zshrc` to aliases, completions, init, and the sourcing loop.

Do not delete an original function until its replacement is verified working.

## Risks

- **`err_return` vs interactive `read` loops.** Functions that read user input
  need their control flow checked so `err_return` doesn't abort mid-prompt.
  Mitigation: apply safety options per-function, not globally, and test the
  confirm paths.
- **`_parse_auth` word-splitting.** Returning args as a string and re-splitting
  risks mishandling paths with spaces. Mitigation: use zsh array output
  conventions (`print -r` + `${(f)...}` or a named output array), and add a test
  with a spaced cookies path.
