# ============================================================================
# Base Brewfile - Common packages for all machines
# ============================================================================
# This profile includes essential CLI tools, development tools, and Docker
# that are needed on both local development machine and Mac Mini server.

# ============================================================================
# PROGRAMMING LANGUAGES & RUNTIMES
# ============================================================================
brew "rust"                          # Rust programming language
brew "node"                          # JavaScript runtime
brew "python@3.13"                   # Python 3.13

# ============================================================================
# CORE DEVELOPMENT TOOLS
# ============================================================================
brew "neovim"                        # Modern Vim-based editor
brew "lua-language-server"           # LSP for Lua (neovim configuration)
brew "tree-sitter"                   # Parser generator for syntax highlighting
brew "zellij"                        # Modern terminal multiplexer (Rust)
brew "gh"                            # GitHub CLI tool
brew "dotbot"                        # Dotfiles bootstrapper (manages symlinks)

# ============================================================================
# PYTHON DEVELOPMENT
# ============================================================================
brew "uv"                            # Fast Python package installer and resolver
brew "ruff"                          # Fast Python linter and formatter
brew "pyright"                       # Python static type checker
brew "isort"                         # Python import sorter

# ============================================================================
# MODERN CLI TOOLS (Rust-based replacements)
# ============================================================================
brew "eza"                           # Modern replacement for ls
brew "bat"                           # Modern replacement for cat
brew "bat-extras"                    # Additional bat-based tools
brew "ripgrep"                       # Fast grep replacement (rg)
brew "fd"                            # Fast find replacement
brew "fzf"                           # Fuzzy finder (ESSENTIAL)
brew "starship"                      # Cross-shell prompt

# ============================================================================
# FILE MANAGEMENT & NAVIGATION
# ============================================================================
brew "tree"                          # Directory tree viewer
brew "zoxide"                        # Smarter cd command (z, zi)

# ============================================================================
# TEXT & DATA PROCESSING
# ============================================================================
brew "jq"                            # JSON processor (ESSENTIAL)

# ============================================================================
# SYSTEM MONITORING & INFO
# ============================================================================
brew "htop"                          # Interactive process viewer

# ============================================================================
# DOWNLOAD & MEDIA TOOLS
# ============================================================================
brew "yt-dlp"                        # YouTube and media downloader
brew "aria2"                         # Multi-protocol download utility
brew "ffmpeg"                        # Video/audio converter and processor

# ============================================================================
# SECURITY
# ============================================================================
brew "gnupg"                         # GNU Privacy Guard (GPG)

# ============================================================================
# AWS DEVELOPMENT
# ============================================================================
brew "awscli"                        # AWS command-line interface (v2)
brew "aws-sam-cli"                   # Serverless Application Model CLI
brew "aws-cdk"                       # Cloud Development Kit (IaC)
cask "aws-vault-binary"              # Secure AWS credential storage

# ============================================================================
# CONTAINERS
# ============================================================================
cask "docker-desktop"                # Docker Desktop (container engine + GUI)

# ============================================================================
# APPLICATIONS - DEVELOPMENT TOOLS
# ============================================================================
cask "claude-code"                   # Claude Code CLI tool

# ============================================================================
# APPLICATIONS - ESSENTIAL GUI (both machines)
# ============================================================================
cask "kitty"                         # GPU-accelerated terminal emulator
cask "firefox@developer-edition"     # Firefox Developer Edition
cask "1password"                     # Password manager
cask "keka"                          # Archive manager
cask "nordvpn"                       # VPN client

# ============================================================================
# FONTS (Nerd Fonts installed via getnf in scripts/setup-nerd-fonts.py)
# ============================================================================
cask "font-ia-writer-mono"           # Clean monospace font
cask "font-fontawesome"              # Icon font
