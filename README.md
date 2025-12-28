# zsh4monkey

A modern, feature-rich Zsh configuration that just works. Built for developers who want a powerful shell without the configuration overhead.

## Features

- **Zero-config excellence** - Works great out of the box
- **Blazing fast** - Sub-50ms startup with [zsh-bench](https://github.com/romkatv/zsh-bench)
- **Syntax highlighting** - Real-time [syntax highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- **Smart autosuggestions** - [Fish-like suggestions](https://github.com/zsh-users/zsh-autosuggestions)
- **Beautiful prompt** - Powered by [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- **Fuzzy search** - [fzf](https://github.com/junegunn/fzf) for completions and history
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
| `z4m help [cmd]` | Show help |
| `z4m uninstall` | Uninstall |

Run `z4m help` for all commands.

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

See [config.md](config.md) for complete reference.

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
