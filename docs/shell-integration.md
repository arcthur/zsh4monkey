# Shell Integration (OSC 133)

## Overview

Shell integration uses OSC 133 escape sequences to mark semantic regions of the terminal:
- **Prompts**: Where commands are entered
- **Command input**: The text the user types
- **Command output**: The results of execution

This enables powerful features in modern terminals and multiplexers.

## Capabilities

### 1. Semantic Prompt Navigation

Jump between prompts in tmux copy-mode:

```
C-Up   → Jump to previous prompt
C-Down → Jump to next prompt
```

**Workflow:**
1. Press `prefix + [` to enter copy-mode
2. Press `C-Up` to jump to the previous prompt
3. Press `C-Down` to jump forward
4. Use visual selection to mark text, `y` to yank

### 2. Output Capture

Copy the output of the last command:

1. Enter copy-mode: `prefix + [`
2. Jump to output start: `C-Up` (goes to previous prompt)
3. Move down one line (to skip the command itself)
4. Select the output region
5. Yank with `y`

### 3. Command Completion Notification

Desktop notification when long-running commands finish:

```
┌──────────────────────────────────┐
│ ✓ cargo build finished (45s)    │
└──────────────────────────────────┘
```

Uses OSC 9 escape sequence for native desktop notifications.

## OSC 133 Protocol

```
precmd   OSC 133;D;$?       end of the previous command, with its exit code
PS1      OSC 133;A … B      prompt start … input start, part of the prompt
PS2      OSC 133;A;k=s … B  secondary prompt start … input start
preexec  OSC 133;C          command output begins
```

A and B live inside the prompt string, so zsh writes them again every time it
redraws the prompt: after a resize, `zle reset-prompt`, or an asynchronous
theme update. Commands and other hooks see `PS1` without them; preexec takes
them out again unless something replaced `PS1` in the meantime.

### Sequence Reference

| Sequence | Name | Meaning |
|----------|------|---------|
| `\e]133;A\a` | Prompt Start | First byte of PS1 |
| `\e]133;A;k=s\a` | Secondary Prompt Start | First byte of PS2 |
| `\e]133;B\a` | Input Start | Last byte of PS1 and PS2; typed input follows |
| `\e]133;C\a` | Output Start | Before command output |
| `\e]133;D;N\a` | Command End | After output, N = exit code |

### Prompt Redraw on Resize

Ghostty and kitty clear the prompt the cursor is in when the window is
resized, starting at its A mark, and let zsh redraw it. Without that, a
multi-line prompt rewrapped by the terminal leaves stale copies behind. Both
act on the marks themselves, so the marks z4m writes are enough, including on
hosts reached with `z4m ssh` where the terminal's own integration is not
loaded. Two details matter:

- A must be repeated on every redraw. Printed once from precmd, a later resize
  can find no prompt start to clear from.
- `k=s` on PS2 tells kitty that the continuation line is a prompt of its own,
  so a resize while a multi-line command is being entered clears only that
  line instead of the lines already entered.

### Who Marks the Prompt

| Prompt | A and B come from |
|--------|-------------------|
| powerlevel10k (default) | p10k itself, with `POWERLEVEL9K_TERM_SHELL_INTEGRATION=true`, which z4m sets unless your config sets it |
| powerlevel10k with that option `false` | precmd prints A; B is printed when line editing starts |
| Any other prompt, including the `z4m ssh` prompt | z4m adds them to `PS1` in precmd |

p10k rebuilds its prompt after every other precmd hook, so z4m lets it place
A and B and keeps writing C and D itself. z4m sets `_z4h_iterm_cmd`, the
variable p10k checks for zsh4humans (z4m's ancestor), so p10k does not write
C and D a second time.

### Terminal Integrations

Ghostty and kitty can load their own shell integration as well. With p10k,
kitty's integration stops marking prompts (p10k turns on its `no-prompt-mark`
option). Ghostty's integration adds its own marks next to z4m's; terminals
treat a repeated mark as the same prompt or command, but if prompt jumps or
command status look doubled, turn one side off: `shell-integration = none` in
Ghostty's config, or `term-shell-integration no` in z4m.

## Configuration

### OSC 133 (Prompt Marking)

```zsh
# Enabled by default. Disable with:
zstyle ':z4m:' term-shell-integration 'no'
```

From zsh 5.10, ZLE can emit OSC 133 and OSC 7 itself. Its `133;D` carries no
exit code, so z4m turns it off with `-integration` in `.term.extensions` and
each mark is sent once. To use the zsh marks instead, list any `integration`
extension in `.term.extensions` before `z4m init` and set
`term-shell-integration` to `no`.

### Command Notification (OSC 9)

```zsh
# Disable notifications entirely
zstyle ':z4m:cmd-notify' enable no

# Set threshold in seconds (default: 30)
zstyle ':z4m:cmd-notify' threshold 30

# Add commands to exclude list
zstyle ':z4m:cmd-notify' exclude 'docker' 'kubectl' 'terraform'
```

### Default Exclusions

These commands are excluded by default (interactive/long-running by nature):

| Category | Commands |
|----------|----------|
| Editors | vim, nvim, vi, nano, emacs |
| Pagers | less, more, man |
| Monitors | top, htop, btop, btm, glances |
| Remote | ssh, mosh, telnet |
| REPLs | python, python3, node, ruby, irb, ghci, lua |
| Databases | mysql, psql, sqlite3, mongosh, redis-cli |
| Multiplexers | tmux, screen |
| Interactive | watch, fzf |

## Requirements

### Terminal Support

Support varies by terminal version and settings.

Known to work with OSC 133 and OSC 9 in common configurations:
- Ghostty
- kitty
- iTerm2
- WezTerm
- VS Code
- Windows Terminal

If you're unsure, use the test commands in the Troubleshooting section to confirm OSC 133 / OSC 9 behavior in your environment.

### Tmux Configuration

For prompt navigation to work through tmux:

```tmux
# ~/.tmux.conf

# Required: allow escape sequences to pass through
set -g allow-passthrough on

# Copy-mode prompt navigation (tmux 3.4+)
bind -T copy-mode-vi C-Up send-keys -X previous-prompt
bind -T copy-mode-vi C-Down send-keys -X next-prompt
```

**Minimum version:** tmux 3.3a (for `allow-passthrough`)
**For prompt navigation:** tmux 3.4+

## Troubleshooting

### Prompt navigation not working

1. Check tmux version:
   ```bash
   tmux -V  # Should be 3.4+
   ```

2. Verify passthrough is enabled:
   ```bash
   tmux show -g allow-passthrough
   # Should show: allow-passthrough on
   ```

3. Verify shell integration is active:
   ```bash
   zstyle -L ':z4m:' term-shell-integration
   # Should show nothing (enabled by default) or 'yes'
   ```

### Notifications not appearing

1. Check if terminal supports OSC 9:
   ```bash
   printf '\e]9;Test notification\a'
   ```
   If no notification appears, your terminal doesn't support OSC 9.

2. Check if feature is enabled:
   ```bash
   zstyle -L ':z4m:cmd-notify'
   ```

3. Check threshold (default 30 seconds):
   ```bash
   # Run a command that takes > 30 seconds
   sleep 35
   # Notification should appear
   ```

### Sequences visible as text

If you see `^[]133;A^G` instead of invisible markers:

1. Terminal doesn't support OSC 133
2. Try a modern terminal (Ghostty, kitty, WezTerm)

## Technical Details

### Implementation Files

| File | Purpose |
|------|---------|
| `fn/-z4m-enable-shell-integration` | OSC 133 sequence emission and prompt marking |
| `fn/-z4m-init-zle` | Chooses who marks the prompt (p10k or z4m) |
| `fn/-z4m-init-cmd-notify` | Command timing and OSC 9 |
| `fn/-z4m-tmux-bypass` | Tmux passthrough wrapper |

### Tmux Passthrough

When running inside tmux, escape sequences z4m writes are also wrapped:

```
\ePtmux;\e\e]133;A\a\e\\
```

This allows the sequence to:
1. Be recognized by tmux for prompt navigation
2. Pass through to the outer terminal

The wrapping is handled automatically by `-z4m-tmux-bypass`.
