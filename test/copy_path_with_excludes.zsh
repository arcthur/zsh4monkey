#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

setopt local_options

cd -- "${0:A:h:h}" || exit 1
fpath=("$PWD/fn" $fpath)
autoload -Uz -- -z4m-copy-path-with-excludes

typeset -gi failures=0

assert_exists() {
  local target=$1 label=$2
  if [[ ! -e $target ]]; then
    print -ru2 -- "$label: missing [$target]"
    ((failures++))
  fi
}

assert_missing() {
  local target=$1 label=$2
  if [[ -e $target ]]; then
    print -ru2 -- "$label: unexpected path [$target]"
    ((failures++))
  fi
}

tmpdir=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-copy-excludes.XXXXXXXXXX") || exit 1
trap 'rm -rf -- "$tmpdir"' EXIT

src=$tmpdir/src
dst=$tmpdir/dst
mkdir -p -- "$src/node_modules/pkg" "$src/.git" "$src/.config" "$src/src" || exit 1
print -r -- link-target >"$src/keep.txt" || exit 1
touch -- \
  "$src/.config/init.lua" \
  "$src/skip.tmp" \
  "$src/.git/config" \
  "$src/node_modules/pkg/index.js" \
  "$src/src/keep.js" \
  "$src/src/skip.log" || exit 1
command ln -s -- keep.txt "$src/link" || exit 1

if ! -z4m-copy-path-with-excludes "$src" "$dst" preserve $'*.tmp\n.git\nnode_modules\nsrc/*.log'; then
  print -ru2 -- 'copy helper failed'
  exit 1
fi

assert_exists "$dst/keep.txt" 'keep top-level file'
assert_exists "$dst/.config/init.lua" 'keep hidden directory entry'
assert_exists "$dst/src/keep.js" 'keep nested file'
assert_missing "$dst/skip.tmp" 'exclude basename pattern'
assert_missing "$dst/.git" 'exclude dotdir basename pattern'
assert_missing "$dst/node_modules" 'exclude directory basename pattern'
assert_missing "$dst/src/skip.log" 'exclude relative path pattern'
if [[ ! -L $dst/link ]]; then
  print -ru2 -- 'preserve mode did not retain a symbolic link'
  ((failures++))
fi

follow_dst=$tmpdir/follow-dst
if ! -z4m-copy-path-with-excludes "$src" "$follow_dst" follow $'*.tmp\n.git\nnode_modules\nsrc/*.log'; then
  print -ru2 -- 'copy helper follow mode failed'
  exit 1
fi
assert_exists "$follow_dst/link" 'materialized symbolic-link target'
if [[ -L $follow_dst/link || $(<$follow_dst/link) != link-target ]]; then
  print -ru2 -- 'follow mode did not materialize a symbolic-link target'
  ((failures++))
fi

if (( failures )); then
  exit 1
fi
