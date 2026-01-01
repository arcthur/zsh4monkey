# Direnv Integration

Automatic environment loading based on directory.

## Overview

[direnv](https://direnv.net/) loads/unloads environment variables when you enter/leave directories. z4m provides seamless integration with proper error handling.

## Configuration

```zsh
# Enable direnv integration
zstyle ':z4m:direnv' enable 'yes'
```

## Timeout

Direnv has a 10-second timeout by default. For slow `.envrc` files (nix-shell, devbox):

```zsh
zstyle ':z4m:direnv' timeout 30  # seconds
```

## Notifications

### Error Notifications

Errors are always shown.

### Success Notifications

Disabled by default (reduces noise). Enable with:

```zsh
zstyle ':z4m:direnv:success' notify 'yes'
```

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  cd ~/project                                               │
│       │                                                     │
│       ▼                                                     │
│  direnv check: .envrc exists?                               │
│       │                                                     │
│       ├─ Yes, allowed → Load environment                    │
│       │                                                     │
│       ├─ Yes, not allowed → Show "direnv allow" prompt      │
│       │                                                     │
│       └─ No → Unload previous environment                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Create .envrc

```bash
cd ~/project
echo 'export MY_VAR=value' > .envrc
direnv allow  # Trust this .envrc
```

### Common .envrc Patterns

```bash
# Simple exports
export DATABASE_URL="postgres://localhost/mydb"
export API_KEY="development-key"

# Load from .env file
dotenv

# Use specific tool versions
use node 18
use python 3.11

# Nix development environment
use nix

# Devbox
eval "$(devbox generate direnv --print-envrc)"
```

## Handling Slow Environments

Some tools take time to initialize:

### Nix

```zsh
# Increase timeout for nix-shell
zstyle ':z4m:direnv' timeout 60
```

### Devbox

```zsh
# Devbox can be slow on first run
zstyle ':z4m:direnv' timeout 30
```

### Timeout Behavior

If direnv times out or is interrupted (Ctrl+C):
1. z4m shows an informative message
2. Shell continues normally
3. Does **not** trigger recovery/safe mode

## Troubleshooting

### Direnv slow in specific directory

Disable for that directory:

```bash
cd problematic-directory
direnv deny
```

### Environment not loading

1. Check if .envrc exists:
   ```bash
   ls -la .envrc
   ```

2. Check if allowed:
   ```bash
   direnv status
   ```

3. Allow if needed:
   ```bash
   direnv allow
   ```

### Conflicts with other tools

If using nvm, pyenv, or similar:

```bash
# In .envrc, explicitly source them
source_up  # Load parent .envrc first

# Or use direnv's built-in support
use node 18
use python 3.11
```

### Debug output

```bash
DIRENV_LOG_FORMAT= direnv allow
cd .  # Trigger reload with verbose output
```

## Best Practices

### Security

1. Never auto-allow untrusted .envrc files
2. Review .envrc before allowing
3. Use `direnv deny` to block specific directories

### Performance

1. Keep .envrc fast (avoid slow commands)
2. Use caching where possible
3. Increase timeout only when necessary

### Organization

```
project/
├── .envrc           # Project-level environment
├── dev/
│   └── .envrc       # Development-specific (inherits from parent)
└── prod/
    └── .envrc       # Production-specific
```

Use `source_up` to inherit parent environment:

```bash
# In dev/.envrc
source_up
export ENV=development
```

## Integration with Other Tools

### asdf

```bash
# .envrc
use asdf
```

### mise (rtx)

```bash
# .envrc
eval "$(mise activate zsh)"
```

### Docker

```bash
# .envrc
export DOCKER_HOST="unix:///var/run/docker.sock"
export COMPOSE_PROJECT_NAME="myproject"
```

## Technical Details

### Implementation

z4m hooks into direnv using:
- `chpwd` hook for directory changes
- `precmd` hook for prompt updates
- Timeout wrapper for safety

### Files

| File | Purpose |
|------|---------|
| `fn/-z4m-init-direnv` | Direnv initialization |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `DIRENV_DIR` | Current direnv directory |
| `DIRENV_DIFF` | Environment diff (internal) |
