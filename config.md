# zsh4monkey Configuration Reference

Configuration options for zsh4monkey. Place `zstyle` settings in `~/.zshrc` **before** `z4m init`.

## Table of Contents

- [Core Settings](#core-settings)
- [Editor Mode](#editor-mode)
- [Autosuggestions](#autosuggestions)
- [Terminal Title](#terminal-title)
- [Tmux Integration](#tmux-integration)
- [FZF Settings](#fzf-settings)
- [SSH Teleportation](#ssh-teleportation)
- [SSH Agent](#ssh-agent)
- [Direnv Integration](#direnv-integration)
- [Shell Integration](#shell-integration)
- [CLI Tools](#cli-tools)
- [Carapace Completion](#carapace-completion)
- [Atuin History](#atuin-history)
- [Auto Update](#auto-update)
- [Recovery & Safe Mode](#recovery--safe-mode)
- [Deferred Loading](#deferred-loading)
- [Usage Guide](#usage-guide)
- [Quick Reference](#quick-reference)
- [Commands Reference](#commands-reference)
- [Built-in Utilities](#built-in-utilities)

---

## Core Settings

### prompt-at-bottom

Move the prompt to the bottom when zsh starts. z4m's clear-screen widgets preserve this layout
(default: `Ctrl+L`, unless overridden by tmux unified navigation).

```zsh
zstyle ':z4m:' prompt-at-bottom 'yes'
```

| Value | Description |
|-------|-------------|
| `yes` | Prompt at bottom (default) |
| `no`  | Prompt at top |

> Effective only when z4m can save/restore the terminal screen (e.g. inside tmux, or when using `z4m ssh`).

### propagate-cwd

Allow tmux to open new windows/panes in the same directory. **Enabled by default.**

```zsh
# Disable if needed:
zstyle ':z4m:' propagate-cwd 'no'
```

---

## Editor Mode

### editor-mode

Choose between emacs and vi editing mode.

```zsh
zstyle ':z4m:' editor-mode 'vi'
```

| Value | Description |
|-------|-------------|
| `emacs` | Emacs keybindings (default) |
| `vi` | Vi keybindings with cursor shape changes, autosuggestions hidden in normal mode |

**Runtime toggle:**

```zsh
z4m vi-mode on|off|toggle|status
```

### keyboard

Keyboard type hint for `z4m bindkey` key name mapping (mainly affects Delete vs Fn+Delete on macOS).

```zsh
zstyle ':z4m:bindkey' keyboard 'pc'
```

| Value | Forward Delete key name |
|-------|--------------------------|
| `pc` | `Delete` |
| `mac` | `Fn+Delete` |

### macos-option-as-alt

Enable Option key as Alt for bindings on macOS terminals that support it.

```zsh
zstyle ':z4m:bindkey' macos-option-as-alt yes
```

---

## Autosuggestions

### forward-char / end-of-line

Control cursor behavior through autosuggestions.

```zsh
zstyle ':z4m:autosuggestions' forward-char 'partial-accept'
zstyle ':z4m:autosuggestions' end-of-line  'partial-accept'
```

| Value | Description |
|-------|-------------|
| `accept` | Accept full autosuggestion (default) |
| `partial-accept` | Accept one character/line |

---

## Terminal Title

### term-title:local / term-title:ssh

Customize terminal window/tab title.

```zsh
zstyle ':z4m:term-title:local' preexec '${1//\%/%%}'
zstyle ':z4m:term-title:local' precmd  '%~'
zstyle ':z4m:term-title:ssh'   preexec '%n@%m: ${1//\%/%%}'
zstyle ':z4m:term-title:ssh'   precmd  '%n@%m: %~'
```

**Expansions:** `%n` (user), `%m` (host), `%~` (directory), `%*` (time), `$1` (command in preexec)

**Use typed hostname instead of remote-reported:**

```zsh
zstyle ':z4m:term-title:ssh' preexec '%n@'${${${Z4M_SSH##*:}//\%/%%}:-%m}': ${1//\%/%%}'
zstyle ':z4m:term-title:ssh' precmd  '%n@'${${${Z4M_SSH##*:}//\%/%%}:-%m}': %~'
```

---

## Tmux Integration

### start-tmux

Control automatic tmux startup.

```zsh
zstyle ':z4m:' start-tmux 'command tmux -u new -A -D -t z4m'
```

| Value | Description |
|-------|-------------|
| `no` | Don't start tmux |
| `integrated` | Shared z4m tmux server (socket keyed by `$TERM`/color capabilities) |
| `isolated` | Isolated z4m tmux server (unique socket per shell process, default) |
| `system` | Use system tmux (`command tmux -u`) |
| `command <cmd>` | Custom tmux command |

### Unified Navigation (tmux-nav)

Seamless `Ctrl+h/j/k/l` navigation across Zsh, Tmux panes, and Neovim splits.

```zsh
# Disable unified navigation
zstyle ':z4m:tmux-nav' enable no

# Navigation mode
zstyle ':z4m:tmux-nav' mode 'unified'  # unified | pane | disabled
```

| Mode | Behavior |
|------|----------|
| `unified` | Smart boundary detection: move within ZLE when possible; otherwise delegate to tmux pane navigation (default) |
| `pane` | Always navigate tmux panes unconditionally |
| `disabled` | No bindings; user-defined configuration |

**Resize bindings** (`Ctrl+Alt+h/j/k/l`):

```zsh
zstyle ':z4m:tmux-nav' resize-bindings yes  # default: yes
```

> Requires Neovim with [smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim) for full integration.
> See `docs/tmux-unified-nav.md` for complete setup.

### Context-Aware Window Title (tmux-title)

Dynamic tmux window naming: project name, git branch with dirty indicator, command icons.

```zsh
# Disable window title feature
zstyle ':z4m:tmux-title' enable no

# Show git branch (default: no)
zstyle ':z4m:tmux-title' git-branch yes

# Show command icons (default: no, requires Nerd Font)
zstyle ':z4m:tmux-title' command-icons yes

# Maximum title length (default: 24)
zstyle ':z4m:tmux-title' max-length 24
```

**Examples:**

| Context | Window Name |
|---------|-------------|
| In `~/work/backend` on `main` branch | `backend:main` |
| With uncommitted changes | `backend:main*` |
| Running `nvim` | ` nvim` |
| Running `docker compose` | ` docker` |

> Requires `automatic-rename off` in tmux.conf (preserves programmatic names).
> See `docs/tmux-context-title.md` for details.

---

## FZF Settings

z4m automatically detects your fzf version and enables advanced features when available.

### Global fzf-flags

```zsh
zstyle ':z4m:*' fzf-flags '--color=hl:5,hl+:5'
```

### Theme Configuration

Choose from popular color themes (requires fzf to apply):

```zsh
zstyle ':z4m:*' fzf-theme 'catppuccin'
```

| Theme | Description |
|-------|-------------|
| `default` | Default highlight colors (magenta) |
| `dracula` | Purple/pink Dracula theme |
| `gruvbox` | Retro groove colors |
| `catppuccin` | Catppuccin Mocha (dark) |
| `catppuccin-latte` | Catppuccin Latte (light) |
| `nord` | Arctic, north-bluish colors |
| `tokyonight` | Tokyo Night theme |
| `onedark` | Atom One Dark theme |
| `solarized-dark` | Solarized Dark |
| `solarized-light` | Solarized Light |
| `rose-pine` | Rose Pine theme |
| `kanagawa` | Kanagawa wave theme |

### Tmux Popup Mode (fzf 0.54+)

Use fzf in a tmux popup window instead of inline:

```zsh
zstyle ':z4m:*' fzf-tmux 'center'   # or: top, bottom, left, right
zstyle ':z4m:*' fzf-tmux 'no'       # disable (default)
```

### Visual Enhancements (fzf 0.52+)

```zsh
# Highlight entire current line
zstyle ':z4m:*' fzf-highlight-line 'yes'

# Enable line wrapping (fzf 0.56+)
zstyle ':z4m:*' fzf-wrap 'yes'

# Custom pointer and marker symbols (fzf 0.54+)
zstyle ':z4m:*' fzf-pointer '▶'
zstyle ':z4m:*' fzf-marker '✓'
```

### fzf-complete

Recursive directory traversal is **enabled by default**.

```zsh
# Disable recursive completion:
zstyle ':z4m:fzf-complete' recurse-dirs 'no'

# Other options:
zstyle ':z4m:fzf-complete' fzf-bindings 'tab:repeat'
```

### fzf-history

```zsh
zstyle ':z4m:fzf-history' fzf-preview 'no'
```

> fzf 0.59+ uses `--scheme=history` for better history matching.

### fzf-dir-history / cd-down

```zsh
zstyle ':z4m:fzf-dir-history' fzf-bindings 'tab:repeat'
zstyle ':z4m:cd-down'         fzf-bindings 'tab:repeat'
zstyle ':z4m:cd-down'         find-command 'command find'
```

> fzf 0.59+ uses `--scheme=path` for better path matching.

> **Note:** fzf 0.48+ uses built-in `--walker` for `z4m-cd-down` when `find-command` is not set.
> Setting `find-command` forces using the custom search command and disables `--walker`.

**fzf-bindings values:** `tab:down`, `tab:up`, `tab:repeat`

### Advanced Keybindings

The following keybindings are automatically enabled based on fzf version:

| Key | Action | Requires |
|-----|--------|----------|
| `Ctrl+/` | Toggle preview | fzf 0.45+ |
| `Alt+P` | Toggle preview | fzf 0.45+ |
| `Alt+T` | Track current item | fzf 0.49+ |
| `Ctrl+F` | Preview page down | (with preview) |
| `Ctrl+B` | Preview page up | (with preview) |
| `Alt+Up/Down` | Preview scroll | (with preview) |

---

## SSH Teleportation

Transfer shell configuration to remote hosts automatically.

### enable

```zsh
# Whitelist approach
zstyle ':z4m:ssh:*'          enable 'no'
zstyle ':z4m:ssh:myserver'   enable 'yes'

# Blacklist approach
zstyle ':z4m:ssh:*'          enable 'yes'
zstyle ':z4m:ssh:production-*' enable 'no'
```

### send-extra-files / retrieve-extra-files

```zsh
zstyle ':z4m:ssh:*' send-extra-files '~/.nanorc' '~/.env.zsh'
zstyle ':z4m:ssh:*' retrieve-extra-files '~/.local/notes'
```

### retrieve-history

```zsh
zstyle ':z4m:ssh:*' retrieve-history '$ZDOTDIR/.zsh_history.remote'
```

### propagate-env

Propagate local environment variables to remote SSH sessions. All variable types are supported: scalars, indexed arrays, and associative arrays. Values are Base64-encoded for safe transport across the SSH boundary.

```zsh
# Explicit variable list
zstyle ':z4m:ssh:*' propagate-env 'EDITOR' 'VISUAL' 'FZF_DEFAULT_OPTS'

# Glob patterns for bulk matching
zstyle ':z4m:ssh:*' propagate-env-patterns 'FZF_*' 'ATUIN_*'

# Additional exclusion patterns (supplements built-in security filters)
zstyle ':z4m:ssh:*' propagate-env-exclude 'MY_INTERNAL_*'
```

**Built-in security exclusions** (always enforced):
- `*_SECRET`, `*_SECRET_*`, `*SECRET_*`
- `*_TOKEN`, `*_TOKEN_*`, `*TOKEN_*`
- `*_KEY`, `*_API_KEY`, `*API_KEY*`
- `*_PASSWORD`, `*PASSWORD*`
- `*_CREDENTIAL*`, `*CREDENTIAL*`
- `AWS_SECRET_*`, `AWS_SESSION_TOKEN`
- `GITHUB_TOKEN`, `GH_TOKEN`, `GITLAB_TOKEN`
- `NPM_TOKEN`, `NPM_AUTH_TOKEN`
- `DOCKER_PASSWORD`, `DOCKER_AUTH_*`

**Size constraints:**
- Per-variable limit: 4KB (variables exceeding this are silently skipped)
- Total payload limit: 64KB

### term / ssh-command

```zsh
zstyle ':z4m:ssh:oldserver' term 'screen-256color'
zstyle ':z4m:ssh:*' ssh-command 'command ssh'
```

### sync-mode

```zsh
zstyle ':z4m:ssh:*' sync-mode 'smart'
```

| Value | Description |
|-------|-------------|
| `smart` | Full on first connection, incremental after (default) |
| `full` | Always full sync |
| `incremental` | Compare with previous state |

Force full sync: `z4m ssh --force-sync <host>`

### offline-mode

Bundle z4m installation for air-gapped hosts without internet access.

```zsh
zstyle ':z4m:ssh:airgapped-host' offline-mode yes
```

### configure

Custom function for advanced SSH setup.

```zsh
zstyle ':z4m:ssh:myhost' configure 'my-ssh-configure'
```

Available arrays: `z4m_ssh_prelude`, `z4m_ssh_send_files`, `z4m_ssh_setup`, `z4m_ssh_run`, `z4m_ssh_teardown`, `z4m_ssh_retrieve_files`

### ProxyJump Support

Jump hosts are supported transparently. Only the final target receives teleportation.

```zsh
z4m ssh -J jumphost user@target
```

---

## SSH Agent

```zsh
zstyle ':z4m:ssh-agent:' start      'yes'
zstyle ':z4m:ssh-agent:' extra-args '-t 20h'
```

---

## Direnv Integration

```zsh
zstyle ':z4m:direnv' enable 'yes'
```

Success notifications are disabled by default (less noise). Enable with:

```zsh
zstyle ':z4m:direnv:success' notify 'yes'
```

---

## Shell Integration

OSC 133 shell integration for modern terminals. **Enabled by default.**

### Features

| Feature | Description |
|---------|-------------|
| Semantic jumping | `C-Up`/`C-Down` in tmux copy-mode jumps between prompts |
| Output capture | Navigate to output region and yank in copy-mode |
| Command notification | Desktop notification when long commands finish |

### OSC 133 (Prompt Marking)

```zsh
# Disable prompt marking:
zstyle ':z4m:' term-shell-integration 'no'
```

Supported terminals: Ghostty, kitty, iTerm2, WezTerm, VS Code, Windows Terminal

**Tmux requirements:**
- tmux 3.3a+ with `allow-passthrough on`
- Copy-mode bindings: `C-Up` (previous-prompt), `C-Down` (next-prompt)

### Command Notification (OSC 9)

Desktop notification when commands exceed a time threshold.

```zsh
# Disable notifications
zstyle ':z4m:cmd-notify' enable no

# Set threshold in seconds (default: 30)
zstyle ':z4m:cmd-notify' threshold 30

# Exclude specific commands
zstyle ':z4m:cmd-notify' exclude 'docker' 'kubectl'
```

**Default exclusions** (interactive commands): vim, nvim, less, man, top, htop, ssh, tmux, python, node, mysql, etc.

Supported terminals: Ghostty, kitty, iTerm2, WezTerm, Windows Terminal

---

## CLI Tools

Modern replacements: `eza`, `bat`, `fd`, `rg`, `zoxide`, `fzf`.

```zsh
z4m install eza bat fd rg zoxide fzf || return
```

**Disable individual tools:**

```zsh
zstyle ':z4m:eza'    enabled no
zstyle ':z4m:bat'    enabled no
zstyle ':z4m:zoxide' enabled no
```

> Only `eza`, `bat`, and `zoxide` support the `enabled` option.

---

## Carapace Completion

Multi-shell completion engine.

```zsh
z4m install carapace || return
```

**Configuration:**

```zsh
zstyle ':z4m:carapace' enabled 'no'
zstyle ':z4m:carapace' exclude docker kubectl
zstyle ':z4m:carapace' force-remote yes  # Use on remote SSH (not recommended)
zstyle ':z4m:carapace' debug yes
```

Default exclusions: `ssh` (use native completion for host/key handling).

Over SSH, Carapace is automatically disabled with fallback to native completions.

---

## Atuin History

SQLite-based history with cross-device sync. Requires Atuin v17.0+, v18.0+ recommended.

```zsh
z4m install atuin || return
```

**z4m Configuration:**

```zsh
zstyle ':z4m:atuin' enabled 'no'         # Disable Atuin entirely
zstyle ':z4m:atuin' up-arrow 'yes'       # Use Atuin for up-arrow (default: no, uses prefix search)
zstyle ':z4m:atuin' ctrl-r 'no'          # Disable Ctrl+R binding (use fzf instead)
zstyle ':z4m:atuin' nobind 'yes'         # Disable all Atuin keybindings (for custom bindings)
zstyle ':z4m:atuin' force-remote yes     # Use on remote SSH (not recommended)
zstyle ':z4m:atuin' debug yes            # Show debug info on startup
```

**Atuin config.toml** (`~/.config/atuin/config.toml`):

```toml
# Recommended settings for fzf-like behavior
enter_accept = false              # Edit command before execution (like fzf)
inline_height = 40                # UI height (0 = fullscreen)
style = "compact"                 # compact or full
filter_mode_shell_up_key_binding = "directory"  # Filter by directory for up-arrow
keymap_mode = "vim-normal"        # vim-normal, vim-insert, emacs, auto

# Other useful options
show_preview = true               # Show command preview
show_help = false                 # Hide help bar
```

**Custom keybindings** (when using `nobind`):

```zsh
zstyle ':z4m:atuin' nobind 'yes'
# After z4m init, bind manually:
bindkey '^r' atuin-search         # Atuin v18.0+
bindkey '^[[A' atuin-up-search    # Up arrow
```

Over SSH, Atuin is automatically disabled with fallback to fzf-history.

---

## Auto Update

By default, z4m asks to update every 28 days. Disable with:

```zsh
zstyle ':z4m:' auto-update 'no'
```

Change update interval:

```zsh
zstyle ':z4m:' auto-update-days '14'
```

---

## Recovery & Safe Mode

When configuration errors prevent normal startup, z4m provides two recovery mechanisms.

### Safe Mode

Skip all plugins and provide a minimal shell environment.

**Triggers:**

```bash
# Environment variable (one-time)
Z4M_SAFE_MODE=1 zsh

# Persistent file (permanent until removed)
touch ~/.cache/zsh4monkey/.safe-mode

# Automatic: detected after previous startup failure
```

**Available commands in safe mode:**

| Command | Description |
|---------|-------------|
| `z4m-safe-help` | Show available commands |
| `z4m-safe-edit [file]` | Edit .zshrc or specified file |
| `z4m-safe-reload` | Reload in safe mode |
| `z4m-safe-exit` | Clear state and restart normally |
| `z4m-safe-diagnose` | Show diagnostic information |

### Recovery Shell

Minimal emergency shell when z4m initialization fails completely.

**Triggers:**

```bash
# Command
z4m recovery

# Keyboard shortcut (requires binding)
z4m bindkey z4m-recovery-shell Ctrl+Alt+R

# Automatic: when main.zsh fails to load
```

**Available commands in recovery mode:**

| Command | Description |
|---------|-------------|
| `z4m-recovery-help` | Show available commands |
| `z4m-recovery-edit [file]` | Edit .zshrc or specified file |
| `z4m-recovery-reload` | Attempt to reload zsh |
| `z4m-recovery-exit` | Exit recovery and restart |
| `z4m-recovery-safe-exit` | Restart in safe mode |
| `z4m-recovery-clear-state` | Clear failure markers and restart |
| `z4m-recovery-diagnose` | Show diagnostic information |

### State Files

| File | Purpose |
|------|---------|
| `$Z4M/.last-init-failed` | Created on startup failure, triggers safe mode |
| `$Z4M/.safe-mode` | Persistent safe mode flag |

**Clear all state:**

```bash
rm -f ~/.cache/zsh4monkey/.last-init-failed ~/.cache/zsh4monkey/.safe-mode

# If you can start a normal z4m session:
z4m reset
```

---

## Deferred Loading

Defer slow plugins until after prompt appears. Place **after** `z4m init`:

```zsh
z4m-defer source ~/.local/share/slow-plugin/plugin.zsh
z4m-defer eval "$(slow-tool init zsh)"
```

**Caveats:** Cannot read stdin, output suppressed, runs in ZLE context.

---

## Usage Guide

### Key Bindings

| Action | PC | Mac |
|--------|-----|-----|
| Directory back | `Shift+Left` | `Shift+Left` |
| Directory forward | `Shift+Right` | `Shift+Right` |
| Directory up | `Shift+Up` | `Shift+Up` |
| Directory down | `Shift+Down` | `Shift+Down` |
| Directory history | `Alt+R` | `Alt+R` |
| History search | `Ctrl+R` | `Ctrl+R` |

### Word-based Widgets

Operate on whole shell arguments: `z4m-forward-zword`, `z4m-backward-zword`, `z4m-kill-zword`, `z4m-backward-kill-zword`

### Prompt Tips

**Smoother rendering** (two-line prompt with empty line):

```zsh
POSTEDIT=$'\n\n\e[2A'
```

**Ctrl+D handling:**

```zsh
z4m bindkey z4m-eof Ctrl+D
setopt ignore_eof
```

**Avoid PS2 prompt:**

```zsh
z4m bindkey z4m-accept-line Enter
```

### Completion Tips

**SSH host completions** (when hosts listed in `~/.ssh/config`):

```zsh
zstyle ':completion:*:ssh:argument-1:'       tag-order  hosts users
zstyle ':completion:*:scp:argument-rest:'    tag-order  hosts files users
zstyle ':completion:*:(ssh|scp|rdp):*:hosts' hosts
```

**Glob expand/verify:** Type `rm **/*.orig`, press `Tab` to expand, `Ctrl+/` to undo.

### SSH Config Recommendations

```text
Host *
  ServerAliveInterval 60
  ConnectTimeout 10
  AddKeysToAgent yes
  EscapeChar `
  ControlMaster auto
  ControlPersist 72000
  ControlPath ~/.ssh/s/%C
```

Create `~/.ssh/s` with mode `0700`.

### Backup and Restore

Store in git: `~/.zshenv`, `~/.zshrc`, `~/.p10k*.zsh`

Bootstrap without installer:

```sh
Z4M_BOOTSTRAPPING=1 . ~/.zshenv
```

### Alternative ZDOTDIR

To use `~/.config/zsh`: [migration script](https://gist.github.com/romkatv/ecce772ce46b36262dc2e702ea15df9f)

### Privileged Shell

```zsh
sudo -Es
```

### Homebrew

`HOMEBREW_PREFIX` is set automatically. Use instead of `brew --prefix`:

```zsh
z4m source -- ${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/opt/asdf/libexec/asdf.sh}
```

---

## Quick Reference

Sensible defaults are already enabled. Only configure what you need:

```zsh
# Required: keyboard type
zstyle ':z4m:bindkey' keyboard 'pc'  # or 'mac'

# Optional customizations
zstyle ':z4m:' editor-mode 'vi'                # vi keybindings (default: emacs)
zstyle ':z4m:' prompt-at-bottom 'yes'          # prompt at bottom (requires tmux or `z4m ssh`)
zstyle ':z4m:direnv' enable 'yes'              # auto-source .envrc files
zstyle ':z4m:ssh:*' enable 'yes'               # SSH teleportation
zstyle ':z4m:ssh-agent:' start 'yes'           # start ssh-agent

# Install CLI tools
z4m install eza bat fd rg zoxide carapace atuin || return
```

**Already enabled by default:**
- Shell integration (OSC 133) with semantic prompt jumping
- Command completion notification (OSC 9, >= 30s)
- Recursive directory completion
- CWD propagation in tmux
- Tmux unified navigation (`Ctrl+h/j/k/l`)
- Tmux context-aware window title
- Auto-update prompts (every 28 days)

---

## Commands Reference

| Command | Description |
|---------|-------------|
| `z4m init` | Initialize zsh |
| `z4m update` | Update z4m and plugins |
| `z4m install <plugin>` | Install plugin |
| `z4m source <file>` | Source script |
| `z4m load <dir>` | Load plugin directory |
| `z4m bindkey <widget> <key>` | Bind key |
| `z4m vi-mode <cmd>` | Vi mode control |
| `z4m ssh <host>` | SSH with teleportation |
| `z4m pack` | Create offline installation package |
| `z4m docker` | Run zsh in Docker container |
| `z4m sudo <cmd>` | Run command as root preserving z4m |
| `z4m version` | Show version |
| `z4m help [cmd]` | Show help |
| `z4m debug [on\|off]` | Toggle debug |
| `z4m bench [n]` | Benchmark startup |
| `z4m compile` | Compile zsh files |
| `z4m env` | Show environment |
| `z4m time <cmd>` | Time command execution |
| `z4m recovery` | Enter recovery shell |
| `z4m reset [--no-restart]` | Clear failure markers and caches |
| `z4m uninstall` | Uninstall |
| `z4m-defer <cmd>` | Defer command |

---

## Built-in Utilities

### md

Create directory and cd into it:

```zsh
md myproject
```

### zmv

Batch rename files:

```zsh
zmv '(*).txt' '$1.md'
zmv -n '(*)' '${(L)1}'  # -n for dry run
```

### GPG_TTY

Automatically set to `$TTY` for GPG passphrase prompts.
