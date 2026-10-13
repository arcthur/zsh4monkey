#!/usr/bin/env zsh

emulate -L zsh -o err_return -o no_unset -o no_aliases -o pipe_fail

local repository=${0:A:h:h}
fpath=("$repository/fn" $fpath)
autoload -Uz -- -z4m-benchmark-precmd

typeset -g Z4M_BENCHMARK_MARKER=ready-marker
typeset -ga precmd_functions=(before -z4m-benchmark-precmd after)
local output_file
output_file=$(mktemp)
trap 'rm -f -- "$output_file"' EXIT HUP INT TERM

-z4m-benchmark-precmd >"$output_file"

[[ $(<"$output_file") == ready-marker ]]
(( ! ${+Z4M_BENCHMARK_MARKER} ))
[[ ${precmd_functions[*]} == 'before after' ]]
