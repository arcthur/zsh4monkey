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

command python3 - "$test_dir/ambiguous-link.tar.gz" <<'PY' || exit 1
import sys
import tarfile

archive_path = sys.argv[1]
with tarfile.open(archive_path, "w:gz") as archive:
    link = tarfile.TarInfo("root/link")
    link.type = tarfile.SYMTYPE
    link.linkname = "../../outside"
    link.uname = "owner -> injected"
    link.gname = "group"
    archive.addfile(link)
PY
assert_fail 'ambiguous verbose symlink metadata' \
  _z4m_archive_safe_p "$test_dir/ambiguous-link.tar.gz"

print -r -- 'not an archive' >"$test_dir/invalid.tar.gz"
assert_fail 'invalid archive' _z4m_archive_safe_p "$test_dir/invalid.tar.gz"

for parser in sc/supply-chain z4m.zsh; do
  if ! command grep -Fq 'if (index(target, marker))' "$parser"; then
    print -ru2 -- "archive parser does not reject ambiguous symlink metadata: $parser"
    (( ++failures ))
  fi
done

if rg -n --color=never \
    'archive/(master|main)\\.tar\\.gz|raw\\.githubusercontent\\.com/[^/]*/[^/]*/(master|main)/' \
    fn/-z4m-install-one sc/exec-zsh-i >/dev/null; then
  print -ru2 -- 'mutable built-in dependency URL remains'
  (( ++failures ))
fi

if ! command grep -Eq \
    'builtin_pkgs=.*powerlevel10k.*tmux' \
    main.zsh; then
  print -ru2 -- 'documented built-in packages are rejected by the install command'
  (( ++failures ))
fi

(( failures == 0 ))
