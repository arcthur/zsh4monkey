#!/usr/bin/env zsh
#
# Contract for the `ranked` autosuggestion strategy: which signal wins over
# which, and what the preexec/precmd hooks record.

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

cd -- "${0:A:h:h}" || exit 1

typeset -gi failures=0

assert_eq() {
  local expected=$1 actual=$2 label=$3
  if [[ $expected != $actual ]]; then
    print -ru2 -- "$label: expected [$expected], got [$actual]"
    (( ++failures ))
  fi
}

# Core init resolves the vendored plugin through $Z4M/zsh4monkey.
tmpdir=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-ranked.XXXXXXXXXX") || exit 1
trap 'rm -rf -- "$tmpdir"' EXIT
command ln -s -- "$PWD" "$tmpdir/zsh4monkey" || exit 1
Z4M=$tmpdir

source fn/-z4m-autosuggest-core || exit 1
-z4m-autosuggest-core-init || { print -ru2 -- 'autosuggest init failed'; exit 1 }
assert_eq 'ranked history' "${_z4m_autosuggest_state[configured_strategy]}" 'default strategy'
assert_eq 500 "${_z4m_autosuggest_state[configured_rank_window]}" 'default rank window'
assert_eq 1 $(( ${preexec_functions[(Ie)-z4m-autosuggest-rank-preexec]} > 0 )) 'preexec hook registered'
assert_eq 1 $(( ${precmd_functions[(Ie)-z4m-autosuggest-rank-precmd]} > 0 )) 'precmd hook registered'

# Usage: with_history <oldest> ... <newest>
# The final `print -s` becomes the line being edited, which history iteration
# skips, so a placeholder follows the real entries.
with_history() {
  fc -P 2>/dev/null
  fc -p /dev/null 1000 1000
  local cmd
  for cmd in "$@" placeholder; do
    print -s -- "$cmd"
  done
  _z4m_rank_status=()
  _z4m_rank_dirs=()
  unset _z4m_rank_last_cmd _z4m_rank_snapshot_key
}

# Usage: ranked <buffer>; sets REPLY to the suggestion.
ranked() {
  local suggestion=
  _zsh_autosuggest_strategy_ranked "$1"
  REPLY=$suggestion
}

with_history 'git commit -m a' 'git checkout b'
ranked 'git c'
assert_eq 'git checkout b' "$REPLY" 'recency breaks a frequency tie'

# A long single command must not win on its length.
with_history 'git checkout b' 'git checkout b' 'git commit -m a-much-longer-message-than-the-other-one'
ranked 'git c'
assert_eq 'git checkout b' "$REPLY" 'frequency is counted, not the command length'

with_history 'git checkout b' 'git checkout b' 'git checkout b' 'git commit -m a'
ranked 'git c'
assert_eq 'git checkout b' "$REPLY" 'frequency beats a single newer match'

with_history 'git add .' 'git commit -m a' 'git status' 'git checkout b'
ranked 'git c'
assert_eq 'git checkout b' "$REPLY" 'without a previous command'
_z4m_rank_last_cmd='git add .'
ranked 'git c'
assert_eq 'git commit -m a' "$REPLY" 'command that followed the previous command'

with_history 'git commit -m a' 'git checkout b'
_z4m_rank_status+=('git checkout b' 1)
ranked 'git c'
assert_eq 'git commit -m a' "$REPLY" 'failed command is demoted'
_z4m_rank_status+=('git checkout b' 130)
ranked 'git c'
assert_eq 'git checkout b' "$REPLY" 'interrupted command is not a failure'

with_history 'git commit -m a' 'git checkout b'
_z4m_rank_dirs+=("$PWD"$'\x1f''git commit -m a' 1)
ranked 'git c'
assert_eq 'git commit -m a' "$REPLY" 'command run in this directory'

with_history 'ls -la' 'ls'
ranked 'ls'
assert_eq 'ls -la' "$REPLY" 'exact buffer match is skipped'

with_history 'echo [abc]' 'echo x'
ranked 'echo [a'
assert_eq 'echo [abc]' "$REPLY" 'glob characters in the buffer are literal'

with_history 'make build' 'make test' 'make lint'
_z4m_autosuggest_state[configured_rank_window]=2
ranked 'make b'
assert_eq '' "$REPLY" 'match outside the window'
_z4m_autosuggest_state[configured_rank_window]=500

# The hooks record status and directory of what actually ran. Init registered
# them, and zsh runs hook arrays in scripts too, so detach them before calling
# them by hand.
preexec_functions=(${preexec_functions:#-z4m-autosuggest-rank-preexec})
precmd_functions=(${precmd_functions:#-z4m-autosuggest-rank-precmd})
with_history
-z4m-autosuggest-rank-preexec 'make test'
false
-z4m-autosuggest-rank-precmd
assert_eq 1 "${_z4m_rank_status[make test]}" 'precmd records exit status'
assert_eq 'make test' "${_z4m_rank_last_cmd-}" 'precmd records previous command'
assert_eq 1 "${_z4m_rank_dirs[$PWD$'\x1f'make test]-}" 'precmd records directory'
true
-z4m-autosuggest-rank-precmd
assert_eq 1 "${_z4m_rank_status[make test]}" 'precmd without preexec records nothing'

zstyle ':z4m:autosuggestions' rank-window 99999
-z4m-autosuggest-core-read-config 2>/dev/null
assert_eq 500 "${_z4m_autosuggest_state[configured_rank_window]}" 'out-of-range rank window'
zstyle -d ':z4m:autosuggestions' rank-window
-z4m-autosuggest-core-init 2>/dev/null
assert_eq 1 ${#${(M)precmd_functions:#-z4m-autosuggest-rank-precmd}} 'precmd hook registered once on re-init'
zstyle ':z4m:autosuggestions' strategy 'history'
-z4m-autosuggest-core-init 2>/dev/null
assert_eq 0 ${#${(M)precmd_functions:#-z4m-autosuggest-rank-precmd}} 'precmd hook removed without ranked'

(( failures == 0 )) || exit 1
print -r -- 'autosuggest_ranked: ok'
