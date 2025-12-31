# zsh4monkey

A modern, feature-rich Zsh configuration that just works. Built for developers who want a powerful shell without the configuration overhead.

## Features

- **Zero-config excellence** - Works great out of the box
- **Blazing fast** - Sub-50ms startup with [zsh-bench](https://github.com/romkatv/zsh-bench)
- **Syntax highlighting** - Feature-rich [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) with 256-color themes
- **Smart autosuggestions** - [Fish-like suggestions](https://github.com/zsh-users/zsh-autosuggestions)
- **Beautiful prompt** - Powered by [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- **Fuzzy completion** - [fzf](https://github.com/junegunn/fzf) with continuous path completion and file coloring
- **SSH teleportation** - Your shell environment follows you to remote hosts
- **Vi mode** - Full vi editing with cursor shape changes and p10k integration
- **Modern CLI tools** - Optional integration with eza, bat, fd, rg, zoxide
- **Carapace completion** - Intelligent completions for hundreds of commands
- **Atuin history** - SQLite-based history with cross-device sync
- **Direnv integration** - Fast `.envrc` loading
- **Shell integration** - OSC 133 support for modern terminals

## Quick Start

```shell
if command -v curl >/dev/null 2>&1; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/arcthur/zsh4monkey/main/install)"
else
  sh -c "$(wget -O- https://raw.githubusercontent.com/arcthur/zsh4monkey/main/install)"
fi
```

The installer backs up existing files, guides you through configuration, and sets zsh as your login shell.

## Requirements

- **Zsh 5.9+** (installer downloads prebuilt binary if needed)
- Linux or macOS

## Key Bindings

| Key | Action |
|-----|--------|
| `Tab` | Completion with fzf |
| `/` (in fzf) | Accept and continue path completion |
| `Ctrl+R` | Search history |
| `Alt+R` | Directory history |
| `Alt+M` | Accept autosuggestion |
| `Up`/`Down` | History prefix search |
| `Alt+Left`/`Right` | Directory back/forward |
| `Alt+Up`/`Down` | Directory up/down |

> On Mac with `keyboard 'mac'`: use `Shift+Arrow` instead of `Alt+Arrow`.

## Commands

| Command | Description |
|---------|-------------|
| `z4m init` | Initialize zsh |
| `z4m update` | Update z4m and plugins |
| `z4m install <plugin>` | Install plugin |
| `z4m ssh <host>` | SSH with teleportation |
| `z4m bindkey <widget> <key>` | Bind key |
| `z4m vi-mode on\|off\|toggle` | Toggle vi mode |
| `z4m recovery` | Enter recovery shell |
| `z4m reset [--no-restart]` | Clear failure markers and caches |
| `z4m help [cmd]` | Show help |
| `z4m uninstall` | Uninstall |

Run `z4m help` for all commands.

## Recovery & Safe Mode

When startup fails, z4m automatically enters **safe mode** on the next launch (plugins disabled).

**Manual triggers:**

```bash
# Safe mode (skip all plugins)
Z4M_SAFE_MODE=1 zsh

# Recovery shell (minimal emergency shell)
z4m recovery

# Clear failure markers and caches (when a normal z4m session can start)
z4m reset
```

**Safe mode:** `z4m-safe-help`, `z4m-safe-exit`, `z4m-safe-diagnose`

**Recovery shell:** `z4m-recovery-help`, `z4m-recovery-edit`, `z4m-recovery-diagnose`

## Configuration

Edit `~/.zshrc` before `z4m init`:

```zsh
# Keyboard layout
zstyle ':z4m:bindkey' keyboard 'pc'  # or 'mac'

# Vi editing mode (optional)
zstyle ':z4m:' editor-mode 'vi'

# SSH teleportation
zstyle ':z4m:ssh:*' enable 'no'
zstyle ':z4m:ssh:myserver' enable 'yes'

# CLI tools
z4m install eza bat fd rg zoxide || return

# Carapace completion engine
z4m install carapace || return

# Atuin history
z4m install atuin || return
```

See [docs/config.md](docs/config.md) for complete reference, [docs/fzf-completion.md](docs/fzf-completion.md) for fzf features.

### Prompt

Run `p10k configure` to customize. Edit `~/.p10k.zsh` for manual tweaks.

## SSH Teleportation

Your shell environment transfers to remote hosts automatically:

```zsh
z4m ssh user@host
```

- First connection installs zsh4monkey on remote
- Subsequent connections are instant
- No git, zsh, or sudo required on remote
- Supports ProxyJump (`-J`) for bastion hosts

## Docker

Try without installation:

```shell
docker run -e TERM -e COLORTERM -w /root -it --rm alpine sh -uec '
  apk add zsh curl tmux
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/arcthur/zsh4monkey/main/install)"'
```

## Updating

```shell
z4m update
```

## Uninstalling

```shell
z4m uninstall
```

Or manually: delete `~/.zshenv`, `~/.zshrc`, restart terminal, then `rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/zsh4monkey"`.

## Architecture

```
~/.zshenv           # Bootstrap
~/.zshrc            # User configuration
~/.p10k.zsh         # Prompt configuration
$Z4M/               # Cache directory (~/.cache/zsh4monkey)
  ├── zsh4monkey/   # Core framework
  ├── fzf/          # Fuzzy finder
  ├── powerlevel10k/# Prompt theme
  ├── zsh-users/    # Plugins
  └── cache/        # Compiled files
```

## License

MIT
