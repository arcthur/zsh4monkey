#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

setopt local_options

cd -- "${0:A:h:h}" || exit 1
fpath=("$PWD/fn" $fpath)
zmodload -F zsh/stat b:zstat || exit 1
autoload -Uz -- -z4m-fzf-keys -z4m-fzf-key-decode -z4m-present-files -z4m-find

typeset -gi failures=0

fail() {
  print -ru2 -- "$1"
  ((failures++))
}

assert_eq() {
  local label=$1 expected=$2 actual=$3
  [[ $actual == $expected ]] || fail "$label: expected ${(q+)expected}, got ${(q+)actual}"
}

tmpdir=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-fzf-find.XXXXXXXXXX") || exit 1
trap 'command rm -rf -- "$tmpdir"' EXIT

# A base64 stub that records every call, so the tests can prove that printable
# values never fork.
mkdir -p -- "$tmpdir/bin" || exit 1
real_base64=${commands[base64]}
print -r -- "#!/bin/sh
echo call >> '$tmpdir/base64.calls'
exec '$real_base64' \"\$@\"" > "$tmpdir/bin/base64"
chmod +x -- "$tmpdir/bin/base64"
path=("$tmpdir/bin" $path)

base64_calls() {
  local -a calls=()
  [[ -f $tmpdir/base64.calls ]] && calls=(${(f)"$(<$tmpdir/base64.calls)"})
  print -r -- $#calls
}

# --- Keys ---------------------------------------------------------------------

-z4m-fzf-keys 'a' 'a b' 'dir/sub/file.txt' 'x*'
assert_eq 'printable value is stored verbatim' 'ra b' "$reply[2]"
assert_eq 'printable values do not fork' 0 "$(base64_calls)"

local -a values=('a' 'a b' 'dir/sub/file.txt' '日本 語' 'x*' $'tab\tx' $'esc\e[31m' 'trail ' ' lead' $'a\xffb')
-z4m-fzf-keys "${values[@]}"
local -a keys=("${reply[@]}")
assert_eq 'one key per value' $#values $#keys

local -i i
for (( i = 1; i <= $#values; ++i )); do
  [[ $keys[i] != *[[:cntrl:]]* && $keys[i] == [[:graph:]]([[:print:]]#[[:graph:]]|) ]] ||
    fail "key is not single-line printable: ${(q+)keys[i]}"
  reply=()
  -z4m-fzf-key-decode "$keys[i]" || { fail "decode failed: ${(q+)values[i]}"; continue }
  assert_eq "roundtrip ${(q+)values[i]}" "$values[i]" "$reply[1]"
done
[[ $keys[6] == b* && $keys[7] == b* && $keys[8] == b* ]] || fail 'unsafe values must be base64-encoded'

-z4m-fzf-key-decode '' && fail 'empty key must be rejected'
-z4m-fzf-key-decode 'xfoo' && fail 'unknown key prefix must be rejected'
-z4m-fzf-key-decode 'b!!!' && fail 'malformed base64 key must be rejected'

# --- Presentation -------------------------------------------------------------

mkdir -p -- "$tmpdir/pf/dir" || exit 1
: > "$tmpdir/pf/exe" && chmod +x -- "$tmpdir/pf/exe"
: > "$tmpdir/pf/plain"

present() {
  ( cd -- "$tmpdir/pf" && print -rl -- dir exe plain | -z4m-present-files "$@" )
}

: > "$tmpdir/base64.calls"
local -a lines=("${(@f)$(present 0 1 0 1)}")
assert_eq 'present-files emits one record per path' 3 $#lines
assert_eq 'type suffix stays out of the key' $'rdir\0dir/' "$lines[1]"
assert_eq 'executable suffix stays out of the key' $'rexe\0exe*' "$lines[2]"
lines=("${(@f)$(present 0 0 0 1)}")
assert_eq 'plain listing' $'rplain\0plain' "$lines[3]"
assert_eq 'presentation does not fork per entry' 0 "$(base64_calls)"

# --- Traversal ----------------------------------------------------------------

tree=$tmpdir/tree
mkdir -p -- $tree/proj/src/deep/deeper $tree/proj/node_modules/pkg $tree/proj/.hidden/inner \
  $tree/proj/build/out $tree/other/sub || exit 1
: > $tree/proj/src/main.c
: > $tree/proj/src/deep/deeper/leaf.c
: > $tree/proj/node_modules/pkg/index.js
: > $tree/proj/build/out/artifact
: > $tree/other/sub/file
mkdir -p -- $tree/pats/a/b $tree/pats/dir.pdf || exit 1
: > $tree/pats/doc.PDF
: > $tree/pats/a/b/notes.pdf
: > $tree/pats/x.c
: > $tree/pats/y.h
: > $tree/pats/m.md

list() {
  local only_dirs=$1 dot_glob=${2:-0}
  ( cd -- $tree && WIDGET=z4m-fzf-complete -z4m-find $dot_glob $only_dirs proj other | command sort )
}

check_common() {
  local backend=$1
  local -a out=("${(@f)$(list 0)}")
  (( ${out[(I)proj/src/main.c]} )) || fail "$backend: missing proj/src/main.c"
  (( ${out[(I)other/sub/file]} )) || fail "$backend: missing other/sub/file"
  (( ${out[(I)proj/src/deep/deeper/leaf.c]} )) || fail "$backend: missing depth-5 path"
  (( ${out[(I)proj]} || ${out[(I)other]} )) && fail "$backend: listed directories must not be printed"
  [[ -n ${(M)out:#(./*|*/)} ]] && fail "$backend: output must be relative without ./ or trailing /"
  [[ -n ${(M)out:#*node_modules*} ]] && fail "$backend: node_modules must be pruned"
  [[ -n ${(M)out:#*.hidden*} ]] && fail "$backend: hidden entries need dot_glob"

  out=("${(@f)$(list 0 1)}")
  (( ${out[(I)proj/.hidden/inner]} )) || fail "$backend: dot_glob must include hidden entries"

  out=("${(@f)$(list 1)}")
  [[ -n ${(M)out:#*.c} ]] && fail "$backend: only_dirs must exclude files"
  (( ${out[(I)proj/src/deep]} )) || fail "$backend: only_dirs must include directories"

  zstyle ':z4m:fzf-complete' max-depth 3
  out=("${(@f)$(list 0)}")
  (( ${out[(I)proj/src/deep]} )) || fail "$backend: max-depth 3 must include depth-3 paths"
  [[ -n ${(M)out:#proj/src/deep/*} ]] && fail "$backend: max-depth 3 must stop at depth 3"
  zstyle -d ':z4m:fzf-complete' max-depth

  out=("${(@f)$(cd -- $tree/proj && WIDGET=z4m-fzf-complete -z4m-find 0 0 node_modules src)}")
  [[ -n ${(M)out:#node_modules/*} ]] && fail "$backend: excluded names must not be descended as roots"
  (( ${out[(I)src/main.c]} )) || fail "$backend: other roots must still be descended"

  zstyle ':z4m:fzf-complete' find-exclude src
  out=("${(@f)$(list 0)}")
  [[ -n ${(M)out:#proj/src*} ]] && fail "$backend: find-exclude must replace the default list"
  (( ${out[(I)proj/node_modules/pkg]} )) || fail "$backend: find-exclude overrides defaults"
  zstyle -d ':z4m:fzf-complete' find-exclude

  # -g values as completion functions pass them to _path_files.
  assert_eq "$backend: glob flag and qualifier" 'pats/a/b/notes.pdf pats/doc.PDF' \
    "$(list_pats '*.(#i)pdf(-.)')"
  assert_eq "$backend: (#q) qualifier" 'pats/a/b/notes.pdf pats/doc.PDF' \
    "$(list_pats '*.(#i)pdf(#q-.)')"
  assert_eq "$backend: every -g value" 'pats/x.c pats/y.h' "$(list_pats '*.c' '*.h')"
  assert_eq "$backend: blank-separated patterns" 'pats/m.md pats/x.c' "$(list_pats ' *.c  *.md ')"
  assert_eq "$backend: _files brace list" 'pats/x.c pats/y.h' "$(list_pats '{*.c,*.h}(#q-.)')"
  assert_eq "$backend: alternation is not a qualifier" 'pats/m.md pats/x.c' "$(list_pats '*.(c|md)')"
  assert_eq "$backend: unqualified pattern keeps directories" 'pats/a/b/notes.pdf pats/dir.pdf' \
    "$(list_pats '*.pdf')"
}

list_pats() {
  local -a _z4m_find_pats=("$@")
  print -r -- ${(o)${(f)"$(cd -- $tree && WIDGET=z4m-fzf-complete -z4m-find 0 0 pats)"}}
}

# Shallow-first order: fd lists two levels, then the rest.
if (( $+commands[fd] || $+commands[fdfind] )); then
  check_common fd
  command git -C $tree/proj init -q 2>/dev/null && print -r -- build > $tree/proj/.gitignore
  local -a ordered=("${(@f)$(cd -- $tree && WIDGET=z4m-fzf-complete -z4m-find 0 0 proj other)}")
  [[ -n ${(M)ordered:#proj/build*} ]] && fail 'fd: .gitignore must be honored'
  # root/a/b is two levels below a root; deeper paths come in a second walk.
  local -i deep=0
  local p
  for p in $ordered; do
    if (( ${#${(s:/:)p}} > 3 )); then
      deep=1
    elif (( deep )); then
      fail "fd: shallow path $p listed after a deeper one"
      break
    fi
  done
  command rm -rf -- $tree/proj/.git $tree/proj/.gitignore
fi

# find fallback: hide fd and bfs.
mkdir -p -- "$tmpdir/fallback" || exit 1
local tool
for tool in find sed sort base64 mktemp tr rm; do
  [[ -n ${commands[$tool]} ]] && ln -s -- "${commands[$tool]}" "$tmpdir/fallback/$tool"
done
(
  path=("$tmpdir/fallback")
  hash -r
  check_common find
  (( failures )) && exit 1
  exit 0
) || ((failures++))

# ~/Library is skipped as a root on macOS unless dot_glob is set.
mkdir -p -- $tmpdir/home/Library/Caches $tmpdir/home/Code/app || exit 1
(
  HOME=$tmpdir/home OSTYPE=darwin24.0
  cd -- $HOME
  local -a out=("${(@f)$(-z4m-find 0 1 Library Code)}")
  [[ -n ${(M)out:#Library/*} ]] && fail 'Library must be skipped in $HOME on macOS'
  (( ${out[(I)Code/app]} )) || fail 'other roots must still be listed'
  out=("${(@f)$(-z4m-find 1 1 Library Code)}")
  (( ${out[(I)Library/Caches]} )) || fail 'dot_glob must include Library'
  (( failures )) && exit 1
  exit 0
) || ((failures++))

if (( failures )); then
  exit 1
fi
