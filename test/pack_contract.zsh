#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail

setopt local_options

cd -- "${0:A:h:h}" || exit 1

if rg -n --color=never 'eval "src=\$extra"' fn/-z4m-cmd-pack >/dev/null 2>&1; then
  print -ru2 -- 'unexpected legacy eval in fn/-z4m-cmd-pack'
  rg -n --color=never 'eval "src=\$extra"' fn/-z4m-cmd-pack >&2 || true
  exit 1
fi

if ! rg -n --color=never -- '--dest|--glob|--exclude' docs/design-pack.md fn/-z4m-cmd-help >/dev/null 2>&1; then
  print -ru2 -- 'missing pack copy spec documentation'
  exit 1
fi
