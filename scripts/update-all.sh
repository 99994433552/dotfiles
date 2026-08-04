#!/usr/bin/env bash
# ============================================================================
# Update All Tools and Configurations
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo
    echo -e "${BLUE}🔄 $1${NC}"
    echo "============================================================================"
}

update_homebrew() {
    log_step "Updating Homebrew packages"

    if command -v brew >/dev/null 2>&1; then
        echo "Updating Homebrew..."
        brew update

        echo "Upgrading packages..."
        brew upgrade

        echo "Running bundle to ensure all packages are installed..."
        local dotfiles_dir="${HOME}/.dotfiles"
        if [[ -f "$dotfiles_dir/Brewfile" ]]; then
            cd "$dotfiles_dir"
            brew bundle --verbose
        else
            log_warning "Brewfile not found, skipping bundle"
        fi

        echo "Cleaning up..."
        brew cleanup

        log_success "Homebrew update completed"
    else
        log_error "Homebrew not found"
        return 1
    fi
}

update_neovim_plugins() {
    log_step "Updating Neovim plugins"

    if command -v nvim >/dev/null 2>&1; then
        echo "Syncing Lazy.nvim plugins..."
        nvim --headless "+Lazy! sync" +qa

        echo "Updating Treesitter parsers..."
        nvim --headless "+TSUpdateSync" +qa

        echo "Updating LSP servers..."
        nvim --headless "+MasonUpdate" +qa 2>/dev/null || log_warning "Mason not available or failed to update"

        log_success "Neovim plugins updated"
    else
        log_error "Neovim not found"
        return 1
    fi
}

update_dotfiles() {
    log_step "Updating dotfiles configuration"

    local dotfiles_dir="${HOME}/.dotfiles"
    cd "$dotfiles_dir"

    echo "Pulling latest changes from git..."
    if git pull --rebase; then
        log_success "Git pull completed"
    else
        log_warning "Git pull failed or had conflicts"
    fi

    echo "Running dotbot to update symlinks..."
    if command -v dotbot >/dev/null 2>&1; then
        dotbot -c install.conf.yaml
        log_success "Dotbot configuration applied"
    else
        log_error "Dotbot not found"
        return 1
    fi
}

update_rust_tools() {
    log_step "Updating Rust tools"

    if command -v rustup >/dev/null 2>&1; then
        echo "Updating Rust toolchain..."
        rustup update

        echo "Updating Rust-based tools..."
        if command -v cargo >/dev/null 2>&1; then
            # Update common cargo tools if installed
            local cargo_tools=("eza" "bat" "ripgrep" "fd-find" "starship")
            for tool in "${cargo_tools[@]}"; do
                if cargo install --list | grep -q "$tool"; then
                    echo "Updating $tool..."
                    cargo install "$tool" || log_warning "Failed to update $tool"
                fi
            done
        fi

        log_success "Rust tools updated"
    else
        log_warning "Rust not installed, skipping Rust tools update"
    fi
}

update_npm_global_packages() {
    log_step "Updating npm global packages"

    if command -v npm >/dev/null 2>&1; then
        echo "Updating npm itself..."
        npm update -g npm

        echo "Updating global packages..."
        npm update -g

        log_success "npm global packages updated"
    else
        log_warning "npm not found, skipping npm updates"
    fi
}

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

cleanup_system() {
    log_step "System cleanup"

    echo "Clearing shell completion cache..."
    rm -f ~/.zcompdump*

    echo "Clearing temporary files..."
    # Clear common cache directories
    if [[ -d ~/Library/Caches ]]; then
        find ~/Library/Caches -name "*.log" -delete 2>/dev/null || true
    fi

    # Clean up Homebrew again after all updates
    if command -v brew >/dev/null 2>&1; then
        echo "Final Homebrew cleanup..."
        brew cleanup --prune=all
        brew doctor || log_warning "Homebrew doctor found issues"
    fi

    log_success "System cleanup completed"
}

run_health_check() {
    log_step "Running health check"

    local dotfiles_dir="${HOME}/.dotfiles"
    if [[ -f "$dotfiles_dir/scripts/health-check.sh" ]]; then
        bash "$dotfiles_dir/scripts/health-check.sh"
    else
        log_warning "Health check script not found"
    fi
}

print_summary() {
    echo
    echo "============================================================================"
    echo -e "${GREEN}🎉 Update process completed!${NC}"
    echo "============================================================================"
    echo
    echo -e "${BLUE}What was updated:${NC}"
    echo "• Homebrew packages"
    echo "• Neovim plugins and language servers"
    echo "• Dotfiles configuration"
    echo "• Rust toolchain and tools"
    echo "• npm global packages"
    echo "• Agent skills"
    echo "• System cleanup"
    echo
    echo -e "${YELLOW}Recommended next steps:${NC}"
    echo "• Restart your terminal to apply all changes"
    echo "• Test critical functionality"
    echo "• Check for any warnings from the health check"
}

main() {
    echo "============================================================================"
    echo -e "${BLUE}🔄 Updating All Tools and Configurations${NC}"
    echo "============================================================================"
    echo

    # Run updates (continue even if some fail)
    update_homebrew || log_error "Homebrew update failed"
    update_neovim_plugins || log_error "Neovim update failed"
    update_dotfiles || log_error "Dotfiles update failed"
    update_rust_tools || log_warning "Rust tools update had issues"
    update_npm_global_packages || log_warning "npm update had issues"
    update_agent_skills || log_warning "Agent skills update had issues"
    cleanup_system || log_warning "System cleanup had issues"

    # Always run health check at the end
    run_health_check || log_warning "Health check found issues"

    print_summary
}

# Allow running specific update functions
if [[ $# -gt 0 ]]; then
    case "$1" in
        "homebrew"|"brew")
            update_homebrew
            ;;
        "neovim"|"nvim")
            update_neovim_plugins
            ;;
        "dotfiles")
            update_dotfiles
            ;;
        "rust")
            update_rust_tools
            ;;
        "npm")
            update_npm_global_packages
            ;;
        "skills")
            update_agent_skills
            ;;
        "cleanup")
            cleanup_system
            ;;
        "health"|"check")
            run_health_check
            ;;
        *)
            echo "Usage: $0 [homebrew|neovim|dotfiles|rust|npm|skills|cleanup|health]"
            echo "  Run without arguments to update everything"
            exit 1
            ;;
    esac
else
    main
fi