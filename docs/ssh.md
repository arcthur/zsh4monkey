# SSH Teleportation

Transfer your zsh4monkey runtime to remote hosts and enter an interactive shell.

## Overview

When you run `z4m ssh host`, z4m:

1. Resolves host-scoped SSH styles
2. Bundles the current z4m runtime, installed z4m-managed packages, and shell dotfiles
3. Uploads that bundle to the remote host in one shot
4. Starts an interactive remote `zsh` using the uploaded runtime

`z4m ssh` no longer uses incremental sync, file retrieval, or output-stream control markers. Once bootstrap finishes, the session is handed directly to the remote shell.

Non-interactive SSH usages are passed through unchanged to the configured `ssh` command.

## Quick Start

```zsh
# Enable for all hosts
zstyle ':z4m:ssh:*' enable 'yes'

# Or whitelist specific hosts
zstyle ':z4m:ssh:*' enable 'no'
zstyle ':z4m:ssh:devbox' enable 'yes'
zstyle ':z4m:ssh:staging-*' enable 'yes'

# Connect
z4m ssh myserver
```

## Configuration

### Host Matching

Styles are matched against the SSH target you pass to `z4m ssh` and, if it resolves to a different `HostName`, against that resolved host as a fallback.

```zsh
# Default-off mode (opt-in hosts)
zstyle ':z4m:ssh:*' enable 'no'
zstyle ':z4m:ssh:myserver' enable 'yes'
zstyle ':z4m:ssh:dev-*' enable 'yes'

# Default-on mode (opt-out hosts)
zstyle ':z4m:ssh:*' enable 'yes'
zstyle ':z4m:ssh:production-*' enable 'no'
zstyle ':z4m:ssh:*.prod.company.com' enable 'no'
```

### Extra Files

Send extra files with kitty-style copy specs. Each `zstyle` element is one copy spec:

```zsh
zstyle ':z4m:ssh:*' send-extra-files \
  '~/.nanorc' \
  '--dest my-conf/zsh/.zshrc ~/.zshrc' \
  '--glob .config/nvim/**/*.lua'
```

Supported options:

- Plain source path: copy one file or directory and keep its path relative to the local `$HOME` on the remote side
- `--dest <remote-path>`: override the remote destination for a single resolved source
- `--glob`: expand the local source as a glob before copying
- `--exclude <pattern>`: exclude files or directories inside a copied directory

Behavior notes:

- Relative local source paths are resolved from the local `$HOME`
- Relative local source paths must not contain `.` or `..` path segments
- If a local source is outside `$HOME` but inside `$ZDOTDIR`, the default remote path is relative to `$ZDOTDIR`
- Relative remote destinations live under the remote `$HOME`; absolute destinations are preserved as-is
- Remote destinations must not contain `.` or `..` path segments
- `--dest` cannot be used with a spec that resolves to multiple local paths
- `--exclude` applies to directory contents; patterns without `/` match basenames, patterns with `/` match relative paths inside the copied tree

When a spec contains spaces, quote it as a single `zstyle` array element.

### Environment Configuration

Set, clear, unset, or copy explicit environment variables during bootstrap:

```zsh
zstyle ':z4m:ssh:*' env \
  'EDITOR=_z4m_copy_env_var_' \
  'VISUAL=_z4m_copy_env_var_' \
  'COLORTERM=truecolor' \
  'GIT_DIR'
```

Directive rules:

- `NAME=value`: set a literal remote value
- `NAME=`: set an empty remote value
- `NAME`: unset on the remote side
- `NAME=_z4m_copy_env_var_`: copy the local scalar value if it exists

`_kitty_copy_env_var_` is also accepted for easier migration from kitty configs.

### Startup Directory

Start the remote shell from a specific directory:

```zsh
zstyle ':z4m:ssh:*' cwd 'src/project'
zstyle ':z4m:ssh:infra' cwd '/srv/app'
```

Relative values are resolved from the remote `HOME`. `~`, `$HOME`, `${HOME}`, `$ZDOTDIR`, and `${ZDOTDIR}` are also accepted. If the directory cannot be entered, `z4m ssh` prints a warning and continues with the remote shell's default directory.

### Bootstrap Interpreter

Use a different POSIX shell to start the bootstrap script:

```zsh
zstyle ':z4m:ssh:*' interpreter 'sh'
zstyle ':z4m:ssh:legacy' interpreter '/bin/bash'
```

`interpreter` must be a single executable name or absolute path that can run POSIX `sh` syntax. It only affects bootstrap startup; the interactive shell still comes from the remote `exec-zsh-i` flow.

### Terminal Override

Override the terminal type for specific hosts:

```zsh
zstyle ':z4m:ssh:oldserver' term 'screen-256color'
```

### Custom SSH Command

Use a different `ssh` binary or wrapper:

```zsh
zstyle ':z4m:ssh:*' ssh-command command ssh
zstyle ':z4m:ssh:bastion' ssh-command /usr/local/bin/ssh-wrapper
```

`ssh-command` is parsed as an argv array.

## Jump Hosts

Jump hosts work transparently:

```bash
z4m ssh -J jumphost user@target
```

Only the final interactive target receives the teleported runtime.

## SSH Agent

Automatically start `ssh-agent`:

```zsh
zstyle ':z4m:ssh-agent:' start 'yes'
zstyle ':z4m:ssh-agent:' extra-args -t 20h
```

## Behavior Notes

- `z4m ssh` is optimized for interactive remote shells.
- Forwarding-only or command-execution SSH invocations fall back to the underlying `ssh`.
- Inline autosuggestions are disabled in SSH sessions to avoid remote TTY redraw corruption.
- Syntax highlighting is disabled in SSH sessions to avoid remote TTY redraw corruption.
- Simplified prompt is used in SSH sessions to avoid remote prompt redraw corruption.
- Remote rendering issues caused by the old file-retrieval and marker protocol are intentionally avoided by keeping bootstrap one-way.
