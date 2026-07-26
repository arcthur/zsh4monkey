#!/usr/bin/env zsh
#
# The update path must never construct a state that needs repairing. Assert the
# structural properties that guarantee it: the candidate is built outside $Z4M,
# it enters through sc/activate-version, and the machinery that used to guard a
# non-atomic replacement is gone rather than merely unused.

emulate -L zsh -o err_return -o no_unset -o pipe_fail -o no_aliases

local repository=${0:A:h:h}
local source_file=$repository/fn/-z4m-cmd-update
local rollback_file=$repository/fn/-z4m-cmd-rollback
local bootstrap_file=$repository/z4m.zsh

typeset -gi failures=0

require() {
  local pattern=$1 file=$2 reason=$3
  if ! command grep -Fq -- "$pattern" "$file"; then
    print -ru2 -- "${file:t}: missing $reason"
    (( ++failures ))
  fi
}

refuse() {
  local pattern=$1 file=$2 reason=$3
  if command grep -Fq -- "$pattern" "$file"; then
    print -ru2 -- "${file:t}: $reason"
    (( ++failures ))
  fi
}

# The candidate is assembled in a throwaway cache next to $Z4M, never inside it.
require 'local staging=$Z4M.staging.$sysparams[pid]' "$source_file" \
  'a staging cache outside the active one'
require 'Z4M_UPDATING=$Z4M Z4M=$staging' "$source_file" \
  'the full rehearsal in the staging cache'
require 'print -n >$Z4M/tmp/update-successful' "$source_file" \
  'the rehearsal success marker'

# Activation is delegated, so the switch semantics live in exactly one place.
require 'sc/activate-version' "$source_file" 'delegated activation'
require 'sc/activate-version' "$bootstrap_file" 'delegated activation in bootstrap'
require 'sc/activate-version' "$rollback_file" 'delegated activation in rollback'
require 'sc/prune-versions' "$source_file" 'version retention'

# Upgrading from a pre-versioning install rehearses with the old bootstrap and
# therefore yields a flat candidate. Promotion must resolve the framework rather
# than require a particular candidate layout.
require 'framework=${framework:A}' "$source_file" \
  'layout-independent candidate resolution'
refuse 'candidate did not produce a versioned layout' "$source_file" \
  'still demands a versioned candidate'

# Ordering: the candidate must be complete and verified before it is activated,
# and packages only move after the framework switch has already succeeded.
local rehearsal_line move_line activate_line packages_line
rehearsal_line=$(command grep -n -- 'print -n >$Z4M/tmp/update-successful' "$source_file" | cut -d: -f1)
move_line=$(command grep -n -F -- '-z4m-mv $framework $target_dir/zsh4monkey' "$source_file" | cut -d: -f1)
activate_line=$(command grep -n -F -- \
  'command sh $Z4M/versions/$target_name/zsh4monkey/sc/activate-version' \
  "$source_file" | cut -d: -f1)
packages_line=$(command grep -n -F -- 'for entry in $staging/*(N)' "$source_file" | cut -d: -f1)

if [[ $rehearsal_line != <-> || $move_line != <-> ||
      $activate_line != <-> || $packages_line != <-> ]]; then
  print -ru2 -- 'update lost one of its ordered phases'
  (( ++failures ))
elif (( ! (rehearsal_line < move_line &&
           move_line < activate_line &&
           activate_line < packages_line) )); then
  print -ru2 -- 'update phases are out of order'
  (( ++failures ))
fi

# The old non-atomic machinery must be deleted, not merely bypassed: each of
# these existed only to survive a window that no longer exists.
local obsolete
for obsolete in \
    fn/-z4m-write-update-bootstrap \
    fn/-z4m-recover-update; do
  if [[ -e $repository/$obsolete ]]; then
    print -ru2 -- "obsolete recovery machinery still present: $obsolete"
    (( ++failures ))
  fi
done

refuse '.z4m-next-bootstrap' "$source_file" 'still stages a replacement bootstrap'
refuse '.update-recovery-lock' "$source_file" 'still keeps a recovery lock'
refuse 'recover-stale' "$source_file" 'still carries stale-transaction recovery'
refuse '$Z4M.old.' "$source_file" 'still snapshots the active cache'

# $Z4M itself is never emptied any more; that loop was the window.
refuse 'zf_rm -rf -- $entry' "$source_file" 'still clears the active cache'

# Startup must not block on a concurrent update: the active version stays usable
# for the whole operation.
refuse 'command sleep' "$bootstrap_file" 'still waits for a concurrent update'

# Rollback is a switch, not a reinstall: it must not fetch or rebuild anything.
require 'zparseopts -D -F -- l=list_only -list=list_only' "$rollback_file" \
  'the --list option'
require 'keep-versions' "$rollback_file" 'a pointer to the retention style'
refuse '-z4m-resolve-update-url' "$rollback_file" 'resolves an update channel'
refuse 'command curl' "$rollback_file" 'downloads during rollback'
refuse 'command tar' "$rollback_file" 'extracts during rollback'

# Runtime state belongs to the machine, not to the candidate: the layout entries
# activation owns and the caches this host accumulated must survive an update.
require '  versions current z4m.zsh z4m.zsh.zwc zsh4monkey' "$source_file" \
  'the preserved layout entries'
require '  cache stickycache tmp bin fn)' "$source_file" \
  'the preserved runtime state'

(( failures == 0 ))
