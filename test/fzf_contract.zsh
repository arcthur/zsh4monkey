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

# Plain Tab lists one level; recursion is opt-in via the trigger or recurse-dirs.
assert_match 'zstyle -t :z4m:\$\{WIDGET#z4m-\} recurse-dirs' \
  fn/-z4m-comp-files

assert_match "recurse-trigger _z4m_recurse_trigger \\|\\| _z4m_recurse_trigger='\\*\\*'" \
  fn/z4m-fzf-complete

# Record keys go through one codec; base64 is the rare fallback only.
assert_no_match '-z4m-b64(enc|dec)\b' \
  fn/-z4m-present-files \
  fn/-z4m-comp-files \
  fn/z4m-cd-down \
  fn/z4m-fzf-dir-history

if (( failures )); then
  exit 1
fi
