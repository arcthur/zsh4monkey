#!/usr/bin/env zsh
#
# `mise activate zsh` spawns `mise hook-env` before every prompt. z4m keeps
# mise's _mise_hook but runs it only when what hook-env reads changes. A fake
# mise with the same hook structure records every hook-env call.

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

local repository=${0:A:h:h}
source $repository/test/lib/sandbox.zsh || exit 1
sandbox_setup $repository || exit 1
trap sandbox_cleanup EXIT HUP INT TERM

# The path must not contain "mise": any such command line forces a refresh.
local log=$SANDBOX/hooks.log
{
  print -r -- '#!/bin/sh'
  print -r -- "log='$log'"
  print -r -- 'case $1 in'
  print -r -- '  activate) cat <<'"'"'EOF'"'"''
  print -r -- 'export MISE_SHELL=zsh'
  print -r -- '_mise_hook() { eval "$(command mise hook-env -s zsh "$@")"; }'
  # Like mise, skip the first prompt when PATH is unchanged since activation.
  print -r -- '_mise_hook_precmd() {'
  print -r -- '  if [[ $PATH == "${__MISE_ZSH_ACTIVATE_PATH-}" ]]; then unset __MISE_ZSH_ACTIVATE_PATH; return; fi'
  print -r -- '  _mise_hook --reason precmd'
  print -r -- '}'
  print -r -- '_mise_hook_chpwd() { _mise_hook --reason chpwd; }'
  print -r -- 'autoload -Uz add-zsh-hook'
  print -r -- 'add-zsh-hook precmd _mise_hook_precmd'
  print -r -- 'add-zsh-hook chpwd _mise_hook_chpwd'
  print -r -- '_mise_hook --force'
  print -r -- 'export __MISE_ZSH_ACTIVATE_PATH="$PATH"'
  print -r -- 'EOF'
  print -r -- '  ;;'
  print -r -- '  hook-env) echo "$*" >>"$log"; echo "export FAKE_MISE_DIR=\"$PWD\"" ;;'
  print -r -- '  *) echo "cmd $*" >>"$log" ;;'
  print -r -- 'esac'
} >$SANDBOX/bin/mise
command chmod 755 -- $SANDBOX/bin/mise || exit 1
command mkdir -p -- $SANDBOX_HOME/project/sub || exit 1

# Prints the number of hook-env calls from inside the shell, so the prompt that
# precedes the command has already run its hooks. A short command line keeps
# the count from depending on how ZLE wraps a long one.
local zshrc_calls="calls() { local -a l=(\${(f)\"\$(<$log)\"}); print -r -- __CALLS__\${#\${(M)l:#hook-env*}}__ }"

# Usage: expect_calls <label> <count>
expect_calls() {
  sandbox_pty_send calls
  sandbox_pty_expect 20 "*__CALLS__${2}__*" && return
  sandbox_fail "$1: expected $2 hook-env calls"
  print -ru2 -- "--- $log ---"
  print -ru2 -- "$(<$log)"
}

# Usage: run <command>
run() {
  sandbox_pty_send "$1"
  sandbox_pty_send 'print -r -- __DO""NE__'
  sandbox_pty_expect 20 '*__DONE__*' || sandbox_fail "no prompt after: $1"
}

sandbox_write_zshrc 'eval "$(mise activate zsh)"' $zshrc_calls
sandbox_pty_start || exit 1
sandbox_pty_expect 60 "*$SANDBOX_READY*" || { sandbox_fail 'shell did not reach the prompt'; exit 1 }

# Activation ran hook-env once; the first prompts reuse it.
expect_calls 'activation only' 1
run 'true'
expect_calls 'unchanged prompts' 1

run 'touch ~/project/mise.toml'
expect_calls 'new config file' 2
run 'touch ~/project/mise.toml'
expect_calls 'config edited within the same second' 3

run 'cd ~/project/sub'
# chpwd and the following precmd see the same state: one call.
expect_calls 'directory change' 4
run '[[ $FAKE_MISE_DIR == ~/project/sub ]] && print -r -- __ENV_O""K__'
[[ $REPLY == *__ENV_OK__* ]] || sandbox_fail 'hook-env output not applied after cd'

run 'export MISE_ENV=dev'
expect_calls 'MISE_ variable changed' 5
run 'mise trust'
expect_calls 'mise command line' 6
run 'PATH=/nonexistent:$PATH'
expect_calls 'PATH changed' 7
run 'true'
expect_calls 'stable again' 7

sandbox_pty_stop

# Opting out leaves mise's own hooks in place: every prompt calls hook-env.
: >$log
SANDBOX_PRE_INIT=("zstyle ':z4m:mise' fast-hook no")
sandbox_write_zshrc 'eval "$(mise activate zsh)"' $zshrc_calls
sandbox_pty_start || exit 1
sandbox_pty_expect 60 "*$SANDBOX_READY*" || { sandbox_fail 'opt-out shell did not reach the prompt'; exit 1 }
run 'true'
run 'true'
sandbox_pty_send calls
sandbox_pty_expect 20 '*__CALLS__<4->__*' || sandbox_fail 'fast-hook no: mise hook should run every prompt'
sandbox_pty_stop

sandbox_expect_offline 'mise hook'
(( SANDBOX_FAILURES == 0 )) && print -r -- 'mise_hook: ok'
(( SANDBOX_FAILURES == 0 ))
