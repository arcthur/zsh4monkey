#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail

setopt local_options

cd -- "${0:A:h:h}" || exit 1
fpath=("$PWD/fn" $fpath)
autoload -Uz -- -z4m-ssh-parse-env-spec

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

typeset action key value

assert_ok 'literal set' -z4m-ssh-parse-env-spec 'EDITOR=vim'
action=$reply[1]
key=$reply[2]
value=$reply[3]
assert_eq 'set' "$action" 'literal set action'
assert_eq 'EDITOR' "$key" 'literal set key'
assert_eq 'vim' "$value" 'literal set value'

assert_ok 'literal value preserves spaces' -z4m-ssh-parse-env-spec 'FZF_DEFAULT_OPTS=--height 40% --layout reverse' 
action=$reply[1]
key=$reply[2]
value=$reply[3]
assert_eq 'set' "$action" 'spacey set action'
assert_eq 'FZF_DEFAULT_OPTS' "$key" 'spacey set key'
assert_eq '--height 40% --layout reverse' "$value" 'spacey set value'

assert_ok 'empty literal set' -z4m-ssh-parse-env-spec 'EMPTY='
action=$reply[1]
key=$reply[2]
value=$reply[3]
assert_eq 'set' "$action" 'empty set action'
assert_eq 'EMPTY' "$key" 'empty set key'
assert_eq '' "$value" 'empty set value'

assert_ok 'copy local sentinel' -z4m-ssh-parse-env-spec 'VISUAL=_z4m_copy_env_var_'
action=$reply[1]
key=$reply[2]
value=$reply[3]
assert_eq 'copy' "$action" 'copy action'
assert_eq 'VISUAL' "$key" 'copy key'
assert_eq '' "$value" 'copy value'

assert_ok 'kitty copy sentinel is accepted' -z4m-ssh-parse-env-spec 'PAGER=_kitty_copy_env_var_'
action=$reply[1]
key=$reply[2]
value=$reply[3]
assert_eq 'copy' "$action" 'kitty copy action'
assert_eq 'PAGER' "$key" 'kitty copy key'

assert_ok 'no equals means unset' -z4m-ssh-parse-env-spec 'GIT_DIR'
action=$reply[1]
key=$reply[2]
value=$reply[3]
assert_eq 'unset' "$action" 'unset action'
assert_eq 'GIT_DIR' "$key" 'unset key'
assert_eq '' "$value" 'unset value'

assert_fail 'empty spec is rejected' -z4m-ssh-parse-env-spec ''
assert_fail 'invalid name is rejected' -z4m-ssh-parse-env-spec '1NOPE=value'

if (( failures )); then
  exit 1
fi
