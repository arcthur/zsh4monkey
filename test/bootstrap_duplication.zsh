#!/usr/bin/env zsh
#
# z4m.zsh runs before sc/supply-chain exists, so it inlines the archive safety
# checks. That duplication is unavoidable, but silent drift is not: assert the
# inlined awk programs stay textually identical to the library implementation
# that test/supply_chain.zsh exercises behaviorally.

emulate -L zsh -o err_return -o no_unset -o pipe_fail -o extended_glob -o no_aliases

local repository=${0:A:h:h}

typeset -ga extracted_programs

extract_awk_programs() {
  local file=$1
  local line trimmed current=
  local -i collecting=0
  extracted_programs=()

  while IFS= read -r line; do
    trimmed=${${line##[[:space:]]#}%%[[:space:]]#}
    if (( ! collecting )); then
      [[ $trimmed == 'BEGIN { safe = 1 }' ]] || continue
      collecting=1
      current=$trimmed
      continue
    fi
    [[ -n $trimmed ]] && current+=$'\n'$trimmed
    if [[ $trimmed == 'END { exit safe ? 0 : 1 }' ]]; then
      extracted_programs+=("$current")
      collecting=0
      current=
    fi
  done <$file

  (( ! collecting )) || {
    print -ru2 -- "unterminated awk program in $file"
    return 1
  }
}

extract_awk_programs "$repository/z4m.zsh"
local -a inlined=("${extracted_programs[@]}")

extract_awk_programs "$repository/sc/supply-chain"
local -a library=("${extracted_programs[@]}")

if (( $#inlined != 2 || $#library != 2 )); then
  print -ru2 -- \
    "expected two archive safety programs per file, found ${#inlined} and ${#library}"
  exit 1
fi

local -i index
for index in 1 2; do
  if [[ $inlined[$index] != $library[$index] ]]; then
    print -ru2 -- "archive safety program $index drifted between z4m.zsh and sc/supply-chain"
    print -ru2 -- '--- z4m.zsh ---'
    print -ru2 -- "$inlined[$index]"
    print -ru2 -- '--- sc/supply-chain ---'
    print -ru2 -- "$library[$index]"
    exit 1
  fi
done

# Every place that hashes a bootstrap file must agree on the same tool chain and
# the same preference order, otherwise a host without sha256sum verifies against
# a digest produced by a different implementation.
local file order
for file in .zshenv z4m.zsh install sc/supply-chain; do
  order=$(command grep -o 'sha256sum\|shasum\|openssl' "$repository/$file" |
    command awk '!seen[$0]++' | command tr '\n' ' ')
  if [[ ${order% } != 'sha256sum shasum openssl' ]]; then
    print -ru2 -- "$file uses an unexpected SHA-256 tool order: ${order% }"
    exit 1
  fi
done
