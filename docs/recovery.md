# Recovery and Safe Mode

When configuration errors prevent normal startup, z4m provides recovery mechanisms.

## Overview

```
┌─────────────────────────────────────────────────────────────┐
│  Startup Problem Detection                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Normal startup fails?                                      │
│       │                                                     │
│       ▼                                                     │
│  .last-init-failed + cache/last-init-failed.log written     │
│       │                                                     │
│       ▼                                                     │
│  Next startup → Safe Mode (automatic)                       │
│       │                                                     │
│       ├─→ Fix issue → z4m-safe-exit → Normal mode           │
│       │                                                     │
│       └─→ Can't fix → z4m recovery → Recovery Shell         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Safe Mode

Minimal shell environment with plugins disabled.

### Triggers

| Method | Description |
|--------|-------------|
| Environment | `Z4M_SAFE_MODE=1 zsh` |
| File | `touch ~/.cache/zsh4monkey/.safe-mode` |
| Automatic | Previous startup failed |

### Available Commands

| Command | Description |
|---------|-------------|
| `z4m-safe-help` | Show available commands |
| `z4m-safe-edit [file]` | Edit .zshrc or specified file |
| `z4m-safe-reload` | Reload shell in safe mode |
| `z4m-safe-exit` | Clear state and restart normally |
| `z4m-safe-diagnose` | Show diagnostic information |

### Workflow

1. **Identify the problem**:
   ```bash
   z4m-safe-diagnose
   ```

2. **Edit configuration**:
   ```bash
   z4m-safe-edit           # Edit ~/.zshrc
   z4m-safe-edit ~/.p10k.zsh  # Edit specific file
   ```

3. **Test the fix**:
   ```bash
   z4m-safe-reload         # Reload in safe mode
   ```

4. **Exit safe mode**:
   ```bash
   z4m-safe-exit           # Clears markers and restarts
   ```

## Recovery Shell

Emergency shell when z4m initialization fails completely.

### Triggers

| Method | Description |
|--------|-------------|
| Command | `z4m recovery` |
| Keyboard | Bind `z4m-recovery-shell` to a key |
| Automatic | main.zsh fails to load |

### Available Commands

| Command | Description |
|---------|-------------|
| `z4m-recovery-help` | Show available commands |
| `z4m-recovery-edit [file]` | Edit .zshrc or specified file |
| `z4m-recovery-reload` | Attempt normal reload |
| `z4m-recovery-exit` | Exit recovery and restart |
| `z4m-recovery-safe-exit` | Restart in safe mode |
| `z4m-recovery-clear-state` | Clear all failure markers |
| `z4m-recovery-diagnose` | Show diagnostic information |

### Binding Recovery Key

```zsh
z4m bindkey z4m-recovery-shell Ctrl+Alt+R
```

## State Files

| File | Purpose |
|------|---------|
| `$Z4M/.last-init-failed` | Transient failure marker (next startup enters safe mode) |
| `$Z4M/.safe-mode` | Persistent safe mode flag |
| `$Z4M/cache/last-init-failed.log` | Detailed init failure diagnostics (key=value lines) |

Default location: `~/.cache/zsh4monkey/`

Note: `.last-init-failed` is a trigger file and is typically cleared once you enter safe mode. Use `cache/last-init-failed.log` for persistent diagnostics; it is cleared automatically on the next successful init (or via manual cleanup).

## Clearing State

### Using Commands

```bash
# In safe mode
z4m-safe-exit

# In recovery mode
z4m-recovery-clear-state

# In normal mode
z4m reset
```

### Manual Cleanup

```bash
rm -f ~/.cache/zsh4monkey/.last-init-failed
rm -f ~/.cache/zsh4monkey/.safe-mode
rm -f ~/.cache/zsh4monkey/cache/last-init-failed.log
```

## Common Issues

### Plugin causing crash

1. Enter safe mode:
   ```bash
   Z4M_SAFE_MODE=1 zsh
   ```

2. Comment out the problematic plugin:
   ```bash
   z4m-safe-edit
   # Comment out: z4m load some-plugin
   ```

3. Exit safe mode:
   ```bash
   z4m-safe-exit
   ```

### Syntax error in .zshrc

1. The error message shows line number
2. Enter safe mode and fix:
   ```bash
   Z4M_SAFE_MODE=1 zsh
   z4m-safe-edit
   ```

### Infinite loop on startup

1. Force safe mode from another terminal:
   ```bash
   touch ~/.cache/zsh4monkey/.safe-mode
   ```

2. Then start new shell and fix the issue

### Can't start any zsh

1. Start bash:
   ```bash
   /bin/bash
   ```

2. Clear z4m state:
   ```bash
   rm -rf ~/.cache/zsh4monkey
   ```

3. Restart zsh

## Reset Command

Full reset of z4m state:

```bash
z4m reset              # Clear state and restart
z4m reset --no-restart # Clear state only
```

This removes:
- Failure markers (`.last-init-failed`, `.safe-mode`)
- Completion caches (`cache/zcompdump-*`, `cache/zcompcache-*`)
- `gitstatus` cache (`cache/gitstatus`)
- Powerlevel10k instant prompt cache (`cache/powerlevel10k/p10k-instant-prompt-*.{zsh,zwc}`)

It does not remove installed plugins or z4m-managed repositories; it only clears failure markers and a small set of caches.

## Diagnostics

### z4m-safe-diagnose Output

```
=== z4m Safe Mode Diagnostics ===

Previous startup failed (log present).
Log: /Users/me/.cache/zsh4monkey/cache/last-init-failed.log

Failure log:
  type=init
  epoch=1700000000
  pid=12345
  ppid=6789
  rc=1
  fail_step=init-zle
  fail_step_rc=1

Key paths:
  ZDOTDIR: /Users/me
  Z4M:     /Users/me/.cache/zsh4monkey
```

### Debug Mode

Enable verbose logging:

```bash
Z4M_DEBUG=1 zsh
```

Or toggle at runtime:

```bash
z4m debug on
z4m debug off
```

## Preventing Issues

### Test Configuration Changes

Before making significant changes:

```bash
# Test in subshell
zsh -c 'source ~/.zshrc'
```

### Backup Configuration

```bash
cp ~/.zshrc ~/.zshrc.backup
cp ~/.p10k.zsh ~/.p10k.zsh.backup
```

### Gradual Changes

When adding new plugins or configurations:

1. Add one change at a time
2. Open a new terminal to test
3. Keep the old terminal open as fallback

## Technical Details

### How Safe Mode Works

Safe mode:
1. Sets `Z4M_SAFE_MODE=1`
2. Skips plugin loading
3. Provides minimal prompt
4. Registers recovery commands

### How Failure Detection Works

1. If `z4m init` fails, z4m writes a failure marker and log:
   - `$Z4M/.last-init-failed` (marker that triggers safe mode)
   - `$Z4M/cache/last-init-failed.log` (diagnostics)
2. Next startup sees the marker file → enters safe mode automatically
3. Safe mode copies marker contents into the log (if needed), then clears the marker
4. A successful init clears both the marker and the log to avoid stale diagnostics

### Implementation Files

| File | Purpose |
|------|---------|
| `fn/-z4m-safe-mode-init` | Safe mode initialization |
| `fn/-z4m-recovery-shell` | Recovery shell |
| `fn/-z4m-cmd-reset` | Reset command |
| `fn/-z4m-show-failure-log` | Shared helper to display failure status/log |
