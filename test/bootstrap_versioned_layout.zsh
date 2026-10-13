#!/usr/bin/env zsh
#
# Drive the real bootstrap in z4m.zsh and assert the layout it produces. The
# property that matters is not just that activation works, but that a candidate
# which fails to assemble leaves the active version completely untouched --
# that is what replaced the guard/backup/temporary-bootstrap machinery.

emulate -L zsh -o err_return -o no_unset -o pipe_fail -o extended_glob -o no_aliases

local repository=${0:A:h:h}
local test_directory
test_directory=$(mktemp -d) || exit 1
trap 'rm -rf -- "$test_directory"' EXIT HUP INT TERM

typeset -gi failures=0

fail() {
  print -ru2 -- "$1"
  (( ++failures ))
}

# A minimal framework that the sh bootstrap can source. Only the pieces the
# bootstrap itself touches are real: sc/setup and the activation scripts.
make_fixture() {
  local dir=$1 marker=$2
  mkdir -p -- $dir/sc $dir/fn
  print -r -- "Z4M_TEST_FRAMEWORK=$marker" >$dir/main.zsh
  print -r -- "return 0" >>$dir/main.zsh
  # The real entry point: activation links $Z4M/z4m.zsh into the version
  # directory, so this file is what the next shell actually bootstraps from.
  command cp -- $repository/z4m.zsh $dir/z4m.zsh
  command cp -- $repository/sc/setup $dir/sc/setup
  command cp -- $repository/sc/activate-version $dir/sc/activate-version
  command cp -- $repository/sc/prune-versions $dir/sc/prune-versions
  print -r -- 100000001 >$dir/version
}

# The bootstrap is expected to fail at `. main.zsh && setopt aliases`, because
# sh has no setopt. The layout is complete before that point, which is exactly
# what these assertions cover.
run_bootstrap() {
  local cache=$1 fixture=$2 ref=$3
  Z4M=$cache \
  Z4M_URL=https://raw.githubusercontent.com/arcthur/zsh4monkey/$ref \
  Z4M_TEST_FIXTURE=$fixture \
  Z4M_BOOTSTRAP_COMMAND='command mkdir -p -- "$Z4M_PACKAGE_DIR" && command cp -R -- "$Z4M_TEST_FIXTURE"/. "$Z4M_PACKAGE_DIR"/' \
    command sh $cache/z4m.zsh >/dev/null 2>&1 || true
}

active_version() {
  REPLY=
  [[ -L $1/current ]] || return 1
  REPLY=$(command readlink -- $1/current) || return 1
  REPLY=${REPLY#versions/}
}

local alpha=$test_directory/fixture-alpha
local beta=$test_directory/fixture-beta
local broken=$test_directory/fixture-broken
make_fixture $alpha alpha
make_fixture $beta beta
# A candidate without a framework: activation must refuse it.
mkdir -p -- $broken
command cp -- $repository/z4m.zsh $broken/z4m.zsh

local cache=$test_directory/cache
mkdir -p -- $cache
command cp -- $repository/z4m.zsh $cache/z4m.zsh

# First bootstrap: a fresh cache reaches the versioned layout.
run_bootstrap $cache $alpha main

[[ -L $cache/current ]] || fail 'bootstrap did not create the switch point'
[[ -L $cache/zsh4monkey ]] || fail 'bootstrap did not link the framework path'
[[ -L $cache/z4m.zsh ]] || fail 'bootstrap did not link the entry point'
[[ -r $cache/zsh4monkey/main.zsh ]] ||
  fail 'framework is not reachable through the stable path'
[[ $(<$cache/zsh4monkey/main.zsh) == *alpha* ]] ||
  fail 'stable path does not resolve to the installed framework'
[[ $(<$cache/zsh4monkey/.z4m-source-ref) == main ]] ||
  fail 'bootstrap did not record the source ref'

active_version $cache || fail 'no active version after bootstrap'
local first=$REPLY
[[ -d $cache/versions/$first ]] || fail 'active version directory is missing'

# The bootstrap works in a hidden staging directory, so it never competes for a
# name a running shell resolves through.
local -a staging=($cache/versions/.staging.*(N))
(( ${#staging} == 0 )) || fail "bootstrap left staging directories: ${staging[*]}"

# A failing candidate must not disturb the active version. This is the whole
# point of assembling outside the active tree.
run_bootstrap $cache $broken v9.9.9

active_version $cache || fail 'switch point disappeared after a failed bootstrap'
[[ $REPLY == $first ]] ||
  fail "a failed bootstrap changed the active version: $REPLY"
[[ $(<$cache/zsh4monkey/main.zsh) == *alpha* ]] ||
  fail 'a failed bootstrap disturbed the active framework'
staging=($cache/versions/.staging.*(N) $cache/versions/v9.9.9*(N))
(( ${#staging} == 0 )) || fail "a failed bootstrap left its candidate behind: ${staging[*]}"

# A second, valid candidate switches the cache and keeps the previous version
# available as a rollback target.
run_bootstrap $cache $beta v1.0.0.1

active_version $cache || fail 'no active version after the second bootstrap'
local second=$REPLY
[[ $second != $first ]] || fail 'the second bootstrap reused the active version'
[[ $(<$cache/zsh4monkey/main.zsh) == *beta* ]] ||
  fail 'stable path still resolves to the previous framework'
[[ -d $cache/versions/$first ]] ||
  fail 'the previous version was not retained for rollback'

# Runtime state created by sc/setup survives a version switch.
local state
for state in bin fn tmp stickycache cache; do
  [[ -d $cache/$state ]] || fail "runtime state was lost across activation: $state"
done

# A cache left in the flat layout by an older install or by ssh bootstrap must
# migrate rather than end up with a link nested inside the old directory.
local legacy=$test_directory/legacy
mkdir -p -- $legacy/zsh4monkey
command cp -- $repository/z4m.zsh $legacy/z4m.zsh
print -r -- 'Z4M_TEST_FRAMEWORK=legacy' >$legacy/zsh4monkey/main.zsh
print -r -- legacy >$legacy/zsh4monkey/leftover

run_bootstrap $legacy $alpha v1.0.0.1

[[ -L $legacy/zsh4monkey ]] || fail 'flat layout was not migrated'
[[ $(<$legacy/zsh4monkey/main.zsh) == *alpha* ]] ||
  fail 'migrated cache does not resolve to the new framework'
[[ ! -e $legacy/zsh4monkey/leftover ]] ||
  fail 'migration nested the link inside the old directory'
local -a scratch=($legacy/.z4m-replaced.*(N))
(( ${#scratch} == 0 )) || fail "migration left scratch entries: ${scratch[*]}"

(( failures == 0 ))
