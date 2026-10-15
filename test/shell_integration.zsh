#!/usr/bin/env zsh
#
# OSC 133 shell integration. Ghostty and kitty clear the prompt the cursor is
# in on resize, starting at its A mark, and let the shell redraw it; that only
# works when A comes from the prompt itself and is repeated on every redraw,
# and when PS2 carries k=s. The first part pins the prompt marking modes, the
# second reads the bytes a real shell writes to its terminal.

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

local repository=${0:A:h:h}
typeset -gi failures=0

assert_eq() {
  [[ $1 == $2 ]] && return
  print -ru2 -- "$3: expected [${(V)1}], got [${(V)2}]"
  (( ++failures ))
}

# --- Prompt marking modes ------------------------------------------------------
() {
  emulate -L zsh -o no_aliases -o extended_glob
  local tmpdir
  tmpdir=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-osc133.XXXXXXXXXX") || exit 1
  {
    fpath=($repository/fn $fpath)
    autoload -Uz -- -z4m-tmux-bypass -z4m-enable-shell-integration
    typeset -gi _z4m_can_save_restore_screen=0
    # -z4m-tmux-bypass writes to the tty fd when stdout is not a terminal.
    local out=$tmpdir/tty
    typeset -gi _z4m_tty_fd
    exec {_z4m_tty_fd}>>$out
    -z4m-enable-shell-integration
    zle() { return 1 }

    local A=$'%{\e]133;A\a%}' B=$'%{\e]133;B\a%}' S=$'%{\e]133;A;k=s\a%}'

    # prompt: precmd wraps PS1 and PS2, preexec hands the clean PS1 back.
    PS1='%~ %# ' PS2=
    -z4m-shell-integration-precmd 0
    assert_eq "$A%~ %# $B" "$PS1" 'prompt mode marks PS1'
    assert_eq "$S$B" "$PS2" 'PS2 carries k=s'
    -z4m-shell-integration-precmd 0
    assert_eq "$A%~ %# $B" "$PS1" 'PS1 is marked once'
    assert_eq "$S$B" "$PS2" 'PS2 is marked once'
    -z4m-shell-integration-preexec
    assert_eq '%~ %# ' "$PS1" 'preexec restores PS1'
    -z4m-shell-integration-precmd 1
    assert_eq $'\e]133;C\a\e]133;D;1\a' "$(<$out)" 'C then D with the exit status'

    # A theme that replaced the marked PS1 keeps its own version.
    PS1=theme
    -z4m-shell-integration-preexec
    assert_eq theme "$PS1" 'preexec keeps a replaced PS1'

    # A trailing bare % must not swallow the B mark into %{.
    PS1='>%'
    -z4m-shell-integration-precmd 0
    assert_eq "$A>%%$B" "$PS1" 'trailing % is doubled'
    -z4m-shell-integration-preexec

    # precmd: p10k with its integration off; A from precmd, B at line-init once.
    : >$out
    _z4m_osc133_prompt=precmd PS1=plain
    -z4m-shell-integration-precmd 0
    -z4m-shell-integration-line-init
    -z4m-shell-integration-line-init
    assert_eq $'\e]133;D;0\a\e]133;A\a\e]133;B\a' "$(<$out)" 'precmd mode prints A, then B once'
    assert_eq plain "$PS1" 'precmd mode leaves PS1 alone'
    : >$out
    PS1="p10k$B"
    -z4m-shell-integration-precmd 0
    -z4m-shell-integration-line-init
    assert_eq '' "$(<$out)" 'precmd mode defers to marks already in PS1'

    # p10k: the prompt marks itself.
    _z4m_osc133_prompt=p10k PS1=p10k
    -z4m-shell-integration-precmd 0
    assert_eq p10k "$PS1" 'p10k mode leaves PS1 alone'

    # Inside tmux every mark also reaches the outer terminal.
    _z4m_can_save_restore_screen=1
    -z4m-osc133-mark A
    assert_eq $'%{\e]133;A\a\ePtmux;\e\e]133;A\a\e\\%}' "$REPLY" 'tmux passthrough copy'
  } always {
    exec {_z4m_tty_fd}>&-
    unfunction zle
    command rm -rf -- $tmpdir
  }
}

# --- What a real shell writes ----------------------------------------------------
source $repository/test/lib/sandbox.zsh || exit 1
sandbox_setup $repository || exit 1
trap sandbox_cleanup EXIT HUP INT TERM

# A widget that redraws the prompt without running a command, as a resize or an
# async prompt update does.
sandbox_write_zshrc \
  'z4m-test-redraw() { zle reset-prompt }' \
  'zle -N z4m-test-redraw' \
  "bindkey '^X^R' z4m-test-redraw"

local A=$'\e]133;A\a' B=$'\e]133;B\a' C=$'\e]133;C\a' D1=$'\e]133;D;1\a' S=$'\e]133;A;k=s\a'

# Usage: expect_stream <label> <glob>
expect_stream() {
  sandbox_pty_expect 20 $2 && return
  sandbox_fail $1
  print -ru2 -- "${(V)REPLY[1,1500]}"
}

sandbox_pty_start || exit 1
if ! sandbox_pty_expect 60 "*$SANDBOX_READY*"; then
  sandbox_fail 'shell did not reach the prompt'
else
  sandbox_pty_send 'false'
  expect_stream 'command output, exit status, then a marked prompt' \
    "*${(b)C}*${(b)D1}*${(b)A}*${(b)B}*"
  [[ $REPLY != *${C}*${B}*${C}* ]] || sandbox_fail 'B emitted at preexec'

  sandbox_pty_send $'\C-x\C-r'
  expect_stream 'redrawing the prompt repeats A' "*${(b)A}*${(b)B}*"

  sandbox_pty_send 'for x in 1; do'
  expect_stream 'PS2 marked as a secondary prompt' "*${(b)S}*${(b)B}*"
  sandbox_pty_send 'done'

  # Commands see PS1 without the marks.
  sandbox_pty_send 'print -r -- "__P""S1__${(V)PS1}__END__"'
  expect_stream 'PS1 printed' '*__PS1__*__END__*'
  local ps1=${${REPLY#*__PS1__}%%__END__*}
  [[ $ps1 != *133* ]] || sandbox_fail "PS1 kept the marks inside a command: $ps1"
fi
sandbox_pty_stop

sandbox_expect_offline 'shell integration'
(( failures == 0 && SANDBOX_FAILURES == 0 )) && print -r -- 'shell_integration: ok'
(( failures == 0 && SANDBOX_FAILURES == 0 ))
