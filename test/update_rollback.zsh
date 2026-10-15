#!/usr/bin/env zsh
#
# Run the real `z4m update` and `z4m rollback` commands inside initialized
# shells. The property that matters is transactional: an update either
# activates a complete, rehearsed candidate or leaves the active version, its
# runtime state, and the cache layout exactly as they were.

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

local repository=${0:A:h:h}
source $repository/test/lib/sandbox.zsh || exit 1
sandbox_setup $repository || exit 1
trap sandbox_cleanup EXIT HUP INT TERM

active_version() {
  REPLY=
  [[ -L $SANDBOX_Z4M/current ]] || return 1
  REPLY=$(command readlink -- $SANDBOX_Z4M/current) || return 1
  REPLY=${REPLY#versions/}
}

# Usage: run_z4m <label> <expected-status: 0|fail> <command...>
run_z4m() {
  local label=$1 expected=$2
  shift 2
  sandbox_command "$* </dev/null; print -r -- __Z4M_STATUS__=\$?"
  local z4m_status=${${(M)REPLY:#*__Z4M_STATUS__=<->*}##*__Z4M_STATUS__=}
  z4m_status=${z4m_status%%[^0-9]*}
  if [[ -z $z4m_status ]]; then
    sandbox_fail "$label: the shell did not run the command"
  elif [[ $expected == 0 && $z4m_status != 0 ]]; then
    sandbox_fail "$label: expected success, got status $z4m_status"
  elif [[ $expected == fail && $z4m_status == 0 ]]; then
    sandbox_fail "$label: expected failure"
  else
    return 0
  fi
  print -ru2 -- "--- output ---"
  print -ru2 -- "${(q+)REPLY[-2000,-1]}"
  return 1
}

# Snapshot of everything an update must not touch when it fails.
snapshot() {
  local -a entries=($SANDBOX_Z4M/*(DN))
  local entry
  REPLY=
  for entry in $entries; do
    REPLY+="${entry:t} "
    [[ -L $entry ]] && REPLY+="-> $(command readlink -- $entry) "
  done
  REPLY+="| versions: ${(j: :)${:-$SANDBOX_Z4M/versions/*(DN:t)}}"
}

expect_no_transaction_leftovers() {
  local -a staging=(${SANDBOX_Z4M}.staging.*(DN) $SANDBOX_Z4M/versions/.staging.*(DN))
  (( ! $#staging )) || sandbox_fail "$1: staging left behind: ${staging[*]}"
  [[ ! -e $SANDBOX_Z4M/.updating ]] || sandbox_fail "$1: update guard left behind"
}

# --- Initial install ----------------------------------------------------------
run_z4m 'initial shell' 0 : || exit 1
active_version || { sandbox_fail 'initial shell did not activate a version'; exit 1 }
local first=$REPLY
print -r -- host-state >$SANDBOX_Z4M/stickycache/host-state

# --- Successful update --------------------------------------------------------
# The new release is distinguishable by a file only it carries.
print -r -- second >$SANDBOX_SOURCE/RELEASE_MARKER
run_z4m 'update to a new release' 0 z4m update --no-restart
sandbox_expect_output 'update did not report success' '*update successful*'
active_version
local second=$REPLY
[[ $second != $first ]] || sandbox_fail 'update did not switch to a new version'
[[ $(<$SANDBOX_Z4M/zsh4monkey/RELEASE_MARKER) == second ]] 2>/dev/null ||
  sandbox_fail 'stable framework path does not resolve to the update'
[[ -r $SANDBOX_Z4M/versions/$first/zsh4monkey/main.zsh ]] ||
  sandbox_fail 'update did not keep the previous version for rollback'
[[ $(<$SANDBOX_Z4M/stickycache/host-state) == host-state ]] 2>/dev/null ||
  sandbox_fail 'update discarded host runtime state'
[[ $(<$SANDBOX_Z4M/zsh4monkey/.z4m-update-source) == *'|https://raw.githubusercontent.com/arcthur/zsh4monkey/main' ]] ||
  sandbox_fail 'update did not record its source in the version'
[[ $(command readlink -- $SANDBOX_Z4M/previous) == versions/$first ]] ||
  sandbox_fail 'update did not record the version it replaced'
expect_no_transaction_leftovers 'successful update'

# The updated cache must start normally, not in safe mode.
sandbox_interactive 30 "*$SANDBOX_READY*" || sandbox_fail 'updated cache did not reach the prompt'

# --- Rehearsal that cannot bootstrap ------------------------------------------
snapshot; local before=$REPLY
command cp -p -- $SANDBOX_SOURCE/main.zsh $SANDBOX/main.orig || exit 1
print -r -- 'return 1' >$SANDBOX_SOURCE/main.zsh
run_z4m 'update with a broken candidate' fail z4m update --no-restart
sandbox_expect_output 'broken candidate update did not report failure' '*update*failed*'
snapshot
[[ $REPLY == $before ]] ||
  sandbox_fail "broken candidate changed the cache: ${(q+)before} -> ${(q+)REPLY}"
[[ ! -e $SANDBOX_Z4M/.last-init-failed ]] ||
  sandbox_fail 'rehearsal failure leaked a failure marker into the active cache'
expect_no_transaction_leftovers 'broken candidate'
command cp -p -- $SANDBOX/main.orig $SANDBOX_SOURCE/main.zsh || exit 1

# --- Rehearsal that never reaches the prompt ----------------------------------
# A .zshrc that overrides Z4M sends the rehearsal into the active cache. The
# rehearsal "succeeds" there, so only the explicit success marker can tell that
# the candidate itself was never initialized.
print -r -- third >$SANDBOX_SOURCE/RELEASE_MARKER
sandbox_write_zshrc
command cp -p -- $SANDBOX_HOME/.zshrc $SANDBOX/zshrc.orig || exit 1
{
  print -r -- "Z4M=${(q)SANDBOX_Z4M}"
  command cat -- $SANDBOX/zshrc.orig
} >$SANDBOX_HOME/.zshrc
snapshot; before=$REPLY
run_z4m 'update whose rehearsal escapes the candidate' fail z4m update --no-restart
sandbox_expect_output 'escaped rehearsal was not explained' '*does not propagate*'
snapshot
[[ $REPLY == $before ]] ||
  sandbox_fail "escaped rehearsal changed the cache: ${(q+)before} -> ${(q+)REPLY}"
expect_no_transaction_leftovers 'escaped rehearsal'
command cp -p -- $SANDBOX/zshrc.orig $SANDBOX_HOME/.zshrc || exit 1

# --- Concurrent update --------------------------------------------------------
# A live owner keeps the guard; a dead one is taken over. Startup never waits
# for either.
command sleep 60 &
local live_pid=$!
print -rl -- "pid=$live_pid" "epoch=$EPOCHSECONDS" >$SANDBOX_Z4M/.updating
snapshot; before=$REPLY
run_z4m 'update while another update runs' fail z4m update --no-restart
sandbox_expect_output 'concurrent update was not refused' "*already running with PID*$live_pid*"
snapshot
[[ $REPLY == $before ]] || sandbox_fail 'refused concurrent update changed the cache'
[[ $(<$SANDBOX_Z4M/.updating) == *pid=$live_pid* ]] ||
  sandbox_fail 'refused update released a guard it does not own'
sandbox_interactive 30 "*$SANDBOX_READY*" ||
  sandbox_fail 'startup blocked on a concurrent update'
kill $live_pid 2>/dev/null
wait $live_pid 2>/dev/null

run_z4m 'update after its owner died' 0 z4m update --no-restart
sandbox_expect_output 'stale guard was not taken over' '*taking over the guard of exited PID*'
active_version
local third=$REPLY
[[ $third != $second && $(<$SANDBOX_Z4M/zsh4monkey/RELEASE_MARKER) == third ]] ||
  sandbox_fail 'update after a stale guard did not activate the new release'
expect_no_transaction_leftovers 'stale guard takeover'

# Retention: two versions by default, the active one and the rollback target.
[[ -d $SANDBOX_Z4M/versions/$third && -d $SANDBOX_Z4M/versions/$second ]] ||
  sandbox_fail 'retention removed the active version or the rollback target'
[[ ! -e $SANDBOX_Z4M/versions/$first ]] ||
  sandbox_fail 'retention kept more versions than keep-versions allows'

# --- Rollback -----------------------------------------------------------------
run_z4m 'rollback --list' 0 z4m rollback --list
sandbox_expect_output 'rollback --list did not mark the active version' "*\\* $third *"
sandbox_expect_output 'rollback --list did not list the rollback target' "*$second*"

run_z4m 'rollback' 0 z4m rollback
active_version
[[ $REPLY == $second ]] || sandbox_fail "rollback activated $REPLY instead of $second"
[[ $(<$SANDBOX_Z4M/zsh4monkey/RELEASE_MARKER) == second ]] 2>/dev/null ||
  sandbox_fail 'rollback did not switch the framework'
[[ -d $SANDBOX_Z4M/versions/$third ]] || sandbox_fail 'rollback discarded the version it left'
sandbox_interactive 30 "*$SANDBOX_READY*" || sandbox_fail 'rolled-back cache did not reach the prompt'

local only
for only in $SANDBOX_Z4M/versions/*(/N:t); do
  [[ $only == $second ]] || command rm -rf -- $SANDBOX_Z4M/versions/$only
done
run_z4m 'rollback without an earlier version' fail z4m rollback
sandbox_expect_output 'rollback without a target was not explained' '*no earlier version*'
active_version
[[ $REPLY == $second ]] || sandbox_fail 'failed rollback changed the active version'

sandbox_expect_offline 'update and rollback'
(( SANDBOX_FAILURES == 0 ))
