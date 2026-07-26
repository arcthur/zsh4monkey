#!/usr/bin/env zsh
#
# sc/activate-version is the single switch point of the versioned layout, and
# sc/prune-versions decides what stays available for rollback. Cover the states
# they have to handle: a fresh cache, a switch between versions, the flat layout
# left by older installs and by ssh bootstrap, and inputs that must be refused.

emulate -L zsh -o err_return -o no_unset -o pipe_fail -o extended_glob -o no_aliases

local repository=${0:A:h:h}
local activate=$repository/sc/activate-version
local prune=$repository/sc/prune-versions
local test_directory
test_directory=$(mktemp -d) || exit 1
trap 'rm -rf -- "$test_directory"' EXIT HUP INT TERM

typeset -gi failures=0

fail() {
  print -ru2 -- "$1"
  (( ++failures ))
}

make_version() {
  local root=$1 name=$2 marker=$3
  mkdir -p -- $root/versions/$name/zsh4monkey
  print -r -- "$marker" >$root/versions/$name/z4m.zsh
  print -r -- "$marker" >$root/versions/$name/zsh4monkey/main.zsh
}

assert_link() {
  local link=$1 expected=$2 name=$3
  if [[ ! -L $link ]]; then
    fail "$name is not a symlink: $link"
    return
  fi
  local actual
  actual=$(command readlink -- $link)
  [[ $actual == $expected ]] || fail "$name points at $actual, expected $expected"
}

# A fresh cache: every stable entry point is created and resolves through the
# single switch point.
local fresh=$test_directory/fresh
make_version $fresh one alpha
command sh $activate $fresh one || fail 'activating a fresh cache failed'

assert_link $fresh/current versions/one 'current'
assert_link $fresh/zsh4monkey current/zsh4monkey 'zsh4monkey'
assert_link $fresh/z4m.zsh current/z4m.zsh 'z4m.zsh'
assert_link $fresh/z4m.zsh.zwc current/z4m.zsh.zwc 'z4m.zsh.zwc'
[[ $(<$fresh/zsh4monkey/main.zsh) == alpha ]] ||
  fail 'framework is not reachable through the stable path'
[[ $(<$fresh/z4m.zsh) == alpha ]] ||
  fail 'bootstrap entry point is not reachable through the stable path'

# Switching only rewrites `current`; the other links keep pointing at it and
# start resolving to the new tree without being touched.
make_version $fresh two beta
command sh $activate $fresh two || fail 'switching versions failed'
assert_link $fresh/current versions/two 'current after switch'
assert_link $fresh/zsh4monkey current/zsh4monkey 'zsh4monkey after switch'
[[ $(<$fresh/zsh4monkey/main.zsh) == beta ]] ||
  fail 'stable path still resolves to the previous version'
[[ -d $fresh/versions/one ]] ||
  fail 'switching removed the previous version'

# Relative link targets keep the cache valid when $Z4M itself is moved.
local moved=$test_directory/moved
command mv -- $fresh $moved
[[ $(<$moved/zsh4monkey/main.zsh) == beta ]] ||
  fail 'layout broke after relocating the cache'

# The flat layout: real z4m.zsh and zsh4monkey entries, as produced by older
# installs and by ssh bootstrap. Activation must replace them, not nest inside.
local flat=$test_directory/flat
mkdir -p -- $flat/zsh4monkey
print -r -- legacy >$flat/z4m.zsh
print -r -- legacy >$flat/zsh4monkey/main.zsh
print -r -- legacy >$flat/zsh4monkey/leftover
make_version $flat migrated gamma
command sh $activate $flat migrated || fail 'migrating a flat layout failed'

assert_link $flat/current versions/migrated 'current after migration'
assert_link $flat/zsh4monkey current/zsh4monkey 'zsh4monkey after migration'
assert_link $flat/z4m.zsh current/z4m.zsh 'z4m.zsh after migration'
[[ $(<$flat/zsh4monkey/main.zsh) == gamma ]] ||
  fail 'migration did not switch the framework'
[[ ! -e $flat/zsh4monkey/leftover ]] ||
  fail 'migration nested the link inside the old directory'
local -a replaced=($flat/.z4m-replaced.*(N) $flat/.z4m-activate.*(N))
(( ${#replaced} == 0 )) ||
  fail "migration left scratch entries behind: ${replaced[*]}"

# Activation is idempotent, so a retry after an interrupted run is safe.
command sh $activate $flat migrated || fail 'reactivating the same version failed'
assert_link $flat/current versions/migrated 'current after reactivation'

# Refusals: a real directory in place of `current` would silently nest the link.
local guarded=$test_directory/guarded
make_version $guarded one alpha
mkdir -p -- $guarded/current
if command sh $activate $guarded one 2>/dev/null; then
  fail 'activation replaced a non-symlink current'
fi

# Refusals: unsafe names and incomplete versions.
local strict=$test_directory/strict
make_version $strict one alpha
mkdir -p -- $strict/versions/hollow
if command sh $activate $strict ../escape 2>/dev/null; then
  fail 'activation accepted a traversing version name'
fi
if command sh $activate $strict missing 2>/dev/null; then
  fail 'activation accepted a missing version'
fi
if command sh $activate $strict hollow 2>/dev/null; then
  fail 'activation accepted a version without a framework'
fi
if command sh $activate $strict 2>/dev/null; then
  fail 'activation accepted a missing version argument'
fi

# Pruning keeps the active version plus the most recent others up to the limit.
local aged=$test_directory/aged
local name
for name in v1 v2 v3 v4; do
  make_version $aged $name $name
  command touch -- $aged/versions/$name
done
command sh $activate $aged v4
command sh $prune $aged 2

[[ -d $aged/versions/v4 ]] || fail 'pruning removed the active version'
[[ -d $aged/versions/v3 ]] || fail 'pruning removed the rollback target'
[[ ! -d $aged/versions/v2 && ! -d $aged/versions/v1 ]] ||
  fail 'pruning kept more versions than requested'

# Rolling back to an older version must protect it from the next prune.
command sh $activate $aged v3
make_version $aged v5 v5
command sh $prune $aged 2
[[ -d $aged/versions/v3 ]] || fail 'pruning removed the active version after rollback'
[[ -d $aged/versions/v5 ]] || fail 'pruning removed the newest version'

# Abandoned staging directories are never rollback targets.
local staged=$test_directory/staged
make_version $staged one alpha
command sh $activate $staged one
mkdir -p -- $staged/versions/.staging.abandoned
command sh $prune $staged 2
[[ -d $staged/versions/one ]] || fail 'pruning removed the only version'

(( failures == 0 ))
