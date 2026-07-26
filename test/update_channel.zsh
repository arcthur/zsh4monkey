#!/usr/bin/env zsh

emulate -L zsh -o no_aliases

cd -- "${0:A:h:h}" || exit 1

typeset -gi failures=0
typeset test_dir
test_dir=$(mktemp -d) || exit 1
trap 'rm -rf -- "$test_dir"' EXIT

source fn/-z4m-resolve-update-url || exit 1

assert_eq() {
  local expected=$1 actual=$2 name=$3
  if [[ $actual != $expected ]]; then
    print -ru2 -- "unexpected value for $name: expected=$expected actual=$actual"
    (( ++failures ))
  fi
}

Z4M_URL=https://raw.githubusercontent.com/arcthur/zsh4monkey/main
zstyle -d :z4m:update channel
source fn/-z4m-resolve-update-url || exit 1
assert_eq "$Z4M_URL" "$REPLY" 'development default'

Z4M_URL=https://raw.githubusercontent.com/arcthur/zsh4monkey/v1.0.0.1
zstyle ':z4m:update' channel pinned
source fn/-z4m-resolve-update-url || exit 1
assert_eq "$Z4M_URL" "$REPLY" 'pinned channel'

cat >"$test_dir/curl" <<'SH'
#!/bin/sh
printf '%s\n' '{"tag_name":"v2.3.4"}'
SH
chmod 755 "$test_dir/curl" || exit 1
typeset saved_path=$PATH
PATH=$test_dir:$PATH
hash -r
Z4M_URL=https://raw.githubusercontent.com/arcthur/zsh4monkey/v1.0.0.1
zstyle -d :z4m:update channel
source fn/-z4m-resolve-update-url || exit 1
assert_eq \
  https://raw.githubusercontent.com/arcthur/zsh4monkey/v2.3.4 \
  "$REPLY" \
  'stable default'

zstyle ':z4m:update' channel stable
source fn/-z4m-resolve-update-url || exit 1
assert_eq \
  https://raw.githubusercontent.com/arcthur/zsh4monkey/v2.3.4 \
  "$REPLY" \
  'stable channel'

# Resolution must take the first tag field. A greedy match would take the last
# one and silently resolve to the oldest entry of an array-shaped response.
cat >"$test_dir/curl" <<'SH'
#!/bin/sh
printf '%s\n' '[{"tag_name": "v2.3.4"},{"tag_name":"v0.9.0"}]'
SH
chmod 755 "$test_dir/curl" || exit 1
source fn/-z4m-resolve-update-url || exit 1
assert_eq \
  https://raw.githubusercontent.com/arcthur/zsh4monkey/v2.3.4 \
  "$REPLY" \
  'leftmost tag field'

cat >"$test_dir/curl" <<'SH'
#!/bin/sh
printf '%s\n' '{"message":"API rate limit exceeded"}'
SH
chmod 755 "$test_dir/curl" || exit 1
if source fn/-z4m-resolve-update-url 2>/dev/null; then
  print -ru2 -- 'stable channel unexpectedly accepted a response without a tag'
  (( ++failures ))
fi

PATH=$saved_path
hash -r

Z4M=$test_dir/cache
mkdir -p -- "$Z4M/zsh4monkey"
print -r -- 300000000 >"$Z4M/zsh4monkey/version"
if source fn/-z4m-resolve-update-url 2>/dev/null; then
  print -ru2 -- 'stable channel unexpectedly allowed a release downgrade'
  (( ++failures ))
fi
unset Z4M

zstyle ':z4m:update' channel invalid
if source fn/-z4m-resolve-update-url 2>/dev/null; then
  print -ru2 -- 'invalid update channel unexpectedly succeeded'
  (( ++failures ))
fi

if ! command grep -Fq \
    'mutable development target; run %Bz4m update%b to refresh' \
    fn/-z4m-cmd-version; then
  print -ru2 -- 'version check treats mutable main as an immutable installed ref'
  (( ++failures ))
fi

zstyle -d :z4m:update channel
(( failures == 0 ))
