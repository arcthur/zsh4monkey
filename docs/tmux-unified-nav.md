# Unified Navigation: Neovim + Tmux + Zsh

## First Principles

**Core Principle**: `Ctrl+h/j/k/l` = move left/down/up/right

Regardless of which layer you're in (Neovim, Tmux, Zsh), the same keypress produces the same semantic action.

## Layer Model

```
┌─────────────────────────────────────────────────────────────┐
│  Neovim (smart-splits.nvim)                                 │
│    Ctrl+h/j/k/l → Check if at split boundary                │
│                   ├─ No  → Move to adjacent split           │
│                   └─ Yes → Delegate to tmux select-pane     │
├─────────────────────────────────────────────────────────────┤
│  Tmux                                                       │
│    Ctrl+h/j/k/l → send-keys to application                  │
│    prefix+h/j/k/l → Direct pane navigation (fallback)       │
├─────────────────────────────────────────────────────────────┤
│  Zsh (z4m-nav-* widgets)                                    │
│    Ctrl+h/j/k/l → Move in ZLE when possible                 │
│                   └─ Otherwise → Delegate to tmux select-pane│
└─────────────────────────────────────────────────────────────┘
```

## Zsh Behavior Details

| Key | Buffer Empty | Buffer Non-empty |
|-----|--------------|------------------|
| `C-h` | → tmux pane left | Move cursor left; at buffer start → pane left |
| `C-j` | → tmux pane down | Last line → pane down; otherwise move down (buffer/history) |
| `C-k` | → tmux pane up | First line → pane up; otherwise move up (buffer/history) |
| `C-l` | → tmux pane right | Move cursor right; at buffer end → pane right |

**Design Rationale**:
- Consistent semantics: the same key always means the same direction across layers.
- Boundary delegation: when ZLE cannot move further in that direction, control is delegated to tmux.

## Complete Keybinding Reference

| Function | Neovim | Tmux | Zsh |
|----------|--------|------|-----|
| **Navigation** | | | |
| Left | `C-h` | `prefix+h` | `C-h` (move left; delegates at buffer start/empty) |
| Down | `C-j` | `prefix+j` | `C-j` (delegates at empty buffer/last line) |
| Up | `C-k` | `prefix+k` | `C-k` (delegates at empty buffer/first line) |
| Right | `C-l` | `prefix+l` | `C-l` (move right; delegates at buffer end/empty) |
| **Resize** | | | |
| Shrink width | `A-h` | `prefix+H` | `C-M-h` |
| Grow height | `A-j` | `prefix+J` | `C-M-j` |
| Shrink height | `A-k` | `prefix+K` | `C-M-k` |
| Grow width | `A-l` | `prefix+L` | `C-M-l` |
| **Swap** | | | |
| Swap left | `<leader>wH` | — | — |
| Swap down | `<leader>wJ` | — | — |
| Swap up | `<leader>wK` | — | — |
| Swap right | `<leader>wL` | — | — |

## Installation

### 1. Neovim

Plugin configured at `~/.config/nvim/lua/plugins/tmux-navigation.lua`

```bash
nvim
:Lazy sync
```

Disable LazyVim default `C-h/j/k/l` bindings:

```lua
-- ~/.config/nvim/lua/config/keymaps.lua
vim.keymap.del("n", "<C-h>")
vim.keymap.del("n", "<C-j>")
vim.keymap.del("n", "<C-k>")
vim.keymap.del("n", "<C-l>")
```

### 2. Tmux

```tmux
# ~/.tmux.conf

# Forward Ctrl+h/j/k/l to applications
bind-key -n C-h send-keys C-h
bind-key -n C-j send-keys C-j
bind-key -n C-k send-keys C-k
bind-key -n C-l send-keys C-l

# Fallback: prefix+h/j/k/l for direct pane navigation
bind-key h select-pane -L
bind-key j select-pane -D
bind-key k select-pane -U
bind-key l select-pane -R
```

### 3. Zsh

Enabled by default. Optional configuration:

```zsh
# ~/.zshrc

# Enable/disable unified navigation entirely (default: enabled in tmux)
zstyle ':z4m:tmux-nav' enable yes

# Navigation mode: unified (default) | pane | disabled
zstyle ':z4m:tmux-nav' mode unified

# Enable Ctrl+Alt+h/j/k/l for pane resizing
zstyle ':z4m:tmux-nav' resize-bindings yes
```

## Workflow Example

```
Scenario: 3 tmux panes - left zsh, center neovim, right zsh

1. Editing in neovim, want to switch to left zsh pane
   → Press C-h, neovim detects leftmost split, calls tmux select-pane -L
   → Now in left zsh pane

2. In left zsh, want to switch to right neovim
   → Command line is empty, press C-l
   → z4m-nav-right detects empty buffer, calls tmux select-pane -R
   → Now back in neovim

3. In left zsh typing a command, press C-l
   → z4m-nav-right moves the cursor right
   → When the cursor is at the end of the buffer, C-l delegates to tmux select-pane -R

4. Need to force pane switch regardless of buffer state
   → Press prefix+h/j/k/l
```

## Troubleshooting

### Ctrl+h displays `^H`

Tmux is not forwarding keys:
```bash
tmux source ~/.tmux.conf
```

If your terminal sends Backspace as `C-h`, Backspace may also trigger left navigation.
Configure your terminal/tmux to send DEL (`^?`) for Backspace if you want Backspace to remain a delete key.

### Neovim navigation not working

Check smart-splits.nvim:
```vim
:checkhealth smart-splits
```

### Zsh not switching panes

Confirm running inside tmux:
```bash
echo $TMUX
```

Check widget registration:
```bash
zle -la | grep z4m-nav
```
