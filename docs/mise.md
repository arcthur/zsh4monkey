# mise Integration

z4m does not activate [mise](https://mise.jdx.dev) itself. Activate it as mise
documents, after `z4m init` in `~/.zshrc`:

```zsh
eval "$(mise activate zsh)"
```

## Fast Hook

`mise activate zsh` installs a `precmd` hook that runs `mise hook-env` before
every prompt, a process spawn of tens of milliseconds even when nothing
changed. On its first prompt z4m keeps mise's `_mise_hook` but replaces mise's
`precmd` and `chpwd` hooks with one that calls it only when a fork-free
signature changes:

- `$PWD` and `$PATH`
- every `MISE_*` variable, including `MISE_ENV`
- nanosecond mtimes of the files mise discovers from `$PWD` up to `/`:
  `mise.toml`, `.mise.toml`, their `.local` and `MISE_ENV` variants,
  `mise/` and `.mise/` and `.config/mise/` config directories with `conf.d`,
  `.config/mise.toml`, `.tool-versions`, `.env`, `.env.local`, and common
  idiomatic version files (`.nvmrc`, `.node-version`, `.python-version`, ...)
- the global config directory (`$MISE_CONFIG_DIR`), `/etc/mise/config.toml`,
  and the tool install directories under `$MISE_DATA_DIR/installs`

Any command line that mentions `mise` also forces a refresh, because commands
such as `mise trust` and `mise settings` change state outside those files.

The signature costs about a millisecond per prompt, measured on macOS.

### Limits

mise re-reads anything its configuration references, and the signature only
covers the files above. Editing a file pulled in from elsewhere (for example
`_.file = "config/app.env"` or a `_.source` script) takes effect on the next
directory change or after any command line that mentions `mise` (`mise env`
will do). Disable the fast hook if that matters:

```zsh
zstyle ':z4m:mise' fast-hook no
```

The fast hook is installed only when `mise activate zsh` defined `_mise_hook`
and registered its `precmd` hook; `mise activate --shims` is left alone. After
`mise deactivate` the hook does nothing.

## Files

| File | Purpose |
|------|---------|
| `fn/-z4m-mise-hook` | Calls `_mise_hook` when the signature changes |
| `fn/-z4m-mise-signature` | Computes the signature without forking |
| `fn/-z4m-init-zle` | Swaps mise's hooks in `-z4m-post-init` |
