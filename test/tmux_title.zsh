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

# Branch display: read from HEAD (worktrees use a .git file), no git process.
command mkdir -p -- $tmpdir/bin $HOME/repo/.git $HOME/repo/sub $HOME/linked $HOME/gitdirs/linked || exit 1
print -r -- "#!/bin/sh
: >'$tmpdir/git-ran'" >$tmpdir/bin/git
command chmod 755 -- $tmpdir/bin/git || exit 1
path=($tmpdir/bin $path)
print -r -- 'ref: refs/heads/main' >$HOME/repo/.git/HEAD
print -r -- "gitdir: $HOME/gitdirs/linked" >$HOME/linked/.git
print -r -- 0123456789abcdef0123456789abcdef01234567 >$HOME/gitdirs/linked/HEAD
zstyle :z4m:tmux-title git-branch yes
zstyle :z4m:tmux-title max-length 40
{
  -z4m-init-tmux-title || fail 'init failed'
  preexec_functions=() precmd_functions=() chpwd_functions=()
} >/dev/null

cd -q -- $HOME/repo/sub || exit 1
capture_title -z4m-tmux-title-precmd
assert_eq 'branch from HEAD' repo:main "$REPLY"
print -r -- 'ref: refs/heads/topic' >$HOME/repo/.git/HEAD
capture_title -z4m-tmux-title-precmd
assert_eq 'checkout shows up on the next prompt' repo:topic "$REPLY"

# The dirty flag comes from p10k's gitstatus result for the same repository.
typeset -g VCS_STATUS_RESULT=ok-async VCS_STATUS_WORKDIR=$HOME/repo
typeset -gi VCS_STATUS_NUM_STAGED=0 VCS_STATUS_NUM_UNSTAGED=1 VCS_STATUS_NUM_UNTRACKED=0
capture_title -z4m-tmux-title-precmd
assert_eq 'dirty flag from gitstatus' 'repo:topic*' "$REPLY"
VCS_STATUS_WORKDIR=$HOME/elsewhere
capture_title -z4m-tmux-title-precmd
assert_eq 'gitstatus result of another repository' repo:topic "$REPLY"

cd -q -- $HOME/linked || exit 1
capture_title -z4m-tmux-title-precmd
assert_eq 'detached HEAD of a linked worktree' linked:01234567 "$REPLY"
[[ ! -e $tmpdir/git-ran ]] || fail 'prompt hooks ran git'

(( ! failures ))
