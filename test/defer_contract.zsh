#!/usr/bin/env zsh

emulate -L zsh -o no_aliases

cd -- "${0:A:h:h}" || exit 1

typeset -gi failures=0
source fn/z4m-defer || exit 1

capture_deferred_args() {
  typeset -ga captured_deferred_args=("$@")
}

fail_deferred_command() {
  return 23
}

function zmodload() {
  return 1
}

source fn/z4m-defer capture_deferred_args \
  'argument with spaces' \
  '*' \
  '$(print unsafe)' || exit 1
unfunction zmodload

typeset -a expected=('argument with spaces' '*' '$(print unsafe)')
if [[ ${(pj:\0:)captured_deferred_args} != ${(pj:\0:)expected} ]]; then
  print -ru2 -- 'deferred command arguments were not preserved'
  (( ++failures ))
fi

_z4m_defer_enqueue fail_deferred_command || exit 1
_z4m_defer_run_queue 2>/dev/null
if (( $? != 23 )); then
  print -ru2 -- 'deferred command failure status was not preserved'
  (( ++failures ))
fi

if (( $#_z4m_defer_queue )); then
  print -ru2 -- 'deferred command queue was not cleared'
  (( ++failures ))
fi

if rg -n --color=never 'eval "\\$cmd"|_z4m_defer_queue\\+=\\("\\$\\*"\\)' fn/z4m-defer >/dev/null; then
  print -ru2 -- 'unsafe deferred command serialization remains'
  (( ++failures ))
fi

(( failures == 0 ))
