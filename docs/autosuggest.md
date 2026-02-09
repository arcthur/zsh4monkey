# Autosuggestions

## Overview

z4m autosuggestions are built into the core runtime and designed for three goals:

- Keep input latency low (local strategies first, AI non-blocking fallback).
- Keep output safe and reviewable (suggest/queue only, never auto-execute).
- Keep behavior observable (`status`, `doctor`, `events`) and easy to debug.

The subsystem combines local history-based suggestions with optional AI lanes:

```
Local strategies (history/history_pwd/match_prev_cmd)
  -> if no local suggestion -> AI fallback lane (non-blocking)

Manual AI rewrite lane (Ctrl+O by default)
Intent command lane (z4m ai "...")
```

## Lanes and Responsibilities

### Local Lanes (Primary Fast Path)

| Lane | Purpose | Blocking behavior |
|------|---------|-------------------|
| `history` | Basic prefix completion from shell history | Non-blocking |
| `history_pwd` | Prefer commands used in current directory | Non-blocking |
| `match_prev_cmd` | Contextual completion based on preceding command pattern | Non-blocking |

### AI Lanes (Optional)

| Lane | Entry point | Purpose | Apply behavior |
|------|-------------|---------|----------------|
| `autosuggest_fallback` | Internal fetch cycle | Fallback suggestion when local lanes miss | Writes suggestion overlay only |
| `manual_rewrite` | `z4m-autosuggest-ai-trigger` (`Ctrl+O` by default) | Rewrite/extend current buffer | No input prefix required; provider `+` -> overlay, `=` -> replace `BUFFER` |
| `intent_command` | `z4m ai "<query>"` | Convert natural language intent into one command | Queues result via `print -z` |

## Key Bindings and Entry Points

| Key / Command | Action |
|---------------|--------|
| `Alt+M` | Accept current autosuggestion |
| `Ctrl+O` | Trigger manual AI rewrite lane |
| `z4m ai "<query>"` | Intent command lane |
| `z4m ai proxy status|on|off` | Manage tmux output-context proxy (v1) |
| `z4m autosuggest status|doctor|events|reset` | Diagnostics and state inspection |

## Runtime Flow

### Fetch Cycle

```
ZLE pre-redraw
  -> local suggestion strategies
  -> if local miss: AI fallback submit/harvest (async)
  -> quality gate
  -> update POSTDISPLAY (never execute)
```

### Manual Rewrite Cycle

```
Ctrl+O
  -> submit manual_rewrite request
  -> harvest response (+/= protocol)
  -> stale-buffer check
  -> apply to POSTDISPLAY or BUFFER
  -> show transient status line (auto-clears on next edit or short timeout)
  -> redraw
```

### Intent Command Cycle

```
z4m ai "query"
  -> submit intent_command request
  -> harvest response (+/= protocol)
  -> return one command line
  -> print -z (queued, not executed)
```

## AI Response Protocol

Provider output must be exactly one protocol line:

- `+<suffix>`: append-style suggestion
- `=<full command>`: full-line rewrite

Any other output is rejected as `invalid_protocol`.

## Context Strategy (Built-in)

Context policy is fixed in code:

- Project context: always enabled.
- Output context: only enabled for `manual_rewrite` and `intent_command`.
- Output source: fixed chain `tmux capture-pane -> proxy tail`.
- Kitty-specific branch: not implemented.

If context capture fails, request continues without output context (safe degradation).

## Safety and Quality Gates

- AI never bypasses local validation gates.
- AI results are single-line validated before apply.
- Stale buffer protection drops outdated manual results.
- Request budgets are enforced (per-minute and per-day token budgets).
- Missing API key disables AI lane with explicit reject reason.
- Generated commands are never auto-executed.

## Configuration

For the full table, see `config.md`. Most users only need to set AI enable + API key.

### Core Autosuggest

```zsh
zstyle ':z4m:autosuggestions' enabled yes
zstyle ':z4m:autosuggestions' strategy 'history_pwd history'
```

### AI Lanes

```zsh
zstyle ':z4m:autosuggestions:ai' enabled yes
export DEEPSEEK_API_KEY='your-token'

# Optional tuning
zstyle ':z4m:autosuggestions:ai' mode passive
zstyle ':z4m:autosuggestions:ai' rewrite-key '^O'
zstyle ':z4m:autosuggestions:ai' intent-command-enabled yes
zstyle ':z4m:autosuggestions:ai' proxy-enabled no
```

Legacy context toggles are ignored (safe no-op):

- `:z4m:autosuggestions:ai context-project-enabled`
- `:z4m:autosuggestions:ai context-output-enabled`
- `:z4m:autosuggestions:ai context-output-source`

## Diagnostics and Observability

### Status

```zsh
z4m autosuggest status
z4m autosuggest status --json
```

Includes lifecycle, active strategy/provider, and AI lane state (manual/intent inflight + last result/apply result).

### Doctor

```zsh
z4m autosuggest doctor
```

Checks include:

- strategy/config validity
- runtime readiness
- AI config sanity (timeouts, token limits, key binding)
- fixed context policy contract
- tmux/proxy degrade semantics

### Events

```zsh
z4m autosuggest events --tail 30
```

Common event types:

- `ai-trigger`, `ai-submit`, `ai-result`
- `manual_trigger`, `rewrite_apply`
- `intent_query`
- `context_source_hit`
- `proxy_state_change`

## Failure and Degrade Semantics

- Non-tmux environments (for example Ghostty without tmux): output context degrades to `none`.
- `z4m ai proxy on` outside tmux returns a clear failure and does not break main flow.
- Provider/network errors are surfaced as structured reject reasons.
- Recovery remains local-first: local suggestion lanes continue even when AI is unavailable.

## Troubleshooting

### AI lane does not run

1. Verify config and API key:

```zsh
z4m autosuggest doctor
z4m autosuggest status
```

2. Check reject/error fields and recent events:

```zsh
z4m autosuggest events --tail 50
```

### `z4m ai` returns no queued command

1. Verify `intent-command-enabled` is on.
2. Check network/provider errors in `last_reject` / `last_error`.
3. Ensure provider output matches `+` / `=` protocol.

### Manual rewrite not applied

1. Confirm rewrite key binding and `rewrite-enabled`.
2. Check `manual_last_apply_result` for `stale_buffer` or `invalid_protocol`.
3. Retry on a stable buffer (rapid edits can intentionally invalidate stale results).

### `z4m ai: applied_*` message stays visible

The status message is transient and is expected to clear on the next edit, or after a short timeout.
If it does not clear, restart the shell to ensure the latest runtime cache (`.zwc`) is loaded.
