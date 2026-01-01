# Context-Aware Tmux Window Naming

## Overview

Dynamic tmux window naming that reflects your current context:
- **Project name**: Detected from directory structure
- **Git branch**: With dirty indicator (`*`) for uncommitted changes
- **Running command**: With Nerd Font icon during execution

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  Tmux Window Name (status bar)                              │
│  Format: project:branch* or  command                       │
│  Example:  backend:main* →  nvim → backend:main           │
├─────────────────────────────────────────────────────────────┤
│  Lifecycle:                                                 │
│    1. chpwd   → Update to project:branch context            │
│    2. preexec → Show running command with icon              │
│    3. precmd  → Restore to project:branch context           │
└─────────────────────────────────────────────────────────────┘
```

## Examples

| Context | Window Name |
|---------|-------------|
| In `~/work/backend` on `main` branch, clean | `backend:main` |
| In `~/work/backend` on `main` branch, dirty | `backend:main*` |
| Running `nvim` | ` nvim` |
| Running `docker compose up` | ` docker` |
| Running `npm install` | ` npm` |
| In `~/Downloads` (no project) | `Downloads` |

## Configuration

All settings use zstyle. Add to your `.zshrc`:

```zsh
# Enable/disable (default: yes when in tmux)
zstyle ':z4m:tmux-title' enable yes

# Show git branch (default: yes)
zstyle ':z4m:tmux-title' git-branch yes

# Show command icons (default: yes)
zstyle ':z4m:tmux-title' command-icons yes

# Maximum title length (default: 24)
zstyle ':z4m:tmux-title' max-length 24
```

### Disable Feature

```zsh
zstyle ':z4m:tmux-title' enable no
```

### Disable Git Branch

```zsh
zstyle ':z4m:tmux-title' git-branch no
# Result: Shows "backend" instead of "backend:main*"
```

### Disable Command Icons

```zsh
zstyle ':z4m:tmux-title' command-icons no
# Result: Shows "nvim" instead of " nvim"
```

## Project Detection

Projects are detected by walking up the directory tree and looking for these markers:

| Marker | Project Type |
|--------|--------------|
| `.git` | Git repository |
| `package.json` | Node.js |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `pyproject.toml` | Python |
| `Makefile` | Make |
| `CMakeLists.txt` | CMake |
| `build.gradle` / `pom.xml` | Java |
| `composer.json` | PHP |
| `Gemfile` | Ruby |
| `mix.exs` | Elixir |
| `deno.json` | Deno |

If no project marker is found, the current directory name is used.

## Git Integration

### Fast Path: gitstatus

If [gitstatus](https://github.com/romkatv/gitstatus) is available (used by powerlevel10k), it provides instant git status via async queries. This is the fastest method.

### Fallback: Direct Git

When gitstatus is not available, direct git commands are used:
- `git symbolic-ref --short HEAD` for branch name
- `git diff --quiet` for dirty detection

### Dirty Indicator

The `*` suffix appears when any of these conditions are true:
- Staged changes exist
- Unstaged changes exist
- Untracked files exist

## Command Icons

Icons are displayed when running commands. Requires a [Nerd Font](https://www.nerdfonts.com/).

### Supported Commands

| Command | Icon | Command | Icon |
|---------|------|---------|------|
| nvim/vim |  | python |  |
| node/npm |  | docker |  |
| ssh |  | git |  |
| cargo |  | go |  |
| make |  | kubectl | 󱃾 |
| lazygit |  | tmux |  |
| curl |  | brew |  |

Full list in `fn/-z4m-init-tmux-title`.

### Fallback

Unknown commands show no icon (command name only).

## Requirements

- **Tmux**: Must be running inside tmux
- **Nerd Font**: For command icons (optional, can be disabled)
- **gitstatus**: For fast git status (optional, falls back to git)

## Troubleshooting

### Window name not updating

1. Verify you're inside tmux:
   ```bash
   echo $TMUX
   ```

2. Check if the feature is enabled:
   ```bash
   zstyle -L ':z4m:tmux-title'
   ```

3. Verify hooks are registered:
   ```bash
   add-zsh-hook -L chpwd | grep tmux-title
   ```

### Icons not displaying

Ensure your terminal uses a Nerd Font. Test with:
```bash
echo ""  # Should show a folder icon
```

### Git branch not showing

1. Verify you're in a git repository:
   ```bash
   git rev-parse --git-dir
   ```

2. Check if git-branch is enabled:
   ```bash
   zstyle -t ':z4m:tmux-title' git-branch && echo "enabled" || echo "disabled"
   ```

### Performance issues

If you notice lag, the git fallback may be slow on large repositories. Install gitstatus for better performance:
```bash
# Already included with powerlevel10k
# Or install standalone:
git clone https://github.com/romkatv/gitstatus.git ~/.gitstatus
echo 'source ~/.gitstatus/gitstatus.plugin.zsh' >> ~/.zshrc
```

## Integration with Tmux Status Bar

For best results, ensure tmux's `automatic-rename` is disabled:

```tmux
# ~/.tmux.conf
setw -g automatic-rename off
```

This prevents tmux from overriding the programmatic window names.
