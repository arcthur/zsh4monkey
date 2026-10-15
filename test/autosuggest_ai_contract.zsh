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

extract_user_prompt() {
  local payload=$1
  command jq -r '.messages[1].content' <<<"$payload"
}

-z4m-autosuggest-ai-read-config
assert_eq manual "${_z4m_autosuggest_ai_state[configured_mode]}" 'default ai mode'
assert_eq 0 "${_z4m_autosuggest_ai_state[configured_history_lines]}" 'default ai history lines'
assert_eq pwd:off,project:off,output:off,source:tmux_then_proxy "${_z4m_autosuggest_ai_state[context_policy]}" 'ai context policy'
assert_ok 'context policy helper' -z4m-autosuggest-ai-context-policy
assert_eq pwd:off,project:off,output:off,source:tmux_then_proxy "$REPLY" 'context policy helper value'

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
assert_contains 'PWD: <not-shared>' "$user_prompt" 'manual pwd privacy default'
assert_not_contains 'PROJECT_CONTEXT:' "$user_prompt" 'manual project privacy default'
assert_not_contains 'history-secret-value' "$user_prompt" 'manual history redaction'
assert_contains 'API_KEY=***REDACTED***' "$user_prompt" 'manual history redaction marker'

zstyle ':z4m:autosuggestions:ai' context-pwd-enabled yes
zstyle ':z4m:autosuggestions:ai' context-project-enabled yes
-z4m-autosuggest-ai-read-config
-z4m-autosuggest-ai-build-payload 'print ok' default manual_rewrite ''
user_prompt=$(extract_user_prompt "$REPLY")
assert_contains "PWD: $PWD" "$user_prompt" 'manual pwd opt-in'
assert_contains 'PROJECT_CONTEXT:' "$user_prompt" 'manual project opt-in'

proxy_test_dir=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-ai-proxy.XXXXXXXXXX") || exit 1
saved_z4m=$Z4M
Z4M=$proxy_test_dir
mkdir -p -- "$Z4M/cache/ai-context/proxy"
print -r -- cross-pane-private-output >"$Z4M/cache/ai-context/proxy/_1.log"
assert_fail 'known pane never falls back to another pane log' \
  -z4m-autosuggest-ai-proxy-tail '%2' 40
assert_ok 'unknown pane may use latest proxy log' \
  -z4m-autosuggest-ai-proxy-tail '' 40
assert_contains cross-pane-private-output "$REPLY" 'unknown pane latest proxy log'
Z4M=$saved_z4m
command rm -rf -- "$proxy_test_dir"

function -z4m-autosuggest-ai-capture-pane() {
  REPLY=$'visible-output\nTOKEN=output-secret-value'
  return 0
}

function -z4m-autosuggest-ai-proxy-effective-p() {
  return 1
}

-z4m-autosuggest-ai-build-payload 'print ok' default autosuggest_fallback ''
user_prompt=$(extract_user_prompt "$REPLY")
assert_contains 'PWD: <not-shared>' "$user_prompt" 'fallback pwd remains private after opt-in'
assert_not_contains 'OUTPUT_CONTEXT:' "$user_prompt" 'fallback output remains private'
assert_not_contains 'output-secret-value' "$user_prompt" 'fallback captured output remains private'

zstyle ':z4m:autosuggestions:ai' context-output-enabled yes
-z4m-autosuggest-ai-read-config
-z4m-autosuggest-ai-build-payload 'print ok' default manual_rewrite ''
user_prompt=$(extract_user_prompt "$REPLY")
assert_contains 'OUTPUT_CONTEXT:' "$user_prompt" 'manual output opt-in'
assert_contains 'visible-output' "$user_prompt" 'manual captured output'
assert_not_contains 'output-secret-value' "$user_prompt" 'manual output redaction'
assert_contains 'TOKEN=***REDACTED***' "$user_prompt" 'manual output redaction marker'

zstyle ':z4m:autosuggestions:ai' context-output-enabled invalid
-z4m-autosuggest-ai-read-config
-z4m-autosuggest-ai-build-payload 'print ok' default intent_command 'show status'
user_prompt=$(extract_user_prompt "$REPLY")
assert_not_contains 'OUTPUT_CONTEXT:' "$user_prompt" 'invalid output opt-in falls back to private'

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
  assert_eq 0 "$perl_count" 'fallback payload construction does not fork perl'
fi

# Request files hold the API key. When mktemp fails there must be no fallback
# to a guessable directory that another local user could have pre-created.
(
  sandbox=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-ai-submit.XXXXXXXXXX") || exit 1
  trap 'command rm -rf -- "$sandbox"' EXIT
  command mkdir -p -- $sandbox/bin $sandbox/tmp || exit 1
  print -r -- '#!/bin/sh
exit 1' >| $sandbox/bin/mktemp
  print -r -- "#!/bin/sh
: >'$sandbox/curl-ran'" >| $sandbox/bin/curl
  command chmod +x -- $sandbox/bin/mktemp $sandbox/bin/curl || exit 1
  PATH=$sandbox/bin:$PATH TMPDIR=$sandbox/tmp Z4M_TEST_AI_KEY=submit-secret-value
  hash -r
  zstyle ':z4m:autosuggestions:ai' api-key-env Z4M_TEST_AI_KEY
  -z4m-autosuggest-ai-read-config
  _z4m_autosuggest_ai_state[inflight]=0
  if -z4m-autosuggest-ai-submit 'print ok' default manual_rewrite '' 2>/dev/null; then
    print -ru2 -- 'submit succeeded without a private request directory'
    exit 1
  fi
  local -a created=($sandbox/tmp/*(DN))
  (( ! $#created )) || { print -ru2 -- "submit created ${(j: :)created}"; exit 1 }
  [[ ! -e $sandbox/curl-ran ]] || { print -ru2 -- 'submit ran curl'; exit 1 }
) || ((failures++))

assert_ok 'no-suggestion protocol is valid' -z4m-autosuggest-ai-parse-protocol '!no_suggestion' 'git '
assert_eq none "$reply[1]" 'no-suggestion kind'
assert_eq '' "$reply[2]" 'no-suggestion payload'

assert_fail 'empty suggestions do not trigger strict retry' -z4m-autosuggest-ai-retryable-reject-p empty_suggestion
assert_fail 'low-quality suggestions do not trigger strict retry' -z4m-autosuggest-ai-retryable-reject-p low_quality
assert_fail 'invalid protocol does not trigger strict retry' -z4m-autosuggest-ai-retryable-reject-p invalid_protocol
assert_fail 'fallback rejects unresolved command-prefix guesses' -z4m-autosuggest-ai-autofallback-eligible-p gi
assert_ok 'fallback allows resolved command arguments' -z4m-autosuggest-ai-autofallback-eligible-p 'print '

payload_tokens() {
  -z4m-autosuggest-ai-estimate-tokens "$1"
  print -r -- $REPLY
}

# The token cap covers the whole JSON payload: optional context is dropped or
# trimmed to fit instead of pushing the request over the submit guard.
zstyle -d ':z4m:autosuggestions:ai'
-z4m-autosuggest-ai-read-config
assert_eq 1024 "${_z4m_autosuggest_ai_state[configured_max_input_tokens]}" 'default max input tokens'
zstyle ':z4m:autosuggestions:ai' max-input-tokens 384
zstyle ':z4m:autosuggestions:ai' context-output-enabled yes
zstyle ':z4m:autosuggestions:ai' history-lines 20
-z4m-autosuggest-ai-read-config
function -z4m-autosuggest-ai-capture-pane() {
  REPLY=${(l:3000::x:)}$'\nlast-output-line'
  return 0
}
-z4m-autosuggest-ai-build-payload 'print ok' default manual_rewrite ''
payload=$REPLY
assert_ok 'budgeted payload is valid json' command jq -e . <<<"$payload" >/dev/null
(( $(payload_tokens "$payload") <= 384 )) || { print -ru2 -- "budgeted payload exceeds 384 tokens"; ((failures++)); }
user_prompt=$(extract_user_prompt "$payload")
assert_contains 'BUFFER: print ok' "$user_prompt" 'core prompt survives budgeting'
assert_contains 'OUTPUT_CONTEXT:' "$user_prompt" 'output context trimmed into budget'
assert_contains 'last-output-line' "$user_prompt" 'output context keeps the most recent lines'

long_buffer="print ${(l:200::a:)}"
-z4m-autosuggest-ai-build-payload "$long_buffer" default autosuggest_fallback ''
assert_ok '200-char fallback payload is valid json' command jq -e . <<<"$REPLY" >/dev/null
(( $(payload_tokens "$REPLY") <= 384 )) || { print -ru2 -- "200-char fallback buffer exceeds budget"; ((failures++)); }

# Opting into every context source does not get the request rejected.
(
  sandbox=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-ai-budget.XXXXXXXXXX") || exit 1
  trap 'command rm -rf -- "$sandbox"' EXIT
  command mkdir -p -- $sandbox/bin || exit 1
  print -r -- '#!/bin/sh' >| $sandbox/bin/curl
  command chmod +x -- $sandbox/bin/curl || exit 1
  PATH=$sandbox/bin:$PATH Z4M_TEST_AI_KEY=test-key
  hash -r
  zstyle -d ':z4m:autosuggestions:ai' max-input-tokens
  zstyle ':z4m:autosuggestions:ai' context-project-enabled yes
  zstyle ':z4m:autosuggestions:ai' context-pwd-enabled yes
  zstyle ':z4m:autosuggestions:ai' api-key-env Z4M_TEST_AI_KEY
  -z4m-autosuggest-ai-read-config
  _z4m_autosuggest_ai_state[inflight]=0
  -z4m-autosuggest-ai-submit 'print ok' default manual_rewrite '' || {
    print -ru2 -- "full-context submit rejected: ${_z4m_autosuggest_ai_state[last_reject]}"
    exit 1
  }
  -z4m-autosuggest-ai-reset test
) || ((failures++))
zstyle -d ':z4m:autosuggestions:ai'

if (( failures )); then
  exit 1
fi
