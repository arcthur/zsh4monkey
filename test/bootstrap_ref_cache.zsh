#!/usr/bin/env zsh

emulate -L zsh -o err_return -o no_unset -o pipe_fail

local repository=${0:A:h:h}
local temporary_directory
temporary_directory=$(mktemp -d)
trap 'rm -rf -- "$temporary_directory"' EXIT HUP INT TERM

local cache=$temporary_directory/cache
mkdir -p -- $cache/zsh4monkey
print -r -- v1.0.0 >$cache/zsh4monkey/.z4m-source-ref
print -r -- 'typeset -g Z4M_CACHE_TEST=hit' >$cache/zsh4monkey/main.zsh

local output
output=$(
  HOME=$temporary_directory \
  ZDOTDIR=$temporary_directory \
  Z4M=$cache \
  Z4M_BOOTSTRAP_COMMAND='exit 1' \
  Z4M_URL=https://raw.githubusercontent.com/arcthur/zsh4monkey/v1.0.0 \
    zsh -dfc 'source "$1"; print -r -- "$Z4M_CACHE_TEST"' _ "$repository/z4m.zsh"
)

[[ $output == hit ]]

print -r -- v2.0.0 >$cache/zsh4monkey/.z4m-source-ref
print -r -- \
  'https://raw.githubusercontent.com/arcthur/zsh4monkey/v1.0.0|https://raw.githubusercontent.com/arcthur/zsh4monkey/v2.0.0' \
  >$cache/zsh4monkey/.z4m-update-source
output=$(
  HOME=$temporary_directory \
  ZDOTDIR=$temporary_directory \
  Z4M=$cache \
  Z4M_BOOTSTRAP_COMMAND='exit 1' \
  Z4M_URL=https://raw.githubusercontent.com/arcthur/zsh4monkey/v1.0.0 \
    zsh -dfc 'source "$1"; print -r -- "$Z4M_URL:$Z4M_CACHE_TEST"' _ "$repository/z4m.zsh"
)

[[ $output == https://raw.githubusercontent.com/arcthur/zsh4monkey/v2.0.0:hit ]]

print -r -- v3.0.0 >$cache/zsh4monkey/.z4m-source-ref
output=$(
  HOME=$temporary_directory \
  ZDOTDIR=$temporary_directory \
  Z4M=$cache \
  Z4M_BOOTSTRAP_COMMAND='exit 1' \
  Z4M_URL=https://raw.githubusercontent.com/arcthur/zsh4monkey/v1.0.0 \
  Z4M_UPDATE_SOURCE_URL=https://raw.githubusercontent.com/arcthur/zsh4monkey/v3.0.0 \
    zsh -dfc 'source "$1"; print -r -- "$Z4M_URL:$Z4M_CACHE_TEST"' _ "$repository/z4m.zsh"
)

[[ $output == https://raw.githubusercontent.com/arcthur/zsh4monkey/v3.0.0:hit ]]
