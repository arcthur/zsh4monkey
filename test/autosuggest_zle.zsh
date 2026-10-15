#!/usr/bin/env zsh
#
# Drives the autosuggestion AI lane through a real ZLE session (zpty) with a
# stub provider, so fd-handler behavior is checked against the live edit line.

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

zmodload zsh/zpty zsh/zselect zsh/datetime || exit 1
[[ -n ${commands[jq]-} ]] || { print -ru2 -- 'skip: jq not installed'; exit 0; }

local repository=${0:A:h:h}
local sandbox
sandbox=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-autosuggest-zle.XXXXXXXXXX") || exit 1
sandbox=${sandbox:A}
trap 'zpty -d t 2>/dev/null; if [[ -n ${Z4M_TEST_KEEP-} ]]; then print -ru2 -- "sandbox: $sandbox"; ls $sandbox $sandbox/fake >&2; else command rm -rf -- "$sandbox"; fi' EXIT

mkdir -p -- $sandbox/{home,bin,z4m,fake} || exit 1
ln -s -- $repository $sandbox/z4m/zsh4monkey || exit 1

# Provider stub: replies with the content of fake/response after fake/delay
# seconds and counts requests.
cat >| $sandbox/bin/curl <<'EOF'
#!/bin/zsh -f
zmodload zsh/datetime zsh/zselect
local out= payload= fake=$Z4M_TEST_FAKE
while (( $# )); do
  [[ $1 == --output ]] && { out=$2; shift }
  [[ $1 == --data-binary ]] && { payload=${2#@}; shift }
  shift
done
print -r -- "$EPOCHREALTIME start $(jq -r .messages[1].content <$payload | grep ^BUFFER:)" >> $fake/count
local content=$(<$fake/response)
local -i delay_cs=$(( $(<$fake/delay) * 100 ))
zselect -t $delay_cs
print -rn -- '{"choices":[{"message":{"content":"'$content'"}}]}' >| $out
print -r -- "$EPOCHREALTIME end" >> $fake/trace
print -rn -- 200
EOF
chmod +x $sandbox/bin/curl || exit 1

cat >| $sandbox/setup.zsh <<EOF
PS1='> '
PS2='>> '
zmodload zsh/datetime zsh/zselect
HISTSIZE=100
export Z4M=$sandbox/z4m Z4M_TEST_FAKE=$sandbox/fake Z4M_TEST_KEY=test-key
path=($sandbox/bin \$path)
rehash
[[ \$commands[curl] == $sandbox/bin/curl ]] || { print -r -- 'stub curl not first in PATH'; exit 1 }
fpath=($repository/fn \$fpath)
autoload -Uz -- $repository/fn/(-|)z4m-autosuggest-*(:t) -z4m-zle-line-finish -z4m-is-valid-list
functions -M _z4m_cursor_max 0 0
_z4m_cursor_max() { (( \$#BUFFER )) }
zstyle ':z4m:autosuggestions:ai' enabled yes
zstyle ':z4m:autosuggestions:ai' api-key-env Z4M_TEST_KEY
# Unroutable endpoint: nothing can leave the host even if the stub were bypassed.
zstyle ':z4m:autosuggestions:ai' endpoint http://127.0.0.1:9
zstyle ':z4m:autosuggestions:ai' debounce-ms 50
zstyle ':z4m:autosuggestions:ai' cooldown-ms 0
setopt hist_ignore_space
zstyle ':z4m:autosuggestions' strategy 'history_pwd history'
-z4m-highlight-render() { }
dbg() { print -rl -- \${(kv)_z4m_autosuggest_ai_state[(I)last_*|manual_*]} \${_z4m_autosuggest_events[-12,-1]} }
dump-pwd-map() {
  local d i
  for d in \${(k)_z4m_dir_history_ids}; do
    for i in \${=_z4m_dir_history_ids[\$d]}; do print -r -- "E\${d:t}:\${history[\$i]}"; done
  done
  print -r -- END\$((6*7))
}
zle-line-init() { -z4m-autosuggest-reset init }
zle-line-finish() { -z4m-zle-line-finish }
zle -N zle-line-finish
zle-line-pre-redraw() { -z4m-autosuggest-fetch }
zle -N zle-line-init
zle -N zle-line-pre-redraw
zle -N z4m-autosuggest-ai-trigger
bindkey '^O' z4m-autosuggest-ai-trigger
bindkey '^E' end-of-line
-z4m-autosuggest-init
print -r -- SETUP-DONE
EOF

typeset -g acc=
typeset -gi failures=0

pump() {
  local chunk
  while zpty -rt t chunk; do acc+=$chunk; done
}

drain() {
  local -F deadline=$(( EPOCHREALTIME + $1 ))
  while (( EPOCHREALTIME < deadline )); do pump; zselect -t 2; done
}

wait_for() {
  local -F deadline=$(( EPOCHREALTIME + ${2:-5} ))
  while (( EPOCHREALTIME < deadline )); do
    pump
    [[ $acc == *$1* ]] && return 0
    zselect -t 2
  done
  return 1
}

# Types $2, waits $3 seconds, types $4, waits $5 seconds, then accepts the
# line with End + Enter. Commands print markers built with $((6*7)) so that
# the echoed input never matches the expected output $6.
scenario() {
  local label=$1 first=$2 pause=$3 second=$4 settle=$5 expected=$6
  acc=
  zpty -w -n t "$first"
  drain $pause
  zpty -w -n t "$second"
  drain $settle
  zpty -w -n t $'\x05\r'
  if ! wait_for "$expected"$'\r' 4; then
    print -ru2 -- "$label: expected output $expected"
    print -ru2 -- "  output: ${(q+)acc[-300,-1]}"
    (( ++failures ))
    if [[ -n ${Z4M_TEST_DEBUG-} ]]; then
      acc=; zpty -w t 'dbg'; drain 1; print -ru2 -- "$acc"
    fi
  fi
}

requests() {
  local -a lines
  [[ -r $sandbox/fake/count ]] && lines=(${(f)"$(<$sandbox/fake/count)"})
  print -r -- ${#lines}
}

print -r -- 0.4 >| $sandbox/fake/delay
: >| $sandbox/fake/count

cd -- $sandbox/home || exit 1
HOME=$sandbox/home ZDOTDIR=$sandbox/home zpty t 'zsh -f -i' || exit 1
zpty -w t "source ${(q)sandbox}/setup.zsh"
wait_for SETUP-DONE 10 || { print -ru2 -- 'zsh did not start'; exit 1; }
drain 0.3
zpty -w t "zstyle ':z4m:autosuggestions:ai' mode manual; -z4m-autosuggest-init"
drain 0.3

# Manual rewrite lands from the fd handler and replaces the live edit line.
print -r -- '=print -r -- M$((6*7))_rewritten' >| $sandbox/fake/response
scenario 'manual rewrite applies to edit line' 'print -r -- M$((6*7))_original' 0.3 $'\x0f' 1.2 M42_rewritten

zpty -w t "zstyle ':z4m:autosuggestions:ai' mode auto; -z4m-autosuggest-init"
drain 0.3

# Fallback suggestion is shown for the buffer it was requested for.
print -r -- '+suggested' >| $sandbox/fake/response
scenario 'fallback suggestion is accepted' 'print -r -- S$((6*7))_' 0 '' 1.2 S42_suggested

# A response for a buffer the user has typed past is dropped.
print -r -- '+suggested' >| $sandbox/fake/response
acc=
zpty -w -n t 'print -r -- T$((6*7))_'
drain 0.25
print -r -- '!no_suggestion' >| $sandbox/fake/response
scenario 'stale fallback is dropped' '' 0 'x' 1.2 T42_x

# history_pwd only indexes lines that actually entered history, so ignored
# lines never steal the id of the next command run in another directory.
mkdir -p -- $sandbox/home/{a,b}
acc=
for line in 'cd a' 'true pwdA' '' ' cd ../b' 'true pwdB'; do
  zpty -w -n t "$line"$'\r'
  drain 0.2
done
zpty -w t 'dump-pwd-map'
wait_for END42 4 || { print -ru2 -- "history_pwd map dump missing: ${(q+)acc[-600,-1]}"; (( ++failures )) }
[[ $acc == *$'Ea:true pwdA\r'* ]] || { print -ru2 -- 'history_pwd lost command in a'; (( ++failures )) }
[[ $acc == *$'Eb:true pwdB\r'* ]] || { print -ru2 -- 'history_pwd lost command in b'; (( ++failures )) }
[[ $acc == *$'Ea:true pwdB\r'* ]] && { print -ru2 -- 'history_pwd associated b command with a'; (( ++failures )) }

zpty -w t 'exit'
(( failures == 0 ))
