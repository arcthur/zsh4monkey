#!/usr/bin/env zsh

emulate -L zsh -o no_aliases

cd -- "${0:A:h:h}" || exit 1
fpath=("$PWD/fn" $fpath)
autoload -Uz -- -z4m-init-tmux-title

typeset -gi failures=0

fail() {
  print -ru2 -- "$1"
  (( ++failures ))
}

assert_eq() {
  local label=$1 expected=$2 actual=$3
  [[ $actual == $expected ]] || fail "$label: expected ${(q+)expected}, got ${(q+)actual}"
}

tmpdir=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-tmux-title.XXXXXXXXXX") || exit 1
tmpdir=${tmpdir:A}
trap 'command rm -rf -- "$tmpdir"' EXIT

# Hooks run after the init function has returned, as they do in a real shell.
export LC_ALL=en_US.UTF-8
TMUX=/tmp/tmux-test,1,0
zstyle :z4m:tmux-title max-length 10
HOME=$tmpdir/home
command mkdir -p -- $HOME/plain || exit 1
cd -q -- $HOME/plain || exit 1
# Scripts run preexec hooks too; this test calls each hook explicitly.
{
  -z4m-init-tmux-title || fail 'init failed'
  preexec_functions=() precmd_functions=() chpwd_functions=()
} >/dev/null

# Usage: capture_title <hook> [args]; sets REPLY to the window name the hook
# emitted. Hooks run from widgets write to the tty fd, as stdout is redirected.
exec {_z4m_tty_fd}>>$tmpdir/tty || exit 1
capture_title() {
  : >|$tmpdir/tty
  "$@" >/dev/null
  local out=$(<$tmpdir/tty)
  if [[ $out != $'\ek'*$'\e\\' ]]; then
    fail "$1: not a window name sequence: ${(q+)out}"
    REPLY=
    return
  fi
  REPLY=${${out#$'\ek'}%$'\e\\'}
}

# Directory names and command words are untrusted text.
capture_title -z4m-tmux-title-preexec $'evil\e\\\e]2;pwned\a arg'
[[ $REPLY != *[[:cntrl:]]* ]] || fail "command word leaks control characters: ${(q+)REPLY}"
assert_eq 'command word is rendered visibly' 'evil^[\^[…' "$REPLY"

command mkdir -p -- $HOME/$'x\e\\y' || exit 1
cd -q -- $HOME/$'x\e\\y' || exit 1
capture_title -z4m-tmux-title-chpwd
assert_eq 'directory name is rendered visibly' 'x^[\y' "$REPLY"

# max-length is read when the hooks run, long after initialization.
capture_title -z4m-tmux-title-preexec abcdefghij
assert_eq 'name within max-length' abcdefghij "$REPLY"
capture_title -z4m-tmux-title-preexec abcdefghijk
assert_eq 'name over max-length' 'abcdefghi…' "$REPLY"

# A cd inside a command substitution must not leak the sequence into its output.
chpwd_functions=(-z4m-tmux-title-chpwd)
local captured=$(cd -- $HOME/plain && print -r -- captured)
chpwd_functions=()
assert_eq 'command substitution output' captured "$captured"

(( ! failures ))
