#!/usr/bin/env zsh
#
# Version lifecycle across activation, rollback, pruning and startup: the active
# version and its rollback target must agree everywhere, whatever the order of
# updates and rollbacks, and whatever characters the cache path contains.

emulate -L zsh -o no_unset -o pipe_fail -o extended_glob -o no_aliases

local repository=${0:A:h:h}
local activate=$repository/sc/activate-version
local prune=$repository/sc/prune-versions
local test_directory
test_directory=$(mktemp -d) || exit 1
trap 'command chmod -R u+rwx -- "$test_directory" 2>/dev/null; rm -rf -- "$test_directory"' EXIT HUP INT TERM

typeset -gi failures=0

fail() {
  print -ru2 -- "$1"
  (( ++failures ))
}

local base=https://raw.githubusercontent.com/arcthur/zsh4monkey

# A version as `z4m update` or the bootstrap leaves it: its source ref and the
# configured|effective record it was installed under.
make_version() {
  local root=$1 name=$2 ref=$3 configured=$4
  mkdir -p -- $root/versions/$name/zsh4monkey/sc
  print -r -- "typeset -g Z4M_LIFECYCLE_TEST=$name" >$root/versions/$name/zsh4monkey/main.zsh
  print -r -- "$name" >$root/versions/$name/z4m.zsh
  print -r -- $ref >$root/versions/$name/zsh4monkey/.z4m-source-ref
  print -r -- "$base/$configured|$base/$ref" >$root/versions/$name/zsh4monkey/.z4m-update-source
  command cp -- $activate $root/versions/$name/zsh4monkey/sc/activate-version
}

link_target() {
  REPLY=
  [[ -L $1 ]] && REPLY=$(command readlink -- $1)
}

# Activation must not split or glob the cache path when it drops the flat-layout
# directories it moved aside. A sibling that matches the first word of the path
# is what word splitting would delete.
local spaced="$test_directory/my cache"
mkdir -p -- "$test_directory/my" "$spaced/zsh4monkey"
print -r -- keep >"$test_directory/my/sentinel"
print -r -- legacy >"$spaced/zsh4monkey/main.zsh"
print -r -- legacy >"$spaced/z4m.zsh"
make_version "$spaced" one v1.0.0 v1.0.0
command sh $activate "$spaced" one || fail 'activation failed for a path with a space'
[[ -r $test_directory/my/sentinel ]] ||
  fail 'activation removed a directory outside the cache'
[[ $(<"$spaced/zsh4monkey/main.zsh") == *one* ]] ||
  fail 'flat layout was not migrated for a path with a space'
local -a scratch=("$spaced"/.z4m-(replaced|activate).*(N))
(( $#scratch == 0 )) || fail "activation left scratch entries: ${scratch[*]}"

# A -> B -> rollback -> C: rollback goes to the version that was active, not to
# the newest directory, and pruning keeps it.
local cache=$test_directory/cache
make_version $cache a v1.0.0 v1.0.0
make_version $cache b v2.0.0 v1.0.0
command sh $activate $cache a
command sh $activate $cache b
link_target $cache/previous
[[ $REPLY == versions/a ]] || fail "previous after update is $REPLY"

fpath=($repository/fn $fpath)
autoload -Uz -- -z4m-cmd-rollback
zmodload -F zsh/files b:zf_rm
-z4m-check-core-params() { return 0 }
typeset -gi _z4m_dangerous_root=0
typeset -g Z4M=$cache

-z4m-cmd-rollback 2>/dev/null || fail 'rollback failed'
link_target $cache/current
[[ $REPLY == versions/a ]] || fail "rollback activated $REPLY instead of a"

# Created after b, so it is the newest directory on disk, yet b must stay the
# rollback target only until c is activated over a.
make_version $cache c v3.0.0 v1.0.0
command sh $activate $cache c
command sh $prune $cache 2
[[ -d $cache/versions/a ]] || fail 'pruning removed the version that was rolled back to'
[[ ! -d $cache/versions/b ]] || fail 'pruning kept a version that is not the rollback target'

-z4m-cmd-rollback 2>/dev/null || fail 'second rollback failed'
link_target $cache/current
[[ $REPLY == versions/a ]] || fail "second rollback activated $REPLY instead of a"

# Without a recorded previous version there is no rollback target to guess,
# and a recorded one that is gone is not replaced by a guess either.
local lone=$test_directory/lone
make_version $lone x v1.0.0 v1.0.0
make_version $lone y v2.0.0 v1.0.0
command sh $activate $lone y
Z4M=$lone
if -z4m-cmd-rollback 2>/dev/null; then
  fail 'rollback guessed a target without a recorded previous version'
fi
make_version $lone z v3.0.0 v1.0.0
command sh $activate $lone z
command rm -rf -- $lone/versions/y
if -z4m-cmd-rollback 2>/dev/null; then
  fail 'rollback guessed a target although the recorded one is gone'
fi
Z4M=$cache

# Startup after a rollback: the configured URL still matches the active
# version's own record, so the cache is used as is. A bootstrap would mean
# fetching the version that was just rolled away from; the bootstrap command is
# made to fail so that this can never reach the network. A cache-wide record
# would go stale on rollback, so one is planted to show it is not consulted.
print -r -- "$base/v1.0.0|$base/v2.0.0" >$cache/.update-source
local output
output=$(
  HOME=$test_directory \
  ZDOTDIR=$test_directory \
  Z4M=$cache \
  Z4M_URL=$base/v1.0.0 \
  Z4M_BOOTSTRAP_COMMAND='exit 1' \
    zsh -dfc 'source "$1" 2>/dev/null
      print -r -- "${Z4M_LIFECYCLE_TEST-}|$Z4M_URL|$_z4m_configured_url"' _ $repository/z4m.zsh
)
[[ $output == "a|$base/v1.0.0|$base/v1.0.0" ]] ||
  fail "startup after rollback did not use the active version: $output"

# After an update the record maps the configured URL to the installed ref and
# keeps the configured one for the next `z4m update`.
command sh $activate $cache c
output=$(
  HOME=$test_directory \
  ZDOTDIR=$test_directory \
  Z4M=$cache \
  Z4M_URL=$base/v1.0.0 \
  Z4M_BOOTSTRAP_COMMAND='exit 1' \
    zsh -dfc 'source "$1" 2>/dev/null
      print -r -- "${Z4M_LIFECYCLE_TEST-}|$Z4M_URL|$_z4m_configured_url"' _ $repository/z4m.zsh
)
[[ $output == "c|$base/v3.0.0|$base/v1.0.0" ]] ||
  fail "startup after update did not follow the active record: $output"

# The sh bootstrap prunes without zstyle access; it must honour the count that
# `z4m update` recorded rather than its own default.
local kept=$test_directory/kept
local name
for name in v1 v2 v3 v4; do
  make_version $kept $name $name $name
  command sh $activate $kept $name
done
print -r -- 4 >$kept/versions/.keep
command sh $prune $kept
local -a remaining=($kept/versions/*(N/:t))
(( $#remaining == 4 )) || fail "bootstrap pruning ignored the recorded count: ${remaining[*]}"
command sh $prune $kept 2
remaining=($kept/versions/*(N/:t))
[[ ${(j: :)${(o)remaining}} == 'v3 v4' ]] ||
  fail "pruning did not keep current and previous: ${remaining[*]}"

# A bootstrap that fails while assembling a candidate leaves no entry that
# rollback or pruning could take for an installed version.
local fixture=$test_directory/fixture
mkdir -p -- $fixture/sc
print -r -- 'return 0' >$fixture/main.zsh
command cp -- $repository/sc/setup $fixture/sc/setup
print -r -- 100000001 >$fixture/version
# No z4m.zsh in the fixture: assembly fails after the framework has been staged.
local boot=$test_directory/boot
mkdir -p -- $boot
command cp -- $repository/z4m.zsh $boot/z4m.zsh
Z4M=$boot \
Z4M_URL=$base/v1.0.0 \
Z4M_TEST_FIXTURE=$fixture \
Z4M_BOOTSTRAP_COMMAND='command mkdir -p -- "$Z4M_PACKAGE_DIR" && command cp -R -- "$Z4M_TEST_FIXTURE"/. "$Z4M_PACKAGE_DIR"/' \
  command sh $boot/z4m.zsh >/dev/null 2>&1
local -a leftovers=($boot/versions/*(ND))
(( $#leftovers == 0 )) || fail "failed bootstrap left entries: ${leftovers[*]}"

# Uninstall keeps whatever it could not back up and reports failure.
if (( EUID )); then
  autoload -Uz -- -z4m-cmd-uninstall
  zmodload -F zsh/files b:zf_mkdir
  local home=$test_directory/home
  mkdir -p -- $home/cache
  print -r -- rc >$home/.zshrc
  print -r -- env >$home/.zshenv
  command chmod 000 $home/.zshrc
  if ( HOME=$home ZDOTDIR=$home Z4M=$home/cache -z4m-cmd-uninstall --force ) >/dev/null 2>&1; then
    fail 'uninstall reported success although a backup failed'
  fi
  [[ -e $home/.zshrc ]] || fail 'uninstall removed a file it could not back up'
  [[ ! -e $home/.zshenv ]] || fail 'uninstall kept a file it backed up'
  local -a backups=($home/.z4m-backup-*/.zshenv(N))
  (( $#backups == 1 )) || fail 'uninstall did not back up the removable file'
fi

(( failures == 0 ))
