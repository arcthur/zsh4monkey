#!/usr/bin/env zsh

emulate -L zsh -o no_aliases

cd -- "${0:A:h:h}" || exit 1
fpath=("$PWD/fn" $fpath)
zmodload zsh/zle || exit 1
autoload -Uz -- -z4m-init-tmux-nav

tmpdir=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-tmux-nav.XXXXXXXXXX") || exit 1
trap 'command rm -rf -- "$tmpdir"' EXIT

print -r -- "#!/bin/sh
printf '%s\n' \"\$*\" >>'$tmpdir/tmux.log'" >$tmpdir/tmux
command chmod 755 -- $tmpdir/tmux || exit 1

TMUX=/tmp/tmux-test,1,0 _Z4M_TMUX_CMD=$tmpdir/tmux
-z4m-init-tmux-nav || { print -ru2 -- 'init failed'; exit 1 }

# Widgets run after the init function has returned, as in a real shell.
-z4m-tmux-select-pane left 2>/dev/null
z4m-resize-up 2>/dev/null

local expected=$'select-pane -L\nresize-pane -U 5'
local actual=$(<$tmpdir/tmux.log) 2>/dev/null
if [[ $actual != $expected ]]; then
  print -ru2 -- "widgets did not reach tmux: expected ${(q+)expected}, got ${(q+)actual}"
  exit 1
fi
