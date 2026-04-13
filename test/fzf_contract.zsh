#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail

setopt local_options

cd -- "${0:A:h:h}" || exit 1

typeset -gi failures=0

assert_match() {
  local pattern=$1
  shift
  if ! rg -n --color=never -e "$pattern" "$@" >/dev/null 2>&1; then
    print -ru2 -- "missing expected pattern: $pattern"
    ((failures++))
  fi
}

assert_no_match() {
  local pattern=$1
  shift
  if rg -n --color=never -e "$pattern" "$@" >/dev/null 2>&1; then
    print -ru2 -- "unexpected match for pattern: $pattern"
    rg -n --color=never -e "$pattern" "$@" >&2 || true
    ((failures++))
  fi
}

assert_match '-z4m-fzf-available-p' \
  fn/-z4m-fzf \
  fn/-z4m-init-zle \
  fn/-z4m-init-vi-mode

assert_match "bindkey '\\^I'.*expand-or-complete" \
  fn/-z4m-init-zle

assert_match "bindkey -M viins '\\^I'.*expand-or-complete" \
  fn/-z4m-init-vi-mode

assert_match "bindkey -M vicmd '\\^I'.*expand-or-complete" \
  fn/-z4m-init-vi-mode

assert_match "_z4m_has_fzf|_z4m_vi_has_fzf" \
  fn/-z4m-init-zle \
  fn/-z4m-init-vi-mode

assert_match "history-incremental-search-backward" \
  fn/-z4m-init-zle \
  fn/-z4m-init-vi-mode

if (( failures )); then
  exit 1
fi
