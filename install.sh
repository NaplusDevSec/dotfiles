#!/usr/bin/env bash

# ==============================================================================
# Dotfiles Installation Script
# Description: Sets up shell environments, symlinks, and machine-local files.
# Usage:       ./install.sh [bash|zsh]
#
# Personal details (git name/email, 42 login) are never stored in this repo.
# You are asked for them during install and they are written to untracked
# machine-local files. For unattended installs, pre-set any of:
#   DOTFILES_GIT_NAME  DOTFILES_GIT_EMAIL
#   DOTFILES_42=yes|no  DOTFILES_42_LOGIN  DOTFILES_42_EMAIL   (42 School students only)
# ==============================================================================

# Fail on errors, unset variables, and failed pipes
set -euo pipefail

# Directory this script lives in (the dotfiles checkout), wherever it was cloned
DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

# Colors (only when writing to a terminal)
if [[ -t 1 ]]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[0;34m'; NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

# ==============================================================================
# Helper Functions
# ==============================================================================
info()    { printf '%s[INFO]%s %s\n'    "$BLUE"   "$NC" "$1"; }
success() { printf '%s[SUCCESS]%s %s\n' "$GREEN"  "$NC" "$1"; }
warn()    { printf '%s[WARNING]%s %s\n' "$YELLOW" "$NC" "$1" >&2; }
error()   { printf '%s[ERROR]%s %s\n'   "$RED"    "$NC" "$1" >&2; exit 1; }

# Symlink $1 (in the repo) to $2. An existing file is backed up, never overwritten.
link_file() {
    local src="$1" dest="$2"

    [[ -e $src ]] || error "Source file missing: $src"

    if [[ -L $dest && "$(readlink -f -- "$dest")" == "$(readlink -f -- "$src")" ]]; then
        echo "  = Already linked: $dest"
        return 0
    fi

    mkdir -p -- "$(dirname -- "$dest")"

    if [[ -e $dest || -L $dest ]]; then
        mv -- "$dest" "${dest}${BACKUP_SUFFIX}"
        warn "Existing $dest backed up to ${dest}${BACKUP_SUFFIX}"
    fi

    ln -s -- "$src" "$dest"
    echo "  ↳ Linked: $(basename -- "$src") → $dest"
}

# Create a machine-local file from the template with private permissions (600)
create_private_file() {
    local dest="$1"
    if [[ -e $dest ]]; then
        chmod 600 -- "$dest"
        echo "  = Kept existing $dest (permissions set to 600)"
        return 0
    fi
    ( umask 077; install -m 600 -- "$DOTFILES_DIR/private.example" "$dest" )
    echo "  + Created $dest (mode 600) — put machine-specific settings here"
}


# ask VAR "Prompt" [default] — read a line from the terminal into VAR.
# Without a terminal (CI, pipes) nothing is asked and VAR becomes the default.
ask() {
    local __var="$1" __prompt="$2" __default="${3:-}" __reply=""
    if [[ -t 0 ]]; then
        if [[ -n $__default ]]; then
            read -r -p "$__prompt [$__default]: " __reply || true
        else
            read -r -p "$__prompt: " __reply || true
        fi
    fi
    printf -v "$__var" '%s' "${__reply:-$__default}"
}

# Escape a value for use inside a double-quoted Lua string
lua_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

valid_email() { [[ $1 =~ ^[^[:space:]@\"]+@[^[:space:]@\"]+\.[^[:space:]@\"]+$ ]]; }
valid_login() { [[ $1 =~ ^[A-Za-z0-9._-]+$ ]]; }

# ==============================================================================
# 1. PRE-FLIGHT CHECKS
# ==============================================================================
check_dependencies() {
    info "Checking dependencies..."
    command -v git >/dev/null 2>&1 || error "git is required but not installed."

    if command -v starship >/dev/null 2>&1; then
        success "Starship is already installed."
        return 0
    fi

    warn "Starship prompt is not installed."
    info "Preferred: install it with your package manager (apt/dnf/brew/pacman)."
    local answer
    read -r -p "Download and run the official Starship installer instead? (y/N): " answer || answer=""
    if [[ $answer =~ ^[Yy]$ ]]; then
        command -v curl >/dev/null 2>&1 || error "curl is required to download Starship."
        local tmp
        tmp="$(mktemp)"
        # Download to a file first (never pipe curl into sh) over HTTPS/TLS 1.2+
        curl --proto '=https' --tlsv1.2 -fsSL https://starship.rs/install.sh -o "$tmp"
        info "Installer saved to $tmp — review it if you wish. Running it now..."
        sh "$tmp"
        rm -f -- "$tmp"
        success "Starship installed."
    else
        warn "Skipping Starship installation. Prompt layout may be incomplete."
    fi
}

# ==============================================================================
# 2. SETUP DIRECTORIES & SYMLINKS
# ==============================================================================
setup_global_links() {
    info "Linking global configurations..."
    link_file "$DOTFILES_DIR/starship.toml" "$HOME/.config/starship.toml"
    link_file "$DOTFILES_DIR/.gitconfig"    "$HOME/.gitconfig"
    link_file "$DOTFILES_DIR/.gitignore"    "$HOME/.gitignore"
    link_file "$DOTFILES_DIR/.tmux.conf"    "$HOME/.tmux.conf"

    info "Linking Neovim configurations..."
    link_file "$DOTFILES_DIR/nvim/init.lua"       "$HOME/.config/nvim/init.lua"
    link_file "$DOTFILES_DIR/nvim/lazy-lock.json" "$HOME/.config/nvim/lazy-lock.json"
}

# ==============================================================================
# 3. PERSONAL IDENTITY (asked once, stored in untracked machine-local files)
# ==============================================================================
setup_git_identity() {
    local file="$HOME/.gitconfig.local" name="${DOTFILES_GIT_NAME:-}" email="${DOTFILES_GIT_EMAIL:-}"

    if [[ -f $file ]] && git config --file "$file" user.name >/dev/null 2>&1 \
        && git config --file "$file" user.email >/dev/null 2>&1; then
        echo "  = Kept existing git identity in $file"
        return 0
    fi

    [[ -n $name ]]  || ask name  "Git name  (commits will use this)" "$(git config --get user.name  2>/dev/null || true)"
    [[ -n $email ]] || ask email "Git email (commits will use this)" "$(git config --get user.email 2>/dev/null || true)"

    if [[ -z $name || -z $email ]]; then
        warn "Git identity skipped. Set it later with: git config --file ~/.gitconfig.local user.name \"Your Name\""
        return 0
    fi
    valid_email "$email" || { warn "'$email' does not look like an email address; git identity skipped."; return 0; }

    (
        umask 077
        git config --file "$file" user.name  "$name"
        git config --file "$file" user.email "$email"
    )
    echo "  + Saved git identity to $file"
}

# yes/no from env var or prompt. $1 = env value, $2 = prompt. Non-interactive -> no.
confirm() {
    local value="$1" prompt="$2" reply=""
    case "$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')" in
        y|yes|1|true)  return 0 ;;
        n|no|0|false)  return 1 ;;
    esac
    ask reply "$prompt (y/N)" ""
    [[ $reply =~ ^[Yy]([Ee][Ss])?$ ]]
}

setup_42() {
    local dir="$HOME/.config/nvim" file="$HOME/.config/nvim/local.lua"
    local login="${DOTFILES_42_LOGIN:-}" mail="${DOTFILES_42_EMAIL:-}" want="${DOTFILES_42:-}"

    if [[ -f $file ]]; then
        echo "  = Kept existing Neovim local settings in $file"
        return 0
    fi

    # Giving a 42 login up front implies "yes"
    [[ -z $want && -n $login ]] && want=yes

    mkdir -p -- "$dir"

    if ! confirm "$want" "Are you a 42 student? (enables Norminette real tabs + the 42 header in Neovim)"; then
        ( umask 077; printf 'return { school42 = false }\n' > "$file" )
        echo "  + Neovim: standard setup (spaces, no 42 header) saved to $file"
        return 0
    fi

    [[ -n $login ]] || ask login "42 login (Enter to use \$USER)" "${USER:-user}"
    valid_login "$login" || { warn "Invalid login '$login'; 42 settings skipped (re-run to retry)."; return 0; }
    [[ -n $mail ]] || ask mail "42 header email" "${login}@student.42.fr"
    valid_email "$mail" || { warn "'$mail' does not look like an email address; 42 settings skipped (re-run to retry)."; return 0; }

    ( umask 077; printf 'return { school42 = true, login = "%s", mail = "%s" }\n' \
        "$(lua_escape "$login")" "$(lua_escape "$mail")" > "$file" )
    echo "  + Neovim: 42 setup (real tabs + header) saved to $file"
}

setup_identity() {
    info "Personal details (stored locally, never committed)..."
    setup_git_identity
    setup_42
}

# ==============================================================================
# 4. SHELL CONFIGURATION
# ==============================================================================
clone_plugin() {
    local name="$1" url="$2" dir="$HOME/.zsh/$1"
    if [[ ! -d $dir ]]; then
        info "Cloning $name..."
        git clone --quiet --depth 1 -- "$url" "$dir"
    fi
}

setup_zsh() {
    info "Setting up Zsh environment..."
    mkdir -p -- "$HOME/.zsh"
    clone_plugin zsh-autosuggestions       https://github.com/zsh-users/zsh-autosuggestions
    clone_plugin zsh-syntax-highlighting   https://github.com/zsh-users/zsh-syntax-highlighting

    link_file "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
    create_private_file "$HOME/.zsh_private"
    success "Zsh setup complete. Run 'source ~/.zshrc' (or open a new terminal)."
}

setup_bash() {
    info "Setting up Bash environment..."
    link_file "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
    create_private_file "$HOME/.bash_private"
    success "Bash setup complete. Run 'source ~/.bashrc' (or open a new terminal)."
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
main() {
    printf '%s==========================================%s\n' "$GREEN" "$NC"
    printf '%s      Starting Dotfiles Installation      %s\n' "$GREEN" "$NC"
    printf '%s==========================================%s\n\n' "$GREEN" "$NC"

    check_dependencies

    local shell_choice="${1:-}"
    if [[ -z $shell_choice ]]; then
        echo ""
        read -r -p "Which shell do you want to set up? (zsh/bash): " shell_choice || shell_choice=""
        echo ""
    fi

    setup_global_links
    echo ""

    setup_identity
    echo ""

    case "$(printf '%s' "$shell_choice" | tr '[:upper:]' '[:lower:]')" in
        zsh)  setup_zsh ;;
        bash) setup_bash ;;
        *)    error "Invalid shell choice ('$shell_choice'). Use 'zsh' or 'bash'." ;;
    esac

    printf '\n%sDotfiles installation finished successfully!%s\n\n' "$GREEN" "$NC"
}

main "$@"
