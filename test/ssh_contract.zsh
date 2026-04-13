#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail

setopt local_options

cd -- "${0:A:h:h}" || exit 1

typeset -gi failures=0

assert_no_match() {
  local pattern=$1
  shift
  if rg -n --color=never -e "$pattern" "$@" >/dev/null 2>&1; then
    print -ru2 -- "unexpected match for pattern: $pattern"
    rg -n --color=never -e "$pattern" "$@" >&2 || true
    ((failures++))
  fi
}

assert_match() {
  local pattern=$1
  shift
  if ! rg -n --color=never -e "$pattern" "$@" >/dev/null 2>&1; then
    print -ru2 -- "missing expected pattern: $pattern"
    ((failures++))
  fi
}

assert_no_match '--force-sync' \
  fn/-z4m-cmd-help \
  fn/_z4m \
  docs/commands.md \
  docs/ssh.md \
  man/man1/z4m-ssh.1 \
  man/man1/z4m.1

assert_no_match 'retrieve-extra-files|retrieve-history|propagate-env-patterns|propagate-env-exclude|sync-mode|offline-mode' \
  fn/-z4m-cmd-ssh \
  fn/-z4m-cmd-help \
  docs/config.md \
  docs/ssh.md \
  man/man1/z4m-ssh.1

assert_no_match 'propagate-env' \
  fn/-z4m-cmd-ssh \
  fn/-z4m-cmd-help \
  docs/config.md \
  docs/ssh.md \
  man/man1/z4m-ssh.1 \
  docs/design-env-propagation.md

assert_no_match '_Z4M_PROPAGATED_ENV_B64|z4m_ssh_retrieve_files|DUMP_MARKER|EMPTY_RETRIEVE_FROM|EMPTY_DELETE_TO|sync_state|files_need_sync|files_need_delete' \
  fn/-z4m-cmd-ssh \
  fn/-z4m-init \
  sc/ssh-bootstrap

assert_no_match '_Z4M_SSH_MARKER' \
  fn/-z4m-save-screen \
  fn/-z4m-restore-screen \
  main.zsh

assert_no_match 'LC_ALL="C"|LC_ALL='"'"'C'"'"'' \
  fn/-z4m-cmd-ssh \
  sc/ssh-bootstrap

assert_no_match 'ssh-sync-state' \
  man/man1/z4m-ssh.1

assert_no_match 'remote_script="~/\$remote_script"' \
  fn/-z4m-cmd-ssh

assert_match '_z4m_use\[powerlevel10k\].*Z4M_SSH|PROMPT='"'"'%~ %# '"'"'|unsetopt transient_rprompt' \
  fn/-z4m-init-zle

assert_no_match '-z4m-autosuggest-core-ssh-redraw' \
  fn/-z4m-autosuggest-core

[[ ! -e fn/-z4m-cmd-env-propagation-diagnose ]] || {
  print -ru2 -- 'unexpected legacy command: fn/-z4m-cmd-env-propagation-diagnose'
  ((failures++))
}

[[ ! -e fn/-z4m-env-propagation-parse ]] || {
  print -ru2 -- 'unexpected legacy helper: fn/-z4m-env-propagation-parse'
  ((failures++))
}

assert_match "send-extra-files" \
  docs/config.md \
  docs/ssh.md \
  fn/-z4m-cmd-help

assert_match "ssh:\\*' env|ssh:\\* env|z4m:ssh:\\*.*env" \
  docs/config.md \
  docs/ssh.md \
  man/man1/z4m-ssh.1 \
  fn/-z4m-cmd-help

assert_match "--dest|--glob|--exclude" \
  docs/ssh.md \
  man/man1/z4m-ssh.1 \
  fn/-z4m-cmd-help

assert_match "z4m_ssh_interpreter|Z4M_SSH_CWD" \
  fn/-z4m-cmd-ssh \
  sc/ssh-bootstrap

assert_match '-z4m-ssh-zstyle-has-host-specific' \
  fn/-z4m-cmd-ssh

assert_no_match '-z4m-ssh-zstyle-has-exact|-z4m-ssh-zstyle-has-specific-pattern' \
  fn/-z4m-cmd-ssh

assert_no_match '\$\{\(q\)(z4m_url|value|term|z4m_min_version|z4m_ssh_host|z4m_ssh_client|remote_script|z4m_ssh_interpreter|z4m_ssh_cwd|package_dir|file:t)\}' \
  fn/-z4m-cmd-ssh

assert_match '\$\{\(qq\)z4m_url\}|\$\{\(qq\)value\}|\$\{\(qq\)term\}|\$\{\(qq\)z4m_min_version\}|\$\{\(qq\)z4m_ssh_host\}|\$\{\(qq\)z4m_ssh_client\}|\$\{\(qq\)remote_script\}|\$\{\(qq\)z4m_ssh_interpreter\}|\$\{\(qq\)z4m_ssh_cwd\}' \
  fn/-z4m-cmd-ssh

assert_match 'z4m_ssh_prelude\+\=\('"'"'"export" Z4M_SSH_CWD=' \
  fn/-z4m-cmd-ssh

assert_no_match "remote_exec='Z4M_SSH_CWD=" \
  fn/-z4m-cmd-ssh

assert_no_match "'set' '--' \"\\$@\" \"\\$_z4m_ssh_tmp\"|'shift'" \
  sc/ssh-bootstrap

assert_no_match '"\\$1"/"\\$_z4m_ssh_src"' \
  sc/ssh-bootstrap

assert_no_match '"\\$@" 2>"' \
  sc/ssh-bootstrap

assert_match '_z4m_ssh_tmp="\$\{_z4m_ssh_tmp-\}"' \
  sc/ssh-bootstrap

assert_match "ssh:\\*' cwd|ssh:\\* cwd|z4m:ssh:\\*.*cwd" \
  docs/config.md \
  docs/ssh.md \
  man/man1/z4m-ssh.1 \
  fn/-z4m-cmd-help

assert_match "ssh:\\*' interpreter|ssh:\\* interpreter|z4m:ssh:\\*.*interpreter" \
  docs/config.md \
  docs/ssh.md \
  man/man1/z4m-ssh.1 \
  fn/-z4m-cmd-help

assert_match 'Z4M_SSH' \
  fn/-z4m-autosuggest-core

assert_match 'enabled=0' \
  fn/-z4m-autosuggest-core

assert_match 'Z4M_SSH' \
  fn/-z4m-highlight-init

assert_match 'backend=none' \
  fn/-z4m-highlight-init

assert_match 'autosuggestions are disabled in SSH sessions' \
  docs/ssh.md \
  man/man1/z4m-ssh.1

assert_match '[Ss]yntax highlighting is disabled in SSH sessions' \
  docs/ssh.md \
  man/man1/z4m-ssh.1

assert_match '[Ss]implified prompt is used in SSH sessions' \
  docs/ssh.md \
  man/man1/z4m-ssh.1

assert_match '[Ss]implified prompt|disable inline autosuggestions and syntax highlighting|redraw stability' \
  README.md \
  docs/commands.md \
  fn/-z4m-cmd-help \
  man/man1/z4m.1

assert_match "SSH with zsh4monkey teleportation" \
  fn/-z4m-cmd-help \
  man/man1/z4m-ssh.1

if (( failures )); then
  exit 1
fi
