#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail

setopt local_options

cd -- "${0:A:h:h}" || exit 1
fpath=("$PWD/fn" $fpath)
autoload -Uz -- -z4m-comp-words -z4m-fzf-keys -z4m-fzf-key-decode

typeset -gi failures=0

fail() {
  print -ru2 -- "$1"
  ((failures++))
}

assert_eq() {
  local label=$1 expected=$2 actual=$3
  [[ $actual == $expected ]] || fail "$label: expected ${(q+)expected}, got ${(q+)actual}"
}

tmpdir=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-comp-words.XXXXXXXXXX") || exit 1
trap 'command rm -rf -- "$tmpdir"' EXIT

# Terminal and fzf stubs: fzf records its input and picks two records.
TERM=xterm-256color LINES=40 COLUMNS=80 TMPPREFIX=$tmpdir/zsh Z4M=/z4m
WIDGET=z4m-fzf-complete
typeset -gi _z4m_can_save_restore_screen=0
exec {_z4m_tty_fd}>/dev/null
-z4m-set-list-colors() { return 1 }
-z4m-get-cursor-pos() { cursor_y=1 cursor_x=1 }
-z4m-cursor-show() {}
-z4m-cursor-hide() {}
-z4m-fzf() {
  print -rl -- "$@" > $tmpdir/fzf.args
  local line
  local -a lines=()
  while IFS= read -r line; do
    lines+=("$line")
  done
  print -rl -- "${(@q+)lines}" > $tmpdir/fzf.in
  print
  for line in "${lines[@]}"; do
    [[ ${line#*$'\0'} == ('a b'|tab) ]] && print -r -- "$line"
  done
}

run() {
  _z4m_words=(foo 'a b' foo $'tab\tx')
  _z4m_descrs=('foo -- desc' 'a b' 'foo -- desc' tab)
  _z4m_curcontext=:complete:foo: _z4m_word_prefix= _z4m_reply=()
  -z4m-comp-words >/dev/null
}

# Another local user can pre-create the old predictable candidate path as a
# symlink; completion must never write through it.
print -r -- victim > $tmpdir/victim
command ln -s -- $tmpdir/victim ${TMPPREFIX}-z4m-words-$$

local sort record
local -a records reply
for sort in no yes; do
  zstyle ':completion:*' sort $sort
  run
  assert_eq "sort=$sort: selection maps back to word indices" '0 2 4' "$_z4m_reply"

  records=("${(@Q)${(f)"$(<$tmpdir/fzf.in)"}}")
  assert_eq "sort=$sort: duplicate words collapse" 3 $#records
  for record in "${records[@]}"; do
    -z4m-fzf-key-decode "${record%%$'\0'*}" ||
      fail "sort=$sort: record key must decode: ${(q+)record}"
  done
done

local -a args=("${(@f)$(<$tmpdir/fzf.args)}")
local preview='--preview=zsh /z4m/zsh4monkey/fn/z4m-preview-key :complete:foo: {1}'
assert_eq 'preview decodes the record key' "$preview" "${(@M)args:#--preview=*}"
local -a leaked=($tmpdir/zsh*(N^@))
assert_eq 'no candidate file is written' 0 $#leaked
assert_eq 'symlinked candidate path is not followed' victim "$(<$tmpdir/victim)"

if (( failures )); then
  exit 1
fi
