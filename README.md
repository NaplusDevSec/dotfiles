# dotfiles
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Portable **bash / zsh**, **Neovim**, **tmux** and **Starship** configuration for C and
assembly development, with an optional [42 School](https://42.fr) mode (Norminette real tabs
and the 42 header). Works for everyone, and comes with a safe, interactive installer.

No personal details are stored in this repo. The installer asks for your git identity (and,
only if you are a 42 student, your 42 login) and keeps them in untracked, machine-local files.

## What's included

| Path | Purpose |
| --- | --- |
| `.bashrc`, `.zshrc` | Shell setup: PATH, history, colors, plugins, prompt |
| `aliases` | Aliases shared by bash and zsh (safety, `ls`, disk usage, C/Valgrind helpers) |
| `.gitconfig`, `.gitignore` | Git defaults (`main` branch, `nvim` editor, `fsckObjects`) and a global ignore list |
| `.tmux.conf` | `C-a` prefix, vim-style pane navigation, mouse support |
| `starship.toml` | Two-line [Starship](https://starship.rs) prompt |
| `nvim/init.lua` | Neovim config: Telescope, nvim-tree, clangd LSP, Markdown preview, plus optional 42 mode (Norminette tabs, 42 header) |
| `nvim/lazy-lock.json` | Pinned plugin versions ([lazy.nvim](https://github.com/folke/lazy.nvim)) |
| `private.example` | Template for machine-local secrets and helpers |
| `install.sh` | Symlinks everything into place and sets up your local identity |

## Requirements

- `git` (required)
- `bash` or `zsh`
- Optional but recommended: [`starship`](https://starship.rs), `neovim` (0.9+), `tmux`, `clangd`,
  `valgrind` and `gdb` (for the `vg` / `vgdb` aliases), `node`/`npm` (Markdown preview plugin)

## Install

```sh
git clone https://github.com/NaplusDevSec/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh zsh    # or: ./install.sh bash
```

Run without an argument and the script asks which shell to set up.

The installer:

1. Checks dependencies (offers to install Starship; the installer is downloaded to a temp
   file first, never piped straight into `sh`).
2. Symlinks the configs into `$HOME`. Existing files are **backed up** as `*.bak.<timestamp>`,
   never overwritten.
3. **Asks for your details** (see below).
4. Creates `~/.zsh_private` or `~/.bash_private` from `private.example` with mode `600`.

It is safe to re-run: existing links and local files are kept.

### Personal details

| Prompt | Stored in | Used for |
| --- | --- | --- |
| Git name and email | `~/.gitconfig.local` | Commit identity (pulled in by `[include]` in `.gitconfig`) |
| "Are you a 42 student?" (and, if yes, 42 login and email) | `~/.config/nvim/local.lua` | Turns the Neovim 42 mode on or off |

Both files are created with mode `600` and are not part of this repository.

**42 mode** is off unless you answer yes (just press Enter to skip). When it is on, Neovim
uses real tabs of width 4 as the Norminette expects, and the 42 header is available. When it
is off you get 4 spaces and no header. At the 42 prompts, press Enter to accept the defaults
(`$USER` and `<login>@student.42.fr`).

For unattended installs, set any of these beforehand and nothing will be asked. Without a
terminal and without these variables, git identity is skipped and 42 mode stays off.

```sh
DOTFILES_GIT_NAME="Jane Doe" \
DOTFILES_GIT_EMAIL="jane@example.com" \
DOTFILES_42=yes \
DOTFILES_42_LOGIN="jdoe" \
DOTFILES_42_EMAIL="jdoe@student.42.fr" \
./install.sh zsh
```

`DOTFILES_42=no` skips 42 mode; setting `DOTFILES_42_LOGIN` alone implies yes.

To change anything later, edit the two files above (or delete them and re-run `./install.sh`).

> **Heads-up:** `~/.gitconfig` is a symlink into this repo, so `git config --global ...`
> writes to the tracked file. Use `git config --file ~/.gitconfig.local ...` for anything
> personal.

## Private and machine-local config

Put tokens, VPN helpers, internal hostnames and similar in `~/.zsh_private` /
`~/.bash_private`. They are listed in `.gitignore`, and the shell refuses to load them if
they are group- or world-writable. See [`private.example`](private.example).

## Neovim

Plugins are installed automatically by lazy.nvim on first launch (requires `git`).

| Key / command | Action |
| --- | --- |
| `Ctrl+Alt+h` or `:Stdheader` | Insert or update the 42 header (42 mode only) |
| `` ` `` | Toggle file tree |
| `<Space>ff` / `fg` / `fb` / `fh` | Telescope: files / live grep / buffers / help |
| `Ctrl+Click` | Go to definition (LSP) |
| `<Space>m` | Toggle Markdown preview in the browser |

Indentation is 4 spaces by default, or real tabs of width 4 in 42 mode (as the Norminette expects).

## Aliases worth knowing

- `cw` / `gcw`: `cc -Wall -Wextra -Werror`, the usual strict flags (the latter adds `-g`)
- `vg`: Valgrind with full leak checking; `vgdb ./prog`: Valgrind and GDB attached together
- `rm`, `cp`, `mv` ask before overwriting; `ll`, `la`, `lt`, `du1`..`du3`, `dfh` for quick listings

## Uninstall

Remove the symlinks in `$HOME` (they point into this repo) and restore any `*.bak.*` backups
the installer created.

## License

[MIT](LICENSE)
