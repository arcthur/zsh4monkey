#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail -o typeset_silent

local repository_root=${0:A:h:h}
local temporary_directory
temporary_directory=$(mktemp -d)
trap 'rm -rf -- "$temporary_directory"' EXIT HUP INT TERM

typeset -g Z4M=$temporary_directory/z4m
mkdir -p -- "$Z4M/zsh4monkey/sc" "$temporary_directory/source" "$temporary_directory/bin"
cp -- "$repository_root/sc/supply-chain" "$Z4M/zsh4monkey/sc/supply-chain"
cp -- "$repository_root/dependencies.lock" "$Z4M/zsh4monkey/dependencies.lock"

function zf_mkdir() {
  command mkdir "$@"
}

function zf_rm() {
  command rm "$@"
}

function -z4m-mv() {
  command mv "$@"
}

local ref=0123456789abcdef0123456789abcdef01234567
local source_directory=$temporary_directory/source/project-$ref
mkdir -p -- "$source_directory"
print -r -- verified >"$source_directory/payload"
command tar -C "$temporary_directory/source" -czf "$temporary_directory/plugin.tar.gz" \
  "project-$ref"

cat >"$temporary_directory/bin/curl" <<'SH'
#!/bin/sh
command cat -- "$Z4M_TEST_ARCHIVE"
SH
chmod 755 "$temporary_directory/bin/curl"

typeset -gx Z4M_TEST_ARCHIVE=$temporary_directory/plugin.tar.gz
typeset saved_path=$PATH
PATH=$temporary_directory/bin:$PATH
hash -r

source "$Z4M/zsh4monkey/sc/supply-chain"
_z4m_sha256_file "$Z4M_TEST_ARCHIVE" || exit 1
local digest=$Z4M_SHA256
zstyle ':z4m:owner/project' sha256 "$digest"

source "$repository_root/fn/-z4m-install-one" "owner/project@$ref" || exit 1
if [[ $(<"$Z4M/owner/project/payload") != verified ]]; then
  print -ru2 -- 'verified dependency was not installed'
  exit 1
fi

zstyle ':z4m:owner/project' sha256 \
  0000000000000000000000000000000000000000000000000000000000000000
if source "$repository_root/fn/-z4m-install-one" "owner/project@$ref" 2>/dev/null; then
  print -ru2 -- 'tampered dependency unexpectedly installed'
  exit 1
fi
if [[ $(<"$Z4M/owner/project/payload") != verified ]]; then
  print -ru2 -- 'failed dependency verification replaced the installed target'
  exit 1
fi

zstyle -d ':z4m:security' allow-unverified-downloads
zstyle -d ':z4m:owner/project' sha256
if source "$repository_root/fn/-z4m-install-one" 'unlocked/project' 2>/dev/null; then
  print -ru2 -- 'unset security opt-in allowed a mutable dependency'
  exit 1
fi
if source "$repository_root/fn/-z4m-install-one" "owner/project@$ref" 2>/dev/null; then
  print -ru2 -- 'unset security opt-in allowed a dependency without SHA-256'
  exit 1
fi

zstyle ':z4m:security' allow-unverified-downloads yes
source "$repository_root/fn/-z4m-install-one" 'owner/project@master' 2>/dev/null || exit 1
if [[ $(<"$Z4M/owner/project/payload") != verified ]]; then
  print -ru2 -- 'explicit compatibility opt-in did not install a legacy ref'
  exit 1
fi
if source "$repository_root/fn/-z4m-install-one" 'owner/project@../main' 2>/dev/null; then
  print -ru2 -- 'unsafe compatibility ref unexpectedly succeeded'
  exit 1
fi
zstyle -d ':z4m:security' allow-unverified-downloads

if source "$repository_root/fn/-z4m-install-one" "owner/../../escaped@$ref" 2>/dev/null; then
  print -ru2 -- 'unsafe repository path unexpectedly succeeded'
  exit 1
fi
if source "$repository_root/fn/-z4m-install-one" "../escaped@$ref" 2>/dev/null; then
  print -ru2 -- 'dot-segment repository owner unexpectedly succeeded'
  exit 1
fi
if [[ -e $temporary_directory/escaped ]]; then
  print -ru2 -- 'unsafe repository path escaped the cache root'
  exit 1
fi

mkdir -p -- "$temporary_directory/outside"
command ln -s -- "$temporary_directory/outside" "$Z4M/escape"
if source "$repository_root/fn/-z4m-install-one" "escape/project@$ref" 2>/dev/null; then
  print -ru2 -- 'symlinked repository owner unexpectedly escaped the cache root'
  exit 1
fi
if [[ -e $temporary_directory/outside/project ]]; then
  print -ru2 -- 'symlinked repository owner wrote outside the cache root'
  exit 1
fi

zstyle ':z4m:owner/project' sha256 "$digest"
typeset -gi activation_failure_pending=1
function -z4m-mv() {
  if (( activation_failure_pending )) &&
     [[ $1 == */project && $2 == $Z4M/owner/project ]]; then
    activation_failure_pending=0
    return 1
  fi
  command mv "$@"
}
if source "$repository_root/fn/-z4m-install-one" "owner/project@$ref" 2>/dev/null; then
  print -ru2 -- 'injected dependency activation failure unexpectedly succeeded'
  exit 1
fi
if [[ $(<"$Z4M/owner/project/payload") != verified ]]; then
  print -ru2 -- 'dependency activation failure did not restore the installed target'
  exit 1
fi
function -z4m-mv() {
  command mv "$@"
}

typeset -g Z4M_UPDATING=$temporary_directory/old
mkdir -p -- "$Z4M_UPDATING/legacy/repo"
print -r -- preserved >"$Z4M_UPDATING/legacy/repo/payload"
source "$repository_root/fn/-z4m-install-one" 'legacy/repo@master' 2>/dev/null || exit 1
if [[ $(<"$Z4M/legacy/repo/payload") != preserved ]]; then
  print -ru2 -- 'legacy unpinned dependency was not preserved during update'
  exit 1
fi
unset Z4M_UPDATING

PATH=$saved_path
hash -r
