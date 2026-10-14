# Commands Reference

## Core Commands

| Command | Description |
|---------|-------------|
| `z4m init` | Initialize zsh (called in .zshrc) |
| `z4m update [--no-restart]` | Update z4m and managed packages; optionally return without restarting |
| `z4m rollback [--list]` | Switch back to the previously installed version, or list installed versions |
| `z4m version` | Show version information |
| `z4m help [cmd]` | Show help for command |

Versioned installations use the stable release channel by default. Stable
bootstrap and update require GitHub CLI for artifact attestation verification;
verification is restricted to the repository's release workflow. Public
attestations normally work anonymously; use `gh auth login` or `GH_TOKEN` if
GitHub requests credentials or the anonymous API limit is exhausted. `main`
remains an explicitly unverified development channel.

The framework is installed under `$Z4M/versions/` and reached through the
`current` symlink, so an update builds its candidate aside and activates it with
a single atomic switch: an update that fails at any point leaves the running
installation untouched, and a shell started during an update keeps using the
active version instead of waiting. `z4m rollback` points that same switch at the
previous version, which costs one symlink write and no network access.

The standalone installer supports both interactive setup and a declarative
automation mode:

```shell
sh install --non-interactive \
  --keyboard pc --editor emacs --tmux no --direnv no \
  --existing backup --no-bootstrap
```

Existing files default to `backup`; `delete` and `fail` are explicit
alternatives. Non-interactive mode does not bootstrap a new shell unless
`--bootstrap` is supplied. Cache and startup-file replacements are staged as
one transaction; handled activation failures restore the previous cache and
startup files.

| Installer option | Meaning |
|------------------|---------|
| `--non-interactive` | Disable prompts and use explicit or documented default values |
| `--keyboard mac\|pc` | Select the keyboard layout |
| `--editor emacs\|vi` | Select editor keybindings |
| `--tmux yes\|no` | Enable or disable automatic tmux startup |
| `--direnv yes\|no` | Enable or disable direnv integration |
| `--existing backup\|delete\|fail` | Choose how existing startup files are handled |
| `--bootstrap` / `--no-bootstrap` | Start initialization immediately or stop after writing files |

## Plugin Management

| Command | Description |
|---------|-------------|
| `z4m install <package>` | Register a plugin or built-in package in the install queue |
| `z4m load <dir>` | Load a plugin directory |
| `z4m source <file>` | Source a script file |

### Installing Tools

```bash
z4m install eza bat fd rg zoxide fzf carapace atuin || return
```

Note: for CLI tools, `z4m install` does not install the binaries; it registers integrations and runs post-install checks.
See [cli-tools.md](cli-tools.md) for details.

Resolve the queue immediately when needed:

```bash
z4m install --resolve fzf powerlevel10k
```

### Loading Plugins

```bash
z4m load ohmyzsh/ohmyzsh/plugins/emoji-clock   # relative to $Z4M
z4m load ~/.local/share/my-plugin
```

`z4m load` adds the directory and its `functions/` to `fpath` and sources the
first entry point it finds: `init.zsh`, `<dir>.plugin.zsh`, or the only
`*.plugin.zsh` in the directory (for example `zsh-auto-notify` ships
`auto-notify.plugin.zsh`). Plugins that only provide `functions/` or completion
functions need no entry point. A missing directory, several candidate
`*.plugin.zsh` files, or a directory with nothing to load is reported and makes
the command fail; load such plugins with `z4m source <dir>/<file>`.

## SSH

| Command | Description |
|---------|-------------|
| `z4m ssh <host>` | Connect with shell teleportation |
| `z4m ssh -J <jump> <host>` | Connect via jump host |

Interactive `z4m ssh` sessions use one-shot bootstrap and then hand control to the remote shell. For redraw stability, remote SSH sessions use a simplified prompt and disable inline autosuggestions and syntax highlighting.

See [ssh.md](ssh.md) for details.

## Container & Privilege

| Command | Description |
|---------|-------------|
| `z4m docker [docker-args...]` | Run `docker` with z4m TERM compatibility wrapper |
| `z4m sudo [sudo-args...]` | Run `sudo` with z4m TERM compatibility wrapper |
| `z4m pack` | Create offline installation package |

See [design-pack.md](design-pack.md) for how `z4m pack` works and what it includes.

### Docker Usage

```bash
z4m docker ps
z4m docker run --rm -it ubuntu:22.04 bash
```

### Sudo Usage

```bash
z4m sudo -v
z4m sudo vim /etc/hosts
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
| `z4m bench [n] [--json] [--timeout seconds]` | Measure time to the first fully initialized prompt in a PTY |
| `z4m time <cmd>` | Time command execution |
| `z4m tty-wait -t <seconds> -p <pattern>` | Wait for terminal size to match a `LINES COLUMNS` pattern (non-tmux) |
| `z4m env` | Show z4m environment variables |
| `z4m history-debug` | Show effective history-search wiring (widgets, flags, key bindings) |

## AI & Suggestion Diagnostics

| Command | Description |
|---------|-------------|
| `z4m ai [--print\|--json\|--queue] "<query>"` | Generate one reviewable command; non-interactive calls print instead of queueing |
| `z4m ai proxy [status\|on\|off]` | Manage tmux-only output-context proxy (optional) |
| `z4m autosuggest [status\|doctor\|events\|reset]` | Inspect autosuggest/AI lane status, checks, and events |
| `z4m highlight [status\|doctor\|events\|reset]` | Inspect the syntax-highlight backend status, checks, and events |

### Benchmark Example

```bash
z4m bench 10
z4m bench 20 --json
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
| `z4m-defer <cmd> [arg ...]` | Defer an argv-preserving command until after prompt |

### Usage

Place after `z4m init`:

```zsh
z4m-defer source ~/.local/share/slow-plugin/plugin.zsh
z4m-defer eval 'eval "$(slow-tool init zsh)"'
```

Arguments are retained exactly as passed. String evaluation only occurs when
`eval` is explicitly supplied as the deferred command. Quote command
substitutions that must run later; an unquoted or double-quoted substitution is
expanded by the caller before `z4m-defer` can enqueue it.

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
