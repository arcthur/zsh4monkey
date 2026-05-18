#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

setopt local_options

cd -- "${0:A:h:h}" || exit 1
Z4M=$PWD
source fn/-z4m-autosuggest-ai || exit 1

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

assert_contains() {
  local needle=$1 haystack=$2 label=$3
  if [[ $haystack != *"$needle"* ]]; then
    print -ru2 -- "$label: missing [$needle]"
    ((failures++))
  fi
}

assert_not_contains() {
  local needle=$1 haystack=$2 label=$3
  if [[ $haystack == *"$needle"* ]]; then
    print -ru2 -- "$label: unexpected [$needle]"
    ((failures++))
  fi
}

assert_no_function() {
  local name=$1 label=$2
  if (( ${+functions[$name]} )); then
    print -ru2 -- "$label: unexpected function [$name]"
    ((failures++))
  fi
}

extract_user_prompt() {
  local payload=$1
  command jq -r '.messages[1].content' <<<"$payload"
}

-z4m-autosuggest-ai-read-config
assert_eq manual "${_z4m_autosuggest_ai_state[configured_mode]}" 'default ai mode'
assert_eq 0 "${_z4m_autosuggest_ai_state[configured_history_lines]}" 'default ai history lines'
assert_eq project:manual_intent,output:manual_intent,source:tmux_then_proxy "${_z4m_autosuggest_ai_state[context_policy]}" 'ai context policy'
assert_ok 'context policy helper' -z4m-autosuggest-ai-context-policy
assert_eq project:manual_intent,output:manual_intent,source:tmux_then_proxy "$REPLY" 'context policy helper value'
assert_no_function -z4m-autosuggest-ai-allow-empty-p 'empty autosuggest fallback gate'

histfile=$(command mktemp "${TMPDIR:-/tmp}/z4m-ai-history.XXXXXXXXXX") || exit 1
trap 'rm -f -- "$histfile"' EXIT
print -r -- ': 1700000000:0;export API_KEY=history-secret-value' >| "$histfile" || exit 1
fc -p "$histfile" 100 100
fc -R "$histfile"
-z4m-autosuggest-ai-build-payload 'export API_KEY=buffer-secret-value' default autosuggest_fallback ''
payload=$REPLY
user_prompt=$(extract_user_prompt "$payload")

assert_not_contains 'PROJECT_CONTEXT:' "$user_prompt" 'fallback project context'
assert_not_contains 'HISTORY (most recent first):' "$user_prompt" 'fallback history context'
assert_not_contains 'buffer-secret-value' "$user_prompt" 'fallback buffer redaction'
assert_not_contains 'history-secret-value' "$user_prompt" 'fallback history redaction'
assert_contains '***REDACTED***' "$user_prompt" 'fallback redaction marker'

zstyle ':z4m:autosuggestions:ai' history-lines 1
-z4m-autosuggest-ai-read-config
-z4m-autosuggest-ai-build-payload 'print ok' default manual_rewrite ''
payload=$REPLY
user_prompt=$(extract_user_prompt "$payload")

assert_contains 'HISTORY (most recent first):' "$user_prompt" 'manual history context'
assert_not_contains 'history-secret-value' "$user_prompt" 'manual history redaction'
assert_contains 'API_KEY=***REDACTED***' "$user_prompt" 'manual history redaction marker'

saved_path=$PATH
PATH=${TMPDIR:-/tmp}/z4m-no-perl-path
hash -r
-z4m-autosuggest-ai-redact-sensitive $'BUFFER: echo password=buffer-secret-value\nBUFFER_META:\nkind: resolved'
redacted=$REPLY
PATH=$saved_path
hash -r

assert_contains 'BUFFER: echo password=***REDACTED***' "$redacted" 'non-perl redaction keeps buffer shape'
assert_contains 'BUFFER_META:' "$redacted" 'non-perl redaction keeps meta header'
assert_contains 'kind: resolved' "$redacted" 'non-perl redaction keeps meta body'
assert_not_contains 'buffer-secret-value' "$redacted" 'non-perl redaction removes secret'

real_perl=${commands[perl]-}
if [[ -n $real_perl ]]; then
  tmpdir=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-ai-contract.XXXXXXXXXX") || exit 1
  trap 'rm -f -- "$histfile"; rm -rf -- "$tmpdir"' EXIT
  count_file=$tmpdir/perl-count
  print -r -- 0 >| "$count_file"
  {
    print -r -- '#!/bin/sh'
    print -r -- 'count=$(cat "$Z4M_TEST_PERL_COUNT" 2>/dev/null || printf 0)'
    print -r -- 'count=$((count + 1))'
    print -r -- 'printf "%s\n" "$count" > "$Z4M_TEST_PERL_COUNT"'
    print -r -- 'exec "$Z4M_TEST_REAL_PERL" "$@"'
  } >| "$tmpdir/perl" || exit 1
  chmod +x "$tmpdir/perl" || exit 1

  saved_path=$PATH
  Z4M_TEST_PERL_COUNT=$count_file Z4M_TEST_REAL_PERL=$real_perl PATH="$tmpdir:$PATH" \
    zsh -fc 'cd "$1" || exit 1; Z4M=$PWD; source fn/-z4m-autosuggest-ai || exit 1; -z4m-autosuggest-ai-read-config; -z4m-autosuggest-ai-build-payload "export TOKEN=fallback-secret-value" default autosuggest_fallback ""; command jq -r ".messages[1].content" <<<"$REPLY" >/dev/null' zsh "$PWD" || {
      print -ru2 -- 'perl-count fixture failed'
      ((failures++))
    }
  PATH=$saved_path
  hash -r
  perl_count=$(<"$count_file")
  assert_eq 1 "$perl_count" 'fallback payload redaction perl calls'
fi

assert_ok 'no-suggestion protocol is valid' -z4m-autosuggest-ai-parse-protocol '!no_suggestion' 'git '
assert_eq none "$reply[1]" 'no-suggestion kind'
assert_eq '' "$reply[2]" 'no-suggestion payload'

assert_fail 'empty suggestions do not trigger strict retry' -z4m-autosuggest-ai-retryable-reject-p empty_suggestion
assert_fail 'low-quality suggestions do not trigger strict retry' -z4m-autosuggest-ai-retryable-reject-p low_quality
assert_fail 'invalid protocol does not trigger strict retry' -z4m-autosuggest-ai-retryable-reject-p invalid_protocol
assert_fail 'fallback rejects unresolved command-prefix guesses' -z4m-autosuggest-ai-autofallback-eligible-p gi
assert_ok 'fallback allows resolved command arguments' -z4m-autosuggest-ai-autofallback-eligible-p 'print '

if (( failures )); then
  exit 1
fi
