# Personal Zsh configuration file. It is strongly recommended to keep all
# shell customization and configuration (including exported environment
# variables such as PATH) in this file or in files sourced from it.
#
# Documentation: https://github.com/arcthur/zsh4monkey/blob/main/README.md.

# Keyboard type: 'mac' or 'pc'.
zstyle ':z4m:bindkey' keyboard  'pc'

# Syntax highlighting backend: 'fast' (default) or 'none' to disable.
# zstyle ':z4m:highlight' backend 'fast'
# Syntax highlighting theme (built-in fast themes or custom file path).
# zstyle ':z4m:highlight' theme 'clean'

# Enable direnv to automatically source .envrc files.
zstyle ':z4m:direnv' enable 'no'

# Enable ('yes') or disable ('no') automatic teleportation of z4m over
# SSH when connecting to these hosts.
zstyle ':z4m:ssh:example-hostname1'   enable 'yes'
zstyle ':z4m:ssh:*.example-hostname2' enable 'no'
# The default value if none of the overrides above match the hostname.
zstyle ':z4m:ssh:*'                   enable 'no'

# Send these files over to the remote host when connecting over SSH to the
# enabled hosts.
zstyle ':z4m:ssh:*' send-extra-files '~/.nanorc' '~/.env.zsh'

# Clone additional Git repositories from GitHub.
#
# This doesn't do anything apart from cloning the repository and keeping it
# up-to-date. Cloned files can be used after `z4m init`. This is just an
# example. If you don't plan to use Oh My Zsh, delete this line.
z4m install ohmyzsh/ohmyzsh || return

# Install CLI tools (eza, bat, fd, rg, zoxide, fzf).
# These provide modern replacements for ls, cat, find, grep, and smart cd.
# Disable individual tools with: zstyle ':z4m:eza' enabled no
z4m install eza bat fd rg zoxide || return

# Install or update core components (fzf, zsh-autosuggestions, etc.) and
# initialize Zsh. After this point console I/O is unavailable until Zsh
# is fully initialized. Everything that requires user interaction or can
# perform network I/O must be done above. Everything else is best done below.
z4m init || return

# Extend PATH.
path=(~/bin $path)

# Export environment variables.
export GPG_TTY=$TTY

# Source additional local files if they exist.
z4m source ~/.env.zsh

# Use additional Git repositories pulled in with `z4m install`.
#
# This is just an example that you should delete. It does nothing useful.
z4m source ohmyzsh/ohmyzsh/lib/diagnostics.zsh  # source an individual file
z4m load   ohmyzsh/ohmyzsh/plugins/emoji-clock  # load a plugin

# Define key bindings.
z4m bindkey z4m-backward-kill-word  Ctrl+Backspace     Ctrl+H
z4m bindkey z4m-backward-kill-zword Ctrl+Alt+Backspace

z4m bindkey undo Ctrl+/ Shift+Tab  # undo the last command line change
z4m bindkey redo Alt+/             # redo the last undone command line change

z4m bindkey z4m-cd-back    Alt+Left   # cd into the previous directory
z4m bindkey z4m-cd-forward Alt+Right  # cd into the next directory
z4m bindkey z4m-cd-up      Alt+Up     # cd into the parent directory
z4m bindkey z4m-cd-down    Alt+Down   # cd into a child directory

# Autoload functions.
autoload -Uz zmv

# Define functions and completions.
function md() { [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1" }
compdef _directories md

# Define aliases.
# Note: ls, cat, tree aliases are handled by CLI tools (eza, bat) when installed.
# alias tree='tree -a -I .git'
# alias ls="${aliases[ls]:-ls} -A"

# Git worktree helpers (optional). Uncomment to enable:
# ga() {
#   [[ -z "$1" ]] && { echo "Usage: ga <branch>"; return 1; }
#   local branch=$1 base=${PWD:t} path=../${base}-${branch}
#   git worktree add -b "$branch" "$path" && cd "$path"
#   (( $+commands[mise] )) && mise trust "$path"
# }
# gd() {
#   (( $+commands[gum] )) || { echo "gd requires gum: brew install gum"; return 1; }
#   gum confirm "Remove worktree and branch?" || return 0
#   local wt=${PWD:t} root=${wt%-*} branch=${wt#*-}
#   [[ $root == $wt ]] && { echo "Not in a worktree"; return 1; }
#   cd ../$root && git worktree remove $wt --force && git branch -D $branch
# }

# Set shell options: http://zsh.sourceforge.net/Doc/Release/Options.html.
setopt glob_dots     # no special treatment for file names with a leading dot
setopt no_auto_menu  # require an extra TAB press to open the completion menu
