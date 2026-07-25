# Dotfiles

macOS dotfiles managed with [dotbot](https://github.com/anishathalye/dotbot). Two machine profiles: `local` (desktop/laptop) and `server` (Mac Mini).

## Set up a new machine

```bash
git clone <repo-url> ~/.dotfiles
cd ~/.dotfiles
echo local > ~/.dotfiles-profile   # or: echo server
./install
```

`./install` installs Homebrew if it is missing, installs the profile's packages, symlinks the configs, and sets up Nerd Fonts and agent skills. To preview the actions without changing anything:

```bash
./install --dry-run
```

### Firefox profile

`./install` installs Firefox but leaves its profile alone. Launch Firefox once so a profile exists, then link the tracked config:

```bash
./setup_firefox.zsh                # pick a profile, links user.js + chrome/
```

The repo tracks config only: settings (`user.js`), UI styling (`chrome/userChrome.css`), and container and handler definitions. Profile data stays out of git. Bookmarks, history, saved logins, cookies, and extensions never get committed, so bring them over with a Firefox account and Sync.

## Update an existing machine

```bash
./scripts/update-all.sh            # update everything
```

Update one area at a time:

```bash
./scripts/update-all.sh homebrew   # brew update, upgrade, bundle
./scripts/update-all.sh neovim     # Lazy.nvim, Treesitter, Mason
./scripts/update-all.sh dotfiles   # git pull + dotbot relink
./scripts/update-all.sh rust       # rustup + cargo tools
./scripts/update-all.sh npm        # global npm packages
./scripts/update-all.sh skills     # agent skills (humanizer)
./scripts/update-all.sh cleanup    # caches + brew cleanup
./scripts/update-all.sh health     # health check only
```

## Manage profiles and packages

```bash
./bin/dotfiles-profile show        # current profile
./bin/dotfiles-profile set local   # switch profile (local | server)
./bin/brew-diff local server       # compare two profiles' package lists
```

Package lists live in `profiles/base.Brewfile` (all machines) plus `profiles/local.Brewfile` and `profiles/server.Brewfile`. Edit those, not the root `Brewfile`, which is generated. Then apply:

```bash
./install                          # regenerates Brewfile and runs brew bundle
```

To drop a package, delete its line from the profile and uninstall it directly:

```bash
brew uninstall <formula>           # or: brew uninstall --cask <cask>
```

Don't run `brew bundle cleanup --force` here. The profiles don't list manually-installed apps or the Nerd Fonts from `setup-nerd-fonts.py`, so cleanup treats them as stray and removes them too.

## Maintenance

```bash
./scripts/health-check.sh          # check symlinks, shell syntax, git, brew, nvim, tools
./scripts/backup.sh                # back up the current dotfiles state
```

## Layout

```
config/          app configs (nvim, kitty, zellij, bat, …), linked into ~/.config
profiles/        Brewfile sources: base + local/server
scripts/         install, update, and maintenance scripts
bin/             profile and brew helpers
git-hooks/       commit-msg + pre-commit, linked into ~/.git-hooks
docker-compose/  server media stack (server profile only)
docs/            detailed guides
```

## Docs

Deeper guides are in [`docs/`](docs/Home.md): [Setup](docs/Setup-Guide.md), [Neovim](docs/Neovim.md), [Tmux](docs/Tmux.md), [Docker Services](docs/Docker-Services.md), [Git Workflow](docs/Git-Workflow.md), [Scripts](docs/Scripts-Reference.md), [Troubleshooting](docs/Troubleshooting.md).
