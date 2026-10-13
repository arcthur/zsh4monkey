#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o extended_glob

cd -- "${0:A:h:h}" || exit 1

typeset -gi failures=0
typeset test_dir
test_dir=$(mktemp -d) || exit 1
trap 'rm -rf -- "$test_dir"' EXIT

fpath=($PWD/fn $fpath)
autoload -Uz -- -z4m-resolve-update-url -z4m-cmd-version -z4m-read-version

assert_eq() {
  local expected=$1 actual=$2 name=$3
  if [[ $actual != $expected ]]; then
    print -ru2 -- "unexpected value for $name: expected=$expected actual=$actual"
    (( ++failures ))
  fi
}

assert_resolve_fails() {
  local name=$1 message=$2 output
  if output=$(-z4m-resolve-update-url 2>&1); then
    print -ru2 -- "expected resolution to fail: $name"
    (( ++failures ))
  elif [[ $output != *$message* ]]; then
    print -ru2 -- "$name failed for the wrong reason: $output"
    (( ++failures ))
  fi
}

# Every case below runs offline. The stable channel talks to the release API
# through this stub, which answers with whatever the case put in $api_response.
mkdir -p -- "$test_dir/bin" "$test_dir/cache/zsh4monkey" || exit 1
cat >"$test_dir/bin/curl" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$Z4M_TEST_CURL_LOG"
cat -- "$Z4M_TEST_API_RESPONSE"
SH
chmod 755 "$test_dir/bin/curl" || exit 1
path=("$test_dir/bin" $path)
hash -r
export Z4M_TEST_API_RESPONSE=$test_dir/api-response Z4M_TEST_CURL_LOG=$test_dir/curl.log
respond() { print -r -- "$1" >$Z4M_TEST_API_RESPONSE }

Z4M=$test_dir/cache
installed() { print -r -- "$1" >$Z4M/zsh4monkey/version }
installed 100000001

typeset -r main_url=https://raw.githubusercontent.com/arcthur/zsh4monkey/main
typeset -r release_url=https://raw.githubusercontent.com/arcthur/zsh4monkey/v1.0.0.1

# --- Channel selection --------------------------------------------------------
Z4M_URL=$main_url
zstyle -d :z4m:update channel
-z4m-resolve-update-url || (( ++failures ))
assert_eq "$main_url" "$REPLY" 'development default'

Z4M_URL=$release_url
zstyle ':z4m:update' channel pinned
-z4m-resolve-update-url || (( ++failures ))
assert_eq "$release_url" "$REPLY" 'pinned channel'

zstyle ':z4m:update' channel development
-z4m-resolve-update-url || (( ++failures ))
assert_eq "$main_url" "$REPLY" 'explicit development channel'

[[ ! -s $Z4M_TEST_CURL_LOG ]] || {
  print -ru2 -- 'pinned or development resolution reached the network'
  (( ++failures ))
}

respond '{"tag_name":"v2.3.4"}'
zstyle -d :z4m:update channel
-z4m-resolve-update-url || (( ++failures ))
assert_eq https://raw.githubusercontent.com/arcthur/zsh4monkey/v2.3.4 "$REPLY" 'stable default'
[[ $(<$Z4M_TEST_CURL_LOG) == *api.github.com/repos/arcthur/zsh4monkey/releases/latest* ]] || {
  print -ru2 -- 'stable channel did not query the latest release'
  (( ++failures ))
}

zstyle ':z4m:update' channel stable
-z4m-resolve-update-url || (( ++failures ))
assert_eq https://raw.githubusercontent.com/arcthur/zsh4monkey/v2.3.4 "$REPLY" 'stable channel'

zstyle ':z4m:update' channel invalid
assert_resolve_fails 'invalid channel' 'invalid update channel'
zstyle ':z4m:update' channel stable

# --- Release response parsing -------------------------------------------------
# Resolution must take the first tag field. A greedy match would take the last
# one and silently resolve to the oldest entry of an array-shaped response.
respond '[{"tag_name": "v2.3.4"},{"tag_name":"v0.9.0"}]'
-z4m-resolve-update-url || (( ++failures ))
assert_eq https://raw.githubusercontent.com/arcthur/zsh4monkey/v2.3.4 "$REPLY" 'leftmost tag field'

respond '{"tag_name":"v2.3.4.5"}'
-z4m-resolve-update-url || (( ++failures ))
assert_eq https://raw.githubusercontent.com/arcthur/zsh4monkey/v2.3.4.5 "$REPLY" 'four-part tag'

respond '{"message":"API rate limit exceeded"}'
assert_resolve_fails 'response without a tag' 'has no tag'

local tag
for tag in main 2.3.4 v2.3 v2.3.4.5.6 v2.x.4 v2.100.4 'v2.3.4;rm' v2..4; do
  respond "{\"tag_name\":\"$tag\"}"
  assert_resolve_fails "malformed tag $tag" 'invalid tag'
done

# --- Downgrade protection -----------------------------------------------------
# v2.3.4 encodes as 203040000.
respond '{"tag_name":"v2.3.4"}'
installed 300000000
assert_resolve_fails 'release older than the installed version' 'refusing release downgrade'
installed 203040000
-z4m-resolve-update-url || {
  print -ru2 -- 'reinstalling the installed release was refused'
  (( ++failures ))
}
installed 203030001
-z4m-resolve-update-url || {
  print -ru2 -- 'upgrading to a newer release was refused'
  (( ++failures ))
}
installed 100000001

# --- z4m version --check ------------------------------------------------------
version_check() {
  REPLY=$(-z4m-cmd-version --check 2>&1)
  REPLY=${REPLY//$'\e'\[[0-9;]#m}
}

Z4M_URL=$main_url
zstyle -d :z4m:update channel
version_check
[[ $REPLY == *'mutable development target; run z4m update to refresh'* ]] || {
  print -ru2 -- "version check treats mutable main as an installed ref: $REPLY"
  (( ++failures ))
}

Z4M_URL=$release_url
zstyle ':z4m:update' channel pinned
version_check
[[ $REPLY == *'current channel target is installed'* ]] || {
  print -ru2 -- "version check does not recognize the installed pinned ref: $REPLY"
  (( ++failures ))
}

zstyle ':z4m:update' channel stable
version_check
[[ $REPLY == *'run z4m update to install v2.3.4'* ]] || {
  print -ru2 -- "version check does not offer the newer release: $REPLY"
  (( ++failures ))
}

zstyle -d :z4m:update channel
(( failures == 0 ))
