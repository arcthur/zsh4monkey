#!/usr/bin/env zsh
#
# Drive real interactive shells through the whole startup lifecycle: first-run
# bootstrap, steady state, an initialization failure, the safe-mode startup it
# must trigger, recovery once the cause is fixed, and the recovery shell for a
# framework that cannot even be sourced.

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

local repository=${0:A:h:h}
source $repository/test/lib/sandbox.zsh || exit 1
sandbox_setup $repository || exit 1
trap sandbox_cleanup EXIT HUP INT TERM

local ready="*$SANDBOX_READY*"
local init_done='*__Z4M_INIT_STATUS__=<->*'
local framework

# --- First run ----------------------------------------------------------------
# The first shell installs the framework and its packages, then must come up
# fully initialized: the readiness marker is printed by the first precmd that
# ZLE initialization installs.
sandbox_interactive 90 $ready ||
  sandbox_fail 'first shell after installation did not reach a fully initialized prompt'
sandbox_expect_output 'first run did not bootstrap the framework' '*installing*zsh4monkey*'
sandbox_expect_output 'first run reported a failed init' '*__Z4M_INIT_STATUS__=0*'
sandbox_reject_output 'first run printed an init failure' '*See error messages above*'
[[ -L $SANDBOX_Z4M/current ]] || sandbox_fail 'first run did not activate a version'
[[ ! -e $SANDBOX_Z4M/.last-init-failed ]] || sandbox_fail 'first run left a failure marker'
sandbox_framework; framework=$REPLY
[[ -r $framework/fn/-z4m-compinit-impl ]] ||
  sandbox_fail 'first run did not generate the patched compinit'

# --- Steady state -------------------------------------------------------------
sandbox_interactive 30 $ready || sandbox_fail 'steady-state shell did not reach the prompt'
sandbox_reject_output 'steady-state shell reinstalled something' '*(installing|initializing)*'
sandbox_reject_output 'steady-state shell entered safe mode' '*Safe Mode*'
# The sandbox runs without a prompt theme; the bootstrap's fallback prompt must
# not survive a successful initialization. The readiness marker is printed
# before the first prompt is drawn, so ask the shell instead of reading output.
sandbox_pty_start || exit 1
if sandbox_pty_expect 30 $ready; then
  sandbox_pty_send 'print -r -- "__RP""S1__=[$RPS1]"'
  sandbox_pty_expect 20 "*${(b):-__RPS1__=[]}*" ||
    sandbox_fail "initialized shell kept the bootstrap fallback prompt: ${(q+)REPLY[-300,-1]}"
  # The sandbox's zsh on PATH is a symlink to the running binary, as with
  # Homebrew and Nix; child shells must not be routed through the zb wrapper.
  sandbox_pty_send 'print -r -- "__Z""B__=[${path[(Ie)$Z4M/zsh4monkey/zb]}|${+_Z4M_EXE}]"'
  sandbox_pty_expect 20 "*${(b):-__ZB__=[0|0]}*" ||
    sandbox_fail "symlinked zsh on PATH is routed through the zb wrapper: ${(q+)REPLY[-300,-1]}"
  # AI suggestions are off by default; their lane is not even loaded then.
  sandbox_pty_send 'print -r -- "__A""I__=[${+functions[-z4m-autosuggest-ai-ensure]}]"'
  sandbox_pty_expect 20 "*${(b):-__AI__=[0]}*" ||
    sandbox_fail "disabled AI lane was loaded at startup: ${(q+)REPLY[-300,-1]}"
else
  sandbox_fail 'steady-state shell did not reach the prompt for the prompt check'
fi
sandbox_pty_stop

# --- Lost runtime state -------------------------------------------------------
# Caches get cleaned behind z4m's back. Missing packages and a missing tmp/ must
# be recreated on the next start rather than fail it.
command rm -rf -- $SANDBOX_Z4M/tmp $SANDBOX_Z4M/fzf $SANDBOX_Z4M/terminfo || exit 1
sandbox_interactive 60 $ready || sandbox_fail 'startup did not recover lost runtime directories'
sandbox_reject_output 'recovering runtime directories failed init' '*See error messages above*'
[[ -d $SANDBOX_Z4M/fzf && -d $SANDBOX_Z4M/terminfo ]] ||
  sandbox_fail 'lost packages were not reinstalled'

# --- Command surface ----------------------------------------------------------
# Every documented built-in package is accepted by name; anything else needs an
# owner/repository form.
sandbox_command 'z4m install eza bat fd rg zoxide fzf carapace atuin powerlevel10k tmux owner/repo &&
  print -r -- __ACCEPTED__; z4m install not-a-package || print -r -- __REJECTED__'
sandbox_expect_output 'documented built-in packages were rejected' '*__ACCEPTED__*'
sandbox_expect_output 'unknown package name was accepted' '*invalid project name*__REJECTED__*'

# --- Initialization failure ---------------------------------------------------
# A framework step that fails must surface as a failed `z4m init`, leave a
# marker with the failing step, and must not pretend the shell is ready.
local init_zle=$framework/fn/-z4m-init-zle
command cp -p -- $init_zle $SANDBOX/init-zle.orig || exit 1
command rm -f -- $init_zle.zwc
print -r -- 'return 7' >$init_zle

sandbox_interactive 30 $init_done
sandbox_expect_output 'failing init step did not fail z4m init' '*__Z4M_INIT_STATUS__=[1-9]*'
sandbox_expect_output 'failing init did not explain itself' '*See error messages above*'
sandbox_reject_output 'failing init still reached a ready prompt' $ready
if [[ -r $SANDBOX_Z4M/.last-init-failed ]]; then
  local marker=$(<$SANDBOX_Z4M/.last-init-failed)
  [[ $marker == *fail_step=init-zle* && $marker == *fail_step_rc=7* ]] ||
    sandbox_fail "failure marker does not record the failing step: ${(q+)marker}"
else
  sandbox_fail 'failing init did not write a failure marker'
fi

# --- Safe mode after a failure ------------------------------------------------
# The next startup must not repeat the failing initialization. Entering safe
# mode consumes the marker but keeps the log for diagnosis.
sandbox_interactive 30 $init_done
sandbox_expect_output 'startup after a failure did not enter safe mode' '*=== z4m Safe Mode ===*'
sandbox_expect_output 'safe mode did not point at the failure log' '*Last failure log:*'
sandbox_reject_output 'safe mode still ran the failing initialization' '*See error messages above*'
[[ ! -e $SANDBOX_Z4M/.last-init-failed ]] || sandbox_fail 'safe mode did not consume the marker'
[[ -r $SANDBOX_Z4M/cache/last-init-failed.log ]] || sandbox_fail 'safe mode discarded the failure log'

# --- Recovery once fixed ------------------------------------------------------
command cp -p -- $SANDBOX/init-zle.orig $init_zle || exit 1
sandbox_interactive 30 $ready || sandbox_fail 'repaired framework did not reach the prompt'
sandbox_reject_output 'repaired framework stayed in safe mode' '*Safe Mode*'
[[ ! -e $SANDBOX_Z4M/cache/last-init-failed.log ]] ||
  sandbox_fail 'successful init did not clear the stale failure log'

# --- Explicit safe mode -------------------------------------------------------
sandbox_interactive 30 $init_done Z4M_SAFE_MODE=1
sandbox_expect_output 'Z4M_SAFE_MODE=1 did not enter safe mode' '*=== z4m Safe Mode ===*'
: >$SANDBOX_Z4M/.safe-mode
sandbox_interactive 30 $init_done
sandbox_expect_output 'persistent .safe-mode did not enter safe mode' '*=== z4m Safe Mode ===*'
command rm -f -- $SANDBOX_Z4M/.safe-mode

# --- Unloadable framework -----------------------------------------------------
# When main.zsh itself cannot be sourced, the bootstrap has nothing to recover
# with but must still hand over a working shell and record the failure.
local main=$framework/main.zsh
command cp -p -- $main $SANDBOX/main.orig || exit 1
command rm -f -- $main.zwc
print -r -- 'return 1' >$main

sandbox_interactive 30 '*z4m-recovery-help*'
sandbox_expect_output 'unloadable framework did not enter the recovery shell' '*recovery shell*'
[[ -e $SANDBOX_Z4M/.last-init-failed ]] ||
  sandbox_fail 'unloadable framework did not write a failure marker'

command cp -p -- $SANDBOX/main.orig $main || exit 1
sandbox_interactive 30 $init_done
sandbox_expect_output 'startup after a bootstrap failure did not enter safe mode' \
  '*=== z4m Safe Mode ===*'
sandbox_interactive 30 $ready || sandbox_fail 'cache did not recover after the bootstrap failure'

sandbox_expect_offline 'startup lifecycle'
(( SANDBOX_FAILURES == 0 ))
