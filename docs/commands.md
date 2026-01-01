# Commands Reference

## Core Commands

| Command | Description |
|---------|-------------|
| `z4m init` | Initialize zsh (called in .zshrc) |
| `z4m update` | Update z4m and z4m-managed packages |
| `z4m version` | Show version information |
| `z4m help [cmd]` | Show help for command |

## Plugin Management

| Command | Description |
|---------|-------------|
| `z4m install <plugin>` | Install a plugin, or register a CLI tool integration |
| `z4m load <dir>` | Load a plugin directory |
| `z4m source <file>` | Source a script file |

### Installing Tools

```bash
z4m install eza bat fd rg zoxide fzf carapace atuin || return
```

Note: for CLI tools, `z4m install` does not install the binaries; it registers integrations and runs post-install checks.
See [cli-tools.md](cli-tools.md) for details.

### Loading Plugins

```bash
z4m load ~/.local/share/my-plugin
```

## SSH

| Command | Description |
|---------|-------------|
| `z4m ssh <host>` | Connect with shell teleportation |
| `z4m ssh --force-sync <host>` | Force full configuration sync |
| `z4m ssh -J <jump> <host>` | Connect via jump host |

See [ssh.md](ssh.md) for details.

## Container & Privilege

| Command | Description |
|---------|-------------|
| `z4m docker [image]` | Run zsh in Docker container |
| `z4m sudo <cmd>` | Run command as root preserving z4m |
| `z4m pack` | Create offline installation package |

### Docker Usage

```bash
z4m docker              # Run in default container
z4m docker ubuntu:22.04 # Run in specific image
```

### Sudo Usage

```bash
z4m sudo vim /etc/hosts  # Edit as root with z4m environment
```

## Key Bindings

| Command | Description |
|---------|-------------|
| `z4m bindkey <widget> <key>` | Bind a widget to a key |

### Examples

```bash
z4m bindkey z4m-cd-down Shift+Down
z4m bindkey z4m-recovery-shell Ctrl+Alt+R
z4m bindkey z4m-eof Ctrl+D
```

See [keybindings.md](keybindings.md) for available widgets.

## Vi Mode

| Command | Description |
|---------|-------------|
| `z4m vi-mode on` | Enable vi mode |
| `z4m vi-mode off` | Disable vi mode |
| `z4m vi-mode toggle` | Toggle vi mode |
| `z4m vi-mode status` | Show current mode |

## Debugging & Performance

| Command | Description |
|---------|-------------|
| `z4m debug <subcommand>` | Debug utilities (mode, tracing, info) |
| `z4m bench [n]` | Benchmark startup time (n iterations) |
| `z4m time <cmd>` | Time command execution |
| `z4m tty-wait -t <seconds> -p <pattern>` | Wait for terminal size to match a `LINES COLUMNS` pattern (non-tmux) |
| `z4m env` | Show z4m environment variables |
| `z4m history-debug` | Show effective history-search wiring (widgets, flags, key bindings) |
| `z4m env-propagation-diagnose [<base64>]` | Validate/inspect SSH env propagation payload (reads stdin if omitted) |

### Benchmark Example

```bash
z4m bench 10  # Average of 10 startup times
```

### Debug Example

```bash
z4m debug on
# ... perform operations ...
z4m debug off
```

### Debug Subcommands

- `on` / `off`: enable or disable debug mode
- `warn`: enable `WARN_NESTED_VAR` only
- `trace <func>` / `untrace <func>`: enable or disable per-function tracing
- `status`: show current debug status
- `info`: print detailed environment info

## Recovery

| Command | Description |
|---------|-------------|
| `z4m recovery` | Enter recovery shell |
| `z4m reset` | Clear failure markers and caches |
| `z4m reset --no-restart` | Clear state without restarting |

See [recovery.md](recovery.md) for details.

## Maintenance

| Command | Description |
|---------|-------------|
| `z4m compile` | Compile zsh files for faster loading |
| `z4m uninstall` | Uninstall z4m |

## Deferred Execution

| Command | Description |
|---------|-------------|
| `z4m-defer <cmd>` | Defer command until after prompt |

### Usage

Place after `z4m init`:

```zsh
z4m-defer source ~/.local/share/slow-plugin/plugin.zsh
z4m-defer eval "$(slow-tool init zsh)"
```

### Caveats

- Cannot read stdin
- Output is suppressed
- Runs in ZLE context

## Built-in Utilities

### md

Create directory and cd into it:

```bash
md myproject  # mkdir -p myproject && cd myproject
```

### zmv

Batch rename files:

```bash
zmv '(*).txt' '$1.md'           # Rename .txt to .md
zmv -n '(*)' '${(L)1}'          # Dry run: lowercase
zmv '(**/)(*).jpeg' '$1$2.jpg'  # Recursive rename
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `Z4M` | z4m installation directory |
| `Z4M_SSH` | Set on remote: `local:remote` format |
| `Z4M_SAFE_MODE` | Set to `1` to force safe mode |
| `Z4M_DEBUG` | Set to `1` for debug output |
| `GPG_TTY` | Automatically set to `$TTY` |

## Widget Commands

These are ZLE widgets, not shell commands. Bind them to keys:

| Widget | Description |
|--------|-------------|
| `z4m-cd-up` | Navigate to parent directory |
| `z4m-cd-down` | Navigate into subdirectories (fzf) |
| `z4m-cd-back` | Go back in directory history |
| `z4m-cd-forward` | Go forward in directory history |
| `z4m-fzf-dir-history` | Browse directory history |
| `z4m-fzf-history` | Search command history |
| `z4m-accept-line` | Accept line (avoid PS2 prompt) |
| `z4m-eof` | Handle Ctrl+D gracefully |
| `z4m-recovery-shell` | Enter recovery shell |

### Default Key Bindings

| Key | Widget |
|-----|--------|
| `Shift+Up` | `z4m-cd-up` |
| `Shift+Down` | `z4m-cd-down` |
| `Shift+Left` | `z4m-cd-back` |
| `Shift+Right` | `z4m-cd-forward` |
| `Alt+R` | `z4m-fzf-dir-history` |
| `Ctrl+R` | `z4m-fzf-history` or atuin |

See [keybindings.md](keybindings.md) for complete reference.
