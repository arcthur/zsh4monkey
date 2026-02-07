# Autosuggest Architecture

This document describes z4m's built-in autosuggestions subsystem after L5.

## Goals

- Keep autosuggestions built into z4m (no remote install path).
- Keep lifecycle and diagnostics owned by z4m.
- Keep overlay ownership clear: autosuggest writes suggestion state, highlight writes `region_highlight`.
- Preserve interaction ordering with ZLE, vi mode, fzf widgets, and Atuin widgets.

## Runtime Model

Core module: `fn/-z4m-autosuggest-core`
AI sidecar module: `fn/-z4m-autosuggest-ai`

State is tracked in:

- `_z4m_autosuggest_state` (associative array)
- `_z4m_autosuggest_events` (array ring buffer)
- `_z4m_autosuggest_ai_state` (associative array)

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
- `:z4m:autosuggestions:ai enabled` -> `yes|no`
- `:z4m:autosuggestions:ai endpoint` -> OpenAI-compatible base URL (default `https://api.deepseek.com/v1`)
- `:z4m:autosuggestions:ai model` -> provider model id (default `deepseek-chat`)
- `:z4m:autosuggestions:ai api-key-env` -> API key environment variable name (default `DEEPSEEK_API_KEY`)
- `:z4m:autosuggestions:ai mode` -> `manual|passive|auto`
- `:z4m:autosuggestions:ai timeout-ms` -> request timeout
- `:z4m:autosuggestions:ai debounce-ms` -> stable-buffer delay
- `:z4m:autosuggestions:ai cooldown-ms` -> min interval between requests
- `:z4m:autosuggestions:ai min-input` -> minimum buffer size
- `:z4m:autosuggestions:ai max-input-tokens` -> approximate input cap
- `:z4m:autosuggestions:ai max-output-tokens` -> output token cap
- `:z4m:autosuggestions:ai history-lines` -> context history count
- `:z4m:autosuggestions:ai token-budget-per-minute` -> minute budget
- `:z4m:autosuggestions:ai token-budget-per-day` -> day budget

No package channel setting controls autosuggestions anymore.

## Runtime Entrypoints

- init: `-z4m-autosuggest-init` -> `-z4m-autosuggest-core-init`
- fetch: `-z4m-autosuggest-fetch` -> `-z4m-autosuggest-core-fetch`
- reset: `-z4m-autosuggest-reset` -> `-z4m-autosuggest-core-reset`
- pending redraw bridge: `-z4m-autosuggest-core-pre-redraw`
- AI sidecar fetch lane: `-z4m-autosuggest-ai-maybe-suggest`

`POSTDISPLAY`, `_z4m_autosuggest_buffer`, `_z4m_autosuggestion` are owned by autosuggest core.
Highlight overlay composition remains in `fn/-z4m-highlight-core`.

AI lane constraints:

- AI requests are asynchronous and never block keypress handling.
- Local history-based suggestion remains the primary fast path.
- AI is only used as fallback when local strategy does not produce a suggestion.
- Sidecar enforces debounce, cooldown, single in-flight request, and token budgets.
- AI lane requires token when enabled; missing API key disables AI lane with `missing_api_key`.
- Suggestion quality is validated in core for all providers (prefix consistency, single-line printable output, and command-head plausibility for AI) before `POSTDISPLAY` is updated.
- AI payload uses a structured TASK/RULES prompt with `CWD`, exact `BUFFER`, and numbered recent history.
- AI payload includes a derived `BUFFER_HINT` (`command_prefix`, `editing_arguments`, `awaiting_argument`, `empty`).
- AI payload includes `BUFFER_META` from local probes (`whence`, `alias`, function head) for command-prefix context.
- AI lane performs one strict retry (higher temperature) when the first response is low quality (`empty_suggestion`, `prefix_mismatch`, `numeric_tail`, etc.).
- AI budget accounting reserves input tokens at submit-time and only adds output tokens after successful harvest.

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
