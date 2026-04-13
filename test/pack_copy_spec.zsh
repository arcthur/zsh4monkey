#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

setopt local_options

cd -- "${0:A:h:h}" || exit 1
fpath=("$PWD/fn" $fpath)
autoload -Uz -- -z4m-pack-parse-copy-spec

typeset -gi failures=0

assert_eq() {
  local expected=$1 actual=$2 label=$3
  if [[ $expected != $actual ]]; then
    print -ru2 -- "$label: expected [$expected], got [$actual]"
    ((failures++))
  fi
}

assert_ok() {
  local label=$1
  shift
  if ! "$@"; then
    print -ru2 -- "expected success: $label"
    ((failures++))
  fi
}

assert_fail() {
  local label=$1
  shift
  if "$@"; then
    print -ru2 -- "expected failure: $label"
    ((failures++))
  fi
}

tmpdir=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-pack-copy-spec.XXXXXXXXXX") || exit 1
trap 'rm -rf -- "$tmpdir"' EXIT

HOME=$tmpdir/home
TEST_ZDOTDIR=$tmpdir/zdotdir
mkdir -p -- "$HOME/.config/nvim" "$HOME/env-files" "$TEST_ZDOTDIR" "$tmpdir/outside" || exit 1
touch -- \
  "$HOME/.config/nvim/init.lua" \
  "$HOME/env-files/a" \
  "$HOME/env-files/b" \
  "$TEST_ZDOTDIR/custom.zsh" \
  "$tmpdir/outside/other" || exit 1

typeset -a local_paths root_kinds rel_paths exclude_specs

assert_ok 'plain home-relative source' -z4m-pack-parse-copy-spec '~/.config/nvim/init.lua' "$TEST_ZDOTDIR" local_paths root_kinds rel_paths exclude_specs
assert_eq "$HOME/.config/nvim/init.lua" "$local_paths[1]" 'plain local path'
assert_eq 'HOME' "$root_kinds[1]" 'plain root kind'
assert_eq '.config/nvim/init.lua' "$rel_paths[1]" 'plain rel path'
assert_eq '' "$exclude_specs[1]" 'plain exclude spec'

assert_ok 'plain zdotdir source' -z4m-pack-parse-copy-spec '$ZDOTDIR/custom.zsh' "$TEST_ZDOTDIR" local_paths root_kinds rel_paths exclude_specs
assert_eq "$TEST_ZDOTDIR/custom.zsh" "$local_paths[1]" 'zdotdir local path'
assert_eq 'ZDOTDIR' "$root_kinds[1]" 'zdotdir root kind'
assert_eq 'custom.zsh' "$rel_paths[1]" 'zdotdir rel path'

assert_ok 'dest override keeps source root by default' -z4m-pack-parse-copy-spec '--dest my-conf/init.lua ~/.config/nvim/init.lua' "$TEST_ZDOTDIR" local_paths root_kinds rel_paths exclude_specs
assert_eq 'HOME' "$root_kinds[1]" 'dest default root kind'
assert_eq 'my-conf/init.lua' "$rel_paths[1]" 'dest default rel path'

assert_ok 'dest override can target zdotdir explicitly' -z4m-pack-parse-copy-spec '--dest $ZDOTDIR/my-conf/custom.zsh ~/.config/nvim/init.lua' "$TEST_ZDOTDIR" local_paths root_kinds rel_paths exclude_specs
assert_eq 'ZDOTDIR' "$root_kinds[1]" 'dest explicit root kind'
assert_eq 'my-conf/custom.zsh' "$rel_paths[1]" 'dest explicit rel path'

assert_ok 'glob expansion' -z4m-pack-parse-copy-spec '--glob env-files/*' "$TEST_ZDOTDIR" local_paths root_kinds rel_paths exclude_specs
assert_eq 2 "${#local_paths}" 'glob local count'
assert_eq 'HOME' "$root_kinds[1]" 'glob first root kind'
assert_eq 'env-files/a' "$rel_paths[1]" 'glob first rel path'
assert_eq 'HOME' "$root_kinds[2]" 'glob second root kind'
assert_eq 'env-files/b' "$rel_paths[2]" 'glob second rel path'

assert_ok 'exclude patterns are captured' -z4m-pack-parse-copy-spec "--exclude '*.tmp' --exclude '.git' ~/.config/nvim" "$TEST_ZDOTDIR" local_paths root_kinds rel_paths exclude_specs
assert_eq "$HOME/.config/nvim" "$local_paths[1]" 'exclude local path'
assert_eq 'HOME' "$root_kinds[1]" 'exclude root kind'
assert_eq '.config/nvim' "$rel_paths[1]" 'exclude rel path'
assert_eq $'*.tmp\n.git' "$exclude_specs[1]" 'exclude spec payload'

assert_fail 'dest with multi-match glob' -z4m-pack-parse-copy-spec '--dest target --glob env-files/*' "$TEST_ZDOTDIR" local_paths root_kinds rel_paths exclude_specs
assert_fail 'absolute destination is rejected' -z4m-pack-parse-copy-spec '--dest /tmp/elsewhere ~/.config/nvim/init.lua' "$TEST_ZDOTDIR" local_paths root_kinds rel_paths exclude_specs
assert_fail 'source outside allowed roots is rejected' -z4m-pack-parse-copy-spec "$tmpdir/outside/other" "$TEST_ZDOTDIR" local_paths root_kinds rel_paths exclude_specs
assert_fail 'relative source with parent segment' -z4m-pack-parse-copy-spec '../outside' "$TEST_ZDOTDIR" local_paths root_kinds rel_paths exclude_specs
assert_fail 'dest with parent segment' -z4m-pack-parse-copy-spec '--dest ../target ~/.config/nvim/init.lua' "$TEST_ZDOTDIR" local_paths root_kinds rel_paths exclude_specs

if (( failures )); then
  exit 1
fi
