#!/usr/bin/env zsh

emulate -L zsh -o err_return -o no_unset -o pipe_fail

local repository=${0:A:h:h}
local source_file=$repository/fn/-z4m-cmd-update
local bootstrap_file=$repository/fn/-z4m-write-update-bootstrap
local staged_line state_line commit_line activate_line

staged_line=$(command grep -n \
  -- '-z4m-mv \$new/z4m.zsh \$next_bootstrap' "$source_file" | cut -d: -f1)
state_line=$(command grep -n \
  -- '-z4m-mv \$Z4M/.update-source.\$\$ \$Z4M/.update-source' "$source_file" | cut -d: -f1)
commit_line=$(command grep -n \
  -- 'zf_rm -f -- \$guard || return' "$source_file" | tail -n 1 | cut -d: -f1)
activate_line=$(command grep -n \
  -- '-z4m-mv \$next_bootstrap \$Z4M/z4m.zsh' "$source_file" |
  tail -n 1 | cut -d: -f1)

[[ $staged_line == <-> && $state_line == <-> &&
   $commit_line == <-> && $activate_line == <-> ]]
(( staged_line < state_line &&
   state_line < commit_line &&
   commit_line < activate_line ))

command grep -Fq \
  'if [[ -r \$_z4m_update_next ]]; then' "$bootstrap_file"
command grep -Fq \
  'command mv -f -- \$_z4m_update_next \$_z4m_update_root/z4m.zsh' "$bootstrap_file"
command grep -Fq \
  'zparseopts -D -F -- n=no_restart -no-restart=no_restart' "$source_file"
command grep -Fq \
  '[[ ! -o interactive || ! -t 0 || ! -t 1 ]]' "$source_file"
command grep -Fq \
  'setopt local_options no_clobber' "$source_file"
command grep -Fq \
  'command kill -0 $existing_pid' "$source_file"
command grep -Fq \
  'zf_mkdir -- $recovery_lock' "$source_file"
command grep -Fq -- \
  '-z4m-cmd-update-release-recovery-lock' "$source_file"
command grep -Fq -- \
  '-z4m-write-update-bootstrap \' "$source_file"
# Replacement removes $Z4M/zsh4monkey, so the rollback path must not depend on
# reading a function file that is gone by the time it runs.
command grep -Fq -- \
  'for preload in -z4m-recover-update -z4m-error-command; do' "$source_file"
command grep -Fq -- \
  "autoload -Uz +X -- \$preload 2>/dev/null" "$source_file"

# `autoload +X` reports failure for an already-loaded function, so a second
# `z4m update` in the same shell must not be rejected by the preload. Exercise
# the pattern the updater uses over two rounds.
() {
  emulate -L zsh -o extended_glob -o no_aliases
  local scratch
  scratch=$(mktemp -d) || return 1
  {
    print -r -- 'print -n' >$scratch/-z4m-preload-probe || return 1
    fpath=($scratch $fpath)
    autoload -Uz -- -z4m-preload-probe || return 1
    local -i round
    for round in 1 2; do
      autoload -Uz +X -- -z4m-preload-probe 2>/dev/null
      [[ -n ${functions[-z4m-preload-probe]-} &&
         ${functions[-z4m-preload-probe]} != *'autoload -X'* ]] || return 1
    done
  } always {
    command rm -rf -- $scratch
  }
} || {
  print -ru2 -- 'preload pattern rejects an already-loaded function'
  exit 1
}
# The restore algorithm must exist once. Both callers route through it.
command grep -Fq -- \
  '-z4m-recover-update $Z4M $guard $recovery_lock $stale_old $stale_new' "$source_file"
command grep -Fq -- \
  '-z4m-recover-update \' "$bootstrap_file"
if command grep -Fq 'command cp -RP -- $entry $Z4M/' "$source_file"; then
  print -ru2 -- 'update reimplements the restore loop instead of using -z4m-recover-update'
  exit 1
fi
# Multi-character dotfiles such as .update-source must be part of the snapshot.
if command grep -Fq '.[^.](N)' "$source_file" ||
   command grep -Fq '.[^.](N)' "$bootstrap_file"; then
  print -ru2 -- 'update globs miss multi-character dotfiles'
  exit 1
fi
command grep -Fq -- \
  '-z4m-mv $temporary_bootstrap $Z4M/z4m.zsh' "$source_file"
if command grep -Fq \
    '>$Z4M/z4m.zsh' "$source_file"; then
  print -ru2 -- 'update bootstrap still writes directly to the active path'
  exit 1
fi
if command grep -Fq \
    'zf_rm -f -- $guard $next_bootstrap' "$source_file"; then
  print -ru2 -- 'update still deletes shared transaction state at startup'
  exit 1
fi
