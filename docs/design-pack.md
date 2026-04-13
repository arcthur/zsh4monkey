# Offline Packaging Design (`z4m pack`)

This document describes how `z4m pack` creates an offline installation package and what it contains.

## Goals

- Install z4m on machines without internet access.
- Preserve a working bootstrap (`.zshenv` + `z4m.zsh`) without requiring network fetch.
- Keep the installer **data-driven** (embedded archive), with minimal runtime dependencies.

## User Interface

`z4m pack` produces a self-extracting POSIX `sh` script:

```sh
z4m pack [-o output] [-t tag]
```

- `-o <output>`: output filename (default: `z4m-offline-install.sh`)
- `-t <tag>`: selects a `zstyle` namespace for extra files (default: `default`)

### Extra Paths (Tag-Scoped)

Include additional local paths by configuring copy specs:

```zsh
zstyle ":z4m:pack:<tag>" extra-files \
  '~/.config/nvim/init.lua' \
  '--dest $ZDOTDIR/custom/init.zsh $ZDOTDIR/.env.zsh' \
  '--glob .config/nvim/**/*.lua'
```

Entries support `~`, `$HOME`, `$ZDOTDIR`, absolute paths, and plain relative paths (resolved from `$HOME`).
Each `extra-files` element is one copy spec. Supported forms are:

- Plain local source path
- `--dest <path>` to override the installed path for one resolved source
- `--glob` to expand the local source as a glob before staging
- `--exclude <pattern>` to exclude files or directories inside a copied directory

Pack keeps a stricter boundary than `z4m ssh`:

- Local sources must resolve under `$HOME` or `$ZDOTDIR`
- Relative destinations stay within the source root by default
- `$HOME/...`, `~/...`, and `$ZDOTDIR/...` can be used in `--dest` to choose the install root explicitly
- Absolute destinations are rejected
- `--exclude` uses the same matching rules as `z4m ssh`: patterns without `/` match basenames, patterns with `/` match relative paths inside the copied tree

## Package Contents

`z4m pack` embeds:

1. **Dotfiles** from `${ZDOTDIR:-$HOME}` (when present): `.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`, `.zlogout`, and `.p10k*.zsh`
2. **Core z4m payload** under `$Z4M/` (when present):
   - `z4m.zsh`
   - `zsh4monkey/`
   - `fzf/`
   - `powerlevel10k/`
   - `zsh-users/`
   - `terminfo/`
3. Any configured `extra-files` under `$HOME` or `$ZDOTDIR`

## Data Model

The output script is:

- a POSIX `sh` header that implements extraction and installation
- a marker line: `___Z4M_DATA_MARKER___`
- a Base64-encoded `tar.gz` archive containing:
  - `z4m.tar.gz` for the z4m installation tree
  - `payload/` with staged dotfiles and extra paths
  - `install.manifest` describing whether each staged path belongs under `$HOME` or `$ZDOTDIR`

On the target machine, the script:

1. Determines `ZDOTDIR` from the first positional argument (default `$HOME`).
2. Determines `Z4M` from the environment or defaults to:

   ```sh
   Z4M="${Z4M:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh4monkey}"
   ```

3. Extracts the embedded archive into a temporary directory.
4. Extracts `z4m.tar.gz` into `$Z4M/` (core framework + bundled deps).
5. Replays `install.manifest`, copying staged content into either `$HOME/` or `$ZDOTDIR/`.

## Requirements and Limitations

The target machine needs:

- POSIX `sh`
- `tar`
- `base64` (decode via `base64 -d` or `base64 -D`)
- `mktemp`, `grep`, `tail`, `cut`, `cp`, `rm`, `mkdir`

Notes:

- `z4m pack` packages z4m and its bundled dependencies. It does not install system packages for you.
- You still need a working `zsh` compatible with z4m (see project requirements).
- Relative source and destination paths in `extra-files` must not contain `.` or `..` path segments.

## Security Considerations

The offline package contains your dotfiles and a copy of your z4m installation state.

- Treat the generated script as sensitive and distribute it only through trusted channels.
- Prefer copying over authenticated transport (e.g., `scp` to a known host, or a secure artifact store).
- Consider adding your own integrity checks (hash/signing) if you distribute widely.

## Relationship to SSH Offline Mode

Historical note: `z4m ssh` no longer supports `offline-mode`. This document only describes the standalone `z4m pack` workflow.

`z4m pack` is a general-purpose offline installer for non-SSH workflows.

## Implementation Anchors

- `fn/-z4m-cmd-pack`: pack implementation and the generated installer template
- `fn/-z4m-cmd-ssh`: SSH teleportation
