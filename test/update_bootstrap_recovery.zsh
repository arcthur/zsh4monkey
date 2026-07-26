#!/usr/bin/env zsh

emulate -L zsh -o err_return -o no_aliases -o no_unset -o pipe_fail

local repository=${0:A:h:h}
local test_directory
test_directory=$(mktemp -d) || exit 1
trap 'rm -rf -- "$test_directory"' EXIT HUP INT TERM

fpath=($repository/fn $fpath)
autoload -Uz -- -z4m-write-update-bootstrap

local dead_pid=999999999

write_original_bootstrap() {
  local output=$1 result=$2
  print -r -- "typeset -g Z4M_TEST_UPDATE_BOOTSTRAP=${(q)result}" >"$output"
}

# The generated bootstrap autoloads the shared restore implementation from a
# tree, so every simulated tree must carry it exactly like a real cache does.
install_recover_function() {
  mkdir -p -- "$1/fn"
  command cp -- "$repository/fn/-z4m-recover-update" "$1/fn/"
}

run_recovery_scenario() {
  local name=$1 mode=$2 keep_guard=$3
  local root=$test_directory/$name
  local guard=$root/.updating
  local backup=$root.old.$dead_pid
  local candidate=$root.new.$dead_pid
  local next=$root/.z4m-next-bootstrap
  local generated=$test_directory/$name.generated.zsh

  mkdir -p -- "$root" "$backup" "$candidate"
  write_original_bootstrap "$backup/z4m.zsh" "$name"
  print -r -- candidate >"$candidate/partial"

  case $mode in
    bootstrap-only)
      mkdir -p -- "$root/zsh4monkey"
      print -r -- core >"$root/zsh4monkey/main.zsh"
      install_recover_function "$root/zsh4monkey"
      ;;
    full)
      mkdir -p -- "$backup/zsh4monkey"
      print -r -- restored-core >"$backup/zsh4monkey/main.zsh"
      install_recover_function "$backup/zsh4monkey"
      print -r -- restored >"$backup/restored"
      print -r -- partial >"$root/partial"
      ;;
    *)
      return 1
      ;;
  esac

  if [[ $keep_guard == yes ]]; then
    print -l -- "pid=$dead_pid" "phase=syncing" >"$guard"
  fi

  -z4m-write-update-bootstrap \
    "$generated" "$root" "$guard" "$backup" "$candidate" "$next"
  command mv -- "$generated" "$root/z4m.zsh"
  zsh -n "$root/z4m.zsh"

  unset Z4M_TEST_UPDATE_BOOTSTRAP
  builtin source -- "$root/z4m.zsh"
  [[ $Z4M_TEST_UPDATE_BOOTSTRAP == $name ]]
  [[ ! -e $guard && ! -e $backup && ! -e $candidate && ! -e $next ]]
  [[ ! -e $root/.update-recovery-lock ]]

  case $mode in
    bootstrap-only)
      [[ -r $root/zsh4monkey/main.zsh ]]
      ;;
    full)
      [[ $(<$root/restored) == restored ]]
      [[ $(<$root/zsh4monkey/main.zsh) == restored-core ]]
      [[ ! -e $root/partial ]]
      ;;
  esac
}

run_recovery_scenario bootstrap-only bootstrap-only yes
run_recovery_scenario full full yes
run_recovery_scenario missing-guard full no

local retry_root=$test_directory/retry
local retry_guard=$retry_root/.updating
local retry_backup=$retry_root.old.$dead_pid
local retry_candidate=$retry_root.new.$dead_pid
local retry_next=$retry_root/.z4m-next-bootstrap
local retry_bin=$test_directory/retry-bin
local retry_state=$test_directory/retry-state
local saved_path=$PATH
local real_cp=${commands[cp]}
mkdir -p -- "$retry_root" "$retry_backup/zsh4monkey" "$retry_candidate" "$retry_bin"
write_original_bootstrap "$retry_backup/z4m.zsh" retry
print -r -- restored >"$retry_backup/restored"
print -r -- core >"$retry_backup/zsh4monkey/main.zsh"
install_recover_function "$retry_backup/zsh4monkey"
print -r -- partial >"$retry_root/partial"
print -l -- "pid=$dead_pid" "phase=syncing" >"$retry_guard"
-z4m-write-update-bootstrap \
  "$retry_root/z4m.zsh" \
  "$retry_root" \
  "$retry_guard" \
  "$retry_backup" \
  "$retry_candidate" \
  "$retry_next"

cat >"$retry_bin/cp" <<'SH'
#!/bin/sh
for argument do
  case "$argument" in
    */restored)
      if [ ! -e "$Z4M_TEST_RETRY_STATE" ]; then
        : >"$Z4M_TEST_RETRY_STATE"
        exit 97
      fi
      ;;
  esac
done
exec "$Z4M_TEST_REAL_CP" "$@"
SH
chmod 755 "$retry_bin/cp"

PATH=$retry_bin:$PATH
export Z4M_TEST_RETRY_STATE=$retry_state
export Z4M_TEST_REAL_CP=$real_cp
hash -r
if builtin source -- "$retry_root/z4m.zsh"; then
  print -ru2 -- 'injected update recovery failure unexpectedly succeeded'
  exit 1
fi
[[ -r $retry_backup/z4m.zsh && -r $retry_root/z4m.zsh && -e $retry_guard ]]

PATH=$saved_path
hash -r
unset Z4M_TEST_UPDATE_BOOTSTRAP
builtin source -- "$retry_root/z4m.zsh"
[[ $Z4M_TEST_UPDATE_BOOTSTRAP == retry ]]
[[ $(<$retry_root/restored) == restored ]]
[[ ! -e $retry_guard && ! -e $retry_backup && ! -e $retry_candidate ]]
