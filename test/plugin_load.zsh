#!/usr/bin/env zsh
#
# `z4m load` must find the entry point plugins actually ship, keep plugins that
# only provide functions working, and report every plugin it cannot load
# instead of returning success having loaded nothing.

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

local repository=${0:A:h:h}
source $repository/test/lib/sandbox.zsh || exit 1
sandbox_setup $repository || exit 1
trap sandbox_cleanup EXIT HUP INT TERM

local plugins=$SANDBOX_Z4M/owner
local external=$SANDBOX/external-plugin

# Usage: plugin <dir> <file> [content]
plugin() {
  command mkdir -p -- ${2:h} || exit 1
  print -r -- "${3:-typeset -g LOADED_${${1:t}//-/_}=${2:t}}" >$2 || exit 1
}

# Both conventional files: init.zsh wins.
plugin both $plugins/both/init.zsh
plugin both $plugins/both/both.plugin.zsh 'typeset -g LOADED_both=wrong'
# Named after the directory.
plugin named $plugins/named/named.plugin.zsh
# The zsh-auto-notify layout: zsh-notify/notify.plugin.zsh.
plugin zsh-notify $plugins/zsh-notify/notify.plugin.zsh
# Absolute path outside $Z4M.
plugin external-plugin $external/external-plugin.plugin.zsh
# Functions only: autoloaded, nothing to source.
plugin fn-only $plugins/fn-only/functions/fn-only-hello 'print -r -- hello-from-function'
# Completions only: the directory joins fpath.
plugin comp-only $plugins/comp-only/_comp-only '#compdef comp-only'
# Two candidates and none named after the directory: no guessing.
plugin ambiguous $plugins/ambiguous/one.plugin.zsh 'typeset -g LOADED_ambiguous=one'
plugin ambiguous $plugins/ambiguous/two.plugin.zsh 'typeset -g LOADED_ambiguous=two'
# Nothing usable.
command mkdir -p -- $plugins/empty $plugins/docs-only || exit 1
print -r -- readme >$plugins/docs-only/README.md
# An empty entry point does not count.
command mkdir -p -- $plugins/hollow || exit 1
: >$plugins/hollow/hollow.plugin.zsh

# Usage: load_status <label> <load arguments...>
# Prints "<label>=<status>" so each call can be checked on its own.
local script='
load_status() { local label=$1; shift; z4m load "$@"; print -r -- "__${label}__=$?" }
load_status both owner/both
load_status named owner/named
load_status notify owner/zsh-notify
load_status external '${(q)external}'
load_status fnonly owner/fn-only
load_status componly owner/comp-only
load_status ambiguous owner/ambiguous
load_status empty owner/empty
load_status docs owner/docs-only
load_status hollow owner/hollow
load_status missing owner/missing
load_status mixed owner/missing owner/named
load_status compiled --compile owner/named
print -r -- "__VALUES__=[${LOADED_both-}|${LOADED_named-}|${LOADED_zsh_notify-}|${LOADED_external_plugin-}|${LOADED_ambiguous-}]"
print -r -- "__FUNCTION__=[$(fn-only-hello 2>&1)]"
print -r -- "__FPATH__=[${fpath[(I)*/owner/comp-only]}]"
'
sandbox_command $script

expect_status() {
  local label=$1 expected=$2
  [[ $REPLY == *"__${label}__=$expected"* ]] && return
  local actual=${${REPLY#*__${label}__=}%%[^0-9]*}
  sandbox_fail "z4m load $label: expected status $expected, got ${actual:-none}"
}

expect_status both 0
expect_status named 0
expect_status notify 0
expect_status external 0
expect_status fnonly 0
expect_status componly 0
expect_status compiled 0
expect_status ambiguous 1
expect_status empty 1
expect_status docs 1
expect_status hollow 1
expect_status missing 1
expect_status mixed 1

sandbox_expect_output 'loaded the wrong entry points' \
  "*${(b):-__VALUES__=[init.zsh|named.plugin.zsh|notify.plugin.zsh|external-plugin.plugin.zsh|]}*"
sandbox_expect_output 'functions-only plugin was not autoloaded' '*__FUNCTION__=\[hello-from-function\]*'
sandbox_expect_output 'completions-only plugin did not join fpath' '*__FPATH__=\[[1-9]*'

sandbox_expect_output 'ambiguous entry point was not explained' \
  '*ambiguous entry point in*/owner/ambiguous: one.plugin.zsh, two.plugin.zsh*z4m source*'
sandbox_expect_output 'empty plugin directory was not reported' '*nothing to load in*/owner/empty*'
sandbox_expect_output 'missing plugin directory was not reported' '*no such plugin directory:*/owner/missing*'
sandbox_reject_output 'functions-only plugin was reported' '*nothing to load in*/owner/fn-only*'
sandbox_reject_output 'completions-only plugin was reported' '*nothing to load in*/owner/comp-only*'

[[ -e $plugins/named/named.plugin.zsh.zwc ]] ||
  sandbox_fail 'z4m load --compile did not compile the entry point'

sandbox_expect_offline 'plugin loading'
(( SANDBOX_FAILURES == 0 ))
