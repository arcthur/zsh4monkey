#!/usr/bin/env zsh
#
# The installer rewrites the downloaded .zshrc by anchoring on comment lines.
# A renamed comment used to make a rewrite silently no-op, so assert every
# anchor still starts a line in both shipped templates, and that each rewrite
# verifies its own result.

emulate -L zsh -o err_return -o no_unset -o pipe_fail -o no_aliases

local repository=${0:A:h:h}
local installer=$repository/install

typeset -gi failures=0

read_anchor() {
  local name=$1 line
  line=$(command grep -m 1 -E "^${name}='" "$installer") || {
    print -ru2 -- "installer does not define $name"
    (( ++failures ))
    return 1
  }
  REPLY=${${line#*=\'}%\'}
  [[ -n $REPLY ]] || {
    print -ru2 -- "installer defines an empty $name"
    (( ++failures ))
    return 1
  }
}

# The installer matches with `index($0, anchor) == 1`, so a template that merely
# contains the text somewhere is not enough.
starts_a_line() {
  local anchor=$1 file=$2 line
  while IFS= read -r line; do
    [[ $line == "$anchor"* ]] && return 0
  done <$file
  return 1
}

local -a anchors=()
local name
for name in zshrc_anchor_keyboard zshrc_anchor_direnv zshrc_anchor_repositories; do
  read_anchor "$name" && anchors+=("$REPLY")
done

local template anchor
for template in .zshrc .zshrc.mac; do
  for anchor in "${anchors[@]}"; do
    if ! starts_a_line "$anchor" "$repository/$template"; then
      print -ru2 -- "$template has no line starting with installer anchor: $anchor"
      (( ++failures ))
    fi
  done
done

# Anchoring is only half the contract: a rewrite that silently produces nothing
# must fail the install, so every conditional rewrite verifies its own output.
local expected
for expected in \
    "zstyle ':z4m:' start-tmux" \
    "zstyle ':z4m:direnv' enable 'yes'" \
    "zstyle ':z4m:' editor-mode 'vi'" \
    "zstyle ':z4m:ssh-agent:' start yes"; do
  if ! command grep -Fq -- "'require_zshrc_line' \"$expected\"" "$installer"; then
    print -ru2 -- "installer does not verify its rewrite result: $expected"
    (( ++failures ))
  fi
done

(( failures == 0 ))
