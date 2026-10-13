#!/usr/bin/env zsh
#
# Key bindings depend on what the host provides. Without fzf, Tab and Ctrl+R
# must fall back to the zsh builtins in every keymap instead of binding widgets
# that cannot work; with fzf they must use the fzf widgets.

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

local repository=${0:A:h:h}
source $repository/test/lib/sandbox.zsh || exit 1
sandbox_setup $repository || exit 1
trap sandbox_cleanup EXIT HUP INT TERM

# Usage: expect_bindings <scenario> <keymap-args> <key> <widget> [<keymap-args> <key> <widget>]...
expect_bindings() {
  local scenario=$1
  shift
  sandbox_pty_start || return
  if ! sandbox_pty_expect 60 "*$SANDBOX_READY*"; then
    sandbox_fail "$scenario: shell did not reach the prompt"
    sandbox_pty_stop
    return
  fi
  local keymap key widget
  while (( $# >= 3 )); do
    keymap=$1 key=$2 widget=$3
    shift 3
    # bindkey prints `"<key>" <widget>`; the typed command never contains that.
    sandbox_pty_send "bindkey $keymap ${(q)key}"
    sandbox_pty_expect 20 "*${(b)${:-\"$key\" $widget}}*" ||
      sandbox_fail "$scenario: ${keymap:-emacs} $key is not bound to $widget"
  done
  sandbox_pty_stop
}

sandbox_write_zshrc
expect_bindings 'emacs without fzf' \
  '' '^I' expand-or-complete \
  '' '^R' history-incremental-search-backward

SANDBOX_PRE_INIT=("zstyle ':z4m:' editor-mode vi")
sandbox_write_zshrc
expect_bindings 'vi without fzf' \
  '-M viins' '^I' expand-or-complete \
  '-M vicmd' '^I' expand-or-complete \
  '-M viins' '^R' history-incremental-search-backward

# A system fzf: the package resolves to the tool on PATH, nothing is fetched.
print -r -- $'#!/bin/sh\necho 0.60.0' >$SANDBOX/bin/fzf
command chmod 755 $SANDBOX/bin/fzf || exit 1
SANDBOX_PRE_INIT=("zstyle -d ':z4m:fzf' channel")
sandbox_write_zshrc
expect_bindings 'emacs with fzf' \
  '' '^I' z4m-fzf-complete \
  '' '^R' z4m-fzf-history

sandbox_expect_offline 'key bindings'
(( SANDBOX_FAILURES == 0 ))
