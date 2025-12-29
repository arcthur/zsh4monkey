# Environment Variable Propagation

## Overview

This feature propagates local shell environment variables to remote SSH sessions, preserving complex types (indexed arrays, associative arrays) via Base64 encoding to ensure safe transport of special characters.

## 1. Configuration Interface

### 1.1 Explicit Variables

```zsh
zstyle ':z4m:ssh:*' propagate-env \
  'FZF_DEFAULT_OPTS' \
  'FZF_CTRL_T_COMMAND' \
  'EDITOR' \
  'VISUAL'

# Per-host configuration
zstyle ':z4m:ssh:devserver' propagate-env 'AWS_PROFILE' 'KUBECONFIG'
```

### 1.2 Glob Patterns

```zsh
# Propagate all variables matching the pattern
zstyle ':z4m:ssh:*' propagate-env-patterns 'FZF_*' 'ATUIN_*'
```

### 1.3 Exclusions

```zsh
# Additional exclusions (supplements built-in security filters)
zstyle ':z4m:ssh:*' propagate-env-exclude 'MY_INTERNAL_*'
```

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     LOCAL: z4m ssh command                      │
│                    fn/-z4m-cmd-ssh:181-286                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Parse zstyle configuration                                  │
│     propagate-env / propagate-env-patterns                      │
│     ↓                                                           │
│  2. Collect matching variables, apply security exclusions       │
│     ↓                                                           │
│  3. Generate export declarations                                │
│     - scalar:      export VAR='value'                           │
│     - array:       export -a ARR=( 'a' 'b' )                   │
│     - association: export -A MAP=( [k]='v' )                   │
│     ↓                                                           │
│  4. Base64-encode all declarations                              │
│     ↓                                                           │
│  5. Inject into z4m_ssh_prelude:                                │
│     export _Z4M_PROPAGATED_ENV_B64='<base64>'                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │  SSH transport (embedded in script)
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│               REMOTE: POSIX sh (ssh-bootstrap)                  │
│                      ^PRELUDE^ section                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  export _Z4M_PROPAGATED_ENV_B64='ZXhwb3J0IEV...'               │
│                                                                 │
│  (Sets environment variable only; no decoding in POSIX sh       │
│   since array syntax is not supported)                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │  zsh startup
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  REMOTE: zsh (fn/-z4m-init)                     │
│                        lines 5-17                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  if [[ -v _Z4M_PROPAGATED_ENV_B64 ]]; then                      │
│    # Base64 decode (compatible with Linux -d and macOS -D)      │
│    _z4m_env_decl=$(base64 -d <<< "$_Z4M_PROPAGATED_ENV_B64")   │
│                                                                 │
│    # Execute all export declarations                            │
│    eval "$_z4m_env_decl"                                        │
│                                                                 │
│    # Cleanup                                                    │
│    unset _Z4M_PROPAGATED_ENV_B64                                │
│  fi                                                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 3. Implementation

### 3.1 Local Collection (fn/-z4m-cmd-ssh:181-286)

```zsh
local -a propagate_env propagate_patterns propagate_exclude
zstyle -a :z4m:ssh:$z4m_ssh_host propagate-env propagate_env
zstyle -a :z4m:ssh:$z4m_ssh_host propagate-env-patterns propagate_patterns
zstyle -a :z4m:ssh:$z4m_ssh_host propagate-env-exclude propagate_exclude

if (( $#propagate_env || $#propagate_patterns )); then
  # Built-in security exclusion patterns
  local -a default_exclude=(
    '*_SECRET' '*_SECRET_*' '*SECRET_*'
    '*_TOKEN' '*_TOKEN_*' '*TOKEN_*'
    '*_KEY' '*_API_KEY' '*API_KEY*'
    '*_PASSWORD' '*PASSWORD*'
    '*_CREDENTIAL*' '*CREDENTIAL*'
    'AWS_SECRET_*' 'AWS_SESSION_TOKEN'
    'GITHUB_TOKEN' 'GH_TOKEN' 'GITLAB_TOKEN'
    'NPM_TOKEN' 'NPM_AUTH_TOKEN'
    'DOCKER_PASSWORD' 'DOCKER_AUTH_*'
  )
  propagate_exclude+=($default_exclude)

  # Variable collection → exclusion filtering → deduplication
  local -a env_to_propagate=()
  # ... (collection logic)

  if (( $#env_to_propagate )); then
    local -a env_decls=()

    for var in $env_to_propagate; do
      local vtype=${(Pt)var}
      case $vtype in
        scalar*)
          local val=${(P)var}
          (( ${#val} > 4096 )) && continue  # 4KB per-variable limit
          env_decls+=("export $var=${(qq)val}")
          ;;
        array*|association*)
          local decl=$(typeset -p $var 2>/dev/null) || continue
          decl=${decl/#typeset /export }
          decl=${decl/#export -g /export }
          env_decls+=("$decl")
          ;;
      esac
    done

    # Unified Base64 encoding
    if (( $#env_decls )); then
      local declarations=${(F)env_decls}
      if (( ${#declarations} <= 65536 )); then  # 64KB total limit
        local encoded=$(print -rn -- "$declarations" | base64)
        encoded=${encoded//$'\n'/}  # Strip newlines for safe transport
        z4m_ssh_prelude+=("export _Z4M_PROPAGATED_ENV_B64='$encoded'")
      fi
    fi
  fi
fi
```

### 3.2 Remote Restoration (fn/-z4m-init:5-17)

```zsh
if [[ -v _Z4M_PROPAGATED_ENV_B64 && -n $_Z4M_PROPAGATED_ENV_B64 ]]; then
  local _z4m_env_decl
  # Cross-platform Base64 decoding (Linux: -d, macOS: -D)
  _z4m_env_decl=$(print -r -- "$_Z4M_PROPAGATED_ENV_B64" | base64 -d 2>/dev/null) ||
    _z4m_env_decl=$(print -r -- "$_Z4M_PROPAGATED_ENV_B64" | base64 -D 2>/dev/null) || true
  if [[ -n $_z4m_env_decl ]]; then
    eval "$_z4m_env_decl" 2>/dev/null || true
  fi
  unset _Z4M_PROPAGATED_ENV_B64 _z4m_env_decl
fi
```

## 4. Design Rationale

### 4.1 Why Unified Base64 Encoding?

**Problem**: Initial design considered direct prelude injection for scalars, reserving Base64 only for complex types. However, this approach fails when scalar values contain newlines:

```zsh
# Variable with embedded newlines
export FZF_OPTS=$'--height=40%\n--layout=reverse'

# Direct injection breaks the script
'export' FZF_OPTS='--height=40%
--layout=reverse'  # Second line becomes invalid command
```

**Solution**: Encode all declarations uniformly via Base64, decode and execute within the zsh environment where all syntax is supported.

### 4.2 Why Restore in zsh Instead of POSIX sh?

1. **Syntax compatibility**: POSIX sh does not support array syntax (`export -a ARR=(...)`)
2. **Error handling**: zsh provides more robust eval semantics
3. **Timing**: Early zsh initialization ensures variables are available immediately

### 4.3 Comparison with xxh

| Aspect | xxh | z4m |
|--------|-----|-----|
| Encoding | Double Base64 | Single Base64 |
| Transport | CLI arguments (+heb) | Script embedding (prelude) |
| Security | None | Built-in exclusion patterns |
| Type detection | Plugin env files | Automatic via `${(Pt)var}` |

xxh requires double encoding because CLI arguments cannot contain newlines. z4m embeds directly in the script payload, requiring only single-layer encoding.

## 5. Security

### 5.1 Built-in Exclusion Patterns

The following patterns are automatically excluded to prevent accidental credential leakage:

```
*_SECRET, *_SECRET_*, *SECRET_*
*_TOKEN, *_TOKEN_*, *TOKEN_*
*_KEY, *_API_KEY, *API_KEY*
*_PASSWORD, *PASSWORD*
*_CREDENTIAL*, *CREDENTIAL*
AWS_SECRET_*, AWS_SESSION_TOKEN
GITHUB_TOKEN, GH_TOKEN, GITLAB_TOKEN
NPM_TOKEN, NPM_AUTH_TOKEN
DOCKER_PASSWORD, DOCKER_AUTH_*
```

### 5.2 Size Constraints

| Constraint | Limit | Behavior |
|------------|-------|----------|
| Per-variable | 4KB | Silently skipped |
| Total payload | 64KB | Entire feature disabled |

## 6. Test Matrix

```zsh
# Case 1: Simple scalar
export EDITOR=vim
# Expected: export EDITOR='vim'

# Case 2: Scalar with whitespace and quotes
export FZF_DEFAULT_OPTS='--height=40% --border'
# Expected: Verbatim preservation

# Case 3: Scalar with embedded newlines (critical edge case)
export MULTI_LINE=$'line1\nline2\nline3'
# Expected: Newlines preserved via Base64 round-trip

# Case 4: Indexed array
export -a MY_ARRAY=('item 1' 'item "2"' $'item\n3')
# Expected: Array structure preserved

# Case 5: Associative array
typeset -A MY_MAP=([key1]='value 1' [key2]='value "2"')
# Expected: Key-value pairs preserved

# Case 6: Security exclusion
export MY_SECRET_KEY='sensitive'
export GITHUB_TOKEN='ghp_xxx'
# Expected: Not propagated (matched by default exclusions)
```

## 7. Modified Files

| File | Lines | Description |
|------|-------|-------------|
| `fn/-z4m-cmd-ssh` | 181-286 | Variable collection and Base64 encoding |
| `fn/-z4m-init` | 5-17 | Remote restoration logic |
| `config.md` | 298-323 | User-facing configuration documentation |
