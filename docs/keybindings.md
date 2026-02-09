# Key Bindings

## Directory Navigation

| Key | Action | Widget |
|-----|--------|--------|
| `Shift+Up` | Go to parent directory | `z4m-cd-up` |
| `Shift+Down` | Navigate into subdirectories (fzf) | `z4m-cd-down` |
| `Shift+Left` | Go back in directory history | `z4m-cd-back` |
| `Shift+Right` | Go forward in directory history | `z4m-cd-forward` |
| `Alt+R` | Browse directory history | `z4m-fzf-dir-history` |

## History Search

| Key | Action | Widget |
|-----|--------|--------|
| `Up` / `Ctrl+P` | Previous matching command (local) | `z4m-history-up` |
| `Down` / `Ctrl+N` | Next matching command (local) | `z4m-history-down` |
| `Ctrl+Up` | Previous matching command (global) | `z4m-history-up-global` |
| `Ctrl+Down` | Next matching command (global) | `z4m-history-down-global` |
| `Ctrl+R` | Interactive history search | atuin or fzf |

See [history-search.md](history-search.md) for details.

## Autosuggest & AI

| Key | Action | Widget |
|-----|--------|--------|
| `Alt+M` | Accept current autosuggestion | `z4m-autosuggest-accept` |
| `Ctrl+O` | Trigger manual AI rewrite for current line | `z4m-autosuggest-ai-trigger` |

## Tmux Navigation

When unified navigation is enabled (default):

| Key | Buffer Empty | Buffer Non-empty |
|-----|--------------|------------------|
| `Ctrl+H` | Tmux pane left | Move cursor left; at start → pane left |
| `Ctrl+J` | Tmux pane down | At last line → pane down |
| `Ctrl+K` | Tmux pane up | At first line → pane up |
| `Ctrl+L` | Tmux pane right | Move cursor right; at end → pane right |

### Resize (Ctrl+Alt)

| Key | Action |
|-----|--------|
| `Ctrl+Alt+H` | Shrink pane width |
| `Ctrl+Alt+J` | Grow pane height |
| `Ctrl+Alt+K` | Shrink pane height |
| `Ctrl+Alt+L` | Grow pane width |

See [tmux-unified-nav.md](tmux-unified-nav.md) for details.

## Editing

| Key | Action |
|-----|--------|
| `Ctrl+A` | Move to beginning of line |
| `Ctrl+E` | Move to end of line |
| `Ctrl+W` | Delete word backward |
| `Ctrl+U` | Delete to beginning of line |
| `Ctrl+K` | Delete to end of line |
| `Alt+B` | Move backward one word |
| `Alt+F` | Move forward one word |
| `Alt+D` | Delete word forward |
| `Ctrl+/` | Undo |

When running inside tmux with `:z4m:tmux-nav` enabled, `Ctrl+H/J/K/L` follow unified pane-navigation behavior instead of default editing actions.

## Completion

| Key | Action |
|-----|--------|
| `Tab` | Complete / open fzf selector |
| `Shift+Tab` | Undo |

### In fzf Completion

| Key | Action |
|-----|--------|
| `Tab` / `Shift+Tab` | Navigate items |
| `Enter` | Accept selection |
| `Ctrl+Space` | Toggle + move down |
| `Ctrl+A` | Toggle all |
| `/` | Accept and continue (path completion) |
| `Esc` | Cancel |
| `Ctrl+/` / `Alt+P` | Toggle preview |
| `Alt+T` | Track current item |

See [fzf-completion.md](fzf-completion.md) for details.

## Word Operations

| Widget | Description |
|--------|-------------|
| `z4m-forward-zword` | Move forward one shell word |
| `z4m-backward-zword` | Move backward one shell word |
| `z4m-kill-zword` | Delete shell word forward |
| `z4m-backward-kill-zword` | Delete shell word backward |

These operate on complete shell arguments (respecting quotes).

## Vi Mode

### Insert Mode

| Key | Action |
|-----|--------|
| `Escape` | Enter normal mode |
| `Ctrl+[` | Enter normal mode |

No `jk`-style insert-mode escape sequence is configured by default.

### Normal Mode

| Key | Action |
|-----|--------|
| `i` | Insert before cursor |
| `a` | Insert after cursor |
| `I` | Insert at line start |
| `A` | Insert at line end |
| `v` | Visual mode |
| `k` / `Up` | Previous history (local) |
| `j` / `Down` | Next history (local) |
| `Ctrl+Up` | Previous history (global) |
| `Ctrl+Down` | Next history (global) |

### Visual Indicators

- Cursor changes shape: block (normal), beam (insert)
- Autosuggestions hidden in normal mode

## Custom Bindings

### Using z4m bindkey

```zsh
z4m bindkey <widget> <key>
```

### Key Names

| Name | Key |
|------|-----|
| `Ctrl+X` | Ctrl + X |
| `Alt+X` | Alt/Option + X |
| `Shift+X` | Shift + X |
| `Ctrl+Alt+X` | Ctrl + Alt + X |
| `Enter` | Enter/Return |
| `Tab` | Tab |
| `Backspace` | Backspace |
| `Delete` | Delete (PC) / Fn+Delete (Mac) |
| `Up`, `Down`, `Left`, `Right` | Arrow keys |
| `Home`, `End` | Home/End |
| `PageUp`, `PageDown` | Page Up/Down |

### Keyboard Layout

Configure keyboard type for correct key mapping:

```zsh
zstyle ':z4m:bindkey' keyboard 'pc'   # PC layout
zstyle ':z4m:bindkey' keyboard 'mac'  # Mac layout
```

This affects:
- `Delete` key mapping (PC: Delete, Mac: Fn+Delete)
- Option/Alt key behavior

### macOS Option as Alt

Enable Option key as Alt:

```zsh
zstyle ':z4m:bindkey' macos-option-as-alt yes
```

## Examples

### Bind Ctrl+D to graceful exit

```zsh
z4m bindkey z4m-eof Ctrl+D
setopt ignore_eof  # Prevent accidental exit
```

### Bind Enter to avoid PS2 prompt

```zsh
z4m bindkey z4m-accept-line Enter
```

### Bind recovery shell

```zsh
z4m bindkey z4m-recovery-shell Ctrl+Alt+R
```

### Check current bindings

```zsh
bindkey | grep z4m
```

### List all z4m widgets

```zsh
zle -la | grep z4m
```

## Troubleshooting

### Key not working

1. Check if key is being captured:
   ```bash
   cat -v  # Then press the key
   ```

2. Check current binding:
   ```bash
   bindkey "^R"  # For Ctrl+R
   ```

3. Check for conflicts with terminal/tmux

### Tmux key conflicts

Tmux may intercept keys. Check:
```bash
tmux list-keys | grep "C-h"
```

### Terminal-specific issues

Some terminals send different escape sequences. Use `cat -v` to see what your terminal actually sends.
