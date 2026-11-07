# shellcheck shell=bash
# ~/.bashrc — loaded by interactive shells only
[[ $- != *i* ]] && return

# Resolve the dotfiles directory from this file's real location (follows symlinks)
DOTFILES_DIR="${DOTFILES_DIR:-$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")}"
export DOTFILES_DIR

# ==========================================
# 1. SYSTEM CONFIG & PATH
# ==========================================
if [[ -f /etc/bashrc ]]; then
    source /etc/bashrc
elif [[ -f /etc/bash.bashrc ]]; then
    source /etc/bash.bashrc
fi

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$HOME/bin:$PATH" ;;
esac
export PATH

if [[ -d "$HOME/.bashrc.d" ]]; then
    for rc in "$HOME"/.bashrc.d/*; do
        [[ -f $rc ]] && source "$rc"
    done
    unset rc
fi

# ==========================================
# 2. HISTORY & SHELL OPTIONS
# ==========================================
HISTCONTROL=ignoreboth:erasedups   # skip duplicates and commands starting with a space
HISTSIZE=5000
HISTFILESIZE=10000
shopt -s histappend checkwinsize

# ==========================================
# 3. LOAD SHARED ALIASES & COLOR SETUP
# ==========================================
if [[ -x /usr/bin/dircolors ]]; then
    if [[ -r ~/.dircolors ]]; then
        eval "$(dircolors -b ~/.dircolors)"
    else
        eval "$(dircolors -b)"
    fi
fi

[[ -f "$DOTFILES_DIR/aliases" ]] && source "$DOTFILES_DIR/aliases"

# Bash-specific alert function
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# ==========================================
# 4. PRIVATE (MACHINE-LOCAL) CONFIG & PROMPT
# ==========================================
# ~/.bash_private is NOT tracked in git. Put machine-specific settings here
# (VPN helpers, tokens, work/campus shortcuts). See private.example.
# It is only loaded if you own it and it is not writable by group/others.
_load_private() {
    local file="$1"
    [[ -f $file && -O $file ]] || return 0
    if [[ -n $(find "$file" -maxdepth 0 -perm /022 2>/dev/null) ]]; then
        printf 'bashrc: refusing to load %s (group/world-writable). Run: chmod 600 %s\n' \
            "$file" "$file" >&2
        return 0
    fi
    source "$file"
}
_load_private "$HOME/.bash_private"
unset -f _load_private

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi
