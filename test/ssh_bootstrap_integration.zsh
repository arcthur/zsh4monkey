#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail

cd -- "${0:A:h:h}" || exit 1

typeset -gi failures=0
typeset test_dir
test_dir=$(mktemp -d) || exit 1
trap 'rm -rf -- "$test_dir"' EXIT

fpath=($PWD/fn $fpath)
autoload -Uz -- -z4m-ssh-payload-offset || exit 1

assert_file_content() {
  local target=$1 expected=$2 name=$3
  local actual
  if [[ ! -f $target ]]; then
    print -ru2 -- "missing file for $name: $target"
    (( ++failures ))
    return
  fi
  actual=$(<$target)
  if [[ $actual != $expected ]]; then
    print -ru2 -- "unexpected content for $name: expected=$expected actual=$actual"
    (( ++failures ))
  fi
}

build_bootstrap() {
  local output=$1 payload=$2
  shift 2
  local -a destinations=("$@")
  local destination_list=${(j: :)${(@qq)destinations}}
  local script=${"$(<sc/ssh-bootstrap)"//$'\r'} || return

  script=${script//'^TERM^'/${(qq)TERM}}
  script=${script//'^MIN_VERSION^'/${(qq)100000001}}
  script=${script//'^SSH_HOST^'/${(qq)test-host}}
  script=${script//'^SSH_CLIENT^'/${(qq)test-client}}
  script=${script//'^PRELUDE^'/}
  script=${script//'^SEND_TO^'/$destination_list}
  script=${script//'^RUN^'/:}
  -z4m-ssh-payload-offset "$script" || return
  script=${script//'^DUMP_POS^'/$REPLY}

  print -r -- "$script" >"$output" || return
  command tar -C "$payload" -czf - -- {1..$#destinations} >>"$output"
}

build_dynamic_bootstrap() {
  local output=$1 payload=$2
  local destination_list='"$Z4M"/z4m.zsh "$ZDOTDIR"/.zshrc'
  local script=${"$(<sc/ssh-bootstrap)"//$'\r'} || return

  script=${script//'^TERM^'/${(qq)TERM}}
  script=${script//'^MIN_VERSION^'/${(qq)100000001}}
  script=${script//'^SSH_HOST^'/${(qq)test-host}}
  script=${script//'^SSH_CLIENT^'/${(qq)test-client}}
  script=${script//'^PRELUDE^'/}
  script=${script//'^SEND_TO^'/$destination_list}
  script=${script//'^RUN^'/:}
  -z4m-ssh-payload-offset "$script" || return
  script=${script//'^DUMP_POS^'/$REPLY}

  print -r -- "$script" >"$output" || return
  command tar -C "$payload" -czf - -- 1 2 >>"$output"
}

# The remote reads the archive with `tail -c`, so the offset is a byte count.
# Under a multibyte locale a character count is smaller and shifts the payload,
# which is only observable when the rendered script contains non-ASCII bytes.
typeset -i multibyte_available=0
() {
  local LC_ALL=en_US.UTF-8
  local sample=$'é'
  (( ${#sample} == 1 )) && multibyte_available=1
}
if (( multibyte_available )); then
  () {
    local LC_ALL=en_US.UTF-8
    -z4m-ssh-payload-offset $'héllo'
  } || exit 1
  if [[ ${REPLY// /} != 6 ]]; then
    print -ru2 -- "payload offset must count bytes: got ${REPLY// /} for a 6-byte script"
    (( ++failures ))
  fi
else
  print -ru2 -- 'note: no UTF-8 locale available; skipping the byte-offset check'
fi

typeset payload=$test_dir/payload
typeset home=$test_dir/home
mkdir -p -- "$payload" "$home" || exit 1
print -r -- new-one >"$payload/1"
mkdir -p -- "$payload/2" || exit 1
print -r -- new-two >"$payload/2/value"
print -r -- old-one >"$home/one"
mkdir -p -- "$home/two" || exit 1
print -r -- old-two >"$home/two/value"

typeset success_script=$test_dir/bootstrap-success
typeset success_log=$test_dir/bootstrap-success.log
build_bootstrap "$success_script" "$payload" "$home/one" "$home/two" || exit 1
HOME=$home Z4M=$home/z4m TMPDIR=$test_dir command sh "$success_script" >"$success_log" 2>&1 || {
  print -ru2 -- 'bootstrap success scenario failed'
  command cat -- "$success_log" >&2
  (( ++failures ))
}
assert_file_content "$home/one" new-one 'atomic file replacement'
assert_file_content "$home/two/value" new-two 'atomic directory replacement'

typeset dynamic_payload=$test_dir/dynamic-payload
typeset dynamic_script=$test_dir/bootstrap-dynamic
typeset dynamic_z4m=$home/dynamic-z4m
typeset dynamic_zdotdir=$home/dynamic-zdotdir
mkdir -p -- "$dynamic_payload"
print -r -- dynamic-z4m >"$dynamic_payload/1"
print -r -- dynamic-zdotdir >"$dynamic_payload/2"
build_dynamic_bootstrap "$dynamic_script" "$dynamic_payload" || exit 1
HOME=$home Z4M=$dynamic_z4m ZDOTDIR=$dynamic_zdotdir TMPDIR=$test_dir \
  command sh "$dynamic_script" >/dev/null 2>&1 || {
  print -ru2 -- 'bootstrap dynamic destination scenario failed'
  (( ++failures ))
}
assert_file_content "$dynamic_z4m/z4m.zsh" dynamic-z4m 'expanded Z4M destination'
assert_file_content "$dynamic_zdotdir/.zshrc" dynamic-zdotdir 'expanded ZDOTDIR destination'

typeset unicode_destination=$home/$'项目-ünïcode'
typeset unicode_script=$test_dir/bootstrap-unicode
typeset unicode_log=$test_dir/bootstrap-unicode.log
build_bootstrap "$unicode_script" "$payload" "$unicode_destination" || exit 1
HOME=$home Z4M=$home/z4m TMPDIR=$test_dir command sh "$unicode_script" \
  >"$unicode_log" 2>&1 || {
  print -ru2 -- 'bootstrap non-ASCII destination scenario failed'
  command cat -- "$unicode_log" >&2
  (( ++failures ))
}
assert_file_content "$unicode_destination" new-one 'non-ASCII remote destination'

typeset injection_destination=$home/'evil;$(touch${IFS}PWNED)'
typeset injection_script=$test_dir/bootstrap-injection
typeset injection_log=$test_dir/bootstrap-injection.log
build_bootstrap "$injection_script" "$payload" "$injection_destination" || exit 1
(
  cd -- "$test_dir" || exit 1
  HOME=$home Z4M=$home/z4m TMPDIR=$test_dir command sh "$injection_script"
) >"$injection_log" 2>&1 || {
  print -ru2 -- 'bootstrap quoted destination scenario failed'
  command cat -- "$injection_log" >&2
  (( ++failures ))
}
assert_file_content "$injection_destination" new-one 'quoted remote destination'
if [[ -e $test_dir/PWNED ]]; then
  print -ru2 -- 'remote destination executed shell syntax'
  (( ++failures ))
fi

typeset overlap_script=$test_dir/bootstrap-overlap
typeset overlap_log=$test_dir/bootstrap-overlap.log
build_bootstrap \
  "$overlap_script" \
  "$payload" \
  "$home/overlap" \
  "$home/overlap/child" || exit 1
if HOME=$home Z4M=$home/z4m TMPDIR=$test_dir \
    command sh "$overlap_script" >"$overlap_log" 2>&1; then
  print -ru2 -- 'overlapping destination scenario unexpectedly succeeded'
  (( ++failures ))
fi
if [[ -e $home/overlap ]]; then
  print -ru2 -- 'overlapping destinations changed the target tree'
  (( ++failures ))
fi

typeset separator_script=$test_dir/bootstrap-repeated-separator
typeset separator_log=$test_dir/bootstrap-repeated-separator.log
build_bootstrap \
  "$separator_script" \
  "$payload" \
  "$home/alias" \
  "$home//alias" || exit 1
if HOME=$home Z4M=$home/z4m TMPDIR=$test_dir \
    command sh "$separator_script" >"$separator_log" 2>&1; then
  print -ru2 -- 'repeated-separator destination scenario unexpectedly succeeded'
  (( ++failures ))
fi
if [[ -e $home/alias ]]; then
  print -ru2 -- 'repeated-separator destinations changed the target tree'
  (( ++failures ))
fi

print -r -- prepare-one >"$payload/1"
print -r -- prepare-two >"$payload/2/value"
print -r -- stable-one >"$home/one"
print -r -- stable-two >"$home/two/value"

typeset fake_bin=$test_dir/bin
typeset mv_state=$test_dir/mv-state
mkdir -p -- "$fake_bin" || exit 1
typeset real_cp=${commands[cp]}
cat >"$fake_bin/cp" <<'SH'
#!/bin/sh
source_path=
for argument in "$@"; do
  case "$argument" in
    -*|'') ;;
    *) source_path=$argument; break ;;
  esac
done
case "$source_path" in
  */2)
    exit 98
    ;;
esac
exec "$Z4M_TEST_REAL_CP" "$@"
SH
chmod 755 "$fake_bin/cp" || exit 1

typeset prepare_script=$test_dir/bootstrap-prepare-failure
typeset prepare_log=$test_dir/bootstrap-prepare-failure.log
build_bootstrap "$prepare_script" "$payload" "$home/one" "$home/two" || exit 1
if HOME=$home Z4M=$home/z4m TMPDIR=$test_dir PATH=$fake_bin:$PATH \
    Z4M_TEST_REAL_CP=$real_cp command sh "$prepare_script" >"$prepare_log" 2>&1; then
  print -ru2 -- 'bootstrap prepare failure scenario unexpectedly succeeded'
  (( ++failures ))
fi
assert_file_content "$home/one" stable-one 'prepare failure first destination'
assert_file_content "$home/two/value" stable-two 'prepare failure second destination'

command rm -f -- "$fake_bin/cp"
print -r -- rollback-one >"$payload/1"
print -r -- rollback-two >"$payload/2/value"

cat >"$fake_bin/mv" <<'SH'
#!/bin/sh
source_path=$1
[ "$source_path" != '--' ] || source_path=$2
case "$source_path" in
  */new)
    if [ -e "$Z4M_TEST_MV_STATE" ]; then
      exit 97
    fi
    : >"$Z4M_TEST_MV_STATE"
    ;;
esac
exec /bin/mv "$@"
SH
chmod 755 "$fake_bin/mv" || exit 1

typeset failure_script=$test_dir/bootstrap-failure
typeset failure_log=$test_dir/bootstrap-failure.log
build_bootstrap "$failure_script" "$payload" "$home/one" "$home/two" || exit 1
if HOME=$home Z4M=$home/z4m TMPDIR=$test_dir PATH=$fake_bin:$PATH Z4M_TEST_MV_STATE=$mv_state \
    command sh "$failure_script" >"$failure_log" 2>&1; then
  print -ru2 -- 'bootstrap failure scenario unexpectedly succeeded'
  (( ++failures ))
fi
assert_file_content "$home/one" stable-one 'rollback first destination'
assert_file_content "$home/two/value" stable-two 'rollback second destination'

typeset -a transaction_leaks=($home/.z4m-ssh.*(N))
if (( $#transaction_leaks )); then
  print -ru2 -- 'transaction directories leaked after bootstrap'
  (( ++failures ))
fi

typeset -a snapshot_leaks=($test_dir/z4m-ssh.*(N))
if (( $#snapshot_leaks )); then
  print -ru2 -- 'bootstrap snapshot directories leaked'
  (( ++failures ))
fi

print -r -- preserve-one >"$payload/1"
print -r -- preserve-two >"$payload/2/value"
print -r -- recovery-one >"$home/one"
mkdir -p -- "$home/two"
print -r -- recovery-two >"$home/two/value"
command rm -f -- "$mv_state"
cat >"$fake_bin/mv" <<'SH'
#!/bin/sh
source_path=$1
[ "$source_path" != '--' ] || source_path=$2
case "$source_path" in
  */new)
    if [ -e "$Z4M_TEST_MV_STATE" ]; then
      exit 97
    fi
    : >"$Z4M_TEST_MV_STATE"
    ;;
  */old)
    exit 96
    ;;
esac
exec /bin/mv "$@"
SH
chmod 755 "$fake_bin/mv" || exit 1

typeset rollback_failure_script=$test_dir/bootstrap-rollback-failure
typeset rollback_failure_log=$test_dir/bootstrap-rollback-failure.log
build_bootstrap "$rollback_failure_script" "$payload" "$home/one" "$home/two" || exit 1
if HOME=$home Z4M=$home/z4m TMPDIR=$test_dir PATH=$fake_bin:$PATH \
    Z4M_TEST_MV_STATE=$mv_state command sh "$rollback_failure_script" \
      >"$rollback_failure_log" 2>&1; then
  print -ru2 -- 'rollback failure scenario unexpectedly succeeded'
  (( ++failures ))
fi

typeset -a preserved_transactions=($home/.z4m-ssh.*(N/))
typeset -a preserved_snapshots=($test_dir/z4m-ssh.*(N/))
if (( ! $#preserved_transactions || ! $#preserved_snapshots )); then
  print -ru2 -- 'failed rollback did not preserve recovery state'
  (( ++failures ))
fi
typeset recovery_path
for recovery_path in $preserved_transactions $preserved_snapshots; do
  command rm -rf -- "$recovery_path"
done

(( failures == 0 ))
