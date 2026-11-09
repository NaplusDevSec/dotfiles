# ~/.zshrc — loaded by interactive zsh shells

# Resolve the dotfiles directory from this file's real location (follows symlinks)
export DOTFILES_DIR="${DOTFILES_DIR:-${${(%):-%x}:A:h}}"

# Add Cargo binaries to PATH if the directory exists
# Zsh-native array syntax (Automatic de-duplication)
typeset -U path
[[ -d "$HOME/.cargo/bin" ]] && path=("$HOME/.cargo/bin" $path)

# ==========================================
# 1. ENVIRONMENT & PATH
# ==========================================
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$HOME/bin:$PATH" ;;
esac

# Zsh history (HISTSIZE must be >= SAVEHIST or older entries are dropped)
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY INC_APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# ==========================================
# 2. LOAD SHARED ALIASES & COLOR SETUP
# ==========================================
if [[ -x /usr/bin/dircolors ]]; then
    if [[ -r ~/.dircolors ]]; then
        eval "$(dircolors -b ~/.dircolors)"
    else
        eval "$(dircolors -b)"
    fi
fi

[[ -f "$DOTFILES_DIR/aliases" ]] && source "$DOTFILES_DIR/aliases"

# ==========================================
# 3. ZSH PLUGINS
# ==========================================
[[ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# zsh-syntax-highlighting must be sourced last among plugins
[[ -f ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ==========================================
# 4. PRIVATE (MACHINE-LOCAL) CONFIG & PROMPT
# ==========================================
# ~/.zsh_private is NOT tracked in git. Only loaded if you own it and it is
# not writable by group/others.
_load_private() {
    local file="$1"
    [[ -f $file && -O $file ]] || return 0
    if [[ -n $(find "$file" -maxdepth 0 -perm /022 2>/dev/null) ]]; then
        print -u2 "zshrc: refusing to load $file (group/world-writable). Run: chmod 600 $file"
        return 0
    fi
    source "$file"
}
_load_private "$HOME/.zsh_private"
unfunction _load_private

if (( $+commands[starship] )); then
    eval "$(starship init zsh)"
fi
