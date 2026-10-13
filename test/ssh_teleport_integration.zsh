#!/usr/bin/env zsh
#
# Teleport a real shell. A local interactive shell runs `z4m ssh testhost`; the
# ssh stub plays the remote host by running the remote command under a separate
# HOME with a clean environment. The test then talks to the remote shell that
# z4m started there and checks what it received.
#
# This exercises the production renderer in -z4m-cmd-ssh end to end: quoting of
# environment values and destinations, the payload offset, the remote
# transaction, and remote initialization of the teleported framework.

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

local repository=${0:A:h:h}
source $repository/test/lib/sandbox.zsh || exit 1
sandbox_setup $repository || exit 1
trap sandbox_cleanup EXIT HUP INT TERM

local remote=$SANDBOX/remote
command mkdir -p -- $remote/tmp || exit 1

# The stub understands what z4m passes: options with values, -T/-t, the host,
# and the remote command, which a real sshd would hand to the login shell.
cat >$SANDBOX/bin/ssh <<SH
#!/bin/sh
printf '%s\\n' "\$*" >>'$SANDBOX/ssh.log'
config=
while [ \$# -gt 0 ]; do
  case \$1 in
    -G) config=1; shift ;;
    -[bcDEeFIiJLlmOopQRSWw]) shift 2 ;;
    -*) shift ;;
    *) break ;;
  esac
done
host=\$1
shift
if [ -n "\$config" ]; then
  printf 'hostname %s\\n' "\$host"
  exit 0
fi
cd '$remote' || exit 1
exec env -i HOME='$remote' PATH="\$PATH" TERM="\$TERM" TMPDIR='$remote/tmp' \\
  GIT_DIR=/remote/preexisting /bin/sh -c "\$*"
SH
command chmod 755 $SANDBOX/bin/ssh || exit 1

# Values that break any renderer which forgets to quote them.
# The template placeholders are included because the renderer must not rescan
# what it has already inserted.
local payload=$'it\'s "quoted" $(touch "$HOME/PWNED") `touch "$HOME/PWNED"` ; $HOME \\ ^SEND_TO^ ^DUMP_POS^ end'
local copied=$'copied \'value\' with  spaces'
local destination=$'conf dir/it\'s $(touch PWNED).txt'

command mkdir -p -- $SANDBOX_HOME/.config/tool || exit 1
print -r -- extra >$SANDBOX_HOME/.extra-config
# Symlinks are materialized: the remote must not depend on local paths.
command ln -s -- .extra-config $SANDBOX_HOME/.linked-config || exit 1
print -r -- keep >$SANDBOX_HOME/.config/tool/keep
print -r -- skip >$SANDBOX_HOME/.config/tool/skip.tmp
command mkdir -p -- "$remote/work dir" || exit 1

# testhost carries every option; plainhost is the common configuration with
# nothing beyond enabling teleportation (its marker is the only setting).
sandbox_write_zshrc \
  "zstyle ':z4m:ssh:testhost' enable yes" \
  "zstyle ':z4m:ssh:testhost' env ${(q)${:-Z4M_BENCHMARK_MARKER=__Z4M_REMOTE_READY__}} ${(q)${:-Z4M_TEST_PAYLOAD=$payload}} Z4M_TEST_COPIED=_z4m_copy_env_var_ GIT_DIR" \
  "zstyle ':z4m:ssh:testhost' send-extra-files '~/.extra-config' '~/.linked-config' ${(q)${:---dest ${(qq)destination} ~/.extra-config}} \"--exclude '*.tmp' ~/.config/tool\"" \
  "zstyle ':z4m:ssh:testhost' cwd '~/work dir'" \
  "zstyle ':z4m:ssh:plainhost' enable yes" \
  "zstyle ':z4m:ssh:plainhost' env Z4M_BENCHMARK_MARKER=__Z4M_PLAIN_READY__" \
  "zstyle ':z4m:ssh:plainhost' interpreter /bin/sh"

sandbox_pty_start Z4M_TEST_COPIED=$copied || exit 1
sandbox_pty_expect 60 "*$SANDBOX_READY*" || {
  sandbox_fail 'local shell did not reach the prompt'
  exit 1
}

# The features SSH sessions turn off must be on locally, or the remote check
# below would prove nothing.
local session_state='print -r -- "__STA""TE__=[${_z4m_autosuggest_state[configured_enabled]}]|[${_z4m_highlight_state[active_backend]}]|[$PROMPT]|__END__"'
sandbox_pty_send $session_state
sandbox_pty_expect 20 "*${(b):-__STATE__=[1]|[fast]|}*" ||
  sandbox_fail "local shell does not run autosuggestions and highlighting: ${(q+)REPLY[-400,-1]}"

sandbox_pty_send 'z4m ssh testhost'
if ! sandbox_pty_expect 60 '*__Z4M_REMOTE_READY__*'; then
  sandbox_fail 'teleported shell did not finish initialization on the remote host'
  print -ru2 -- "${(q+)REPLY[-3000,-1]}"
  [[ -r $SANDBOX/ssh.log ]] && print -ru2 -- "$(<$SANDBOX/ssh.log)"
else
  sandbox_pty_send 'print -r -- "__RE""MOTE__=[$Z4M_TEST_PAYLOAD]|[$Z4M_TEST_COPIED]|[${GIT_DIR-unset}]|[$PWD]|[${Z4M_SSH:+set}]|__END__"'
  local expected="__REMOTE__=[$payload]|[$copied]|[unset]|[$remote/work dir]|[set]|__END__"
  sandbox_pty_expect 20 "*${(b)expected}*" || {
    sandbox_fail 'remote shell did not receive the configured environment and cwd'
    print -ru2 -- "expected: ${(q+)expected}"
    print -ru2 -- "got:      ${(q+)${${REPLY#*__REMOTE__=}%%__END__*}}"
  }
  # Z4M_SSH only exists on the remote side, so this tells the two shells apart.
  sandbox_pty_send $session_state
  sandbox_pty_expect 20 "*${(b):-__STATE__=[0]|[none]|[%~ %# ]|__END__}*" ||
    sandbox_fail "remote shell did not use the simplified SSH session: ${(q+)REPLY[-400,-1]}"

  sandbox_pty_send 'exit'
  sandbox_pty_send 'print -r -- "__LO""CAL__=${Z4M_SSH:+remote}"'
  sandbox_pty_expect 20 '*__LOCAL__=[^r]*' ||
    sandbox_fail 'local shell did not resume after the remote session'

  # Teleporting again replaces the remote state the first session left.
  sandbox_pty_send 'z4m ssh plainhost'
  sandbox_pty_expect 60 '*__Z4M_PLAIN_READY__*' || {
    sandbox_fail 'host with default teleportation settings did not initialize'
    print -ru2 -- "${(q+)REPLY[-2000,-1]}"
  }
  sandbox_pty_send 'exit'
fi
sandbox_pty_stop

# --- Remote state -------------------------------------------------------------
local -a pwned=($SANDBOX/**/PWNED(DN))
(( ! $#pwned )) || sandbox_fail "teleported values executed as shell code: ${pwned[*]}"

[[ $(<$remote/.extra-config) == extra ]] 2>/dev/null ||
  sandbox_fail 'extra file was not sent to its home-relative destination'
[[ $(<$remote/$destination) == extra ]] 2>/dev/null ||
  sandbox_fail 'extra file was not sent to its explicit destination'
[[ -f $remote/.linked-config && ! -L $remote/.linked-config &&
   $(<$remote/.linked-config) == extra ]] 2>/dev/null ||
  sandbox_fail 'symlinked extra file was not materialized on the remote host'
[[ -r $remote/.config/tool/keep && ! -e $remote/.config/tool/skip.tmp ]] ||
  sandbox_fail 'directory transfer ignored its exclude patterns'
[[ -r $remote/.cache/zsh4monkey/zsh4monkey/main.zsh && -r $remote/.cache/zsh4monkey/z4m.zsh ]] ||
  sandbox_fail 'framework was not teleported into the remote cache'
[[ $(<$remote/.zshrc) == $(<$SANDBOX_HOME/.zshrc) ]] 2>/dev/null ||
  sandbox_fail 'local .zshrc was not teleported'

local -a leftovers=($remote/.z4m-ssh.*(DN) $remote/**/.z4m-ssh.*(DN) $remote/tmp/z4m-ssh.*(/DN))
(( ! $#leftovers )) || sandbox_fail "remote transaction state leaked: ${leftovers[*]}"
# The uploaded script can carry propagated values; only its owner may read it.
local -a readable_scripts=($remote/tmp/z4m-ssh.*(.DNf:go+r:))
(( ! $#readable_scripts )) || sandbox_fail "remote bootstrap script is readable by others: ${readable_scripts[*]}"
[[ $(<$SANDBOX/ssh.log) == *"-t plainhost '/bin/sh' "* ]] ||
  sandbox_fail 'configured interpreter was not used to run the remote bootstrap'
local -a local_staging=($SANDBOX_Z4M/tmp/ssh.*(DN))
(( ! $#local_staging )) || sandbox_fail "local staging leaked: ${local_staging[*]}"

# --- Pass-through -------------------------------------------------------------
# Hosts without teleportation, and invocations teleportation cannot handle, go
# to ssh unchanged.
: >$SANDBOX/ssh.log
sandbox_command 'z4m ssh otherhost true; z4m ssh -N testhost'
local log=$(<$SANDBOX/ssh.log)
[[ $log == *'otherhost true'* ]] || sandbox_fail 'host without teleportation was not passed through'
[[ $log == *'-N testhost'* ]] || sandbox_fail 'non-interactive ssh invocation was not passed through'
[[ $log != *' -T '* ]] || sandbox_fail 'pass-through invocation uploaded a bootstrap'

sandbox_expect_offline 'ssh teleportation'
(( SANDBOX_FAILURES == 0 ))
