#!/usr/bin/env zsh
#
# Startup caches must stay valid across shells: a cache written for a tool
# that has since gone away must not break later startups, and a cache that is
# still valid must be reused instead of rebuilt on every start.

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

zmodload -F zsh/stat b:zstat || exit 1

local repository=${0:A:h:h}
source $repository/test/lib/sandbox.zsh || exit 1
sandbox_setup $repository || exit 1
trap sandbox_cleanup EXIT HUP INT TERM

local ready="*$SANDBOX_READY*"
local cache=$SANDBOX_Z4M/cache

# A completion directory whose name is not ASCII, as with a localized home.
local completions=$SANDBOX_HOME/compléments
command mkdir -p -- $completions || exit 1
print -r -- '#compdef z4m-test-cmd' >$completions/_z4m-test-cmd

# Any direnv will do: with no .envrc in sight it is never asked to export.
print -r -- '#!/bin/sh
exit 0' >$SANDBOX/bin/direnv
command chmod 755 -- $SANDBOX/bin/direnv || exit 1

SANDBOX_PRE_INIT=(
  "zstyle ':z4m:direnv' enable yes"
  "fpath=(${(q)completions} \$fpath)"
)
sandbox_write_zshrc

# Completion initialization is deferred until ZLE first sits idle, which a
# line already waiting on the terminal preempts; ask until it has happened.
start_shell() {
  local label=$1
  local -i attempt
  sandbox_pty_start LANG=en_US.UTF-8 || return
  if sandbox_pty_expect 60 $ready; then
    for (( attempt = 0; attempt < 20; ++attempt )); do
      zselect -t 20
      sandbox_pty_send 'print -r -- "__COMP=${+_comps[z4m-test-cmd]}__"'
      sandbox_pty_expect 10 '*__COMP=<->__*' || break
      [[ $REPLY == *__COMP=1__* ]] && break
    done
    [[ $REPLY == *__COMP=1__* ]] || {
      sandbox_fail "$label: completion was not initialized"
      print -ru2 -- "${(q+)REPLY[-800,-1]}"
    }
  else
    sandbox_fail "$label: shell did not reach the prompt"
    print -ru2 -- "${(q+)REPLY[-1500,-1]}"
  fi
  sandbox_pty_stop
}

# --- Compdump reuse -----------------------------------------------------------
sandbox_interactive 90 $ready LANG=en_US.UTF-8 || sandbox_fail 'installation shell did not reach the prompt'
start_shell 'first shell'
local -a dumps=($cache/zcompdump-*~*.zwc(N))
(( $#dumps == 1 )) || { sandbox_fail "expected one compdump, got: ${dumps[*]}"; exit 1 }
local -A st
zstat -H st -- $dumps[1] || exit 1
local before="$st[inode] $st[mtime]"
[[ -r $cache/direnv ]] || sandbox_fail 'direnv cache was not written'

start_shell 'second shell'
st=()
zstat -H st -- $dumps[1] 2>/dev/null
[[ "$st[inode] $st[mtime]" == $before ]] ||
  sandbox_fail 'an unchanged fpath with a non-ASCII entry rebuilt the compdump'

# --- direnv removed -----------------------------------------------------------
# The shell after removal notices that direnv is gone; every later shell must
# still initialize, which needs the stale cache gone rather than emptied.
command rm -f -- $SANDBOX/bin/direnv
local i
for i in 1 2; do
  sandbox_interactive 30 $ready LANG=en_US.UTF-8 ||
    sandbox_fail "shell $i after removing direnv did not reach the prompt"
  sandbox_reject_output "shell $i after removing direnv failed init" '*See error messages above*'
  [[ ! -e $SANDBOX_Z4M/.last-init-failed ]] ||
    sandbox_fail "shell $i after removing direnv left a failure marker"
done

sandbox_expect_offline 'startup caches'
(( SANDBOX_FAILURES == 0 ))
