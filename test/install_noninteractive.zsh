#!/usr/bin/env zsh

emulate -L zsh -o err_return -o no_unset -o pipe_fail

local repository=${0:A:h:h}
local temporary_directory
temporary_directory=$(mktemp -d)
trap 'rm -rf -- "$temporary_directory"' EXIT HUP INT TERM

local test_home=$temporary_directory/home
local test_bin=$temporary_directory/bin
local test_cache=$temporary_directory/cache
mkdir -p -- "$test_home" "$test_bin"
print -r -- legacy >"$test_home/.zshrc"

cat >"$test_bin/curl" <<'SH'
#!/bin/sh
output=
url=
expect_output=0
for argument do
  if [ "$expect_output" = 1 ]; then
    output=$argument
    expect_output=0
    continue
  fi
  case "$argument" in
    *o) expect_output=1 ;;
    https://*) url=$argument ;;
  esac
done
case "$url" in
  */z4m.zsh) source_file=z4m.zsh ;;
  */.zshenv) source_file=.zshenv ;;
  */.zshrc) source_file=.zshrc ;;
  */.zshrc.mac) source_file=.zshrc.mac ;;
  *) exit 1 ;;
esac
case "$source_file" in
  .zshrc*)
    if [ -n "${Z4M_TEST_ZSHRC_TEMPLATE-}" ]; then
      exec cp -- "$Z4M_TEST_ZSHRC_TEMPLATE" "$output"
    fi
    ;;
esac
command cp -- "$Z4M_TEST_REPOSITORY/$source_file" "$output"
SH
chmod 755 "$test_bin/curl"

HOME=$test_home \
XDG_CACHE_HOME=$test_cache \
PATH=$test_bin:$PATH \
Z4M_TEST_REPOSITORY=$repository \
Z4M_INSTALL_REF=main \
  sh "$repository/install" \
    --non-interactive \
    --keyboard pc \
    --editor vi \
    --tmux no \
    --direnv no \
    --existing backup \
    --no-bootstrap >/dev/null

[[ -r $test_home/.zshenv ]]
[[ -r $test_home/.zshrc ]]
[[ -r $test_cache/zsh4monkey/z4m.zsh ]]
command grep -Fq "editor-mode 'vi'" "$test_home/.zshrc"
command grep -Eq "start-tmux[[:space:]]+no" "$test_home/.zshrc"

local backup_directory
backup_directory=$(<$test_cache/zsh4monkey/welcome)
[[ -n $backup_directory && -r $backup_directory/.zshrc ]]
[[ $(<$backup_directory/.zshrc) == legacy ]]

if HOME=$test_home \
   XDG_CACHE_HOME=$test_cache \
   PATH=$test_bin:$PATH \
   Z4M_TEST_REPOSITORY=$repository \
   Z4M_INSTALL_REF=main \
     sh "$repository/install" \
       --non-interactive \
       --existing fail \
       --no-bootstrap >/dev/null 2>&1; then
  print -ru2 -- 'non-interactive installer replaced existing files in fail mode'
  exit 1
fi

local alternate_home=$temporary_directory/alternate-home
local alternate_cache=$temporary_directory/alternate-cache
mkdir -p -- "$alternate_home"
print -r -- legacy >"$alternate_home/.zshenv"

HOME=$alternate_home \
XDG_CACHE_HOME=$alternate_cache \
PATH=$test_bin:$PATH \
Z4M_TEST_REPOSITORY=$repository \
Z4M_INSTALL_REF=main \
  sh "$repository/install" \
    --non-interactive \
    --keyboard mac \
    --editor emacs \
    --tmux yes \
    --direnv yes \
    --existing delete >/dev/null 2>&1

command grep -Fq "keyboard  'mac'" "$alternate_home/.zshrc"
command grep -Fq "start-tmux command tmux" "$alternate_home/.zshrc"
command grep -Fq "zstyle ':z4m:direnv' enable 'yes'" "$alternate_home/.zshrc"
[[ $(<$alternate_cache/zsh4monkey/welcome) == '' ]]

local symlink_home=$temporary_directory/symlink-home
local symlink_cache=$temporary_directory/symlink-cache
local external_startup=$temporary_directory/external-zshrc
mkdir -p -- "$symlink_home"
print -r -- external >"$external_startup"
command ln -s -- "$external_startup" "$symlink_home/.zshrc"
command ln -s -- "$temporary_directory/missing-zprofile" "$symlink_home/.zprofile"

HOME=$symlink_home \
XDG_CACHE_HOME=$symlink_cache \
PATH=$test_bin:$PATH \
Z4M_TEST_REPOSITORY=$repository \
Z4M_INSTALL_REF=main \
  sh "$repository/install" \
    --non-interactive \
    --existing backup >/dev/null 2>&1

backup_directory=$(<$symlink_cache/zsh4monkey/welcome)
[[ -L $backup_directory/.zshrc ]]
[[ -L $backup_directory/.zprofile ]]
[[ $(command readlink "$backup_directory/.zshrc") == $external_startup ]]
[[ $(<$external_startup) == external ]]
[[ -f $symlink_home/.zshrc && ! -L $symlink_home/.zshrc ]]

local directory_home=$temporary_directory/directory-home
local directory_cache=$temporary_directory/directory-cache
mkdir -p -- "$directory_home/.zshrc"
if HOME=$directory_home \
   XDG_CACHE_HOME=$directory_cache \
   PATH=$test_bin:$PATH \
   Z4M_TEST_REPOSITORY=$repository \
   Z4M_INSTALL_REF=main \
     sh "$repository/install" \
       --non-interactive \
       --existing backup >/dev/null 2>&1; then
  print -ru2 -- 'installer unexpectedly replaced a directory-valued startup path'
  exit 1
fi
[[ -d $directory_home/.zshrc ]]

local failure_home=$temporary_directory/failure-home
local failure_cache=$temporary_directory/failure-cache
local failure_bin=$temporary_directory/failure-bin
local failure_state=$temporary_directory/failure-state
local real_mv=${commands[mv]}
mkdir -p -- "$failure_home" "$failure_cache/zsh4monkey" "$failure_bin"
print -r -- original-zshenv >"$failure_home/.zshenv"
print -r -- original-zshrc >"$failure_home/.zshrc"
print -r -- original-cache >"$failure_cache/zsh4monkey/marker"
command ln -s -- "$test_bin/curl" "$failure_bin/curl"

cat >"$failure_bin/mv" <<'SH'
#!/bin/sh
destination=
for argument do
  destination=$argument
done
if [ "$destination" = "$Z4M_TEST_FAILURE_DESTINATION" ] &&
   [ ! -e "$Z4M_TEST_FAILURE_STATE" ]; then
  : >"$Z4M_TEST_FAILURE_STATE"
  exit 97
fi
exec "$Z4M_TEST_REAL_MV" "$@"
SH
chmod 755 "$failure_bin/mv"

if HOME=$failure_home \
   XDG_CACHE_HOME=$failure_cache \
   PATH=$failure_bin:$PATH \
   Z4M_TEST_REPOSITORY=$repository \
   Z4M_TEST_FAILURE_DESTINATION=$failure_home/.zshrc \
   Z4M_TEST_FAILURE_STATE=$failure_state \
   Z4M_TEST_REAL_MV=$real_mv \
   Z4M_INSTALL_REF=main \
     sh "$repository/install" \
       --non-interactive \
       --existing delete \
       --no-bootstrap >/dev/null 2>&1; then
  print -ru2 -- 'installer activation failure unexpectedly succeeded'
  exit 1
fi
[[ $(<$failure_home/.zshenv) == original-zshenv ]]
[[ $(<$failure_home/.zshrc) == original-zshrc ]]
[[ $(<$failure_cache/zsh4monkey/marker) == original-cache ]]
local -a install_leaks=(
  $failure_home/.z4m-install-*(N)
  $failure_cache/.z4m-install-*(N)
)
if (( $#install_leaks )); then
  print -ru2 -- 'installer transaction state leaked after successful rollback'
  exit 1
fi

# A template whose anchor no longer starts a line: the rewrite would silently do
# nothing, so the installer must refuse before touching anything.
local template_home=$temporary_directory/template-home
local template_cache=$temporary_directory/template-cache
local template=$temporary_directory/indented-zshrc
mkdir -p -- "$template_home"
print -r -- original-zshrc >"$template_home/.zshrc"
command sed 's/^# Keyboard type:/  # Keyboard type:/' "$repository/.zshrc" >"$template"
local output
if output=$(HOME=$template_home \
    XDG_CACHE_HOME=$template_cache \
    PATH=$test_bin:$PATH \
    Z4M_TEST_REPOSITORY=$repository \
    Z4M_TEST_ZSHRC_TEMPLATE=$template \
    Z4M_INSTALL_REF=main \
      sh "$repository/install" --non-interactive --existing delete --no-bootstrap 2>&1); then
  print -ru2 -- 'installer accepted a template without a line-start anchor'
  exit 1
fi
[[ $output == *'missing anchor'* ]] || {
  print -ru2 -- "installer failed for the wrong reason: $output"
  exit 1
}
[[ $(<$template_home/.zshrc) == original-zshrc && ! -e $template_home/.zshenv ]]

# A rewrite that produces nothing (an incompatible awk, say) must fail the
# install instead of shipping a .zshrc without the requested settings.
local real_awk=${commands[awk]}
local noop_bin=$temporary_directory/noop-awk-bin
mkdir -p -- "$noop_bin"
command ln -s -- "$test_bin/curl" "$noop_bin/curl"
cat >"$noop_bin/awk" <<'SH'
#!/bin/sh
rewrite=
for argument do
  case "$argument" in
    anchor=*) rewrite=1 ;;
    *'found = 1'*) rewrite= ; break ;;
  esac
  file=$argument
done
[ -n "$rewrite" ] && exec cat -- "$file"
exec "$Z4M_TEST_REAL_AWK" "$@"
SH
chmod 755 "$noop_bin/awk"
rm -rf -- "$template_home" "$template_cache"
mkdir -p -- "$template_home"
print -r -- original-zshrc >"$template_home/.zshrc"
if output=$(HOME=$template_home \
    XDG_CACHE_HOME=$template_cache \
    PATH=$noop_bin:$PATH \
    Z4M_TEST_REAL_AWK=$real_awk \
    Z4M_TEST_REPOSITORY=$repository \
    Z4M_INSTALL_REF=main \
      sh "$repository/install" --non-interactive --editor vi --existing delete --no-bootstrap 2>&1); then
  print -ru2 -- 'installer accepted a rewrite that produced nothing'
  exit 1
fi
[[ $output == *'generated'*'.zshrc'*'is missing'* ]] || {
  print -ru2 -- "installer failed for the wrong reason: $output"
  exit 1
}
[[ $(<$template_home/.zshrc) == original-zshrc && ! -e $template_home/.zshenv ]]

sh "$repository/install" --help >/dev/null
