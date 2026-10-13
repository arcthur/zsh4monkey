#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail

cd -- "${0:A:h:h}" || exit 1

typeset -gi failures=0
typeset test_dir
test_dir=$(mktemp -d) || exit 1
trap 'rm -rf -- "$test_dir"' EXIT

source sc/supply-chain || exit 1

assert_ok() {
  local name=$1
  shift
  if ! "$@"; then
    print -ru2 -- "expected success: $name"
    (( ++failures ))
  fi
}

assert_fail() {
  local name=$1
  shift
  if "$@"; then
    print -ru2 -- "expected failure: $name"
    (( ++failures ))
  fi
}

assert_eq() {
  local expected=$1 actual=$2 name=$3
  if [[ $actual != $expected ]]; then
    print -ru2 -- "unexpected value for $name: expected=$expected actual=$actual"
    (( ++failures ))
  fi
}

assert_ok 'locked dependency lookup' \
  _z4m_dependency_get dependencies.lock powerlevel10k
assert_eq \
  9253fb1c5034410c43a0c681ff8294181c54016c \
  "$Z4M_DEPENDENCY_REF" \
  'powerlevel10k ref'
assert_eq \
  052e0f1e4118b7a7ea9f34bfa7e5dcd42a26b4e5b007c8244b779ed600242318 \
  "$Z4M_DEPENDENCY_SHA256" \
  'powerlevel10k digest'

print -rn -- test >"$test_dir/payload"
assert_ok 'matching digest' \
  _z4m_verify_sha256 \
  "$test_dir/payload" \
  9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08
assert_fail 'tampered payload' \
  _z4m_verify_sha256 \
  "$test_dir/payload" \
  0000000000000000000000000000000000000000000000000000000000000000
assert_fail 'unknown dependency' \
  _z4m_dependency_get dependencies.lock missing

mkdir -p -- "$test_dir/archive/root" || exit 1
print -r -- safe >"$test_dir/archive/root/file"
command tar -C "$test_dir/archive" -czf "$test_dir/safe.tar.gz" root || exit 1
assert_ok 'safe archive paths' _z4m_archive_safe_p "$test_dir/safe.tar.gz"

command ln -s -- file "$test_dir/archive/root/link" || exit 1
command tar -C "$test_dir/archive" -czf "$test_dir/safe-link.tar.gz" root || exit 1
assert_ok 'contained symlink target' _z4m_archive_safe_p "$test_dir/safe-link.tar.gz"

command rm -f -- "$test_dir/archive/root/link"
command ln -s -- ../../outside "$test_dir/archive/root/link" || exit 1
command tar -C "$test_dir/archive" -czf "$test_dir/escaping-link.tar.gz" root || exit 1
assert_fail 'escaping symlink target' _z4m_archive_safe_p "$test_dir/escaping-link.tar.gz"

command rm -f -- "$test_dir/archive/root/link"
command ln -- "$test_dir/archive/root/file" "$test_dir/archive/root/hard-link" || exit 1
command tar -C "$test_dir/archive" -czf "$test_dir/hard-link.tar.gz" root || exit 1
assert_fail 'hard-link member' _z4m_archive_safe_p "$test_dir/hard-link.tar.gz"

# Hostile archives are built member by member: tar refuses to create most of
# them, which is exactly why extraction must not trust its input.
hostile_archive() {
  command python3 - "$@" <<'PY' || exit 1
import sys
import tarfile

archive_path, kind, name, target = sys.argv[1:5]
with tarfile.open(archive_path, "w:gz") as archive:
    root = tarfile.TarInfo("root")
    root.type = tarfile.DIRTYPE
    archive.addfile(root)
    member = tarfile.TarInfo(name)
    if kind == "symlink":
        member.type = tarfile.SYMTYPE
        member.linkname = target
    elif kind == "ambiguous":
        # `tar -tv` prints "owner -> injected ... root/link -> target", so a
        # parser that splits on the first arrow would read the wrong target.
        member.type = tarfile.SYMTYPE
        member.linkname = target
        member.uname = "owner -> injected"
    archive.addfile(member)
PY
}

local -a hostile=(
  'absolute member path|file|/etc/z4m-escape|'
  'parent member path|file|../escape|'
  'nested parent member path|file|root/../../escape|'
  'trailing parent member path|file|root/sub/..|'
  'absolute symlink target|symlink|root/link|/etc/passwd'
  'parent symlink target|symlink|root/link|../outside'
  'ambiguous verbose symlink metadata|ambiguous|root/link|../../outside'
)
local entry label kind name target
local -i index=0
for entry in $hostile; do
  IFS='|' read -r label kind name target <<<"$entry"
  hostile_archive "$test_dir/hostile-$(( ++index )).tar.gz" "$kind" "$name" "$target"
  assert_fail "$label" _z4m_archive_safe_p "$test_dir/hostile-$index.tar.gz"
done

hostile_archive "$test_dir/dot-segment.tar.gz" file root/./file ''
assert_ok 'current-directory segment' _z4m_archive_safe_p "$test_dir/dot-segment.tar.gz"

print -r -- 'not an archive' >"$test_dir/invalid.tar.gz"
assert_fail 'invalid archive' _z4m_archive_safe_p "$test_dir/invalid.tar.gz"

# --- Dependency lock ----------------------------------------------------------
# Every entry must be usable through the lookup the installer uses, and its URL
# must name the locked commit: a URL that tracks a branch breaks the install as
# soon as the branch moves, even though the digest still guards the content.
local lock_name lock_ref lock_sha256 lock_url
local -i lock_entries=0
while IFS='|' read -r lock_name lock_ref lock_sha256 lock_url; do
  [[ -z $lock_name || $lock_name == '#'* ]] && continue
  (( ++lock_entries ))
  if ! _z4m_dependency_get dependencies.lock "$lock_name"; then
    print -ru2 -- "unusable dependency lock entry: $lock_name"
    (( ++failures ))
  elif [[ $Z4M_DEPENDENCY_URL != *"/$Z4M_DEPENDENCY_REF"[/.]* ]]; then
    print -ru2 -- "dependency URL is not pinned to its commit: $lock_name $Z4M_DEPENDENCY_URL"
    (( ++failures ))
  fi
done <dependencies.lock
(( lock_entries )) || { print -ru2 -- 'dependency lock is empty'; (( ++failures )) }

# --- SHA-256 tool fallback ----------------------------------------------------
# Hosts differ in which tool they have; each one must yield the same digest.
local tool helper
for tool in sha256sum shasum openssl; do
  (( $+commands[$tool] )) || continue
  mkdir -p -- "$test_dir/only-$tool" || exit 1
  # shasum is a perl script on most systems.
  for helper in $tool tr perl; do
    (( $+commands[$helper] )) && ln -sf -- "$commands[$helper]" "$test_dir/only-$tool/$helper"
  done
  (
    PATH=$test_dir/only-$tool
    _z4m_sha256_file "$test_dir/payload" &&
      [[ $Z4M_SHA256 == 9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08 ]]
  ) || {
    print -ru2 -- "SHA-256 through $tool did not produce the expected digest"
    (( ++failures ))
  }
done
if ( PATH=$test_dir/no-tools; _z4m_sha256_file "$test_dir/payload" ); then
  print -ru2 -- 'SHA-256 without any tool unexpectedly succeeded'
  (( ++failures ))
fi

(( failures == 0 ))
