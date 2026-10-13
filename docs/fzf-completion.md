# FZF Completion

## Overview

z4m integrates fzf for fuzzy completion, providing an interactive interface when multiple completions are available.

## Data Model (No Hidden Assumptions)

z4m uses a strict, line-based protocol between its completion generators and fzf:

- **Record delimiter**: newline (`\n`). Each selectable item is one line.
- **Field delimiter inside a record**: ASCII NUL (`\0`). This allows separating an internal key from the displayed text.
- **Key encoding**: for path-like completions, the internal key is `r<value>` when the value is printable and has no leading or trailing whitespace, and `b<base64>` otherwise. Keys are single-line and ANSI-free, so control characters in the operational value cannot corrupt the UI protocol, and the common case costs no process spawn. Unknown or malformed keys are rejected.
- **Invariant**: selectable items must not contain newline characters. (This is also a practical limitation because upstream generators read and write line-oriented streams.)

z4m's fzf wrapper always produces a **first line** indicating which key closed fzf:

- Enter is represented as an **empty** first line.
- Custom triggers (e.g. `/` for continuous completion) appear as the literal key string on the first line.

This makes the output parsing stable across all widgets and avoids relying on undefined behavior when multiple `--expect` sources interact.

## Basic Usage

Press `Tab` to trigger completion. When multiple matches exist, fzf opens for selection.
Path completion lists the current directory level only; end the word with `**`
to search recursively (see [Recursive Search](#recursive-search)).

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

### Recursive Search

Plain `Tab` lists only the current level, like fzf-tab and fzf's own
completion. Type `**` at the end of a path word and press `Tab` to list
everything below it:

```
$ cd ~/Projects/**<Tab>     # directories below ~/Projects
$ vim src/**<Tab>           # files and directories below src
$ vim src/ma**<Tab>         # entries matching ma*, plus everything below them
```

If the word completes unambiguously (a single directory), z4m descends into it
and opens the recursive listing there. If nothing gets completed, the `**` is
restored.
`Shift+Down` (`z4m-cd-down`) offers the same recursive listing for `cd`.

Recursive listings are bounded so they stay responsive in large trees such as
`$HOME`:

- **Backend**: [fd](https://github.com/sharkdp/fd) when installed (`fd` or
  `fdfind`), otherwise `bfs`, otherwise `find`. fd honors `.gitignore`, `.ignore`
  and `.fdignore`, and runs depth by depth so shallow paths appear first.
- **Depth**: at most `max-depth` path components below the completion base
  (default `6`; `0` means unlimited).
- **Pruning**: `find-exclude` names are skipped at any depth (default `.git`
  and `node_modules`). Hidden entries need `setopt glob_dots`. Traversal stays
  on one filesystem and follows symlinks.
- **macOS**: `~/Library` is skipped when listing `$HOME`, since Finder hides it
  too. Complete `~/Library/**` explicitly or `setopt glob_dots` to include it.

```zsh
zstyle ':z4m:fzf-complete' recurse-trigger '**'   # default; '' disables
zstyle ':z4m:fzf-complete' recurse-dirs yes       # recurse on plain Tab (default: no)
zstyle ':z4m:*' max-depth 8                       # fzf-complete, cd-down, fzf-dir-history
zstyle ':z4m:*' find-exclude .git node_modules target
```

Setting `find-command` or `find-flags` switches to the legacy find-compatible
pipeline, which ignores `max-depth` and `find-exclude`.

### Preview

Enabled by default. Shows context-aware preview for completions:

| Context | Preview |
|---------|---------|
| Files | Metadata + `bat` with syntax highlighting (binary files shown with `xxd`) |
| Directories | `eza -la` or `ls -la` |
| Git branches | Upstream status (ahead/behind) + `git log` |
| Git diff/add/reset | File status + staged/unstaged diffs |
| Git show/log | Commit summary + changed files + patch |
| Git stash | Stats + full diff |
| Git worktree | Uncommitted changes + recent commits |
| Tmux sessions | Window list with pane counts |
| Tmux windows | Pane list with commands and sizes |
| Docker | Container/image/volume/network info |
| Workmux | Uncommitted changes + recent commits |
| kill/pkill | Process info (PID, user, CPU, memory, command) |
| gh (GitHub CLI) | PR/issue title, state, author, changed files |

```zsh
# Disable preview
zstyle ':z4m:fzf-complete' fzf-preview no

# Custom preview command
# Note: z4m uses NUL-delimited records in fzf.
# - {1} is the internal key field
# - {2} is the displayed text field
zstyle ':z4m:fzf-complete' fzf-preview 'bat --color=always -- {2}'
```

## Configuration

### Triggers

```zsh
# Recursive listing trigger typed before Tab (default: **)
zstyle ':z4m:fzf-complete' recurse-trigger '**'

# Continuous completion trigger (default: /)
zstyle ':z4m:fzf-complete' continuous-trigger '/'

# Accept and execute trigger (default: disabled)
zstyle ':z4m:fzf-complete' accept-line 'ctrl-x'
```

### Appearance

```zsh
# Tmux popup mode (requires fzf 0.54+, tmux)
zstyle ':z4m:fzf-complete' fzf-tmux 'popup'  # or: top, bottom, left, right

# Highlight current line (fzf 0.52+, enabled by default)
zstyle ':z4m:fzf-complete' fzf-highlight-line no

# Line wrapping (fzf 0.56+, enabled by default)
zstyle ':z4m:fzf-complete' fzf-wrap no

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
