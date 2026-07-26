# Core Framework Design

This document describes the core zsh4monkey (z4m) framework design: initialization flow, safety/recovery, package installation semantics, and performance principles.

See also:
- [config.md](config.md) for user-facing configuration
- [commands.md](commands.md) for the CLI surface
- [recovery.md](recovery.md) for safe mode and recovery usage
- `docs/ssh.md` for the current SSH bootstrap surface and configuration model

## Goals

- **Zero-config excellence**: the default setup should be useful and consistent.
- **Safety first**: fail closed on untrusted inputs, provide recovery paths for broken startup.
- **Performance**: keep interactive startup fast; prefer caching and lazy init.
- **Maintainability**: strict, testable contracts at module boundaries.

## Initialization Flow

High-level layers:

1. `~/.zshenv`: bootstrap, sets `Z4M` and sources `z4m.zsh`
2. `z4m.zsh`: entrypoint, sets baseline options, then loads `main.zsh`
3. `main.zsh`: runtime detection, safe mode/recovery checks, core module autoloading
4. `z4m init`: starts the full framework init (`fn/-z4m-init` and feature inits)

Key properties:

- Safe mode and recovery are decided **early** in `main.zsh`, before heavy initialization.
- `z4m install` is intended to be called **before** `z4m init`, so installs can run while standard I/O is still reliable.

## Failure Detection and Safe Mode

When `-z4m-init` fails, `main.zsh` writes:

- `$Z4M/.last-init-failed` (transient marker for the next startup)
- `$Z4M/cache/last-init-failed.log` (persistent diagnostics)

On the next startup, the marker triggers safe mode (`fn/-z4m-safe-mode-init`):

- plugins are skipped (install queue cleared)
- z4m hooks are removed
- key bindings are reset to sane defaults
- a minimal prompt is installed, plus `z4m-safe-*` helper commands

Successful initialization clears both the marker and the stale log to prevent confusion.

## Recovery Shell

Recovery shell (`fn/-z4m-recovery-shell`) is a last-resort minimal environment to fix `.zshrc`:

- resets key bindings and disables z4m hooks/widgets
- provides `z4m-recovery-*` commands to edit and restart
- can be entered via `z4m recovery` or the ZLE widget `z4m-recovery-shell`

## Package Installation Semantics

`z4m install` is a **declarative registration** mechanism:

- validates project names
- appends them to the global install queue (`_z4m_install_queue`)
- does not necessarily perform network I/O immediately

Use `z4m install --resolve ...` when you want to resolve the queue immediately.

Design intent:

- allow `.zshrc` to define a stable “desired set” of dependencies
- keep interactive init robust by avoiding accidental prompts/TTY issues mid-init

## Performance Model

z4m uses a few recurring strategies:

- **Feature gating**: don’t do work when a feature is disabled or a dependency is missing.
- **Caching**: cache expensive init output (e.g., `zoxide init zsh`, `atuin init zsh`) under `$Z4M/cache/` and reuse it until the binary changes.
- **Lazy execution**: `z4m-defer` queues user commands to execute after prompt display (ZLE idle time).
- **Compilation**: `z4m compile` compiles zsh sources to `.zwc` to reduce load overhead.
- **Readiness measurement**: `z4m bench` measures time to the first fully
  initialized prompt through a PTY and reports distribution statistics rather
  than a fixed startup-time claim.

## Update and Distribution Model

- Versioned releases are the production channel. Archives use SHA-256 sidecars
  and GitHub artifact attestations; the separate release installer pins and
  verifies bootstrap files.
- `main` is a mutable, explicitly unverified development channel.
- Built-in remote dependencies resolve through `dependencies.lock` to exact
  commits and SHA-256 digests. Custom repositories require the same immutable
  ref and digest contract unless the compatibility opt-out is enabled.
- `z4m update` builds a complete candidate tree before replacing the active
  cache. A guard serializes updates, while a temporary bootstrap and immutable
  backup snapshot provide idempotent recovery if replacement or rollback is
  interrupted.

Replacement is not atomic: between clearing `$Z4M` and moving the candidate in,
the cache is incomplete. Everything else in the update path exists to make that
window survivable — the guard, the recovery lock, the backup snapshot, and the
temporary `z4m.zsh` that a shell entering the window will load instead of the
framework.

Recovery therefore has exactly one implementation, `fn/-z4m-recover-update`.
Both callers use it: `z4m update` for in-process rollback and stale-transaction
cleanup, and the temporary bootstrap, which autoloads it from the backup
snapshot (falling back to the active tree once replacement has completed). It
either restores the backup or, when the new tree is already in place and only
the entry point is missing, rolls forward. Keeping it in one file is what
prevents the two paths from drifting into different notions of "recovered".

A content-addressed layout — versioned directories plus an atomic `current`
symlink, with state separated from code — would remove the window rather than
guard it. That is a deliberate future direction, not the current model.

See [SECURITY.md](../SECURITY.md) for the release trust boundary and
[config.md](config.md) for channel and dependency configuration.

## Security Model (First Principles)

Security-sensitive paths follow two rules:

- **No eval of untrusted inputs**: propagated data must be treated as data, not code.
- **Fail closed**: invalid payloads are rejected as a whole.

SSH now uses one-shot bootstrap with explicit `env` directives instead of a separate env-payload protocol; see [ssh.md](ssh.md).

## Implementation Anchors

Core entrypoints:

- `z4m.zsh`: baseline environment and bootstrap
- `main.zsh`: safe mode / recovery checks + core autoloading
- `fn/-z4m-init`: main init pipeline (features, hooks, widgets)

Safety:

- `fn/-z4m-safe-mode-init`
- `fn/-z4m-recovery-shell`
- `fn/-z4m-show-failure-log`
- `fn/-z4m-recover-update`: the single update restore/roll-forward implementation
  shared by `z4m update` and the temporary bootstrap

Performance primitives:

- `z4m-defer`
- `fn/-z4m-compile` and `z4m compile`
