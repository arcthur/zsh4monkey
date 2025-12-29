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
│    Ctrl+h/j/k/l → Check buffer state                        │
│                   ├─ Empty  → Delegate to tmux select-pane  │
│                   └─ Non-empty → Edit/history operations    │
└─────────────────────────────────────────────────────────────┘
```

## Zsh Behavior Details

| Key | Buffer Empty | Buffer Non-empty |
|-----|--------------|------------------|
| `C-h` | → tmux pane left | backward-delete-char |
| `C-j` | → tmux pane down | Last line → pane; else history↓ |
| `C-k` | → tmux pane up | First line → pane; else history↑ |
| `C-l` | → tmux pane right | clear-screen |

**Design Rationale**:
- When no command is being typed, the intent is pane switching
- When editing a command, preserve useful traditional behaviors

## Complete Keybinding Reference

| Function | Neovim | Tmux | Zsh |
|----------|--------|------|-----|
| **Navigation** | | | |
| Left | `C-h` | `prefix+h` | `C-h` (empty buffer) |
| Down | `C-j` | `prefix+j` | `C-j` (empty buffer) |
| Up | `C-k` | `prefix+k` | `C-k` (empty buffer) |
| Right | `C-l` | `prefix+l` | `C-l` (empty buffer) |
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
   → z4m-nav-right detects non-empty buffer, executes clear-screen
   → Screen clears, continue editing command

4. Need to force pane switch regardless of buffer state
   → Press prefix+h/j/k/l
```

## Troubleshooting

### Ctrl+h displays `^H`

Tmux is not forwarding keys:
```bash
tmux source ~/.tmux.conf
```

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
