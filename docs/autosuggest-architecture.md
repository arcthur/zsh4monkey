# Autosuggest Architecture

This document describes z4m's built-in autosuggestions subsystem after L5.

## Goals

- Keep autosuggestions built into z4m (no remote install path).
- Keep lifecycle and diagnostics owned by z4m.
- Keep overlay ownership clear: autosuggest writes suggestion state, highlight writes `region_highlight`.
- Preserve interaction ordering with ZLE, vi mode, fzf widgets, and Atuin widgets.

## Runtime Model

Core module: `fn/-z4m-autosuggest-core`

State is tracked in:

- `_z4m_autosuggest_state` (associative array)
- `_z4m_autosuggest_events` (array ring buffer)

Lifecycle states:

- `uninitialized`
- `initializing`
- `ready`
- `degraded`
- `disabled`

## Public Configuration

- `:z4m:autosuggestions enabled` -> `yes|no`
- `:z4m:autosuggestions strategy` -> `history|match_prev_cmd`
- `:z4m:autosuggestions buffer-min-size` -> non-negative integer (optional)
- `:z4m:autosuggestions match-prev-max-cmds` -> positive integer or `-1`
- `:z4m:autosuggestions match-prev-cmd-count` -> positive integer
- `:z4m:autosuggestions forward-char` -> `accept|partial-accept`
- `:z4m:autosuggestions end-of-line` -> `accept|partial-accept`

No package channel setting controls autosuggestions anymore.

## Runtime Entrypoints

- init: `-z4m-autosuggest-init` -> `-z4m-autosuggest-core-init`
- fetch: `-z4m-autosuggest-fetch` -> `-z4m-autosuggest-core-fetch`
- reset: `-z4m-autosuggest-reset` -> `-z4m-autosuggest-core-reset`
- pending redraw bridge: `-z4m-autosuggest-core-pre-redraw`

`POSTDISPLAY`, `_z4m_autosuggest_buffer`, `_z4m_autosuggestion` are owned by autosuggest core.
Highlight overlay composition remains in `fn/-z4m-highlight-core`.

## Vendor Policy

Vendor source is under `vendor/zsh-autosuggestions`.

Metadata file: `vendor/zsh-autosuggestions/.z4m-vendor-meta`

Rules:

- Any vendor change must update `.z4m-vendor-meta` in the same change set.
- z4m runs vendor in library mode (`Z4M_ZAS_LIBRARY_MODE=1`).
- z4m owns highlight overlay composition (`Z4M_ZAS_EXTERNAL_HIGHLIGHT=1`).
- In library mode, vendor binds only the "special widgets" lists (clear/accept/partial-accept/execute).
  z4m fetches suggestions from the redraw loop instead of wrapping every widget.
- completion strategy is disabled in library mode to avoid completion/focus conflicts.
- z4m carries correctness patches for widget binding and invocation semantics:
  - preserve `ZLE_KILL` / `ZLE_YANK` / `ZLE_YANKBEFORE` flags
  - bind underscore-prefixed widgets except internal `_zsh_autosuggest_*`
  - robust completion widget binding under custom `IFS`
  - invoke original widgets with `zle -w` to keep widget context

## Diagnostics CLI

`z4m autosuggest` provides:

- `status [--json] [--init]`
- `doctor [--json] [--no-init]`
- `events [--tail N] [--json]`
- `reset [--json]`

`doctor` exit codes:

- `0`: healthy
- `1`: warnings/degraded
- `2`: errors
