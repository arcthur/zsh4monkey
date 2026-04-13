#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail

setopt local_options

cd -- "${0:A:h:h}" || exit 1
fpath=("$PWD/fn" $fpath)
autoload -Uz -- -z4m-expand-user-path

typeset -gi failures=0

assert_expand() {
  local label=$1 spec=$2 expected=$3
  if ! -z4m-expand-user-path "$spec" "$TEST_ZDOTDIR"; then
    print -ru2 -- "expected success: $label"
    ((failures++))
    return
  fi
  if [[ $REPLY != $expected ]]; then
    print -ru2 -- "$label: expected [$expected], got [$REPLY]"
    ((failures++))
  fi
}

assert_fail() {
  local label=$1 spec=$2
  if -z4m-expand-user-path "$spec" "$TEST_ZDOTDIR"; then
    print -ru2 -- "expected failure: $label"
    ((failures++))
  fi
}

tmpdir=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-expand-user-path.XXXXXXXXXX") || exit 1
trap 'rm -rf -- "$tmpdir"' EXIT

HOME=$tmpdir/home
TEST_ZDOTDIR=$tmpdir/zdotdir
mkdir -p -- "$HOME/.config" "$TEST_ZDOTDIR" || exit 1

assert_expand 'tilde path' '~/.config' "$HOME/.config"
assert_expand 'home var path' '$HOME/.config' "$HOME/.config"
assert_expand 'zdotdir var path' '$ZDOTDIR/custom.zsh' "$TEST_ZDOTDIR/custom.zsh"
assert_expand 'absolute path' '/tmp/example' '/tmp/example'
assert_expand 'plain relative path' '.config' "$HOME/.config"
assert_fail 'empty path' ''
assert_fail 'parent segment path' '../outside'
assert_fail 'home parent segment path' '$HOME/../outside'
assert_fail 'dot segment path' 'config/./file'

if (( failures )); then
  exit 1
fi
