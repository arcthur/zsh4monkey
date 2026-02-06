# Highlight Architecture

This document describes z4m's highlight subsystem after the L4 refactor.

## Goals

- Keep `_zsh_highlight` stable as a z4m-owned facade.
- Use hardcoded backends (`fast`, `none`) with a shared lifecycle.
- Provide actionable observability through `z4m highlight`.
- Preserve runtime behavior ordering with autosuggestions and substring-search overlays.

## Runtime Model

Core module: `fn/-z4m-highlight-core`

State is tracked in:

- `_z4m_highlight_state` (associative array)
- `_z4m_highlight_events` (array ring buffer)

Lifecycle states:

- `uninitialized`
- `initializing`
- `ready`
- `degraded`
- `disabled`

## Backend Contract

Each backend must implement five functions:

- `probe`
- `init`
- `render`
- `reset`
- `teardown`

Backends are internal-only and hardcoded (`fast`, `none`). Third-party backend APIs are intentionally not public.
Invalid backend config values are treated as errors and coerced to `none`.

## Theme Contract

`fast` backend accepts exactly two built-in theme names:

- `clean` (default)
- `catppuccin-mocha`

No legacy aliases and no external file-path themes are supported.
Invalid configured theme values are treated as configuration errors and coerced to `clean` at runtime.

## Facade and Render Flow

`_zsh_highlight` must always call `-z4m-highlight-render`.

`-z4m-highlight-render` delegates to `-z4m-highlight-core-render`.

`-z4m-highlight-core-render` strips previously applied z4m overlays, runs the active backend render, then applies overlays:

- history substring-search query highlights
- autosuggestion `POSTDISPLAY` highlight

Overlays are applied independently from the syntax backend.

The fast backend stores vendor `_zsh_highlight` logic in `-z4m-highlight-fast-core` and never exports vendor internals as the public facade.

## Diagnostics CLI

`z4m highlight` provides:

- `status [--json] [--init]`
- `doctor [--json] [--no-init]`
- `events [--tail N] [--json]`
- `reset [--json]`

`doctor` exit codes:

- `0`: healthy
- `1`: warnings/degraded
- `2`: errors

## Vendor Policy

Vendor source is under `vendor/fast-syntax-highlighting`.

Metadata file: `vendor/fast-syntax-highlighting/.z4m-vendor-meta`

Rules:

- Keep `patches=` and `z4m_improvements=` up to date for every vendor delta.
- Any vendor file change must update `.z4m-vendor-meta` in the same change set.
- Keep initialization offline-safe (no network downloads during runtime init).
