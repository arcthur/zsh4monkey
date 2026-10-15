#!/usr/bin/env zsh
#
# Behavior that must hold on every supported zsh, including the 5.10 line.
# Run it with each zsh binary under test.

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

cd -- "${0:A:h:h}" || exit 1
fpath=("$PWD/fn" $fpath)
autoload -Uz -- -z4m-cmd-compile -z4m-term-ext-disable

typeset -gi failures=0
fail() {
  print -ru2 -- "FAIL: $1"
  (( ++failures ))
}

tmpdir=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-zsh-compat.XXXXXXXXXX") || exit 1
trap 'command rm -rf -- "$tmpdir"' EXIT

# `z4m compile` takes no options. zsh 5.10 rejects `zparseopts` without specs,
# which broke the first initialization there.
() {
  local -a compiled
  function -z4m-compile() { compiled+=($1) }
  function _z4m_err() { return 1 }
  functions -Ms _z4m_err
  : >$tmpdir/a.zsh >$tmpdir/b.zsh

  -z4m-cmd-compile -- $tmpdir/a.zsh $tmpdir/b.zsh $tmpdir/missing.zsh 2>$tmpdir/err ||
    fail "compile with --: $(<$tmpdir/err)"
  [[ $compiled == "$tmpdir/a.zsh $tmpdir/b.zsh" ]] || fail "compile with --: compiled [$compiled]"

  compiled=()
  -z4m-cmd-compile $tmpdir/a.zsh 2>$tmpdir/err || fail "compile without --: $(<$tmpdir/err)"
  [[ $compiled == $tmpdir/a.zsh ]] || fail "compile without --: compiled [$compiled]"

  compiled=()
  -z4m-cmd-compile -x $tmpdir/a.zsh 2>/dev/null && fail 'compile accepted an unknown option'
  (( ! $#compiled )) || fail 'compile ran despite an unknown option'
}

# Native terminal extensions only exist from zsh 5.10. Without them the helper
# must fail quietly instead of aborting the caller on the invalid name.
() {
  local name=.term.extensions
  if ! -z4m-term-ext-disable integration 2>$tmpdir/err; then
    [[ -s $tmpdir/err ]] && fail "unsupported zsh printed: $(<$tmpdir/err)"
    return
  fi

  [[ "${(@P)name}" == -integration ]] || fail "integration not disabled: [${(@P)name}]"
  -z4m-term-ext-disable integration
  [[ "${(@P)name}" == -integration ]] || fail "disabling twice duplicated: [${(@P)name}]"

  # A family the user configured, in either direction, is left alone.
  set -A $name integration-pwd -cursor-color
  -z4m-term-ext-disable integration cursor-shape bracketed-paste
  [[ "${(@P)name}" == 'integration-pwd -cursor-color -bracketed-paste' ]] ||
    fail "user configuration not respected: [${(@P)name}]"
}

# In zsh 5.10, unsetting an element of a zsh/parameter hash such as
# `functions[name]` inside a function leaves a dangling parameter behind, and
# the shell crashes when the function returns if that heap page is gone. It
# does not reproduce reliably, so forbid the pattern instead.
() {
  local -a hits=(${(f)"$(command grep -nE \
    "^[^#]*unset[^#]*[\"'](functions|aliases|galiases|saliases|widgets|commands|options|parameters|nameddirs|userdirs|history)\[" \
    main.zsh z4m.zsh fn/*(.))"})
  (( ! $#hits )) || fail "unset of a zsh/parameter hash element: ${(j:; :)hits}"
}

(( failures == 0 ))
