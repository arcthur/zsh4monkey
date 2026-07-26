#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail

local repository=${0:A:h:h}
local temporary_directory
temporary_directory=$(mktemp -d)
trap 'rm -rf -- "$temporary_directory"' EXIT HUP INT TERM

local trusted=$temporary_directory/trusted-z4m.zsh
local tampered=$temporary_directory/tampered-z4m.zsh
print -r -- 'typeset -g Z4M_BOOTSTRAP_TEST=trusted' >"$trusted"
print -r -- 'typeset -g Z4M_BOOTSTRAP_TEST=tampered' >"$tampered"

source "$repository/sc/supply-chain"
_z4m_sha256_file "$trusted" || exit 1
local digest=$Z4M_SHA256

local zshenv=$temporary_directory/release.zshenv
command sed \
  -e 's|^: "${Z4M_URL:=.*}"$|: "${Z4M_URL:=https://raw.githubusercontent.com/arcthur/zsh4monkey/v1.0.0}"|' \
  -e "s|^Z4M_BOOTSTRAP_SHA256=.*$|Z4M_BOOTSTRAP_SHA256='$digest'|" \
  "$repository/.zshenv" >"$zshenv"

mkdir -p -- "$temporary_directory/bin"
cat >"$temporary_directory/bin/curl" <<'SH'
#!/bin/sh
command cat -- "$Z4M_TEST_BOOTSTRAP"
SH
chmod 755 "$temporary_directory/bin/curl"

local output
output=$(
  HOME=$temporary_directory \
  ZDOTDIR=$temporary_directory \
  XDG_CACHE_HOME=$temporary_directory/cache \
  PATH=$temporary_directory/bin:$PATH \
  Z4M_TEST_BOOTSTRAP=$trusted \
    zsh -dfc 'Z4M_BOOTSTRAPPING=1; source "$1"; print -r -- "$Z4M_BOOTSTRAP_TEST"' \
      _ "$zshenv"
) || exit 1
[[ $output == trusted ]] || exit 1

command rm -rf -- "$temporary_directory/cache"
if HOME=$temporary_directory \
    ZDOTDIR=$temporary_directory \
    XDG_CACHE_HOME=$temporary_directory/cache \
    PATH=$temporary_directory/bin:$PATH \
    Z4M_TEST_BOOTSTRAP=$tampered \
      zsh -dfc 'Z4M_BOOTSTRAPPING=1; source "$1"' _ "$zshenv" 2>/dev/null; then
  print -ru2 -- 'tampered bootstrap unexpectedly passed verification'
  exit 1
fi

[[ ! -e $temporary_directory/cache/zsh4monkey/z4m.zsh ]]
