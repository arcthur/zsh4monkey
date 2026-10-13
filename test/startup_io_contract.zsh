#!/usr/bin/env zsh
#
# Steady-state startup must not spawn processes or rewrite files that are already current.

emulate -L zsh -o no_aliases -o extended_glob

cd -- "${0:A:h:h}" || exit 1

zmodload zsh/datetime zsh/system || exit 1
zmodload -F zsh/files b:{zf_mkdir,zf_mv,zf_rm} || exit 1
zmodload -F zsh/stat b:zstat || exit 1

typeset -gi failures=0
fail() {
  print -ru2 -- "$1"
  (( ++failures ))
}

typeset -g root=${TMPDIR:-/tmp}/z4m-startup-io.$$
trap 'command rm -rf -- $root' EXIT
zf_mkdir -p -- $root/bin $root/z4m/stickycache $root/z4m/cache || exit 1

# Fake external commands record each invocation, then defer to the real tool.
typeset -g calls=$root/calls
: >$calls
cat >$root/bin/cp <<EOF
#!/bin/sh
echo "cp \$*" >>'$calls'
exec /bin/cp "\$@"
EOF
cat >$root/bin/atuin <<EOF
#!/bin/sh
echo "atuin \$*" >>'$calls'
case \$1 in
  uuid) echo 00000000000070008000000000000000 ;;
  init) cat <<'INIT'
if [[ -z "\${ATUIN_SESSION:-}" || "\${ATUIN_SHLVL:-}" != "\$SHLVL" ]]; then
    export ATUIN_SESSION=\$(atuin uuid)
    export ATUIN_SHLVL=\$SHLVL
fi
INIT
  ;;
esac
EOF
chmod +x $root/bin/cp $root/bin/atuin || exit 1
path=($root/bin $path)
hash -r

call_count() {
  local -a lines=(${(f)"$(<$calls)"})
  REPLY=${#${(M)lines:#$1*}}
}

# Highlight theme: an unchanged theme is neither copied nor recompiled.
() {
  local FAST_WORK_DIR=$root/fsh vendor=$PWD/vendor/fast-syntax-highlighting
  local target=$FAST_WORK_DIR/current_theme.zsh
  local -a before after
  zf_mkdir -p -- $FAST_WORK_DIR
  source fn/-z4m-highlight-backend-fast || exit 1

  zstyle :z4m:highlight theme catppuccin-mocha
  -z4m-highlight-fast-apply-theme $vendor || fail 'theme apply failed'
  cmp -s $target $vendor/themes/catppuccin-mocha.zsh || fail 'theme was not installed'

  : >$target.zwc
  command touch -t 200001010000 -- $target
  : >$calls
  zstat -A before +mtime -- $target
  -z4m-highlight-fast-apply-theme $vendor || fail 'theme re-apply failed'
  zstat -A after +mtime -- $target
  call_count cp
  (( REPLY == 0 )) || fail 'unchanged theme spawned cp'
  [[ $before == $after ]] || fail 'unchanged theme was rewritten'
  [[ -e $target.zwc ]] || fail 'unchanged theme dropped its compiled file'

  zstyle :z4m:highlight theme clean
  -z4m-highlight-fast-apply-theme $vendor || fail 'theme switch failed'
  cmp -s $target $vendor/themes/clean.zsh || fail 'theme switch did not install the new theme'
  [[ ! -e $target.zwc ]] || fail 'theme switch kept a stale compiled file'
}

# Directory history: starting in the most recent directory does not rewrite the file.
() {
  local Z4M=$root/z4m
  local -i writes=0
  local -a dirstack=()
  local DIRSTACKSIZE=10
  autoload -Uz -- $PWD/fn/-z4m-update-dir-history $PWD/fn/-z4m-read-dir-history
  function -z4m-write-dir-history() { (( ++writes )) }

  print -rl -- '~/current' '~/older' >$Z4M/stickycache/dir-history-$EUID
  unset _z4m_last_dir
  zstyle :z4m:dir-history: cwd '~/current'
  -z4m-update-dir-history
  (( writes == 0 )) || fail 'unchanged directory history was rewritten'

  zstyle :z4m:dir-history: cwd '~/older'
  -z4m-update-dir-history
  (( writes == 1 )) || fail 'directory history change was not written'
  [[ $_z4m_dir_history[1] == '~/older' ]] || fail 'directory history did not move the new directory first'

  zstyle -d :z4m:dir-history: cwd
  unfunction -- -z4m-write-dir-history
}

# Atuin: the session id is generated in-process instead of forking `atuin uuid`.
() {
  local Z4M=$root/z4m SSH_CONNECTION= Z4M_SSH=
  unset ATUIN_SESSION ATUIN_SHLVL
  function -z4m-compile() { return 0 }
  : >$calls
  # The exit status reflects the optional trailing rebind step, not init success.
  source fn/-z4m-init-atuin
  call_count 'atuin uuid'
  (( REPLY == 0 )) || fail 'atuin init forked atuin uuid'
  [[ $ATUIN_SESSION == [0-9a-f](#c12)7[0-9a-f](#c3)[89ab][0-9a-f](#c15) ]] ||
    fail "ATUIN_SESSION is not a simple-form UUIDv7: $ATUIN_SESSION"
  [[ $ATUIN_SHLVL == $SHLVL ]] || fail 'ATUIN_SHLVL was not set'
  unfunction -- -z4m-compile
}

(( failures == 0 ))
