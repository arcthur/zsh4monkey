# CLI Tools

Modern command-line tool replacements integrated with z4m.

## Installation

```zsh
z4m install eza bat fd rg zoxide fzf carapace atuin || return
```

`z4m install` registers these integrations and runs post-install checks.
It does **not** install the tool binaries for you.

Install the actual binaries using your package manager (e.g., Homebrew / apt / dnf / pacman / `cargo install` / `mise`).

## Supported Tools

| Tool | Replaces | Description |
|------|----------|-------------|
| `eza` | `ls` | Modern ls with git integration |
| `bat` | `cat` | Syntax highlighting for files |
| `fd` | `find` | Fast, user-friendly find |
| `rg` | `grep` | Fast recursive grep |
| `zoxide` | `cd` | Smarter directory navigation |
| `fzf` | — | Fuzzy finder |
| `carapace` | — | Multi-shell completion engine |
| `atuin` | — | Shell history with sync |

## eza

Modern replacement for `ls` with colors and git status.

### Aliases

When enabled, z4m creates these aliases:

| Alias | Command | Description |
|-------|---------|-------------|
| `ls` | `eza --group-directories-first` | Basic listing (directories first) |
| `ll` | `eza -la --group-directories-first` | Long format with hidden files |
| `la` | `eza -a --group-directories-first` | All files |
| `lt` | `eza --tree --level=2` | Tree view (depth 2) |
| `tree` | `eza --tree` | Full tree view |

### Configuration

```zsh
# Disable eza integration (use system ls)
zstyle ':z4m:eza' enabled no
```

## bat

Syntax-highlighted file viewer.

### Aliases

| Alias | Command | Description |
|-------|---------|-------------|
| `cat` | `bat --paging=never --style=plain` | View files with highlighting (no pager) |

When enabled and `BAT_THEME` is unset, z4m sets a default theme:

```zsh
export BAT_THEME=TwoDark
```

If `MANPAGER` is unset, z4m also sets:

```zsh
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"
```

### Usage

```bash
bat file.py              # View with syntax highlighting
bat -l json file         # Force language
bat --paging=never file  # No pager
```

### Configuration

```zsh
# Disable bat integration (use system cat)
zstyle ':z4m:bat' enabled no
```

### bat Configuration File

Create `~/.config/bat/config`:

```
--theme="Catppuccin-mocha"
--italic-text=always
--map-syntax "*.zsh:Bourne Again Shell (bash)"
```

## fd

Fast alternative to `find`.

### Usage

```bash
fd pattern              # Find files matching pattern
fd -e py                # Find by extension
fd -H pattern           # Include hidden files
fd -t d pattern         # Directories only
fd -x command {}        # Execute on each result
```

### Integration

z4m uses fd for:
- `z4m-cd-down` widget (Shift+Down)
- fzf file completion when available

## rg (ripgrep)

Fast recursive grep.

### Usage

```bash
rg pattern              # Search in current directory
rg -i pattern           # Case insensitive
rg -t py pattern        # Search only Python files
rg -l pattern           # List files only
rg -C 3 pattern         # Context lines
```

## zoxide

Smarter cd that learns your habits.

### Commands

| Command | Description |
|---------|-------------|
| `z foo` | Jump to directory matching "foo" |
| `z foo bar` | Jump to directory matching "foo" and "bar" |
| `zi` | Interactive selection with fzf |

### Configuration

```zsh
# Disable zoxide integration
zstyle ':z4m:zoxide' enabled no
```

### How It Works

zoxide tracks directory visits and uses frecency (frequency + recency) to rank results:

```bash
z pro        # Jumps to ~/projects if visited frequently
z doc        # Jumps to ~/Documents
zi           # Opens fzf to select from all known directories
```

## fzf

Fuzzy finder used throughout z4m.

### Key Bindings

| Key | Widget | Description |
|-----|--------|-------------|
| `Ctrl+R` | History search | Fuzzy search command history |
| `Tab` | Completion | Fuzzy file/path completion |
| `Shift+Down` | cd-down | Navigate into subdirectories |
| `Alt+R` | dir-history | Directory history |

### Themes

```zsh
zstyle ':z4m:*' fzf-theme 'catppuccin'
```

Available: `dracula`, `gruvbox`, `catppuccin`, `nord`, `tokyonight`, `onedark`, `solarized-dark`, `solarized-light`, `rose-pine`, `kanagawa`

See [fzf-completion.md](fzf-completion.md) for detailed fzf configuration.

## carapace

Multi-shell completion engine with 1000+ command completions.

### Configuration

```zsh
# Disable carapace
zstyle ':z4m:carapace' enabled no

# Exclude specific commands (use native completion)
zstyle ':z4m:carapace' exclude git docker kubectl
```

### Default Exclusions

- `ssh` (native completion handles hosts/keys better)

### Remote Behavior

Carapace is automatically disabled over SSH with fallback to native completions.

## atuin

SQLite-based shell history with optional sync.

### Configuration

```zsh
# Use atuin for up-arrow (default: substring search)
zstyle ':z4m:atuin' up-arrow yes

# Disable atuin for Ctrl+R (use fzf)
zstyle ':z4m:atuin' ctrl-r no

# Disable all atuin bindings (for custom setup)
zstyle ':z4m:atuin' nobind yes
```

### Remote Behavior

Atuin is automatically disabled over SSH with fallback to fzf-history.

See [history-search.md](history-search.md) for detailed history configuration.

## Version Management

### Update Tools

```bash
z4m update  # Updates z4m and its managed dependencies
```

Note: `z4m update` does not upgrade system-level binaries (e.g., Homebrew packages).

### Check Versions

```bash
eza --version
bat --version
fd --version
rg --version
zoxide --version
fzf --version
carapace --version
atuin --version
```

## Troubleshooting

### Tool not found after install

1. Restart shell or run:
   ```bash
   hash -r
   ```

2. Check PATH:
   ```bash
   echo $PATH | tr ':' '\n' | grep local
   ```

### Aliases not working

1. Check if tool is enabled:
   ```bash
   zstyle -L ':z4m:eza'
   zstyle -L ':z4m:bat'
   ```

2. Check if tool is installed:
   ```bash
   which eza
   which bat
   ```

### Colors not showing

1. Check TERM:
   ```bash
   echo $TERM  # Should be *-256color or similar
   ```

2. For bat, check theme:
   ```bash
   bat --list-themes
   ```

## Platform Notes

z4m does not install tool binaries; platform-specific installation details depend on your package manager.
If a tool is installed but not detected by z4m, it is usually a PATH issue (see Troubleshooting).

### SSH/Remote

Over SSH, some tools (carapace, atuin) are automatically disabled for faster connections. Use `force-remote` options to override:

```zsh
zstyle ':z4m:carapace' force-remote yes
zstyle ':z4m:atuin' force-remote yes
```
