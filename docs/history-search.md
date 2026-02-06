# History Search

## Overview

z4m provides a unified history search system with intelligent fallback:

```
Atuin (if enabled) → Substring Search (embedded) → Prefix Search (builtin)
```

This gives you Fish-style history search out of the box, with optional cloud sync via Atuin.

## Key Bindings

### Local History (Current Session First)

| Key | Widget | Description |
|-----|--------|-------------|
| `Up` / `Ctrl+P` | `z4m-history-up` | Previous matching command |
| `Down` / `Ctrl+N` | `z4m-history-down` | Next matching command |

### Global History (All Sessions)

| Key | Widget | Description |
|-----|--------|-------------|
| `Ctrl+Up` | `z4m-history-up-global` | Previous (all history) |
| `Ctrl+Down` | `z4m-history-down-global` | Next (all history) |

### Interactive Search

| Key | Widget | Description |
|-----|--------|-------------|
| `Ctrl+R` | Atuin or fzf | Full-text fuzzy search |
| `Alt+R` | `z4m-fzf-dir-history` | Directory history |

## How It Works

### Substring Search (Default)

Type any part of a previous command and press `Up`:

```
$ docker<Up>
# Matches: docker run -it ubuntu
#          docker-compose up
#          sudo docker ps
```

Features:
- **Fuzzy matching (optional)**: Enable to match words in order (see `HISTORY_SUBSTRING_SEARCH_FUZZY` below)
- **Case-insensitive**: By default, searches ignore case
- **Highlighting**: Matched portions are highlighted in the result
- **Unique results**: Duplicate commands are filtered by default

### Atuin Integration

When Atuin is installed and configured for up-arrow, it takes precedence:

```zsh
zstyle ':z4m:atuin' up-arrow yes
```

Atuin provides:
- SQLite-based history with full-text search
- Cross-device sync (optional)
- Context-aware filtering (by directory, session, etc.)

Over SSH, z4m disables Atuin by default for faster startup. Override with:

```zsh
zstyle ':z4m:atuin' force-remote yes
```

## Fallback Chain

```
┌─────────────────────────────────────────────────────────┐
│                    User presses Up                      │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
              ┌──────────────────────────┐
              │ Atuin up-arrow enabled?  │
              └──────────────────────────┘
                    │            │
                   yes           no
                    │            │
                    ▼            ▼
            ┌──────────┐  ┌─────────────────────┐
            │  Atuin   │  │ Substring loaded?   │
            │ up-search│  └─────────────────────┘
            └──────────┘        │            │
                               yes           no
                                │            │
                                ▼            ▼
                        ┌────────────┐  ┌────────────┐
                        │ Substring  │  │   Prefix   │
                        │   Search   │  │   Search   │
                        └────────────┘  └────────────┘
```

## Configuration

### Atuin

```zsh
# Enable Atuin for up-arrow (default: no, uses substring search)
zstyle ':z4m:atuin' up-arrow yes

# Disable Atuin for Ctrl+R (use fzf instead)
zstyle ':z4m:atuin' ctrl-r no

# Disable all Atuin key bindings (for custom setup)
zstyle ':z4m:atuin' nobind yes

# Force Atuin on remote SSH (not recommended)
zstyle ':z4m:atuin' force-remote yes

# Debug mode
zstyle ':z4m:atuin' debug yes
```

### Substring Search

```zsh
# Highlight colors
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='bg=magenta,fg=white,bold'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='bg=red,fg=white,bold'

# Case sensitivity (default: case-insensitive)
HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS='i'   # 'i' = insensitive, '' = sensitive

# Fuzzy matching (match words in order, not contiguous)
HISTORY_SUBSTRING_SEARCH_FUZZY=1

# Prefix mode (only match from start of command)
HISTORY_SUBSTRING_SEARCH_PREFIXED=1

# Unique results (filter duplicates, default: yes)
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1

# Cursor-aware mode: search using text before cursor only
HISTORY_SUBSTRING_SEARCH_CURSOR_AWARE=1
```

### Cursor-Aware Search

When `HISTORY_SUBSTRING_SEARCH_CURSOR_AWARE=1` is set, the search uses only the text **before** the cursor (`$LBUFFER`) as the search pattern. This enables matching commands that continue beyond where you've typed.

This applies to both fuzzy and non-fuzzy matching: cursor-aware mode changes the query source (`$LBUFFER` vs `$BUFFER`), not the matching algorithm.

**Example:**
```
$ docker run -it ub|     # cursor at end of "ub"
# Press Up
# Matches: "docker run -it ubuntu:latest"
#          "docker run -it ubuntu bash"
# Cursor stays at position 17 (after "ub")
```

**Use cases:**
- Partial command recall with room for modification
- Finding command variations without typing the full prefix
- Fish-shell style behavior

**Default behavior** (cursor-aware disabled):
- Uses entire buffer as search pattern
- Cursor moves to end of line after match

### History File

```zsh
# Custom history file location
HISTFILE=~/.local/share/zsh/history

# History size (z4m defaults to effectively infinite)
HISTSIZE=1000000000
SAVEHIST=1000000000
```

## Local vs Global History

z4m distinguishes between:

- **Local history**: Commands from the current terminal session
- **Global history**: All commands from all sessions

By default, `Up`/`Down` search local history first. Use `Ctrl+Up`/`Ctrl+Down` for global search.

This prevents interference between concurrent sessions while allowing access to the full history when needed.

## Vi Mode

In vi mode, history navigation is available in both insert and normal modes:

### Insert Mode (viins)

| Key | Action |
|-----|--------|
| `Up` / `Ctrl+P` | Previous (local) |
| `Down` / `Ctrl+N` | Next (local) |
| `Ctrl+Up` | Previous (global) |
| `Ctrl+Down` | Next (global) |

### Normal Mode (vicmd)

| Key | Action |
|-----|--------|
| `k` / `Up` | Previous (local) |
| `j` / `Down` | Next (local) |
| `Ctrl+Up` | Previous (global) |
| `Ctrl+Down` | Next (global) |

## Multi-line Commands

When navigating multi-line commands, `Up`/`Down` first move within the command:

```
$ docker run \
    -it \
    ubuntu    # cursor here
# Press Up: moves to previous line within command
# Press Up again at top: searches history
```

## Comparison

| Feature | Prefix Search | Substring Search | Atuin |
|---------|---------------|------------------|-------|
| Match position | Start only | Anywhere | Anywhere |
| Fuzzy matching | No | Optional | Yes |
| Cursor-aware | No | Optional | Yes |
| Highlighting | No | Yes | Yes |
| Cross-device sync | No | No | Yes |
| Context filtering | No | No | Yes |
| Requires binary | No | No | Yes |

## Troubleshooting

### Search not finding expected commands

1. Check if you're in local vs global mode:
   ```zsh
   # Use Ctrl+Up for global search
   ```

2. Check if unique filtering is hiding duplicates:
   ```zsh
   HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=''
   ```

3. Check if Atuin is intercepting:
   ```zsh
   zstyle ':z4m:atuin' debug yes
   # Then restart shell and check output
   ```

### Highlighting not working

The highlighting backend is built-in fast-syntax-highlighting. Ensure backend is `fast`:

```zsh
zstyle ':z4m:highlight' backend fast  # default
```

To disable syntax highlighting:

```zsh
zstyle ':z4m:highlight' backend none
```

Note: UI overlays such as autosuggestions and history substring-search query highlights are applied independently from the syntax backend.

Run diagnostics:

```zsh
z4m highlight doctor
z4m highlight status --init --json
z4m highlight events --tail 20
```

### Atuin not activating

1. Verify Atuin is installed:
   ```bash
   which atuin
   atuin --version
   ```

2. Check if disabled by configuration:
   ```zsh
   zstyle -L ':z4m:atuin'
   ```

3. Enable debug mode:
   ```zsh
   zstyle ':z4m:atuin' debug yes
   exec zsh
   ```

### Verify effective key bindings

If you suspect a plugin has overridden `Up`/`Down`, run:

```zsh
z4m history-debug
```

## Technical Details

### Implementation Files

| File | Purpose |
|------|---------|
| `fn/-z4m-history-substring-search` | Embedded substring search |
| `fn/z4m-history-up` | Unified up widget (local) |
| `fn/z4m-history-down` | Unified down widget (local) |
| `fn/z4m-history-up-global` | Unified up widget (global) |
| `fn/z4m-history-down-global` | Unified down widget (global) |
| `fn/-z4m-history-up-impl` | Backend detection and dispatch |
| `fn/-z4m-history-down-impl` | Backend detection and dispatch |
| `fn/-z4m-init-atuin` | Atuin initialization |
| `fn/-z4m-with-local-history` | Local/global history scope wrapper |

### State Variables

The embedded substring search uses these variables (compatible with the original zsh-history-substring-search):

| Variable | Purpose |
|----------|---------|
| `_history_substring_search_query` | Current search pattern |
| `_history_substring_search_result` | Last displayed result |
| `_history_substring_search_matches` | Array of matching history indices |
| `_z4m_substring_search_highlight` | Highlight regions for display |

### Atuin Flags

| Flag | Set When |
|------|----------|
| `_z4m_atuin_available` | Atuin binary found and initialized |
| `_z4m_atuin_ctrl_r` | Atuin handles Ctrl+R binding |
| `_z4m_atuin_up_arrow` | Atuin handles up-arrow binding |
