#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail

setopt local_options

cd -- "${0:A:h:h}" || exit 1
fpath=("$PWD/fn" $fpath)
zmodload -F zsh/files b:zf_mkdir b:zf_mv b:zf_rm || exit 1
autoload -Uz -- -z4m-complete-carapace

typeset -gi failures=0

fail() {
  print -ru2 -- "$1"
  ((failures++))
}

assert_eq() {
  local label=$1 expected=$2 actual=$3
  [[ $actual == $expected ]] || fail "$label: expected ${(q+)expected}, got ${(q+)actual}"
}

tmpdir=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-carapace.XXXXXXXXXX") || exit 1
trap 'command rm -rf -- "$tmpdir"' EXIT

# A fake carapace that prints a script in carapace's generated format.
mkdir -p -- $tmpdir/bin $tmpdir/cache || exit 1
print -r -- '#!/bin/sh
cat <<END
#compdef $1
function _$1_completion {
  completion_calls+=(\$words[1])
}
compquote '"''"' 2>/dev/null && _$1_completion
compdef _$1_completion $1
END' > $tmpdir/bin/carapace
print -r -- '#!/bin/sh' > $tmpdir/bin/foo
chmod +x -- $tmpdir/bin/carapace $tmpdir/bin/foo
path=($tmpdir/bin $path)

typeset -gA _comps=() _z4m_carapace_prev_comps=()
typeset -ga _z4m_carapace_supported_commands=(foo) _z4m_carapace_exclude=()
typeset -g _z4m_carapace_bin=$tmpdir/bin/carapace _z4m_carapace_cache=$tmpdir/cache
typeset -ga completion_calls=() default_calls=()

compdef() { _comps[$2]=$1 }
_default() { default_calls+=(1) }
-z4m-compile() {}
# Inside a completion widget the compquote builtin succeeds.
compquote() { return 0 }
stub_compquote=$functions[compquote]

words=(foo '')
-z4m-complete-carapace
assert_eq 'first Tab runs carapace exactly once' 1 $#completion_calls
assert_eq 'first Tab does not fall back' 0 $#default_calls
assert_eq 'carapace stays registered' _foo_completion "${_comps[foo]-}"
assert_eq 'compquote is restored' "$stub_compquote" "${functions[compquote]-}"

$_comps[foo]
assert_eq 'later Tabs keep using carapace' 2 $#completion_calls
assert_eq 'later Tabs do not fall back' 0 $#default_calls

if (( failures )); then
  exit 1
fi
