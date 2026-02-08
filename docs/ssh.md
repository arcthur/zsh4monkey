# SSH Teleportation

Transfer your shell configuration to remote hosts automatically.

## Overview

When you run `z4m ssh host`, z4m:
1. Bundles your zsh configuration
2. Transfers it to the remote host
3. Starts zsh with your familiar environment
4. Optionally retrieves files (history, notes) when you disconnect

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

Use patterns to control which hosts receive teleportation:

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

Send additional files to remote hosts:

```zsh
zstyle ':z4m:ssh:*' send-extra-files '~/.nanorc' '~/.env.zsh' '~/.config/nvim/init.lua'
```

Retrieve files after session ends:

```zsh
zstyle ':z4m:ssh:*' retrieve-extra-files '~/.local/notes'
zstyle ':z4m:ssh:*' retrieve-history '$ZDOTDIR/.zsh_history.remote'
```

### Environment Propagation

Propagate local environment variables to remote sessions:

```zsh
# Explicit variable list
zstyle ':z4m:ssh:*' propagate-env 'EDITOR' 'VISUAL' 'FZF_DEFAULT_OPTS'

# Glob patterns for bulk matching
zstyle ':z4m:ssh:*' propagate-env-patterns 'FZF_*' 'ATUIN_*' 'MY_*'

# Exclude specific patterns
zstyle ':z4m:ssh:*' propagate-env-exclude 'MY_INTERNAL_*'
```

**Supported types**: scalars, indexed arrays, associative arrays (base64-encoded for transport).

**Size limits**:
- Per-variable: 4KB
- Total payload: 64KB

### Security Exclusions

These patterns are **always** excluded from propagation:

| Category | Patterns |
|----------|----------|
| Secrets | `*_SECRET`, `*_SECRET_*`, `*SECRET_*` |
| Tokens | `*_TOKEN`, `*_TOKEN_*`, `*TOKEN_*` |
| Keys | `*_KEY`, `*_API_KEY`, `*API_KEY*` |
| Passwords | `*_PASSWORD`, `*PASSWORD*` |
| Credentials | `*_CREDENTIAL*`, `*CREDENTIAL*` |
| AWS | `AWS_SECRET_*`, `AWS_SESSION_TOKEN` |
| Git providers | `GITHUB_TOKEN`, `GH_TOKEN`, `GITLAB_TOKEN` |
| Package managers | `NPM_TOKEN`, `NPM_AUTH_TOKEN` |
| Docker | `DOCKER_PASSWORD`, `DOCKER_AUTH_*` |

### Sync Mode

Control how z4m syncs configuration:

```zsh
zstyle ':z4m:ssh:*' sync-mode 'smart'
```

| Mode | Description |
|------|-------------|
| `smart` | Full sync on first connection, incremental after (default) |
| `full` | Always perform full sync |
| `incremental` | Compare with previous state, sync only changes |

Force full sync for a single connection:

```bash
z4m ssh --force-sync host
```

### Offline Mode

For air-gapped hosts without internet:

```zsh
zstyle ':z4m:ssh:airgapped-host' offline-mode yes
```

This bundles the complete z4m installation in the transfer.

### Terminal Override

For hosts with limited terminfo:

```zsh
zstyle ':z4m:ssh:oldserver' term 'screen-256color'
```

### Custom SSH Command

Use a different ssh binary or wrapper:

```zsh
# Note: `ssh-command` is parsed as an argv array (command + args).
# Do not quote multi-word values like 'command ssh' as a single string.
zstyle ':z4m:ssh:*' ssh-command command ssh
zstyle ':z4m:ssh:bastion' ssh-command /usr/local/bin/ssh-wrapper

# Example with extra default args
zstyle ':z4m:ssh:legacy' ssh-command ssh -o ControlMaster=no
```

## Advanced Configuration

### Configure Hook

For complex setups, define a custom configuration function:

```zsh
my-ssh-configure() {
  # Add files to send (associative array: local -> remote)
  z4m_ssh_send_files[$HOME/.special-config]=$HOME/.special-config

  # Add setup commands (run on remote before shell starts)
  z4m_ssh_setup+=('mkdir -p ~/.local/bin')

  # Add prelude commands (run before zsh)
  z4m_ssh_prelude+=('export SPECIAL_VAR=value')

  # Add run commands (run inside zsh)
  z4m_ssh_run+=('source ~/.special-init')

  # Add teardown commands (run after zsh exits)
  z4m_ssh_teardown+=('rm -f ~/.temp-file')

  # Add files to retrieve (associative array: remote -> local)
  z4m_ssh_retrieve_files[$HOME/.remote-notes]=$HOME/.remote-notes
}

zstyle ':z4m:ssh:specialhost' configure 'my-ssh-configure'
```

Available arrays:

| Array | When | Purpose |
|-------|------|---------|
| `z4m_ssh_prelude` | Before ssh | Shell setup before connection |
| `z4m_ssh_send_files` | During transfer | Files to send (associative map: local -> remote) |
| `z4m_ssh_setup` | After transfer | Setup commands on remote |
| `z4m_ssh_run` | In zsh | Commands to run in shell |
| `z4m_ssh_teardown` | After exit | Cleanup commands |
| `z4m_ssh_retrieve_files` | After exit | Files to retrieve (associative map: remote -> local) |

### ProxyJump Support

Jump hosts work transparently:

```bash
z4m ssh -J jumphost user@target
```

Only the final target receives the teleported configuration.

## SSH Agent

Automatically start ssh-agent:

```zsh
zstyle ':z4m:ssh-agent:' start 'yes'
zstyle ':z4m:ssh-agent:' extra-args -t 20h  # Key lifetime
```

## Commands

| Command | Description |
|---------|-------------|
| `z4m ssh <host>` | Connect with teleportation |
| `z4m ssh --force-sync <host>` | Force full sync |
| `z4m ssh -J <jump> <host>` | Connect via jump host |

## Troubleshooting

### Teleportation not working

1. Check if enabled for host:
   ```bash
   zstyle -L ':z4m:ssh:myhost'
   ```

2. Verify z4m ssh is being used (not system ssh):
   ```bash
   which z4m
   type z4m
   ```

### Slow connection

1. Try incremental sync:
   ```zsh
   zstyle ':z4m:ssh:slowhost' sync-mode 'incremental'
   ```

2. Reduce files being sent:
   ```bash
   # Check what's being sent
   z4m ssh -v slowhost
   ```

### Environment not propagating

1. Check variable size (must be < 4KB):
   ```bash
   echo ${#MY_VAR}
   ```

2. Check if excluded by security patterns:
   ```bash
   # Variables matching *_TOKEN, *_SECRET, etc. are never propagated
   ```

3. Enable debug:
   ```zsh
   Z4M_ENV_PROPAGATION_DEBUG=1 z4m ssh host
   ```

### Remote shell issues

1. Check TERM compatibility:
   ```zsh
   zstyle ':z4m:ssh:problematic-host' term 'xterm-256color'
   ```

2. Try offline mode for hosts without internet:
   ```zsh
   zstyle ':z4m:ssh:isolated-host' offline-mode yes
   ```

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  z4m ssh host                                               │
├─────────────────────────────────────────────────────────────┤
│  1. Bundle: Pack ~/.zshrc, p10k, plugins into tarball       │
│  2. Transfer: Send via ssh stdin/stdout                     │
│  3. Unpack: Extract to ~/.cache/zsh4monkey on remote        │
│  4. Start: Launch zsh with ZDOTDIR pointing to bundle       │
│  5. Cleanup: Remove bundle on disconnect (optional)         │
│  6. Retrieve: Fetch history/files back to local             │
└─────────────────────────────────────────────────────────────┘
```

## Technical Details

### Implementation Files

| File | Purpose |
|------|---------|
| `fn/-z4m-cmd-ssh` | Main ssh command wrapper and transfer orchestration |
| `sc/ssh-bootstrap` | Remote bootstrap script template |
| `fn/-z4m-init` | Remote-side env propagation restore |
| `fn/-z4m-env-propagation-*` | Env propagation parser/limits/diagnostics |

### Environment Variable

| Variable | Description |
|----------|-------------|
| `Z4M_SSH` | Set on remote: `local-host:remote-host` format |
