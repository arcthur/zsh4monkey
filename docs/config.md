# Configuration Reference

All configuration uses `zstyle`. Place settings in `~/.zshrc` before `z4m init`.

## Core

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m: editor-mode` | string | `emacs` | Editing mode: `emacs` or `vi` |
| `:z4m: prompt-at-bottom` | bool | `yes` | Position prompt at terminal bottom |
| `:z4m: chsh` | bool | `yes` | Change login shell to zsh |
| `:z4m: propagate-cwd` | bool | `yes` | Propagate CWD to new terminals |
| `:z4m: term-shell-integration` | bool | `yes` | Enable OSC 133 shell integration |
| `:z4m: start-tmux` | array | `(isolated)` | Tmux startup mode |
| `:z4m: check-orphan-rc-zwc` | bool | `yes` | Check for orphaned compiled files |

## Keyboard

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:bindkey keyboard` | string | `pc` | Layout: `pc` or `mac` |
| `:z4m:bindkey macos-option-as-alt` | bool | `yes` | Treat Option as Alt on macOS |

## FZF Completion

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:fzf-complete continuous-trigger` | string | `/` | Key to accept and continue path completion |
| `:z4m:fzf-complete accept-line` | string | — | Key to accept and execute command |
| `:z4m:fzf-complete recurse-dirs` | bool | `yes` | Enable recursive directory search |
| `:z4m:fzf-complete fzf-preview` | bool/string | `yes` | Preview: `yes`, `no`, or custom command |
| `:z4m:fzf-complete find-command` | array | auto | File finder: `(bfs)` or `(fd)` |
| `:z4m:fzf-complete find-flags` | array | — | Extra flags for find command |
| `:z4m:fzf-complete fzf-command` | array | `(fzf)` | fzf binary and base args |
| `:z4m:fzf-complete fzf-flags` | array | — | Extra fzf flags |
| `:z4m:fzf-complete fzf-bindings` | array | — | Custom key bindings (`key:action`) |
| `:z4m:fzf-complete fzf-tmux` | string | — | Tmux popup: `popup`, `top`, `bottom`, `left`, `right` |
| `:z4m:fzf-complete fzf-highlight-line` | bool | `yes` | Highlight current line (fzf 0.52+) |
| `:z4m:fzf-complete fzf-wrap` | bool | `yes` | Wrap long lines (fzf 0.56+) |
| `:z4m:* fzf-pointer` | string | — | Pointer character (fzf 0.54+) |
| `:z4m:* fzf-marker` | string | — | Multi-select marker (fzf 0.54+) |
| `:z4m:* fzf-theme` | string | auto | Theme: `dark`, `light`, or custom |

See [fzf-completion.md](fzf-completion.md) for details.

## Autosuggestions

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:autosuggestions forward-char` | bool | `yes` | Accept suggestion on cursor right |
| `:z4m:autosuggestions end-of-line` | bool | `yes` | Accept suggestion on end-of-line |

## Terminal Title

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:term-title:local preexec` | string | `${1//\%/%%}` | Title during command (local) |
| `:z4m:term-title:local precmd` | string | `%~` | Title at prompt (local) |
| `:z4m:term-title:ssh preexec` | string | `%n@%m: ${1//\%/%%}` | Title during command (SSH) |
| `:z4m:term-title:ssh precmd` | string | `%n@%m: %~` | Title at prompt (SSH) |

## Tmux Title

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:tmux-title enable` | bool | `yes` | Enable tmux pane titles |
| `:z4m:tmux-title max-length` | int | `24` | Maximum title length |

## Tmux Navigation

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:tmux-nav enable` | bool | `yes` | Enable Ctrl+hjkl navigation |
| `:z4m:tmux-nav mode` | string | `unified` | Mode: `unified`, `pane`, `disabled` |
| `:z4m:tmux-nav resize-bindings` | bool | `yes` | Enable Ctrl+Alt+hjkl resize |

See [tmux-unified-nav.md](tmux-unified-nav.md) for details.

## CLI Tools

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:eza enabled` | bool | `yes` | Enable eza aliases |
| `:z4m:bat enabled` | bool | `yes` | Enable bat aliases |
| `:z4m:zoxide enabled` | bool | `yes` | Enable zoxide integration |

## Carapace

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:carapace enabled` | bool | `yes` | Enable carapace completions |
| `:z4m:carapace exclude` | array | — | Commands to exclude |

## Atuin

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:atuin enabled` | bool | `yes` | Enable atuin history |
| `:z4m:atuin up-arrow` | bool | `no` | Use atuin for up-arrow (default: substring search) |
| `:z4m:atuin ctrl-r` | bool | `yes` | Bind Ctrl+R to atuin |
| `:z4m:atuin nobind` | bool | `no` | Disable all atuin bindings |
| `:z4m:atuin force-remote` | bool | `no` | Force atuin on SSH (not recommended) |
| `:z4m:atuin debug` | bool | `no` | Show debug info on startup |

See [docs/history-search.md](history-search.md) for detailed history search documentation.

## SSH Teleportation

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:ssh:* enable` | bool | `no` | Enable for all hosts |
| `:z4m:ssh:<host> enable` | bool | — | Enable for specific host |

## Directory History

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:dir-history: cwd` | string | `%~` | CWD format |
| `:z4m:dir-history: max-size` | int | `1000` | Maximum entries |

## Command Notification

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:cmd-notify enable` | bool | `yes` | Enable long-command notifications |
| `:z4m:cmd-notify threshold` | int | `30` | Minimum seconds before notify |
| `:z4m:cmd-notify exclude` | array | — | Commands to exclude |

## Direnv

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:direnv notify` | bool | `yes` | Show direnv error notifications |

## Docker/Sudo

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:docker term` | string | auto | TERM for docker containers |
| `:z4m:sudo term` | string | auto | TERM for sudo sessions |

## Plugin Installation

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:<plugin> channel` | array | `(stable)` | Update channel |
| `:z4m:<plugin> postinstall` | string | — | Post-install command |

## Examples

```zsh
# Vi mode with custom bindings
zstyle ':z4m:' editor-mode 'vi'

# Mac keyboard layout
zstyle ':z4m:bindkey' keyboard 'mac'

# FZF completion with Ctrl+X to execute
zstyle ':z4m:fzf-complete' accept-line 'ctrl-x'
zstyle ':z4m:fzf-complete' fzf-tmux 'popup'

# SSH teleportation for specific hosts
zstyle ':z4m:ssh:*' enable 'no'
zstyle ':z4m:ssh:devbox' enable 'yes'
zstyle ':z4m:ssh:prod-*' enable 'yes'

# Atuin without Ctrl+R binding
zstyle ':z4m:atuin' ctrl-r no

# Disable specific carapace completions
zstyle ':z4m:carapace' exclude git docker
```
