#!/usr/bin/env zsh
#
# Isolated end-to-end sandbox: a throwaway HOME whose ~/.zshenv is the shipped
# one, a z4m cache bootstrapped offline from this working tree, and helpers to
# drive real `zsh -i` shells through a PTY.
#
# Nothing here reaches the network. Bootstrap copies the working tree through
# the supported Z4M_BOOTSTRAP_COMMAND hook, and the managed packages are
# configured with `channel none`. PATH only exposes system directories plus
# zsh itself, Homebrew points at an empty prefix, and integrations that would
# pick up host binaries are disabled, so tools installed on the host (fzf,
# atuin, ...) cannot change what is being tested.
#
# Source it from a test, then call `sandbox_setup`.

zmodload zsh/zpty zsh/datetime zsh/zselect zsh/system || return

typeset -g SANDBOX SANDBOX_HOME SANDBOX_Z4M SANDBOX_SOURCE SANDBOX_REPOSITORY
typeset -gi SANDBOX_FAILURES=0

# The marker -z4m-init-zle prints from the first precmd. It only appears when
# full ZLE initialization completed, which is what "the shell is usable" means.
typeset -gr SANDBOX_READY=__Z4M_SANDBOX_READY__

sandbox_fail() {
  print -ru2 -- "FAIL: $1"
  (( ++SANDBOX_FAILURES ))
}

# Usage: sandbox_setup <repository>
sandbox_setup() {
  SANDBOX_REPOSITORY=$1
  SANDBOX=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-sandbox.XXXXXXXXXX") || return
  SANDBOX=${SANDBOX:A}
  SANDBOX_HOME=$SANDBOX/home
  SANDBOX_Z4M=$SANDBOX_HOME/.cache/zsh4monkey
  SANDBOX_SOURCE=$SANDBOX/source
  command mkdir -p -- $SANDBOX/bin $SANDBOX/homebrew $SANDBOX_SOURCE $SANDBOX_Z4M || return

  # The framework as the bootstrap would download it: the working tree without
  # VCS metadata or compiled files, so local edits are what gets tested.
  local entry
  for entry in $SANDBOX_REPOSITORY/*(DN); do
    [[ ${entry:t} == .git ]] && continue
    command cp -R -- $entry $SANDBOX_SOURCE/ || return
  done
  local -a compiled=($SANDBOX_SOURCE/**/*.zwc(DN))
  (( ! $#compiled )) || command rm -f -- $compiled || return

  command cp -- $SANDBOX_REPOSITORY/.zshenv $SANDBOX_HOME/.zshenv || return
  # What the installer leaves behind before the first shell starts.
  command cp -- $SANDBOX_REPOSITORY/z4m.zsh $SANDBOX_Z4M/z4m.zsh || return
  command ln -s -- ${commands[zsh]:A} $SANDBOX/bin/zsh || return

  # Network sentinels: anything that tries to download is recorded and fails,
  # so a test can assert that a code path stayed offline.
  local tool
  for tool in curl wget; do
    print -r -- "#!/bin/sh
printf '%s\\n' \"$tool \$*\" >>'$SANDBOX/network.log'
exit 7" >$SANDBOX/bin/$tool || return
    command chmod 755 -- $SANDBOX/bin/$tool || return
  done
  sandbox_write_zshrc
}

# Usage: sandbox_expect_offline <label>
sandbox_expect_offline() {
  [[ -s $SANDBOX/network.log ]] || return 0
  sandbox_fail "$1: $(<$SANDBOX/network.log)"
  : >$SANDBOX/network.log
}

# Set Z4M_TEST_KEEP_SANDBOX=1 to inspect the sandbox after a failing run.
sandbox_cleanup() {
  [[ -n $SANDBOX && -d $SANDBOX ]] || return 0
  if [[ -n ${Z4M_TEST_KEEP_SANDBOX-} ]]; then
    print -ru2 -- "sandbox kept: $SANDBOX"
    return 0
  fi
  command rm -rf -- $SANDBOX
}

# Lines placed before `z4m init`, for settings that initialization reads.
typeset -ga SANDBOX_PRE_INIT=()

# Usage: sandbox_write_zshrc [line...]
# The extra lines run after `z4m init`. The init status is printed rather than
# acted on so that tests can observe failures.
sandbox_write_zshrc() {
  {
    print -r -- "zstyle ':z4m:' start-tmux no"
    print -r -- "zstyle ':z4m:' chsh no"
    print -r -- "zstyle ':z4m:' auto-update no"
    print -r -- "zstyle ':z4m:' prompt-at-bottom no"
    print -r -- 'for _pkg in fzf powerlevel10k zsh-completions terminfo; do'
    print -r -- '  zstyle ":z4m:$_pkg" channel none'
    print -r -- 'done'
    # Integrations that pick up host binaries from directories z4m adds to PATH
    # itself; the outcome of a test must not depend on what the host installed.
    print -r -- 'for _tool in atuin carapace eza bat zoxide; do'
    print -r -- '  zstyle ":z4m:$_tool" enabled no'
    print -r -- 'done'
    print -rl -- $SANDBOX_PRE_INIT
    print -r -- 'z4m init'
    print -r -- 'print -r -- "__Z4M_INIT_STATUS__=$?"'
    print -rl -- "$@"
  } >$SANDBOX_HOME/.zshrc
}

# The framework the cache currently resolves to.
sandbox_framework() {
  REPLY=$SANDBOX_Z4M/zsh4monkey
  REPLY=${REPLY:A}
}

# Usage: sandbox_environment [NAME=value...]
sandbox_environment() {
  reply=(
    HOME=$SANDBOX_HOME
    TERM=xterm-256color
    PATH=$SANDBOX/bin:/usr/bin:/bin:/usr/sbin:/sbin
    TMPDIR=$SANDBOX
    # z4m adds Homebrew's bin directory to PATH on its own; point it at an empty
    # prefix so host packages stay invisible.
    HOMEBREW_PREFIX=$SANDBOX/homebrew
    Z4M_TEST_SOURCE=$SANDBOX_SOURCE
    'Z4M_BOOTSTRAP_COMMAND=command cp -R -- "$Z4M_TEST_SOURCE"/. "$Z4M_PACKAGE_DIR"/'
    Z4M_BENCHMARK_MARKER=$SANDBOX_READY
    "$@"
  )
}

# PTY session primitives. Output accumulates in SANDBOX_PTY_OUTPUT; every
# expectation only looks at what arrived after the last sandbox_pty_send, so a
# pattern can never match the echo of an earlier command.
typeset -g SANDBOX_PTY_OUTPUT
typeset -gi SANDBOX_PTY_MARK

# Usage: sandbox_pty_start [NAME=value...]
sandbox_pty_start() {
  sandbox_environment "$@"
  local -a command=(env -i "${reply[@]}" $SANDBOX/bin/zsh -i)
  SANDBOX_PTY_OUTPUT=
  SANDBOX_PTY_MARK=0
  # zpty evaluates the command in a forked copy of this shell. `exec` keeps that
  # copy from running the caller's EXIT trap, which would delete the sandbox.
  zpty -b z4m_sandbox "exec ${(j: :)${(@q)command}}"
}

# Usage: sandbox_pty_expect <timeout-seconds> <glob>
# Returns 0 once the output since the last send matches; REPLY holds it.
sandbox_pty_expect() {
  local -F deadline=$(( EPOCHREALTIME + $1 ))
  local pattern=$2 chunk
  while true; do
    REPLY=${SANDBOX_PTY_OUTPUT[SANDBOX_PTY_MARK+1,-1]}
    [[ $REPLY == $~pattern ]] && return 0
    (( EPOCHREALTIME < deadline )) || return 1
    if zpty -rt z4m_sandbox chunk 2>/dev/null; then
      SANDBOX_PTY_OUTPUT+=$chunk
      continue
    fi
    zpty -t z4m_sandbox 2>/dev/null || {
      REPLY=${SANDBOX_PTY_OUTPUT[SANDBOX_PTY_MARK+1,-1]}
      [[ $REPLY == $~pattern ]]
      return
    }
    zselect -t 2
  done
}

# Usage: sandbox_pty_send <line>
sandbox_pty_send() {
  SANDBOX_PTY_MARK=${#SANDBOX_PTY_OUTPUT}
  zpty -w z4m_sandbox "$1"
}

sandbox_pty_stop() {
  zpty -w z4m_sandbox exit 2>/dev/null
  zpty -d z4m_sandbox 2>/dev/null
  return 0
}

# Usage: sandbox_interactive <timeout-seconds> <stop-pattern> [NAME=value...]
#
# Starts `zsh -i` on a PTY and collects its output in REPLY until the output
# matches the glob <stop-pattern>, the shell exits, or the timeout expires.
# Returns 0 only if the pattern matched.
sandbox_interactive() {
  local timeout=$1 stop=$2
  shift 2
  sandbox_pty_start "$@" || return
  sandbox_pty_expect $timeout $stop
  local -i rc=$?
  sandbox_pty_stop
  return rc
}

# Usage: sandbox_command <command> [NAME=value...]
# Runs <command> inside a fully initialized non-tty interactive shell. Combined
# output, without color escapes, goes to REPLY; the status of the shell is
# returned.
sandbox_command() {
  local script=$1
  shift
  sandbox_environment "$@"
  REPLY=$(command env -i "${reply[@]}" $SANDBOX/bin/zsh -ic $script 2>&1 </dev/null)
  local -i rc=$?
  # Messages are colored even without a terminal; match on the text.
  REPLY=${REPLY//$'\e'\[[0-9;]#m}
  return rc
}

# Usage: sandbox_expect_output <label> <glob>
sandbox_expect_output() {
  [[ $REPLY == $~2 ]] && return
  sandbox_fail "$1"
  print -ru2 -- "--- output ---"
  print -ru2 -- "${(q+)REPLY[-2000,-1]}"
}

# Usage: sandbox_reject_output <label> <glob>
sandbox_reject_output() {
  [[ $REPLY != $~2 ]] && return
  sandbox_fail "$1"
  print -ru2 -- "--- output ---"
  print -ru2 -- "${(q+)REPLY[-2000,-1]}"
}
