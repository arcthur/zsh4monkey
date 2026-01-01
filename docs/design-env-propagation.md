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
│  3. Generate data payload (no shell code)                       │
│     - scalar:      NAME\tS\t<val_b64>                           │
│     - array:       NAME\tA\t<count>\t<elem1_b64>...             │
│     - association: NAME\tM\t<count>\t<k1_b64>\t<v1_b64>...       │
│     ↓                                                           │
│  4. Base64-encode the whole payload                             │
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
│                 data-only restore (no eval)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  if [[ -v _Z4M_PROPAGATED_ENV_B64 ]]; then                      │
│    # Base64 decode into a tab-separated data payload            │
│    # Parse & restore via namerefs (no eval)                     │
│    unset _Z4M_PROPAGATED_ENV_B64                                │
│  fi                                                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 3. Implementation

### 3.1 Local Collection (fn/-z4m-cmd-ssh:181-286)

```zsh
# Collect variables according to zstyle rules, apply exclusions, deduplicate.
# For each selected variable, emit one tab-separated record:
#   scalar: NAME\tS\t<val_b64>
#   array:  NAME\tA\t<count>\t<elem1_b64>...
#   assoc:  NAME\tM\t<count>\t<k1_b64>\t<v1_b64>...
# Then base64-encode the whole payload and export it as _Z4M_PROPAGATED_ENV_B64
# in the ssh bootstrap prelude.
```

### 3.2 Remote Restoration (fn/-z4m-init)

```zsh
# Decode-and-parse only (no eval). Payload is a tab-separated format:
#   Z4M_ENV
#   NAME\tS\t<val_b64>
#   NAME\tA\t<count>\t<elem1_b64>...
#   NAME\tM\t<count>\t<k1_b64>\t<v1_b64>...
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

**Solution**: Encode values uniformly via Base64 (per-field) and transmit a data-only payload. This preserves newlines and special characters without embedding shell syntax.

### 4.2 Why Restore in zsh Instead of POSIX sh?

1. **Syntax compatibility**: POSIX sh does not support array syntax (`export -a ARR=(...)`)
2. **Type support**: associative arrays and indexed arrays are native in zsh
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

### 5.3 Formal Invariants (Fail-Closed)

Remote restoration treats the payload as untrusted input and validates it as a strict data format. Any violation causes the entire payload to be discarded (no partial application).

- Bounded sizes: base64 input, decoded payload, per-line length
- Strict grammar: tab-separated records only
- Structural checks: field count and declared element/pair counts must match
- Bounded counts: maximum number of variables and elements/pairs
- Bounded values: maximum scalar/value/key lengths after decode
- Namespace protection: variables matching `(_Z4M_*|Z4M_*|_z4m_*|z4m_*)` are rejected

### 5.4 Diagnostics

To debug why a payload was rejected:

- On any machine, you can validate a captured payload:

```zsh
z4m env-propagation-diagnose '<base64>'
```

- On the remote side, set `Z4M_ENV_PROPAGATION_DEBUG=1` to print a rejection reason to stderr during init.

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
