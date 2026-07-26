#!/usr/bin/env zsh
#
# -z4m-recover-update is the single restore implementation shared by
# `z4m update` and the temporary bootstrap. Cover its semantics directly:
# restore from a backup, roll forward when the new tree is already active,
# fail closed without a usable backup, and carry multi-character dotfiles.

emulate -L zsh -o err_return -o no_unset -o pipe_fail -o extended_glob -o no_aliases

local repository=${0:A:h:h}
local test_directory
test_directory=$(mktemp -d) || exit 1
trap 'rm -rf -- "$test_directory"' EXIT HUP INT TERM

fpath=($repository/fn $fpath)
autoload -Uz -- -z4m-recover-update

typeset -gi failures=0

fail() {
  print -ru2 -- "$1"
  (( ++failures ))
}

# Scenario 1: a complete backup is restored over a partially replaced cache,
# including the dotfiles that record transaction state.
local root=$test_directory/restore
local backup=$root.old
local candidate=$root.new
local guard=$root/.updating
local lock=$root/.update-recovery-lock

mkdir -p -- $root/zsh4monkey $backup/zsh4monkey $candidate
print -r -- bootstrap-old >$backup/z4m.zsh
print -r -- core-old >$backup/zsh4monkey/main.zsh
print -r -- source-old >$backup/.update-source
print -r -- keep >$backup/.a
print -r -- bootstrap-temporary >$root/z4m.zsh
print -r -- core-new >$root/zsh4monkey/main.zsh
print -r -- source-new >$root/.update-source
print -r -- leftover >$root/.last-init-failed
print -r -- guard >$guard
mkdir -p -- $lock

-z4m-recover-update $root $guard $lock $backup $candidate ||
  fail 'restore scenario returned failure'

[[ $(<$root/z4m.zsh) == bootstrap-old ]] ||
  fail 'restore did not reinstate the backed-up bootstrap'
[[ $(<$root/zsh4monkey/main.zsh) == core-old ]] ||
  fail 'restore did not reinstate the backed-up tree'
[[ $(<$root/.update-source) == source-old ]] ||
  fail 'restore did not reinstate a multi-character dotfile'
[[ $(<$root/.a) == keep ]] ||
  fail 'restore did not reinstate a short dotfile'
[[ ! -e $root/.last-init-failed ]] ||
  fail 'restore left a stale marker that the backup does not contain'
[[ ! -e $guard && ! -e $backup && ! -e $candidate ]] ||
  fail 'restore did not clear transaction state'
[[ -d $lock ]] ||
  fail 'restore removed the recovery lock owned by its caller'

# Scenario 2: replacement finished and only the entry point is missing, so the
# new tree must be kept rather than rolled back.
local forward_root=$test_directory/forward
local forward_backup=$forward_root.old
local forward_candidate=$forward_root.new
local forward_guard=$forward_root/.updating

mkdir -p -- $forward_root/zsh4monkey $forward_backup $forward_candidate
print -r -- bootstrap-old >$forward_backup/z4m.zsh
print -r -- core-new >$forward_root/zsh4monkey/main.zsh
print -r -- payload-new >$forward_root/.update-source
print -r -- guard >$forward_guard

-z4m-recover-update \
  $forward_root $forward_guard $forward_root/.lock \
  $forward_backup $forward_candidate ||
  fail 'roll-forward scenario returned failure'

[[ $(<$forward_root/z4m.zsh) == bootstrap-old ]] ||
  fail 'roll-forward did not reinstate the bootstrap entry point'
[[ $(<$forward_root/zsh4monkey/main.zsh) == core-new ]] ||
  fail 'roll-forward discarded the already-installed tree'
[[ $(<$forward_root/.update-source) == payload-new ]] ||
  fail 'roll-forward discarded new transaction state'
[[ ! -e $forward_guard ]] ||
  fail 'roll-forward did not clear the guard'

# Scenario 3: without a usable backup there is nothing to restore, so the guard
# must survive for the operator instead of being cleared silently.
local broken_root=$test_directory/broken
local broken_backup=$broken_root.old
local broken_guard=$broken_root/.updating

mkdir -p -- $broken_root $broken_backup
print -r -- bootstrap-temporary >$broken_root/z4m.zsh
print -r -- guard >$broken_guard

if -z4m-recover-update \
    $broken_root $broken_guard $broken_root/.lock \
    $broken_backup $broken_root.new 2>/dev/null; then
  fail 'recovery without a backup bootstrap unexpectedly succeeded'
fi
[[ -e $broken_guard ]] ||
  fail 'failed recovery cleared the guard'

# Scenario 4: wrong argument counts are rejected rather than acting on defaults.
if -z4m-recover-update $broken_root $broken_guard 2>/dev/null; then
  fail 'recovery accepted an incomplete argument list'
fi

(( failures == 0 ))
