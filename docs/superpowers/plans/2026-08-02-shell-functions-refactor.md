# Shell Functions Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the utility/media functions out of the monolithic `zshrc` into sourced `config/zsh` modules with a deduplicated shared library, hardened failure behavior, and a shellspec test suite.

**Architecture:** Functions move from `zshrc` into domain modules under `config/zsh/functions/`, backed by small single-purpose helpers in `config/zsh/lib/`. `zshrc` sources every module in a loop directly from `$DOTFILES_DIR` (no symlink, no build step). Pure logic is extracted into side-effect-free helpers covered by shellspec.

**Tech Stack:** zsh, shellspec (zsh mode), Homebrew, dotbot.

## Global Constraints

- Shell is **zsh**, not bash. Use zsh idioms (`local -a`, `setopt local_options`, glob qualifiers `*(N.)`).
- Comments and documentation in **English**.
- Functions are **sourced directly from `$DOTFILES_DIR`** (exported at `zshrc:10`). No dotbot symlink for `config/zsh`.
- Shared helpers are prefixed with `_` and live in `config/zsh/lib/`.
- shellspec spec files live in `config/zsh/spec/*_spec.sh`; project config is `.shellspec` at repo root with `--shell zsh`.
- Non-trivial functions open with `setopt local_options pipe_fail`. Add `no_unset` **only** when the function makes no bare positional-parameter reference for a graceful no-arg path (e.g. `unlockdir`, which guards with `${1:-.}`) — `no_unset` aborts on `$1`/`$2` when unset and swallows the `Usage` messages of the arg-parsing functions (`ytmp3`, `vidcut`, `storycut`, `makesticker`), so they omit it. Never add `err_return` to functions whose body contains an interactive `read` loop — it fights the loop; those keep explicit `return` checks. (Pre-flight ruling 2026-08-02, verified empirically.)
- Commit messages: summary ≤72 chars, imperative, specific first word (not fix/update/change); blank line; body explaining why. No AI attribution (the `commit-msg` hook rejects `claude|generated|assisted|copilot` and 🤖).
- Never delete an original function until its replacement is sourced and verified working.

---

## File Structure

```
.shellspec                          # Create: shellspec project config (--shell zsh, default-path)
config/zsh/
├── lib/
│   ├── confirm.zsh                 # Create: _confirm
│   ├── auth-args.zsh               # Create: _parse_auth
│   ├── preview.zsh                 # Create: _preview
│   └── media-helpers.zsh           # Create: _crop_x, _sticker_bitrate, _duration_min, _channel_name
├── functions/
│   ├── nav.zsh                     # Create: v, notes, pva
│   ├── files.zsh                   # Create: mkcd, prefix_dirname, cleanmusic, unlockdir
│   └── media.zsh                   # Create: ydl, dlref, skvotdl, ytmp3, vidcut, storycut, makesticker
└── spec/
    ├── spec_helper.sh              # Create: shellspec bootstrap (generated)
    ├── confirm_spec.sh             # Create
    ├── auth_args_spec.sh           # Create
    ├── preview_spec.sh             # Create
    ├── media_helpers_spec.sh       # Create
    └── functions_spec.sh           # Create: validation/error-path tests for migrated functions
zshrc                               # Modify: add sourcing loop, remove migrated functions
profiles/base.Brewfile             # Modify: add shellspec
Brewfile                            # Modify: mirror shellspec
```

---

### Task 1: shellspec test harness

**Files:**
- Create: `.shellspec`
- Create: `config/zsh/spec/spec_helper.sh`
- Modify: `profiles/base.Brewfile`, `Brewfile`

**Interfaces:**
- Produces: a runnable `shellspec` command using zsh, reading specs from `config/zsh/spec/`.

- [ ] **Step 1: Install shellspec locally**

Run: `brew install shellspec`
Expected: `shellspec --version` prints a version.

- [ ] **Step 2: Add shellspec to the Brewfiles**

Add this line under the dev-tools section of both `profiles/base.Brewfile` and `Brewfile`:

```ruby
brew "shellspec"                     # BDD test framework for shell (zsh mode)
```

- [ ] **Step 3: Create the shellspec project config**

Create `.shellspec` with:

```
--shell zsh
--default-path config/zsh/spec
--require spec_helper
```

- [ ] **Step 4: Create the spec helper**

Create `config/zsh/spec/spec_helper.sh` with:

```sh
# shellcheck shell=sh
# shellspec bootstrap. Individual specs Include the file under test.
```

- [ ] **Step 5: Add a smoke spec and run it**

Create `config/zsh/spec/smoke_spec.sh`:

```sh
Describe 'harness'
  It 'runs under zsh'
    When call test -n "$ZSH_VERSION"
    The status should be success
  End
End
```

Run: `shellspec config/zsh/spec/smoke_spec.sh`
Expected: 1 example, 0 failures.

- [ ] **Step 6: Remove the smoke spec and commit**

Run: `rm config/zsh/spec/smoke_spec.sh`

```bash
git add .shellspec config/zsh/spec/spec_helper.sh profiles/base.Brewfile Brewfile
git commit -m "Add shellspec harness for zsh function tests" \
  -m "Sets up shellspec in zsh mode with specs under config/zsh/spec, and pins shellspec in the Brewfiles so it deploys with the rest of the dev tooling."
```

---

### Task 2: Sourcing loop in zshrc

**Files:**
- Modify: `zshrc` (add loop in the Utility Functions region, near `zshrc:108`)

**Interfaces:**
- Produces: every `config/zsh/lib/*.zsh` then `config/zsh/functions/*.zsh` is sourced on shell start. Tolerates empty/missing dirs.

- [ ] **Step 1: Add the sourcing loop**

Replace the `# Utility Functions` banner region opener at `zshrc:108-110` by inserting, immediately after the banner comment, before the first function (`unalias v`):

```zsh
# Load modular functions and their shared helpers (lib first, then functions)
for _zf in "$DOTFILES_DIR"/config/zsh/lib/*.zsh(N) "$DOTFILES_DIR"/config/zsh/functions/*.zsh(N); do
  source "$_zf"
done
unset _zf
```

The `(N)` glob qualifier makes an empty match expand to nothing instead of erroring.

- [ ] **Step 2: Verify the shell still starts cleanly**

Run: `zsh -i -c 'echo ok'`
Expected: prints `ok` with no errors (the `config/zsh` dirs may not exist yet; `(N)` handles that).

- [ ] **Step 3: Commit**

```bash
git add zshrc
git commit -m "Source modular zsh functions from config/zsh" \
  -m "Adds a startup loop that sources shared helpers then function modules directly from the repo, so new modules load without a symlink or build step."
```

---

### Task 3: `_confirm` helper

**Files:**
- Create: `config/zsh/lib/confirm.zsh`
- Create: `config/zsh/spec/confirm_spec.sh`

**Interfaces:**
- Produces: `_confirm <prompt>` — prints `<prompt> [y/N] `, reads one line from stdin, returns 0 for `y`/`Y`, non-zero otherwise.

- [ ] **Step 1: Write the failing test**

Create `config/zsh/spec/confirm_spec.sh`:

```sh
Describe '_confirm'
  Include config/zsh/lib/confirm.zsh

  It 'returns success on y'
    Data 'y'
    When call _confirm 'Continue?'
    The status should be success
    The output should include 'Continue?'
  End

  It 'returns failure on empty (default No)'
    Data ''
    When call _confirm 'Continue?'
    The status should be failure
  End

  It 'returns failure on n'
    Data 'n'
    When call _confirm 'Continue?'
    The status should be failure
  End
End
```

- [ ] **Step 2: Run test to verify it fails**

Run: `shellspec config/zsh/spec/confirm_spec.sh`
Expected: FAIL — `_confirm` not found / file to Include is missing.

- [ ] **Step 3: Write the implementation**

Create `config/zsh/lib/confirm.zsh`:

```zsh
# _confirm <prompt> — ask a y/N question. Returns 0 only on y/Y.
_confirm() {
  local prompt="$1" response
  print -n -- "${prompt} [y/N] "
  read -r response
  [[ "$response" =~ ^[Yy]$ ]]
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `shellspec config/zsh/spec/confirm_spec.sh`
Expected: 3 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add config/zsh/lib/confirm.zsh config/zsh/spec/confirm_spec.sh
git commit -m "Add _confirm shared y/N prompt helper" \
  -m "Replaces three copy-pasted confirmation prompts with one tested helper."
```

---

### Task 4: `_parse_auth` helper

**Files:**
- Create: `config/zsh/lib/auth-args.zsh`
- Create: `config/zsh/spec/auth_args_spec.sh`

**Interfaces:**
- Produces: `_parse_auth <method> <browser> <cookies_file>` — populates the caller-local array `auth_args` (zsh dynamic scope) with the matching yt-dlp flags. `method` ∈ `browser|file|oauth|""`. For `browser`: `(--cookies-from-browser <browser>)`; `file`: `(--cookies <cookies_file>)`; `oauth`: `(--username oauth --password '')`; empty/other: leaves `auth_args` untouched.
- Consumes: caller declares `local -a auth_args` before calling.

- [ ] **Step 1: Write the failing test**

Create `config/zsh/spec/auth_args_spec.sh`:

```sh
Describe '_parse_auth'
  Include config/zsh/lib/auth-args.zsh

  # Wrapper prints the populated array so we can assert on it.
  build() { local -a auth_args; _parse_auth "$@"; print -r -- "${auth_args[@]}"; }

  It 'builds browser auth'
    When call build browser firefox ''
    The output should eq '--cookies-from-browser firefox'
  End

  It 'builds file auth and preserves spaced paths'
    When call build file firefox '/tmp/my cookies.txt'
    The output should eq '--cookies /tmp/my cookies.txt'
  End

  It 'builds oauth'
    When call build oauth firefox ''
    The output should eq '--username oauth --password'
  End

  It 'produces nothing for empty method'
    When call build '' firefox ''
    The output should eq ''
  End
End
```

- [ ] **Step 2: Run test to verify it fails**

Run: `shellspec config/zsh/spec/auth_args_spec.sh`
Expected: FAIL — Include target missing.

- [ ] **Step 3: Write the implementation**

Create `config/zsh/lib/auth-args.zsh`:

```zsh
# _parse_auth <method> <browser> <cookies_file>
# Populates the caller-local array `auth_args` with yt-dlp auth flags.
# Relies on zsh dynamic scope: caller must `local -a auth_args` first.
_parse_auth() {
  local method="$1" browser="$2" cookies_file="$3"
  case "$method" in
    browser) auth_args=(--cookies-from-browser "$browser") ;;
    file)    auth_args=(--cookies "$cookies_file") ;;
    oauth)   auth_args=(--username oauth --password '') ;;
  esac
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `shellspec config/zsh/spec/auth_args_spec.sh`
Expected: 4 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add config/zsh/lib/auth-args.zsh config/zsh/spec/auth_args_spec.sh
git commit -m "Add _parse_auth helper for yt-dlp cookie flags" \
  -m "Collapses the duplicated auth case-blocks from vidcut, storycut, and ytmp3 into one helper that returns a zsh array, so spaced cookie paths survive."
```

---

### Task 5: `_preview` helper

**Files:**
- Create: `config/zsh/lib/preview.zsh`
- Create: `config/zsh/spec/preview_spec.sh`

**Interfaces:**
- Produces: `_preview <max> <item>...` — prints up to `<max>` items (one per line, indented `   `) then, if more remain, `   ... and <N> more`. Returns 0. Note: this is the narrowed form of the spec's `_collect_files` — only the preview rendering is shared between `prefix_dirname` and `cleanmusic`; the two collect files differently (glob vs recursive find) so collection stays per-function.

- [ ] **Step 1: Write the failing test**

Create `config/zsh/spec/preview_spec.sh`:

```sh
Describe '_preview'
  Include config/zsh/lib/preview.zsh

  It 'lists all when under the cap'
    When call _preview 3 a b
    The line 1 should eq '   a'
    The line 2 should eq '   b'
  End

  It 'truncates and reports the remainder'
    When call _preview 2 a b c d
    The line 1 should eq '   a'
    The line 2 should eq '   b'
    The line 3 should eq '   ... and 2 more'
  End
End
```

- [ ] **Step 2: Run test to verify it fails**

Run: `shellspec config/zsh/spec/preview_spec.sh`
Expected: FAIL — Include target missing.

- [ ] **Step 3: Write the implementation**

Create `config/zsh/lib/preview.zsh`:

```zsh
# _preview <max> <item>... — print up to <max> items, then a remainder line.
_preview() {
  local max="$1"; shift
  local total=$#
  local shown=$(( total < max ? total : max ))
  local i
  for (( i = 1; i <= shown; i++ )); do
    print -r -- "   ${@[i]}"
  done
  (( total > max )) && print -r -- "   ... and $(( total - max )) more"
  return 0
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `shellspec config/zsh/spec/preview_spec.sh`
Expected: 2 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add config/zsh/lib/preview.zsh config/zsh/spec/preview_spec.sh
git commit -m "Add _preview helper for truncated file listings" \
  -m "Shared preview rendering used by prefix_dirname and cleanmusic; collection stays per-function because their traversal differs."
```

---

### Task 6: Pure media helpers

**Files:**
- Create: `config/zsh/lib/media-helpers.zsh`
- Create: `config/zsh/spec/media_helpers_spec.sh`

**Interfaces:**
- Produces:
  - `_crop_x <pos>` — prints the ffmpeg crop-x expression for `left|center|right|0..100`; returns non-zero (no output) on invalid input. (`blur` is handled separately in `storycut`, not here.)
  - `_sticker_bitrate <max_kb> <duration>` — prints integer kbit/s = round((max_kb·8·0.95)/duration).
  - `_duration_min <a> <b>` — prints the smaller of two numbers.
  - `_channel_name <url>` — prints the YouTube channel handle extracted from the URL.

- [ ] **Step 1: Write the failing tests**

Create `config/zsh/spec/media_helpers_spec.sh`:

```sh
Describe 'media helpers'
  Include config/zsh/lib/media-helpers.zsh

  Describe '_crop_x'
    Parameters
      left   '0'
      center '(iw-ow)/2'
      right  'iw-ow'
      25     '(iw-ow)*25/100'
    End
    It "resolves $1"
      When call _crop_x "$1"
      The output should eq "$2"
      The status should be success
    End
    It 'rejects invalid position'
      When call _crop_x sideways
      The status should be failure
    End
  End

  Describe '_sticker_bitrate'
    It 'rounds (kb*8*0.95)/duration'
      When call _sticker_bitrate 256 3
      The output should eq '649'
    End
  End

  Describe '_duration_min'
    It 'returns the smaller value'
      When call _duration_min 5 3
      The output should eq '3'
    End
    It 'returns the input when below the cap'
      When call _duration_min 1.5 3
      The output should eq '1.5'
    End
  End

  Describe '_channel_name'
    It 'extracts the handle'
      When call _channel_name 'https://www.youtube.com/@somechannel/videos'
      The output should eq 'somechannel'
    End
  End
End
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `shellspec config/zsh/spec/media_helpers_spec.sh`
Expected: FAIL — Include target missing.

- [ ] **Step 3: Write the implementation**

Create `config/zsh/lib/media-helpers.zsh`:

```zsh
# _crop_x <pos> — ffmpeg crop-x expression for left/center/right/0-100.
_crop_x() {
  case "$1" in
    left)  print -r -- '0' ;;
    center) print -r -- '(iw-ow)/2' ;;
    right) print -r -- 'iw-ow' ;;
    *)
      if [[ "$1" =~ '^[0-9]+$' ]] && (( $1 >= 0 && $1 <= 100 )); then
        print -r -- "(iw-ow)*$1/100"
      else
        return 1
      fi ;;
  esac
}

# _sticker_bitrate <max_kb> <duration> — target kbit/s, rounded.
_sticker_bitrate() {
  print -r -- "$1 $2" | awk '{printf "%.0f", ($1 * 8 * 0.95) / $2}'
}

# _duration_min <a> <b> — numeric minimum.
_duration_min() {
  print -r -- "$1 $2" | awk '{print ($1 < $2) ? $1 : $2}'
}

# _channel_name <url> — extract the @handle from a YouTube URL.
_channel_name() {
  print -r -- "$1" | sed -E 's|.*/@@?([^/]+).*|\1|'
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `shellspec config/zsh/spec/media_helpers_spec.sh`
Expected: all examples pass (note: `_sticker_bitrate 256 3` = round(648.53) = 649).

- [ ] **Step 5: Commit**

```bash
git add config/zsh/lib/media-helpers.zsh config/zsh/spec/media_helpers_spec.sh
git commit -m "Extract pure media helpers with unit tests" \
  -m "Pulls crop-x resolution, sticker bitrate math, duration min, and channel-name extraction out of the media functions so the arithmetic and parsing are testable without ffmpeg or yt-dlp."
```

---

### Task 7: Migrate navigation functions

**Files:**
- Create: `config/zsh/functions/nav.zsh`
- Modify: `zshrc` (remove `v` at `114-120`, `notes` at `123-125`, `pva` at `128-142`)

**Interfaces:**
- Produces: `v`, `notes`, `pva` defined via the sourcing loop.

- [ ] **Step 1: Create the module**

Create `config/zsh/functions/nav.zsh` by moving the three functions verbatim from `zshrc` (including the `unalias v 2>/dev/null || true` line that precedes `v`):

```zsh
# Smart nvim launcher
unalias v 2>/dev/null || true
v() {
  if [[ $# -eq 0 ]]; then
    nvim .
  else
    nvim "$@"
  fi
}

# Open Obsidian vault in nvim
notes() {
  cd ~/Documents/obsidian/nostromo && nvim .
}

# Python virtual environment activation
pva() {
  local venv_paths=("venv" ".venv" "env" ".env")
  for venv_path in "${venv_paths[@]}"; do
    if [[ -f "${venv_path}/bin/activate" ]]; then
      source "${venv_path}/bin/activate"
      echo "✅ Activated: ${venv_path}"
      return 0
    fi
  done
  echo "🚫 No virtual environment found"
  echo "💡 Checked: ${venv_paths[*]}"
  return 1
}
```

Note: `notes`/`pva` mutate the parent shell (`cd`, `source`) — they stay plain functions and get **no** `setopt err_return`.

- [ ] **Step 2: Remove the originals from zshrc**

Delete lines `zshrc:112-142` (the `# Smart nvim launcher` block through the end of `pva`).

- [ ] **Step 3: Verify**

Run: `zsh -i -c 'whence -w v notes pva'`
Expected: each prints `<name>: function`.
Run: `cd /tmp && zsh -i -c 'v --version >/dev/null && echo v-ok'`
Expected: `v-ok` (v forwards to nvim).

- [ ] **Step 4: Commit**

```bash
git add config/zsh/functions/nav.zsh zshrc
git commit -m "Move navigation functions into config/zsh/functions/nav.zsh" \
  -m "Relocates v, notes, and pva out of the zshrc monolith; they stay plain functions because they mutate the parent shell."
```

---

### Task 8: Migrate file utilities

**Files:**
- Create: `config/zsh/functions/files.zsh`
- Create: `config/zsh/spec/functions_spec.sh`
- Modify: `zshrc` (remove `mkcd` at `145-147`, `prefix_dirname` at `150-198`, `unlockdir` at `201-221`, `cleanmusic` at `224-273`)

**Interfaces:**
- Consumes: `_confirm` (Task 3), `_preview` (Task 5).
- Produces: `mkcd`, `prefix_dirname`, `cleanmusic`, `unlockdir`.

- [ ] **Step 1: Write the failing test (confirm-decline is a no-op)**

Create `config/zsh/spec/functions_spec.sh`:

```sh
Describe 'file functions'
  Include config/zsh/lib/confirm.zsh
  Include config/zsh/lib/preview.zsh
  Include config/zsh/functions/files.zsh

  It 'cleanmusic deletes nothing when the user declines'
    setup() { cd "$SHELLSPEC_TMPBASE" && mkdir -p cm && cd cm && : > junk.log; }
    BeforeCall setup
    Data 'n'
    When call cleanmusic
    The output should include 'junk.log'
    The path "$SHELLSPEC_TMPBASE/cm/junk.log" should be exist
  End
End
```

- [ ] **Step 2: Run test to verify it fails**

Run: `shellspec config/zsh/spec/functions_spec.sh`
Expected: FAIL — `config/zsh/functions/files.zsh` Include missing.

- [ ] **Step 3: Create the module**

Create `config/zsh/functions/files.zsh`. Move `mkcd` verbatim, then move `prefix_dirname`, `unlockdir`, and `cleanmusic`, applying these exact edits:

- In `unlockdir`: add `setopt local_options no_unset pipe_fail` as the first line of the body (no `err_return` — it has an interactive `read`), and replace its inline prompt block:

  Replace:
  ```zsh
  echo -n "Continue? [y/N] "
  read -r response
  if [[ "$response" =~ ^[Yy]$ ]]; then
  ```
  with:
  ```zsh
  if _confirm "Continue?"; then
  ```

- In `prefix_dirname`: replace the "Preview first 3 files" loop plus its trailing "... and N more" line:

  Replace:
  ```zsh
  for file in "${files[@]:0:3}"; do
    local base="${file%.*}"
    local ext="${file##*.}"
    echo "   $file → ${dirname}_${base}.${ext}"
  done
  [[ ${#files[@]} -gt 3 ]] && echo "   ... and $((${#files[@]} - 3)) more"
  ```
  with:
  ```zsh
  local -a previews=()
  for file in "${files[@]}"; do
    previews+=("$file → ${dirname}_${file%.*}.${file##*.}")
  done
  _preview 3 "${previews[@]}"
  ```
  And replace its confirm block (`echo -n "Continue? [y/N] "` + `read` + `if [[ ! "$response" ... ]]`) with:
  ```zsh
  if ! _confirm "Continue?"; then
    echo "❌ Cancelled"
    return 0
  fi
  ```

- In `cleanmusic`: replace its preview loop:

  Replace:
  ```zsh
  echo "📝 Files to delete (${#files[@]} total):"
  for file in "${files[@]:0:10}"; do
    echo "   $file"
  done
  [[ ${#files[@]} -gt 10 ]] && echo "   ... and $((${#files[@]} - 10)) more"
  ```
  with:
  ```zsh
  echo "📝 Files to delete (${#files[@]} total):"
  _preview 10 "${files[@]}"
  ```
  And replace its confirm block with:
  ```zsh
  if ! _confirm "Delete all?"; then
    echo "❌ Cancelled"
    return 0
  fi
  ```

- [ ] **Step 4: Remove the originals from zshrc**

Delete lines `zshrc:144-273` (the `# Create and change directory` block through the end of `cleanmusic`).

- [ ] **Step 5: Run the test to verify it passes**

Run: `shellspec config/zsh/spec/functions_spec.sh`
Expected: PASS — declining leaves `junk.log` in place.

- [ ] **Step 6: Verify functions load and mkcd works**

Run: `zsh -i -c 'whence -w mkcd prefix_dirname cleanmusic unlockdir'`
Expected: each prints `<name>: function`.
Run: `cd "$(mktemp -d)" && zsh -ic 'mkcd sub && [[ $PWD == */sub ]] && echo mkcd-ok'`
Expected: `mkcd-ok`.

- [ ] **Step 7: Commit**

```bash
git add config/zsh/functions/files.zsh config/zsh/spec/functions_spec.sh zshrc
git commit -m "Move file utilities into config/zsh and dedupe prompts" \
  -m "Relocates mkcd, prefix_dirname, unlockdir, and cleanmusic; routes their prompts through _confirm and their previews through _preview, and adds a shellspec check that declining cleanmusic deletes nothing."
```

---

### Task 9: Migrate download functions

**Files:**
- Create: `config/zsh/functions/media.zsh` (downloaders portion)
- Modify: `zshrc` (remove `ydl` at `280-309`, `dl_with_referer`/`skvotdl` at `312-326`, `ytmp3` at `593-684`)

**Interfaces:**
- Consumes: `_parse_auth` (Task 4), `_channel_name` (Task 6).
- Produces: `ydl`, `dlref`, `skvotdl`, `ytmp3`.

- [ ] **Step 1: Add validation tests**

Append to `config/zsh/spec/functions_spec.sh`:

```sh
Describe 'download functions'
  Include config/zsh/lib/auth-args.zsh
  Include config/zsh/lib/media-helpers.zsh
  Include config/zsh/functions/media.zsh

  It 'dlref errors without a url'
    When call dlref
    The status should be failure
    The output should include 'Usage'
  End

  It 'ytmp3 errors without a url'
    When call ytmp3
    The status should be failure
    The output should include 'Usage'
  End
End
```

- [ ] **Step 2: Run to verify it fails**

Run: `shellspec config/zsh/spec/functions_spec.sh`
Expected: FAIL — media.zsh Include missing.

- [ ] **Step 3: Create the downloaders in media.zsh**

Create `config/zsh/functions/media.zsh` starting with a banner and the downloaders. Move `ydl` verbatim. Rename `dl_with_referer` → `dlref` and replace `skvotdl` to call it:

```zsh
# Download with a custom referer
dlref() {
  local url="$1" referer="${2:-https://lms.skvot.io/}"
  if [[ -z "$url" ]]; then
    echo "Usage: dlref <url> [referer]"
    return 1
  fi
  yt-dlp "$url" --referer "$referer"
}

skvotdl() { dlref "$1" "https://lms.skvot.io/"; }
```

Move `ytmp3` with these exact edits:
- Add `setopt local_options pipe_fail` as the first body line (no `no_unset` — its `while [[ "$1" == -* ]]` option loop reads a bare `$1`; no `err_return` — the option loop and `read` need explicit control).
- Replace its channel-name extraction:
  ```zsh
  local dirname
  dirname=$(echo "$url" | sed -E 's|.*/@@?([^/]+).*|\1|')
  ```
  with:
  ```zsh
  local dirname
  dirname=$(_channel_name "$url")
  ```
- Replace its auth `case` block:
  ```zsh
  local auth_args=()
  case "$auth_method" in
    browser) auth_args=(--cookies-from-browser "$browser") ;;
    oauth)   auth_args=(--username oauth --password '') ;;
    file)    auth_args=(--cookies "$cookies_file") ;;
  esac
  ```
  with:
  ```zsh
  local -a auth_args=()
  _parse_auth "$auth_method" "$browser" "$cookies_file"
  ```

- [ ] **Step 4: Remove the originals from zshrc**

Delete `zshrc:279-326` (the `# Download Functions` banner through `skvotdl`) and `zshrc:592-684` (the `# Download YouTube channel as MP3` block through the end of `ytmp3`). Keep the file's remaining structure intact.

- [ ] **Step 5: Run tests to verify they pass**

Run: `shellspec config/zsh/spec/functions_spec.sh`
Expected: all examples pass.

- [ ] **Step 6: Verify functions load**

Run: `zsh -i -c 'whence -w ydl dlref skvotdl ytmp3'`
Expected: each prints `<name>: function`.

- [ ] **Step 7: Commit**

```bash
git add config/zsh/functions/media.zsh config/zsh/spec/functions_spec.sh zshrc
git commit -m "Move download functions into config/zsh/functions/media.zsh" \
  -m "Relocates ydl and ytmp3, renames dl_with_referer to dlref with skvotdl as a thin wrapper, and routes auth and channel-name parsing through the shared helpers."
```

---

### Task 10: Migrate video-cutting functions

**Files:**
- Modify: `config/zsh/functions/media.zsh` (append cutters)
- Modify: `zshrc` (remove `vidcut` at `329-412`, `storycut` at `415-516`, `makesticker` at `519-590`)
- Modify: `config/zsh/spec/functions_spec.sh` (add validation tests)

**Interfaces:**
- Consumes: `_parse_auth` (Task 4), `_crop_x`, `_sticker_bitrate`, `_duration_min` (Task 6).
- Produces: `vidcut`, `storycut`, `makesticker`.

- [ ] **Step 1: Add validation tests**

Append to `config/zsh/spec/functions_spec.sh`:

```sh
Describe 'cutting functions'
  Include config/zsh/lib/auth-args.zsh
  Include config/zsh/lib/media-helpers.zsh
  Include config/zsh/functions/media.zsh

  It 'vidcut errors when required args are missing'
    When call vidcut -u https://example.com/x
    The status should be failure
    The error should include 'Required arguments missing'
  End

  It 'vidcut -h prints usage and succeeds'
    When call vidcut -h
    The status should be success
    The output should include 'Usage: vidcut'
  End

  It 'storycut errors when required args are missing'
    When call storycut -u https://example.com/x
    The status should be failure
    The error should include 'Required arguments missing'
  End
End
```

Note: the current functions print the "missing args" message with `echo` (stdout). If `The error should include` fails, change the assertion to `The output should include` — do not change the function's output stream as part of this task.

- [ ] **Step 2: Run to verify it fails**

Run: `shellspec config/zsh/spec/functions_spec.sh`
Expected: FAIL — `vidcut`/`storycut` not defined in media.zsh yet.

- [ ] **Step 3: Append the cutters to media.zsh**

Move `vidcut`, `storycut`, `makesticker` into `config/zsh/functions/media.zsh`, applying:

- All three: add `setopt local_options pipe_fail` as the first body line. Do **not** add `no_unset` — `makesticker` starts with `local input="$1"` and `vidcut`/`storycut` reference `$2` in their option loops, all of which `no_unset` would abort before the `Usage`/validation messages. Do **not** add `err_return` — each parses options in a `while` loop and `makesticker` inspects `$?` after each ffmpeg pass explicitly.
- `vidcut` and `storycut`: replace the auth `case` block:
  ```zsh
  local -a auth_args=()
  case "$auth_method" in
    browser) auth_args=(--cookies-from-browser "$browser") ;;
    file)    auth_args=(--cookies "$cookies_file") ;;
  esac
  ```
  with:
  ```zsh
  local -a auth_args=()
  _parse_auth "$auth_method" "$browser" "$cookies_file"
  ```
- `storycut`: replace the non-blur crop-x `case` block:
  ```zsh
  local crop_x
  case "$crop_pos" in
    left) crop_x="0" ;;
    center) crop_x="(iw-ow)/2" ;;
    right) crop_x="iw-ow" ;;
    *)
      if [[ "$crop_pos" =~ ^[0-9]+$ ]] && (( crop_pos >= 0 && crop_pos <= 100 )); then
        crop_x="(iw-ow)*${crop_pos}/100"
      else
        echo "❌ Invalid crop position: $crop_pos (use left, center, right, blur, or 0-100)"
        return 1
      fi ;;
  esac
  vf="crop=ih*9/16:ih:${crop_x}:0,scale=1080:1920"
  ```
  with:
  ```zsh
  local crop_x
  if ! crop_x=$(_crop_x "$crop_pos"); then
    echo "❌ Invalid crop position: $crop_pos (use left, center, right, blur, or 0-100)"
    return 1
  fi
  vf="crop=ih*9/16:ih:${crop_x}:0,scale=1080:1920"
  ```
- `makesticker`: replace the duration and bitrate computations:
  ```zsh
  local duration
  duration=$(echo "$input_duration $max_duration" | awk '{print ($1 < $2) ? $1 : $2}')
  local bitrate
  bitrate=$(echo "$max_size_kb $duration" | awk '{printf "%.0f", ($1 * 8 * 0.95) / $2}')
  ```
  with:
  ```zsh
  local duration
  duration=$(_duration_min "$input_duration" "$max_duration")
  local bitrate
  bitrate=$(_sticker_bitrate "$max_size_kb" "$duration")
  ```

- [ ] **Step 4: Remove the originals from zshrc**

Delete `zshrc:328-590` (the `# Video/Audio cutter` block through the end of `makesticker`).

- [ ] **Step 5: Run tests to verify they pass**

Run: `shellspec config/zsh/spec/functions_spec.sh`
Expected: all examples pass.

- [ ] **Step 6: Verify functions load**

Run: `zsh -i -c 'whence -w vidcut storycut makesticker'`
Expected: each prints `<name>: function`.

- [ ] **Step 7: Commit**

```bash
git add config/zsh/functions/media.zsh config/zsh/spec/functions_spec.sh zshrc
git commit -m "Move video-cutting functions into config/zsh and share logic" \
  -m "Relocates vidcut, storycut, and makesticker; wires them to _parse_auth, _crop_x, _duration_min, and _sticker_bitrate, and hardens them with local setopt safety."
```

---

### Task 11: Final zshrc trim, docs, full verification

**Files:**
- Modify: `zshrc` (confirm only aliases/completions/init/sourcing-loop remain in the functions area)
- Modify: `README.md` (document `config/zsh` layout and running tests)

**Interfaces:**
- Consumes: everything above.
- Produces: a clean `zshrc` and a documented, fully green test suite.

- [ ] **Step 1: Confirm no orphaned function definitions remain in zshrc**

Run: `grep -nE '^[a-zA-Z_]+\(\)' zshrc`
Expected: no matches for the migrated names (`v`, `notes`, `pva`, `mkcd`, `prefix_dirname`, `cleanmusic`, `unlockdir`, `ydl`, `dlref`, `skvotdl`, `ytmp3`, `vidcut`, `storycut`, `makesticker`). Only `_uv_run_mod` (completion) may remain.

- [ ] **Step 2: Run the full suite**

Run: `shellspec`
Expected: all specs across `config/zsh/spec/` pass, 0 failures.

- [ ] **Step 3: Full interactive-shell smoke test**

Run: `zsh -i -c 'whence -w v notes pva mkcd prefix_dirname cleanmusic unlockdir ydl dlref skvotdl ytmp3 vidcut storycut makesticker | grep -v function || echo all-functions-ok'`
Expected: `all-functions-ok` (every name resolves to a function).

- [ ] **Step 4: Document the layout in README**

Add a short subsection to `README.md` describing: functions live in `config/zsh/functions/`, shared helpers in `config/zsh/lib/`, tests in `config/zsh/spec/`, run with `shellspec`. (If editing README prose, invoke the `humanizer` skill per global instructions before committing.)

- [ ] **Step 5: Commit**

```bash
git add zshrc README.md
git commit -m "Trim zshrc to config and document config/zsh layout" \
  -m "zshrc now holds only aliases, completions, init, and the sourcing loop; README explains where functions and their tests live."
```

---

## Self-Review

**Spec coverage:**
- Deduplication (`_confirm`, `_parse_auth`, preview) → Tasks 3, 4, 5, applied in 8/9/10. ✓
- Silent-failure hardening (`setopt` per function) → applied in Tasks 8/9/10 with the interactive-`read` exception honored. ✓
- Monolith split into `lib/`+`functions/` modules → Tasks 2, 7–11. ✓
- Sourcing without symlink/build → Task 2. ✓
- Pure helpers + shellspec → Tasks 1, 6, plus validation tests in 8/9/10. ✓
- Non-goals (no speed work, no rewrite) → respected; all functions stay shell. ✓
- `_collect_files` narrowed to `_preview` → documented in Task 5 interface and the insight above. ✓
- Brewfile `shellspec` + deployment → Task 1. ✓
- Risk: `err_return` vs `read` → honored (no `err_return` on interactive functions). ✓
- Risk: `_parse_auth` spaced paths → covered by a dedicated test in Task 4. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full content; migration edits show exact before/after snippets. ✓

**Type consistency:** `auth_args` array name is consistent across `_parse_auth` and all three consumers; `_crop_x`/`_sticker_bitrate`/`_duration_min`/`_channel_name` signatures match their call sites; `_preview <max> <item>...` matches usage in Tasks 8. ✓
