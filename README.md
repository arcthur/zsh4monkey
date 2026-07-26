# zsh4monkey

A modern, feature-rich Zsh configuration that just works. Built for developers who want a powerful shell without the configuration overhead.

## Features

- **Zero-config excellence** - Works great out of the box
- **Measured startup** - PTY-based time-to-ready benchmarking with p50 and p95 reporting
- **Syntax highlighting** - Built-in [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) with 256-color themes
- **Smart autosuggestions** - Built-in [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
- **AI assist lanes** - Manual rewrite + natural-language command intent, with optional conservative autosuggest fallback
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

For a stable, provenance-verified installation:

```shell
z4m_installer=$(mktemp)
trap 'rm -f -- "$z4m_installer"' EXIT HUP INT TERM
curl -fsSLo "$z4m_installer" https://github.com/arcthur/zsh4monkey/releases/latest/download/install
gh attestation verify "$z4m_installer" \
  --repo arcthur/zsh4monkey \
  --signer-workflow arcthur/zsh4monkey/.github/workflows/release.yml
sh "$z4m_installer"
```

Release installers pin and verify all bootstrap files. Attestation is what makes
a stable install trustworthy: the `.sha256` sidecar ships from the same host as
the archive, so it detects transport corruption rather than tampering. Stable
bootstrap and update therefore require GitHub CLI. Public attestations can
normally be read without authentication; if GitHub requests credentials or the
anonymous API limit is exhausted, run `gh auth login` or set `GH_TOKEN`. See
[SECURITY.md](SECURITY.md) for the full trust model, including what
`Z4M_ALLOW_CHECKSUM_ONLY_RELEASES=1` actually gives up.

The development channel follows mutable `main` and is intentionally unverified:

```shell
z4m_installer=$(mktemp)
trap 'rm -f -- "$z4m_installer"' EXIT HUP INT TERM
curl -fsSLo "$z4m_installer" https://raw.githubusercontent.com/arcthur/zsh4monkey/main/install
Z4M_INSTALL_REF=main sh "$z4m_installer"
```

Interactive installation backs up existing files, guides configuration, and can
prompt to make the selected zsh binary the login shell during initialization.
Cache and startup-file activation is transactional, with the previous state
restored after handled failures. For automation, use the explicit
non-interactive contract:

```shell
sh "$z4m_installer" --non-interactive \
  --keyboard pc --editor emacs --tmux no --direnv no \
  --existing backup --no-bootstrap
```

## Requirements

- **Zsh 5.9+** (installer downloads prebuilt binary if needed)
- `curl` or `wget`, plus `tar`
- **GitHub CLI** for stable release provenance verification
- Python 3 for `z4m bench`
- Linux or macOS

## Key Bindings

| Key | Action |
|-----|--------|
| `Tab` | Completion with fzf |
| `/` (in fzf) | Accept and continue path completion |
| `Ctrl+R` | Search history |
| `Alt+R` | Directory history |
| `Alt+M` | Accept autosuggestion |
| `Ctrl+O` | Trigger manual AI rewrite for current line (no prefix required) |
| `Up`/`Down` | History prefix search |
| `Alt+Left`/`Right` | Directory back/forward |
| `Alt+Up`/`Down` | Directory up/down |

> On Mac with `keyboard 'mac'`: use `Shift+Arrow` instead of `Alt+Arrow`.

## Commands

| Command | Description |
|---------|-------------|
| `z4m init` | Initialize zsh |
| `z4m update [--no-restart]` | Update z4m and managed dependencies |
| `z4m install <pkg>` | Register dependency in install queue |
| `z4m ssh <host>` | SSH with teleportation |
| `z4m bindkey <widget> <key>` | Bind key |
| `z4m vi-mode on\|off\|toggle` | Toggle vi mode |
| `z4m ai [--print\|--json\|--queue] "<query>"` | Generate a reviewable command without executing it |
| `z4m ai proxy [status\|on\|off]` | Manage tmux output-context proxy (v1, optional) |
| `z4m autosuggest [status\|doctor\|events\|reset]` | Autosuggestions subsystem diagnostics |
| `z4m highlight [status|doctor|events|reset]` | Highlight subsystem diagnostics |
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

# Built-in syntax highlight theme
zstyle ':z4m:highlight' theme 'clean'  # or 'catppuccin-mocha'

# SSH teleportation
zstyle ':z4m:ssh:*' enable 'no'
zstyle ':z4m:ssh:myserver' enable 'yes'
# Matches the SSH target you pass to z4m and the resolved HostName fallback.
zstyle ':z4m:ssh:*' send-extra-files '--dest my-conf/zsh/.zshrc ~/.zshrc' '--exclude *.tmp ~/.config/nvim'
zstyle ':z4m:ssh:*' env 'EDITOR=_z4m_copy_env_var_' 'COLORTERM=truecolor'
zstyle ':z4m:ssh:*' cwd 'src/project'
zstyle ':z4m:ssh:*' interpreter 'sh'

# CLI tools
z4m install eza bat fd rg zoxide || return

# Carapace completion engine
z4m install carapace || return

# Atuin history
z4m install atuin || return
```

See [docs/config.md](docs/config.md) for complete reference, [docs/autosuggest.md](docs/autosuggest.md) for autosuggest lanes, and [docs/fzf-completion.md](docs/fzf-completion.md) for fzf features.

### Prompt

Run `p10k configure` to customize. Edit `~/.p10k.zsh` for manual tweaks.

## SSH Teleportation

Your shell environment transfers to remote hosts automatically:

```zsh
z4m ssh user@host
```

For interactive hosts, `z4m ssh` can also start in a chosen remote directory and use a specific POSIX bootstrap shell via `:z4m:ssh:* cwd` and `:z4m:ssh:* interpreter`.

- Each session uploads a fresh runtime snapshot before entering the remote shell
- No git, zsh, or sudo required on remote
- Supports ProxyJump (`-J`) for bastion hosts
- Non-interactive SSH usages are passed through to the underlying `ssh`
- SSH sessions use a simplified prompt and disable inline autosuggestions and syntax highlighting for redraw stability

## Docker

Try the explicitly unverified development channel without changing the host:

```shell
docker run -e TERM -e COLORTERM -w /root -it --rm alpine sh -uec '
  apk add zsh curl tmux
  curl -fsSLo /tmp/z4m-install https://raw.githubusercontent.com/arcthur/zsh4monkey/main/install
  Z4M_INSTALL_REF=main sh /tmp/z4m-install --non-interactive \
    --keyboard pc --editor emacs --tmux no --direnv no \
    --existing delete --no-bootstrap
  exec zsh -l'
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
  ├── fzf/          # Optional fzf integration state
  ├── powerlevel10k/# Managed prompt theme
  ├── zsh-users/    # Plugins
  └── cache/        # Compiled files
```

## License

MIT
