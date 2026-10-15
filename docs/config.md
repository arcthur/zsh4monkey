# Configuration Reference

All configuration uses `zstyle`. Place settings in `~/.zshrc` before `z4m init`.

## Notes on `zstyle` semantics

- Most feature toggles in z4m use `zstyle -T ...`, which treats an **unset** style as **enabled**.
  - To disable such features, explicitly set the style to `no`.
- Use `zstyle -L <context> <style>` to inspect the current effective values.

## Quick Start

```zsh
# Keyboard type (recommended)
zstyle ':z4m:bindkey' keyboard 'pc'  # or 'mac'

# Optional customizations
zstyle ':z4m:' editor-mode 'vi'
zstyle ':z4m:' prompt-at-bottom 'yes'
zstyle ':z4m:direnv' enable 'yes'
zstyle ':z4m:ssh:*' enable 'yes'
zstyle ':z4m:ssh-agent:' start 'yes'

# Install CLI tools
# Note: for these “CLI tool” packages, `z4m install` registers integrations and runs
# a post-install check. Install the actual binaries via your package manager.
z4m install eza bat fd rg zoxide fzf carapace atuin || return

# Resolve immediately when you need the queue applied before z4m init.
# z4m install --resolve fzf powerlevel10k
```

---

## Core

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m: editor-mode` | string | `emacs` | Editing mode: `emacs` or `vi` |
| `:z4m: prompt-at-bottom` | bool | `yes` | Position prompt at terminal bottom |
| `:z4m: propagate-cwd` | bool | `yes` | Propagate CWD to new tmux panes |
| `:z4m: term-shell-integration` | bool | `yes` | Enable OSC 133 shell integration |
| `:z4m: start-tmux` | string | `isolated` | Tmux startup: `no`, `integrated`, `isolated`, `system`, `command <cmd>` |
| `:z4m: auto-update` | string | `ask` | Update prompt policy: `ask` (default) or `no` |
| `:z4m: auto-update-days` | int | `28` | Days between update checks |

## Keyboard

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:bindkey keyboard` | string | `pc` | Layout: `pc` or `mac` |
| `:z4m:bindkey macos-option-as-alt` | bool | `yes` | Treat Option as Alt on macOS |

See [keybindings.md](keybindings.md) for key binding reference.

## Autosuggestions

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:autosuggestions enabled` | bool | `yes` | Enable built-in autosuggestions |
| `:z4m:autosuggestions strategy` | string | `ranked history` | Suggestion strategy list, tried in order: `ranked`, `history`, `history_pwd`, `match_prev_cmd` |
| `:z4m:autosuggestions buffer-min-size` | int | unset | Skip suggestions when `BUFFER` length is below this threshold |
| `:z4m:autosuggestions match-prev-max-cmds` | int | `200` | Max matching history commands to inspect for `match_prev_cmd` (`-1` means all) |
| `:z4m:autosuggestions match-prev-cmd-count` | int | `1` | Number of preceding commands that must match for `match_prev_cmd` |
| `:z4m:autosuggestions case-insensitive` | bool | `no` | Case-insensitive matching for local history strategies |
| `:z4m:autosuggestions pwd-scan-limit` | int | `500` | Max history entries scanned for `history_pwd` strategy |
| `:z4m:autosuggestions rank-window` | int | `500` | Recent history entries scored by the `ranked` strategy (1-5000) |
| `:z4m:autosuggestions forward-char` | string | `accept` | Cursor right behavior: `accept` or `partial-accept` |
| `:z4m:autosuggestions end-of-line` | string | `accept` | End-of-line behavior: `accept` or `partial-accept` |
| `:z4m:autosuggestions:ai enabled` | bool | `no` | Enable AI sidecar suggestions |
| `:z4m:autosuggestions:ai endpoint` | string | `https://api.deepseek.com/v1` | OpenAI-compatible API base URL |
| `:z4m:autosuggestions:ai model` | string | `deepseek-chat` | Model ID used for AI suggestions |
| `:z4m:autosuggestions:ai api-key-env` | string | `DEEPSEEK_API_KEY` | Environment variable name containing API key (required when AI is enabled) |
| `:z4m:autosuggestions:ai mode` | string | `manual` | Trigger mode: `manual`, `passive`, `auto` |
| `:z4m:autosuggestions:ai timeout-ms` | int | `3000` | HTTP timeout in milliseconds |
| `:z4m:autosuggestions:ai debounce-ms` | int | `160` | Buffer-stable debounce window |
| `:z4m:autosuggestions:ai cooldown-ms` | int | `800` | Minimum time between AI requests |
| `:z4m:autosuggestions:ai min-input` | int | `2` | Minimum buffer length before querying AI fallback; empty buffers are not sent |
| `:z4m:autosuggestions:ai max-input-tokens` | int | `384` | Approximate input token cap per request |
| `:z4m:autosuggestions:ai max-output-tokens` | int | `96` | Max completion tokens requested from model |
| `:z4m:autosuggestions:ai history-lines` | int | `0` | Number of recent history lines sent as context for manual/intent lanes |
| `:z4m:autosuggestions:ai token-budget-per-minute` | int | `12000` | Approximate per-minute token budget |
| `:z4m:autosuggestions:ai token-budget-per-day` | int | `300000` | Approximate per-day token budget |
| `:z4m:autosuggestions:ai rewrite-enabled` | bool | `yes` | Enable manual AI rewrite lane (`Ctrl+O`, no input prefix required) |
| `:z4m:autosuggestions:ai rewrite-key` | string | `^O` | ZLE key sequence used to trigger manual AI rewrite |
| `:z4m:autosuggestions:ai intent-command-enabled` | bool | `yes` | Enable the `z4m ai "..."` intent command lane |
| `:z4m:autosuggestions:ai prompt-extend` | string | empty | Extra instruction appended to AI system prompt |
| `:z4m:autosuggestions:ai context-pwd-enabled` | bool | `no` | Send the current working directory to manual/intent requests |
| `:z4m:autosuggestions:ai context-project-enabled` | bool | `no` | Send project type, Git state, and top-level names to manual/intent requests |
| `:z4m:autosuggestions:ai context-output-enabled` | bool | `no` | Send sanitized terminal output to manual/intent requests |
| `:z4m:autosuggestions:ai context-output-lines` | int | `40` | Max lines captured from terminal output context |
| `:z4m:autosuggestions:ai context-output-max-chars` | int | `2000` | Max chars kept from terminal output context |
| `:z4m:autosuggestions:ai proxy-enabled` | bool | `no` | Enable tmux pane proxy fallback for output context |

Autosuggestions are built into z4m. No installation is required.
If `:z4m:autosuggestions:ai enabled` is `yes`, the API key environment variable must be set.

The command buffer or intent query is always sent when an AI request is
triggered. PWD, project metadata, command history, and terminal output are
separate opt-ins. Output capture uses `tmux capture-pane -> proxy tail`.

Example:

```zsh
zstyle ':z4m:autosuggestions' enabled yes
zstyle ':z4m:autosuggestions' strategy match_prev_cmd
zstyle ':z4m:autosuggestions' match-prev-max-cmds 300
zstyle ':z4m:autosuggestions' match-prev-cmd-count 2
zstyle ':z4m:autosuggestions' buffer-min-size 3

# Optional AI sidecar (manual lanes by default)
zstyle ':z4m:autosuggestions:ai' enabled yes
export DEEPSEEK_API_KEY='your-token'
zstyle ':z4m:autosuggestions:ai' mode manual
zstyle ':z4m:autosuggestions:ai' model deepseek-chat
zstyle ':z4m:autosuggestions:ai' max-input-tokens 384
zstyle ':z4m:autosuggestions:ai' max-output-tokens 96
zstyle ':z4m:autosuggestions:ai' token-budget-per-minute 12000
zstyle ':z4m:autosuggestions:ai' token-budget-per-day 300000

# Manual rewrite lane (Ctrl+O by default)
zstyle ':z4m:autosuggestions:ai' rewrite-enabled yes
zstyle ':z4m:autosuggestions:ai' rewrite-key '^O'

# Intent command lane
zstyle ':z4m:autosuggestions:ai' intent-command-enabled yes

# Optional context sharing (all default to no)
zstyle ':z4m:autosuggestions:ai' context-pwd-enabled no
zstyle ':z4m:autosuggestions:ai' context-project-enabled no
zstyle ':z4m:autosuggestions:ai' context-output-enabled no

# Optional output-context proxy (tmux-only, default off)
zstyle ':z4m:autosuggestions:ai' proxy-enabled no
```

See [autosuggest.md](autosuggest.md) for runtime flow, lane design, and diagnostics details.

## Dependency Integrity

Built-in dependencies and the bundled Oh My Zsh example are resolved through
`dependencies.lock` using an exact commit and SHA-256 digest. Custom GitHub
repositories require both:

```zsh
zstyle ':z4m:owner/project' sha256 '<sha256>'
z4m install owner/project@0123456789abcdef0123456789abcdef01234567
```

For temporary compatibility with legacy mutable plugin declarations:

```zsh
zstyle ':z4m:security' allow-unverified-downloads yes
```

This opt-out permits mutable and unverified code downloads and is not
recommended for persistent configuration.

During framework updates, an already-installed legacy unpinned plugin is copied
forward without contacting the network, with a migration warning. This keeps
existing shells usable while avoiding a new mutable download; pin the plugin to
an exact commit and digest to resume verified updates.

Stable bootstrap and update require GitHub CLI for artifact attestation
verification and bind accepted provenance to
`arcthur/zsh4monkey/.github/workflows/release.yml`. Public attestations can
normally be read anonymously; if GitHub requests credentials or the anonymous
API limit is exhausted, run `gh auth login` or set `GH_TOKEN`. Environments
that cannot run GitHub CLI may set `Z4M_ALLOW_CHECKSUM_ONLY_RELEASES=1` before
sourcing `.zshenv`. The adjacent checksum ships from the same host as the
archive, so this drops the only independent anchor and falls back to
trust-on-first-use; see [SECURITY.md](../SECURITY.md#release-trust-model).

## Update Channel

The default channel is `development` for installations that currently track
`main`, and `stable` for versioned installations.

```zsh
zstyle ':z4m:update' channel stable
```

Supported values:

- `stable`: resolve the latest versioned release and require checksum plus
  GitHub artifact-attestation verification;
- `development`: follow mutable `main` with an explicit warning;
- `pinned`: retain the ref already present in `Z4M_URL`; versioned refs keep
  release verification, while `main` remains unverified.

## Version Retention

Updating keeps the previous framework version so `z4m rollback` has a target.

```zsh
zstyle ':z4m:update' keep-versions 2
```

The value counts retained versions in total, including the active one, and is
clamped to at least 1. Versions live under `$Z4M/versions/`; only the framework
is versioned, so retaining more of them costs little. `z4m rollback --list`
shows what is currently available.

## Highlighting

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:highlight backend` | string | `fast` | Highlight backend: `fast` or `none` |
| `:z4m:highlight theme` | string | `clean` | Built-in fast theme: `clean` (default) or `catppuccin-mocha` |

Syntax highlighting is built into z4m (based on fast-syntax-highlighting). No installation required.

The backend controls syntax highlighting only. UI overlays such as autosuggestions and history substring-search query highlights are applied independently.

Theme contract is strict: only `clean` and `catppuccin-mocha` are accepted.
Unknown values are rejected and runtime falls back to `clean`.
Backend contract is strict: only `fast` and `none` are accepted.
Unknown backend values are forced to `none`.

Example:

```zsh
zstyle ':z4m:highlight' backend fast
zstyle ':z4m:highlight' theme clean
```

Diagnostics:

```zsh
z4m autosuggest status --init
z4m autosuggest doctor
z4m highlight status --init
z4m highlight doctor
z4m highlight events --tail 20
```

## Terminal Title

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:term-title:local preexec` | string | `${1//\%/%%}` | Title during command (local) |
| `:z4m:term-title:local precmd` | string | `%~` | Title at prompt (local) |
| `:z4m:term-title:ssh preexec` | string | `%n@%m: ${1//\%/%%}` | Title during command (SSH) |
| `:z4m:term-title:ssh precmd` | string | `%n@%m: %~` | Title at prompt (SSH) |

## Tmux

`start-tmux` is a core setting; see **Core**.

### Navigation

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:tmux-nav enable` | bool | `yes` | Enable Ctrl+hjkl navigation |
| `:z4m:tmux-nav mode` | string | `unified` | Mode: `unified`, `pane`, `disabled` |
| `:z4m:tmux-nav resize-bindings` | bool | `yes` | Enable Ctrl+Alt+hjkl resize |

See [tmux-unified-nav.md](tmux-unified-nav.md) for details.

### Window Title

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:tmux-title enable` | bool | `yes` | Enable context-aware window naming |
| `:z4m:tmux-title git-branch` | bool | `no` | Show git branch in title |
| `:z4m:tmux-title command-icons` | bool | `no` | Show command icons (requires Nerd Font) |
| `:z4m:tmux-title max-length` | int | `24` | Maximum title length |

See [tmux-context-title.md](tmux-context-title.md) for details.

## FZF

### Global Settings

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:* fzf-flags` | array | — | Extra fzf flags for all widgets |
| `:z4m:* fzf-theme` | string | `default` | Theme: `dracula`, `gruvbox`, `catppuccin`, `nord`, etc. |
| `:z4m:* fzf-tmux` | string | — | Tmux popup mode: `no` (disable), `yes`/`popup`/`center`, `top`, `bottom`, `left`, `right` |
| `:z4m:* fzf-highlight-line` | bool | `yes` | Highlight current line (fzf 0.52+) |
| `:z4m:* fzf-wrap` | bool | `yes` | Line wrapping (fzf 0.56+) |
| `:z4m:* fzf-pointer` | string | — | Pointer symbol (fzf 0.54+) |
| `:z4m:* fzf-marker` | string | — | Multi-select marker (fzf 0.54+) |

### Completion

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:fzf-complete recurse-trigger` | string | `**` | Word suffix that makes `Tab` list paths recursively; empty disables |
| `:z4m:fzf-complete recurse-dirs` | bool | `no` | Recurse on plain `Tab` as well |
| `:z4m:fzf-complete fzf-preview` | bool/string | `yes` | Preview: `yes`, `no`, or custom command |
| `:z4m:fzf-complete continuous-trigger` | string | `/` | Key to accept and continue path completion |
| `:z4m:fzf-complete accept-line` | string | — | Key to accept and execute command |
| `:z4m:fzf-complete fzf-bindings` | array | — | Custom key bindings |

See [fzf-completion.md](fzf-completion.md) for details.

### History

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:fzf-history fzf-preview` | bool | `yes` | Show command preview |

### Directory Navigation

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:fzf-dir-history fzf-bindings` | array | — | Key bindings |
| `:z4m:cd-down fzf-bindings` | array | — | Key bindings |
| `:z4m:cd-down find-command` | array | — | Custom find command (command + args); selects the legacy pipeline |

### Recursive Listings

Apply to `fzf-complete`, `cd-down`, and `fzf-dir-history` (use `:z4m:*` or a widget context).

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:* max-depth` | int | `6` | Path components below the base; `0` means unlimited |
| `:z4m:* find-exclude` | array | `.git node_modules` | Names pruned at any depth |

## SSH Teleportation

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:ssh:* enable` | bool | `no` | Enable for all hosts |
| `:z4m:ssh:<host> enable` | bool | — | Enable for a specific SSH target or resolved `HostName` |
| `:z4m:ssh:* send-extra-files` | array | — | Kitty-style copy specs for extra files (`--dest`, `--glob`, `--exclude`) |
| `:z4m:ssh:* env` | array | — | Environment directives: `NAME=value`, `NAME=` (empty), `NAME` (unset), or `NAME=_z4m_copy_env_var_` |
| `:z4m:ssh:* cwd` | string | — | Remote startup directory; relative values are placed under remote `HOME` |
| `:z4m:ssh:* interpreter` | string | `sh` | POSIX shell interpreter used to start the bootstrap script |
| `:z4m:ssh:* term` | string | — | Override TERM for specific hosts |
| `:z4m:ssh:* ssh-command` | array | `command ssh` | Custom ssh command (command + args; do not quote multi-word values as a single string) |

See [ssh.md](ssh.md) for details.

## SSH Agent

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:ssh-agent: start` | bool | `no` | Start ssh-agent automatically |
| `:z4m:ssh-agent: extra-args` | array | — | Extra ssh-agent args (e.g., `-t 20h`) |

## CLI Tools

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:eza enabled` | bool | `yes` | Enable eza aliases |
| `:z4m:bat enabled` | bool | `yes` | Enable bat aliases |
| `:z4m:zoxide enabled` | bool | `yes` | Enable zoxide integration |

See [cli-tools.md](cli-tools.md) for details.

## Carapace

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:carapace enabled` | bool | `yes` | Enable carapace completions |
| `:z4m:carapace exclude` | array | — | Commands to use native completion |
| `:z4m:carapace force-remote` | bool | `no` | Use on SSH (not recommended) |
| `:z4m:carapace debug` | bool | `no` | Show debug info |

## Atuin

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:atuin enabled` | bool | `yes` | Enable atuin history |
| `:z4m:atuin up-arrow` | bool | `no` | Use atuin for up-arrow |
| `:z4m:atuin ctrl-r` | bool | `yes` | Bind Ctrl+R to atuin |
| `:z4m:atuin nobind` | bool | `no` | Disable all atuin bindings |
| `:z4m:atuin force-remote` | bool | `no` | Use on SSH (not recommended) |
| `:z4m:atuin debug` | bool | `no` | Show debug info |

See [history-search.md](history-search.md) for details.

## Direnv

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:direnv enable` | bool | `no` | Enable direnv integration |
| `:z4m:direnv timeout` | int | `10` | Timeout in seconds |
| `:z4m:direnv:success notify` | bool | `no` | Show success notifications |

See [direnv.md](direnv.md) for details.

## mise

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:mise fast-hook` | bool | `yes` | Run `mise hook-env` only when its inputs change instead of before every prompt |

See [mise.md](mise.md) for details.

## Shell Integration

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:cmd-notify enable` | bool | `yes` | Enable long-command notifications |
| `:z4m:cmd-notify threshold` | int | `30` | Seconds before notification |
| `:z4m:cmd-notify exclude` | array | — | Commands to exclude |

OSC 133 prompt marking is controlled by `:z4m: term-shell-integration` (see **Core**).

See [shell-integration.md](shell-integration.md) for details.

## Directory History

| Style | Type | Default | Description |
|-------|------|---------|-------------|
| `:z4m:dir-history: cwd` | string | `%~` | CWD display format |
| `:z4m:dir-history: max-size` | int | `10000` | Maximum entries |

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [design-core.md](design-core.md) | Core framework design (init, safety, performance) |
| [design-pack.md](design-pack.md) | Offline packaging design (`z4m pack`) |
| [keybindings.md](keybindings.md) | Key binding reference |
| [commands.md](commands.md) | Command reference |
| [ssh.md](ssh.md) | SSH teleportation guide |
| [cli-tools.md](cli-tools.md) | CLI tools integration |
| [autosuggest.md](autosuggest.md) | Autosuggestions runtime and AI lanes |
| [fzf-completion.md](fzf-completion.md) | FZF completion details |
| [history-search.md](history-search.md) | History search and Atuin |
| [shell-integration.md](shell-integration.md) | OSC 133 and notifications |
| [tmux-unified-nav.md](tmux-unified-nav.md) | Tmux navigation |
| [tmux-context-title.md](tmux-context-title.md) | Tmux window naming |
| [direnv.md](direnv.md) | Direnv integration |
| [mise.md](mise.md) | mise activation fast hook |
| [recovery.md](recovery.md) | Safe mode and recovery |
