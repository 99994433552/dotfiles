# Scripts Reference

Comprehensive documentation for all utility scripts in the dotfiles repository. These scripts help manage your development environment, packages, and tmux sessions.

---

## Profile Management

### dotfiles-profile

Manage which dotfiles profile is active on the current machine. Profiles determine which Homebrew packages get installed (local development vs server).

**Location:** `~/.dotfiles/bin/dotfiles-profile`

**Usage:**
```bash
dotfiles-profile [command]
```

**Commands:**
- `show` - Display current profile (default if no command given)
- `set <profile>` - Set profile to 'local' or 'server'
- `help` - Show help message

**Available Profiles:**
- `local` - Primary development machine with GUI apps
- `server` - Mac Mini server with minimal GUI and server-specific tools

**Examples:**
```bash
# Check current profile
dotfiles-profile
dotfiles-profile show

# Switch to server profile
dotfiles-profile set server

# Switch to local profile
dotfiles-profile set local
```

**Profile File:** `~/.dotfiles-profile`

**Notes:**
- After changing profile, run `./install` or `setup_homebrew.zsh` to apply changes
- Profile setting persists across terminal sessions
- Defaults to 'local' if no profile is set

---

## Package Management

### brew-diff

Compare Homebrew packages between different profiles to see what's unique to each configuration.

**Location:** `~/.dotfiles/bin/brew-diff`

**Usage:**
```bash
brew-diff [profile1] [profile2]
```

**Arguments:**
- `profile1` - First profile to compare (default: local)
- `profile2` - Second profile to compare (default: server)

**Available Profiles:**
- `base` - Common packages for all machines
- `local` - Local development machine packages
- `server` - Mac Mini server packages

**Examples:**
```bash
# Compare local vs server (default)
brew-diff

# Compare base vs local additions
brew-diff base local

# Compare server vs base
brew-diff server base
```

**Output:**
- Common packages (shared between both profiles)
- Packages unique to first profile
- Packages unique to second profile
- Count of packages in each category

**Notes:**
- Compares packages from `profiles/*.Brewfile` files
- Ignores comments and empty lines
- Extracts both brew and cask packages
- Base profile is shared by all machines

---

### Package Cleanup

Remove packages not defined in your Brewfile. This is handled automatically during `setup_homebrew.zsh` which shows extra packages and asks if you want to remove them.

**Manual Usage:**
```bash
# Preview what would be removed (dry-run)
brew bundle cleanup

# Remove extra packages
brew bundle cleanup --force
```

**How It Works:**
1. Compares installed packages with Brewfile (base + profile)
2. Shows packages not in Brewfile
3. During setup: asks interactively whether to remove
4. Removes both brew formulas and cask applications

**Notes:**
- Works with both brew formulas and cask packages
- Brewfile is generated from `profiles/base.Brewfile` + `profiles/{profile}.Brewfile`
- Safe to run `brew bundle cleanup` (without --force) anytime to preview

---

## Maintenance Scripts

### update-all.sh

Comprehensive update script that updates all tools and configurations in your development environment.

**Location:** `~/.dotfiles/scripts/update-all.sh`

**Usage:**
```bash
# Update everything
update-all.sh

# Update specific component
update-all.sh [component]
```

**Components:**
- `homebrew` or `brew` - Update Homebrew and packages
- `neovim` or `nvim` - Update Neovim plugins and LSP servers
- `dotfiles` - Pull latest dotfiles from git
- `rust` - Update Rust toolchain and cargo tools
- `npm` - Update npm and global packages
- `cleanup` - Clean caches and temporary files
- `health` or `check` - Run health check

**What Gets Updated:**
- Homebrew packages and casks
- Neovim plugins (Lazy.nvim sync)
- Treesitter parsers
- Mason LSP servers
- Dotfiles repository (git pull)
- Rust toolchain and tools (eza, bat, ripgrep, fd-find, starship)
- npm global packages
- System cleanup (caches, completions)

**Examples:**
```bash
# Update everything (recommended weekly)
update-all.sh

# Just update Homebrew
update-all.sh homebrew

# Just update Neovim plugins
update-all.sh neovim
```

**Process Flow:**
1. Update Homebrew (update, upgrade, bundle, cleanup)
2. Update Neovim plugins and language servers
3. Pull latest dotfiles from git and run dotbot
4. Update Rust toolchain and tools
5. Update npm global packages
6. Clean system caches and temporary files
7. Run health check
8. Display summary

**Notes:**
- Continues even if individual components fail
- Shows colored output for status (success/warning/error)
- Automatically cleans up after updates
- Recommends restarting terminal after completion
- Safe to run regularly

---

### backup.sh

Create comprehensive backups of your dotfiles configuration, including the repository, symlinks state, and config directories.

**Location:** `~/.dotfiles/scripts/backup.sh`

**Usage:**
```bash
backup.sh [command] [options]
```

**Commands:**
- `backup` or `create` - Create new backup (default)
- `list` - List all available backups
- `restore TIMESTAMP` - Restore from specific backup
- `cleanup [DAYS]` - Remove backups older than DAYS (default: 7)

**Examples:**
```bash
# Create a backup
backup.sh
backup.sh backup

# List available backups
backup.sh list

# Restore from specific backup
backup.sh restore 20241201_143022

# Clean up backups older than 14 days
backup.sh cleanup 14
```

**What Gets Backed Up:**
1. **Dotfiles Repository** - Complete copy of ~/.dotfiles
2. **Symlinks State** - Current state of dotfile symlinks:
   - .zshrc, .zshenv, .gitconfig, .gitmessage
   - .gitignore_global, .vimrc, .psqlrc
3. **Config Directories** - State of config directory symlinks:
   - nvim, kitty, yazi, aerospace, tmux, bat
4. **Manifest File** - Backup metadata and system information

**Backup Location:** `~/.dotfiles-backups/YYYYMMDD_HHMMSS/`

**Manifest Contents:**
- Backup creation date and location
- System information (hostname, user, OS, shell)
- Git status and last commit
- File types explanation (.link files, .backup files)
- Restoration instructions

**Automatic Cleanup:**
- Automatically removes backups older than 7 days
- Keeps backup directory clean
- Customizable retention period

**Restore Process:**
1. Creates backup of current state before restoring
2. Removes current dotfiles directory
3. Copies backup to ~/.dotfiles
4. Runs dotbot to recreate symlinks

**Notes:**
- Safe to run frequently
- Includes git status in manifest
- Color-coded output for clarity
- Interactive confirmation for restore operations

---

### health-check.sh

Comprehensive diagnostics to verify your dotfiles setup is working correctly. Checks symlinks, configuration syntax, git setup, and essential tools.

**Location:** `~/.dotfiles/scripts/health-check.sh`

**Usage:**
```bash
health-check.sh
```

**What It Checks:**

**Symlink Health:**
- Common dotfiles (.zshrc, .gitconfig, etc.)
- Config directories (nvim, kitty, yazi, bat)
- Specific config files (tmux.conf, musikcube/hotkeys.json)
- Identifies broken symlinks
- Warns about non-symlinked files

**Shell Syntax:**
- Main zshrc file
- All zsh modules in config/zsh/
- All shell scripts in scripts/

**Git Configuration:**
- user.name and user.email settings
- Global gitignore configuration
- Gitignore file existence

**Homebrew Setup:**
- Homebrew installation
- Outdated packages count
- Brewfile existence

**Neovim Configuration:**
- Neovim installation
- Configuration loading (headless check)

**Essential Tools:**
- git, zsh, starship, eza, bat, nvim

**Exit Codes:**
- `0` - All checks passed or only warnings
- `1` - Critical issues found

**Output Summary:**
- Count of successful checks
- Count of warnings
- Count of critical issues
- Overall health status

**Examples:**
```bash
# Run health check
health-check.sh

# Run as part of update process
update-all.sh  # Includes health check at the end
```

**Notes:**
- Color-coded output (green = success, yellow = warning, red = error)
- Safe to run anytime
- No modifications to system
- Helpful for troubleshooting dotfiles issues
- Automatically runs after update-all.sh

---

## Claude Code

### claude-statusline.sh

Renders the status line at the bottom of a Claude Code session.

**Location:** `~/.dotfiles/scripts/claude-statusline.sh`
**Symlinked to:** `~/.claude/statusline-command.sh` (wired up in `install.conf.yaml`)
**Configured by:** the `statusLine` key in `.claude/settings.json`

**Output:**

```
 ~/.dotfiles   main ●   auto  ▐██░░░░░░░░ 168k/1M  5h 31% (2h) · 7d 59% (3d)   Opus 5 · high
```

Directory, git branch with a `●` when the tree is dirty, permission mode, how
full the context window is, the two plan rate limits, then the model and its
effort level. Every percentage turns yellow past 50% and red past 75%.

`5h` is the rolling session limit and `7d` the weekly one — Claude Code has no
daily limit. The parenthetical is the time left until that window resets,
rounded down to one unit, so `2h` means at least two hours remain.

The context window sits ahead of the model on purpose. A single-line status line
is truncated from the right, and the model is the part worth losing first.

**How it gets its data:**

Claude Code pipes a JSON snapshot of the session on stdin on every change,
debounced to roughly 300ms. Everything shown comes out of that payload in one
`jq` pass: `context_window`, `permission_mode`, `model.display_name`,
`effort.level`, `rate_limits` and the workspace directory. Nothing reads the
transcript file, and nothing reads the stale `cachedUsageUtilization` block in
`~/.claude.json`.

`context_window.used_percentage` drives the bar, and
`context_window.total_input_tokens` over `context_window.context_window_size`
gives the numbers. Claude Code computes the percentage as
`round(total_input_tokens / context_window_size * 100)`, so the bar and the
numbers cannot disagree.

Two field names in that payload are misleading. `total_input_tokens` is not a
session total: it is the last message's `input_tokens + cache_creation +
cache_read`, which is exactly what currently occupies the window. `total_output_tokens`
is likewise just the last response. A cumulative figure for the session exists
only in the transcript file, which this script does not read.

`rate_limits.five_hour` and `rate_limits.seven_day` each carry a
`used_percentage` and a `resets_at` timestamp. Claude Code only puts the key in
the payload when one of the two is present, so the segment disappears on an API
key, Bedrock or Vertex session, where plan limits do not apply.

`resets_at` is a Unix epoch in the payloads this was checked against (Claude
Code 2.1.236). The jq pass also accepts an ISO 8601 string, so a build that
spells it `2026-08-27T15:00:00.902275+00:00` keeps working — a form neither
`fromdateiso8601` nor BSD `date` will parse, so the pass strips the fractional
seconds and folds the offset back in by hand. Either way the render stays a
single `jq` call. An unparseable timestamp collapses to "no reset time known"
and drops the parenthetical rather than shifting the fields that follow it.

Sections disappear when the session does not report them. `effort` only appears
on models that support it, and the git segment is skipped outside a repository.

**Requirements:**
- `jq`
- A Nerd Font in the terminal. Without one the icons render as boxes; the text
  stays readable.
- Set `NO_COLOR` to drop the ANSI escapes.

**Tests:**
```bash
shellspec --shell bash --default-path scripts/spec --helperdir scripts/spec
```

**Notes:**
- Targets bash 3.2, the `/bin/bash` that macOS ships and the interpreter named
  in `settings.json`.
- Nerd Font icons are written as UTF-8 byte escapes (`$'\xee\x82\xa0'`). Their
  Private Use Area codepoints do not survive every editor and transport, and
  bash 3.2 has no `$'\uXXXX'`.
- The `jq` fields are joined on U+001F, not a tab. `read` collapses runs of
  whitespace delimiters and drops leading ones, so a tab-separated line shifts
  every value left as soon as one field comes back empty.

---

## Tmux Scripts

### Session Management

#### tmux-session-selector.sh

Interactive session switcher using fzf with vim-style navigation.

**Location:** `~/.dotfiles/scripts/tmux-session-selector.sh`

**Usage:**
```bash
# From within tmux
tmux-session-selector.sh

# Or via keybinding (Ctrl+s s)
```

**Features:**
- Shows all sessions except current one
- Displays window count for each session
- Vim-style navigation (j/k to move, Enter to select)
- ESC to cancel
- Excludes current session from list

**Keybindings:**
- `j` - Move down
- `k` - Move up
- `Enter` - Switch to selected session
- `ESC` - Cancel

**Requirements:**
- fzf must be installed
- Must be run from within tmux

**Notes:**
- Sessions shown with format: "session_name (N windows)"
- Color scheme optimized for readability
- No confirmation needed - instant switch

---

#### tmux-session-create.sh

Create new tmux session with interactive name input via fzf.

**Location:** `~/.dotfiles/scripts/tmux-session-create.sh`

**Usage:**
```bash
# From within tmux
tmux-session-create.sh

# Or via keybinding (Ctrl+s Ctrl+c)
```

**Features:**
- Interactive name input with fzf prompt
- Creates session in detached mode
- Automatically switches to new session
- ESC to cancel creation

**Workflow:**
1. Prompt appears: "New session name:"
2. Type desired session name
3. Press Enter to create
4. Automatically switches to new session

**Requirements:**
- fzf must be installed
- Must be run from within tmux

**Notes:**
- Session created in background first
- Name required to create session
- Shows success message after creation

---

#### tmux-session-delete.sh

Interactive session deletion with fzf and confirmation prompts.

**Location:** `~/.dotfiles/scripts/tmux-session-delete.sh`

**Usage:**
```bash
# From within tmux
tmux-session-delete.sh

# Or via keybinding (Ctrl+s Ctrl+x)
```

**Features:**
- Shows all sessions with window counts
- Red color theme to indicate destructive action
- Vim-style navigation
- Confirmation before deletion
- Error handling if deletion fails

**Keybindings:**
- `j` - Move down
- `k` - Move up
- `Enter` - Delete selected session
- `ESC` - Cancel

**Safety Features:**
- Visual warning via red color scheme
- Clear header: "Delete session (Esc to cancel)"
- Shows success/error message after deletion

**Requirements:**
- fzf must be installed
- Must be run from within tmux

**Notes:**
- Cannot delete current session (use switch first)
- Shows error if session cannot be deleted
- Red color indicates destructive operation

---

### Window Management

#### tmux-window-create.sh

Create new window with optional custom name, opens in current pane's directory.

**Location:** `~/.dotfiles/scripts/tmux-window-create.sh`

**Usage:**
```bash
# From within tmux
tmux-window-create.sh

# Or via keybinding (Ctrl+s c)
```

**Features:**
- Interactive name input with fzf
- Opens in current pane's directory
- Press Enter for default name
- ESC to cancel creation
- Captures fzf exit codes correctly

**Workflow:**
1. Prompt: "New window name:"
2. Options:
   - Type name + Enter = Custom named window
   - Just Enter = Default automatic name
   - ESC = Cancel without creating

**Requirements:**
- fzf must be installed
- Must be run from within tmux

**Notes:**
- Inherits current pane's working directory
- Default window naming follows tmux conventions
- Shows success message after creation

---

### Utilities

#### tmux-url-picker.sh

Extract and open URLs from tmux pane content with smart context display.

**Location:** `~/.dotfiles/scripts/tmux-url-picker.sh`

**Usage:**
```bash
# From within tmux
tmux-url-picker.sh

# Or via keybinding (Ctrl+s u)
```

**Features:**
- Scans last 1000 lines of pane history (for performance)
- Extracts both markdown links and plain URLs
- Shows context around URLs for easy identification
- Deduplicates URLs
- Opens selected URL in default browser
- Smart context extraction (before/after text or domain name)

**URL Detection:**
- Markdown links: `[text](url)` or `[text](<url>)`
- Plain URLs: `https://...` or `http://...`
- Skips lines that already have markdown links

**Display Format:**
```
context │ url
```

**Keybindings:**
- `j` - Move down
- `k` - Move up
- `Enter` - Open selected URL
- `ESC` - Cancel

**Browser Support:**
- macOS: Uses `open` command
- Linux: Uses `xdg-open` command

**Performance:**
- Only scans last 1000 lines (much faster than full history)
- Deduplicates URLs before display
- Shows loading indicator during scan

**Examples:**
```
# Markdown link
Documentation │ https://github.com/user/repo

# Plain URL with context
See issue at │ https://github.com/user/repo/issues/123

# URL with domain as context
github.com │ https://github.com/user/repo
```

**Requirements:**
- fzf must be installed
- Must be run from within tmux
- Browser opener (open/xdg-open) must be available

**Notes:**
- Shows count of URLs found
- Displays truncated URL in success message
- Empty result if no URLs found in last 1000 lines
- Context limited to 35-40 characters for compact display

---

#### setup-tmux-plugins.sh

Install and update Tmux Plugin Manager (TPM) and all configured plugins.

**Location:** `~/.dotfiles/scripts/setup-tmux-plugins.sh`

**Usage:**
```bash
setup-tmux-plugins.sh
```

**What It Does:**
1. Creates required plugin directories
2. Installs TPM if not present
3. Updates TPM to latest version
4. Installs/updates all configured plugins
5. Verifies plugin installation
6. Shows status for each plugin

**Plugin Directories:**
- TPM: `~/.tmux/plugins/tpm`
- Plugins: `~/.tmux/plugins/`
- Resurrect saves: `~/.config/tmux/resurrect`

**Configured Plugins:**
- **tmux-resurrect** - Session persistence (manual save/restore)
- **tmux-continuum** - Automatic session saving every 15 minutes
- **vim-tmux-navigator** - Seamless Vim/Tmux pane navigation
- **minimal-tmux-status** - Minimal status bar theme

**Smart Execution:**
- If tmux is running: Uses TPM directly
- If tmux not running: Starts headless session for installation

**Session Management Keybindings:**
- `Ctrl+s Ctrl+s` - Save current session manually
- `Ctrl+s Ctrl+r` - Restore last saved session manually
- Auto-save runs every 15 minutes
- Auto-restore on tmux start

**Output:**
- Installation progress for TPM
- Plugin update status
- Verification checklist for all plugins
- Key bindings reminder

**Examples:**
```bash
# Run during initial setup
setup-tmux-plugins.sh

# Re-run after adding plugins to tmux.conf
setup-tmux-plugins.sh
```

**Notes:**
- Safe to run multiple times
- Automatically updates existing installations
- Works even when tmux is not running
- Run `Ctrl+s r` to reload tmux config after plugin changes
- Session saves stored in `~/.config/tmux/resurrect`

---

## Script Organization

**bin/** - User-facing commands (in PATH):
- Profile and package management tools
- Intended for regular interactive use

**scripts/** - System automation and maintenance:
- Backup, update, and health check utilities
- Tmux integration scripts
- Run automatically or via keybindings

## Common Patterns

**Error Handling:**
- All scripts check for required dependencies (fzf, brew, etc.)
- Color-coded output for visibility
- Meaningful error messages

**Safety:**
- Dry-run options for destructive operations
- Confirmation prompts for dangerous actions
- Automatic backups before major changes

**Usability:**
- Consistent command-line interface
- Help text available (--help, help command)
- Example usage in help output
- Color-coded status messages

**Integration:**
- Scripts work together (update-all.sh calls health-check.sh)
- Tmux keybindings mapped to scripts
- Consistent paths and conventions

## Tips

**Regular Maintenance:**
```bash
# Weekly: Update everything
update-all.sh

# Monthly: Create backup before major changes
backup.sh

# After updates: Verify health
health-check.sh
```

**Profile Management:**
```bash
# Before setting up new machine
dotfiles-profile set server
./install

# Compare profiles
brew-diff base server
```

**Tmux Workflow:**
```bash
# Session management
Ctrl+s s      # Switch sessions
Ctrl+s Ctrl+c # Create session
Ctrl+s Ctrl+x # Delete session

# Window management
Ctrl+s c      # Create window

# Utilities
Ctrl+s u      # Pick and open URL
```

**Troubleshooting:**
```bash
# Verify dotfiles setup
health-check.sh

# Restore from backup if needed
backup.sh list
backup.sh restore 20241201_143022

# Re-setup tmux plugins
setup-tmux-plugins.sh
```
