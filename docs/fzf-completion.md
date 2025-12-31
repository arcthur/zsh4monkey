# FZF Completion

## Overview

z4m integrates fzf for fuzzy completion, providing an interactive interface when multiple completions are available.

## Basic Usage

Press `Tab` to trigger completion. When multiple matches exist, fzf opens for selection.

| Key | Action |
|-----|--------|
| `Tab` / `Shift+Tab` | Navigate items |
| `Enter` | Accept selection |
| `Ctrl+Space` | Toggle + move down |
| `Ctrl+A` | Toggle all |
| `/` | Accept and continue (path completion) |
| `Esc` | Cancel |

## Features

### Continuous Completion

For path completion, press `/` to accept the current selection and immediately continue completing the next level.

```
$ cd ~/pr<Tab>
  > projects/
    private/
# Press / on "projects/"
$ cd ~/projects/<Tab>
  > work/
    personal/
```

This eliminates the need for repeated `Tab` presses when navigating deep directory structures.

### Accept Line

Configure a key to accept completion and execute the command immediately:

```zsh
zstyle ':z4m:fzf-complete' accept-line 'ctrl-x'
```

Press `Ctrl+X` in fzf to insert the selection and run the command in one action.

### File Coloring

Completions are colored based on `LS_COLORS`, showing file types at a glance:
- Directories in blue
- Executables in green
- Symlinks in cyan
- etc.

### Recursive Directory Search

When completing paths, fzf can recursively search subdirectories:

```zsh
zstyle ':z4m:fzf-complete' recurse-dirs yes  # default
```

### Preview

Enabled by default. Shows context-aware preview for completions:

| Context | Preview |
|---------|---------|
| Files | `bat` with syntax highlighting (falls back to `head`) |
| Directories | `eza -la` or `ls -la` |
| Git branches | `git log` with delta (if available) |
| Git diff/add | `git diff` with delta |
| Git show | `git show` with delta |
| Git stash | `git stash show -p` with delta |
| Tmux sessions | Window list with flags |
| Tmux windows | Pane list with commands |
| Tmux commands | Current state (options, buffers, etc.) |
| Docker | Container/image info |

```zsh
# Disable preview
zstyle ':z4m:fzf-complete' fzf-preview no

# Custom preview command
zstyle ':z4m:fzf-complete' fzf-preview 'bat --color=always {}'
```

## Configuration

### Triggers

```zsh
# Continuous completion trigger (default: /)
zstyle ':z4m:fzf-complete' continuous-trigger '/'

# Accept and execute trigger (default: disabled)
zstyle ':z4m:fzf-complete' accept-line 'ctrl-x'
```

### Appearance

```zsh
# Tmux popup mode (requires fzf 0.54+, tmux)
zstyle ':z4m:fzf-complete' fzf-tmux 'popup'  # or: top, bottom, left, right

# Highlight current line (fzf 0.52+)
zstyle ':z4m:fzf-complete' fzf-highlight-line yes

# Line wrapping (fzf 0.56+)
zstyle ':z4m:fzf-complete' fzf-wrap yes

# Custom pointer/marker (fzf 0.54+)
zstyle ':z4m:*' fzf-pointer '>'
zstyle ':z4m:*' fzf-marker '+'
```

### Custom fzf Flags

```zsh
zstyle ':z4m:fzf-complete' fzf-flags --border=rounded --margin=1
```

### Key Bindings in fzf

```zsh
# Format: key:action
zstyle ':z4m:fzf-complete' fzf-bindings 'ctrl-y:accept' 'ctrl-e:abort'
```

Default bindings:

| Key | Action |
|-----|--------|
| `Ctrl+H` | Delete word backward |
| `Ctrl+U` / `Alt+J` | Clear query |
| `Ctrl+K` | Kill to end of line |
| `Alt+K` | Kill to start of line |
| `Ctrl+Space` | Toggle + move down |
| `Ctrl+A` | Toggle all |
| `Ctrl+/` / `Alt+P` | Toggle preview |
| `Alt+T` | Track current item |

## Version Features

z4m automatically detects fzf version and enables available features:

| Feature | Minimum fzf Version |
|---------|---------------------|
| Toggle preview | 0.45 |
| Track current | 0.49 |
| Highlight line | 0.52 |
| Tmux popup | 0.54 |
| Pointer/marker | 0.54 |
| Line wrap | 0.56 |
| Path scoring | 0.59 |
