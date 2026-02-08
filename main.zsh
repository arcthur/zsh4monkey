if '[' '-z' "${ZSH_VERSION-}" ']' || ! 'eval' '[[ "$ZSH_VERSION" == (5.<9->*|<6->.*) ]]'; then
  '.' "$Z4M"/zsh4monkey/sc/exec-zsh-i || 'return'
fi

if [[ -x /proc/self/exe ]]; then
  typeset -gr _z4m_exe=${${:-/proc/self/exe}:P}
else
  () {
    emulate zsh -o posix_argzero -c 'local exe=${0#-}'
    if [[ $SHELL == /* && ${SHELL:t} == $exe && -x $SHELL ]]; then
      exe=$SHELL
    elif (( $+commands[$exe] )); then
      exe=$commands[$exe]
    elif [[ -x $exe ]]; then
      exe=${exe:a}
    else
      print -Pru2 -- "%F{3}z4m%f: unable to find path to %F{1}zsh%f"
      return 1
    fi
    typeset -gr _z4m_exe=${exe:P}
  } || return
fi

if ! { zmodload -s zsh/terminfo zsh/zselect && [[ -n $^fpath/compinit(#qN) ]] ||
       [[ $ZSH_PATCHLEVEL == zsh-5.9-*-g* && $_z4m_exe == */bin/zsh &&
          -e ${_z4m_exe:h:h}/share/zsh/5.9/scripts/relocate ]] }; then
  builtin source $Z4M/zsh4monkey/sc/exec-zsh-i || return
fi

if [[ ! -o interactive ]]; then
  # print -Pru2 -- "%F{3}z4m%f: starting interactive %F{2}zsh%f"
  # This is caused by Z4M_BOOTSTRAPPING, so we don't need to consult ZSH_SCRIPT and the like.
  exec -- $_z4m_exe -i || return
fi

# Recovery mode: skip z4m initialization and enter minimal shell
if [[ -n ${_Z4M_RECOVERY_MODE-} ]]; then
  unset _Z4M_RECOVERY_MODE
  autoload -Uz $Z4M/zsh4monkey/fn/-z4m-recovery-shell
  -z4m-recovery-shell
  return 0
fi

# Safe mode: skip plugins but keep basic shell functional
# Triggered by: Z4M_SAFE_MODE=1, $Z4M/.safe-mode file, or previous startup failure
if [[ -n ${Z4M_SAFE_MODE-} || -e $Z4M/.safe-mode || -e $Z4M/.last-init-failed ]]; then
  unset Z4M_SAFE_MODE
  zmodload zsh/{parameter,system} 2>/dev/null
  zmodload -F zsh/files b:zf_rm 2>/dev/null
  autoload -Uz $Z4M/zsh4monkey/fn/-z4m-safe-mode-init
  -z4m-safe-mode-init
  return 0
fi

# Standard zsh4monkey emulation options (for reference)
# Use: emulate -L zsh -o typeset_silent -o pipe_fail -o extended_glob \
#     -o prompt_percent -o no_prompt_subst -o no_prompt_bang -o no_bg_nice -o no_aliases

zmodload zsh/{datetime,langinfo,parameter,system,terminfo,zutil} || return
zmodload -F zsh/files b:{zf_mkdir,zf_mv,zf_rm,zf_rmdir,zf_ln}    || return
zmodload -F zsh/stat b:zstat                                     || return

() {
  if [[ $1 != $Z4M/zsh4monkey/main.zsh ]]; then
    print -Pru2 -- "%F{3}z4m%f: confusing %Umain.zsh%u location: %F{1}${1//\%/%%}%f"
    return 1
  fi
  if (( _z4m_zle )); then
    typeset -gr _z4m_param_pat=$'ZDOTDIR=$ZDOTDIR\0Z4M=$Z4M\0Z4M_URL=$Z4M_URL'
    typeset -gr _z4m_param_sig=${(e)_z4m_param_pat}
    function -z4m-check-core-params() {
      [[ "${(e)_z4m_param_pat}" == "$_z4m_param_sig" ]] || {
        -z4m-error-param-changed
        return 1
      }
    }
  else
    function -z4m-check-core-params() {}
  fi
} ${${(%):-%x}:a} || return

export -T MANPATH=${MANPATH:-:} manpath
export -T INFOPATH=${INFOPATH:-:} infopath
typeset -gaU cdpath fpath mailpath path manpath infopath

function -z4m-init-homebrew() {
  (( ARGC )) || return 0
  local dir=${1:h:h}
  export HOMEBREW_PREFIX=$dir
  export HOMEBREW_CELLAR=$dir/Cellar
  if [[ -e $dir/Homebrew/Library ]]; then
    export HOMEBREW_REPOSITORY=$dir/Homebrew
  else
    export HOMEBREW_REPOSITORY=$dir
  fi
}

if [[ $OSTYPE == darwin* ]]; then
  if [[ ! -e $Z4M/cache/init-darwin-paths ]] || ! source $Z4M/cache/init-darwin-paths; then
    autoload -Uz $Z4M/zsh4monkey/fn/-z4m-gen-init-darwin-paths
    -z4m-gen-init-darwin-paths && source $Z4M/cache/init-darwin-paths
  fi
  [[ -z $HOMEBREW_PREFIX ]] && -z4m-init-homebrew {/opt/homebrew,/usr/local}/bin/brew(N)
elif [[ $OSTYPE == linux* && -z $HOMEBREW_PREFIX ]]; then
  -z4m-init-homebrew {/home/linuxbrew/.linuxbrew,~/.linuxbrew}/bin/brew(N)
fi

fpath=(
  ${^${(M)fpath:#*/$ZSH_VERSION/functions}/%$ZSH_VERSION\/functions/site-functions}(-/N)
  ${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/share/zsh/site-functions}(-/N)
  /opt/homebrew/share/zsh/site-functions(-/N)
  /usr{/local,}/share/zsh/{site-functions,vendor-completions}(-/N)
  $fpath
  $Z4M/zsh4monkey/fn)

autoload -Uz -- $Z4M/zsh4monkey/fn/(|-|_)z4m[^.]#(:t) || return
functions -Ms _z4m_err

() {
  path=(${@:|path} $path /snap/bin(-/N))
} {~/bin,~/.local/bin,~/.cargo/bin,${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/bin},${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/sbin},/opt/local/sbin,/opt/local/bin,/usr/local/sbin,/usr/local/bin}(-/N)

() {
  manpath=(${@:|manpath} "${manpath[@]}" '')
} {$Z4M/zsh4monkey/man,${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/share/man},/opt/local/share/man}(-/N)

() {
  infopath=(${@:|infopath} $infopath '')
} {${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/share/info},/opt/local/share/info}(-/N)

if [[ $ZSH_PATCHLEVEL == zsh-5.9-*-g* && $_z4m_exe == */bin/zsh &&
      -e ${_z4m_exe:h:h}/share/zsh/5.9/scripts/relocate ]]; then
  if [[ $TERMINFO != ~/.terminfo && $TERMINFO != ${_z4m_exe:h:h}/share/terminfo &&
        -e ${_z4m_exe:h:h}/share/terminfo/$TERM[1]/$TERM ]]; then
    export TERMINFO=${_z4m_exe:h:h}/share/terminfo
  fi
  if [[ -e ${_z4m_exe:h:h}/share/man ]]; then
    manpath=(${_z4m_exe:h:h}/share/man $manpath '')
  fi
fi

path+=($Z4M/fzf/bin)
manpath+=($Z4M/fzf/man)

: ${GITSTATUS_CACHE_DIR=$Z4M/cache/gitstatus}
: ${ZSH=$Z4M/ohmyzsh/ohmyzsh}
: ${ZSH_CUSTOM=$Z4M/ohmyzsh/ohmyzsh/custom}
: ${ZSH_CACHE_DIR=$Z4M/cache/ohmyzsh}

[[ $terminfo[Tc] == yes && -z $COLORTERM ]] && export COLORTERM=truecolor

if [[ $EUID == 0 && -z ~(#qNU) && $Z4M == ~/* ]]; then
  typeset -gri _z4m_dangerous_root=1
else
  typeset -gri _z4m_dangerous_root=0
fi

[[ $langinfo[CODESET] == (utf|UTF)(-|)8 ]] || -z4m-fix-locale

function -z4m-cmd-source() {
  local _z4m_file _z4m_compile
  zparseopts -D -F -- c=_z4m_compile -compile=_z4m_compile || return '_z4m_err()'
  emulate zsh -o extended_glob -c 'local _z4m_files=(${^${(M)@:#/*}}(N) $Z4M/${^${@:#/*}}(N))'
  if (( ${#_z4m_compile} )); then
    builtin set --
    for _z4m_file in "${_z4m_files[@]}"; do
      -z4m-compile "$_z4m_file" || true
      builtin source -- "$_z4m_file"
    done
  else
    emulate zsh -o extended_glob -c 'local _z4m_rm=(${^${(@)_z4m_files:#$Z4M/*}}.zwc(N))'
    (( ! ${#_z4m_rm} )) || zf_rm -f -- "${_z4m_rm[@]}" || true
    builtin set --
    for _z4m_file in "${_z4m_files[@]}"; do
      builtin source -- "$_z4m_file"
    done
  fi
}

function -z4m-cmd-load() {
  local -a compile
  zparseopts -D -F -- c=compile -compile=compile || return '_z4m_err()'

  local -a files

  () {
    emulate -L zsh -o extended_glob
    local pkgs=(${(M)@:#/*} $Z4M/${^${@:#/*}})
    pkgs=(${^${(u)pkgs}}(-/FN))
    local dirs=(${^pkgs}/functions(-/FN))
    local funcs=(${^dirs}/^([_.]*|prompt_*_setup|README*|*~|*.zwc)(-.N:t))
    fpath+=($pkgs $dirs)
    (( $#funcs )) && autoload -Uz -- $funcs
    local dir
    for dir in $pkgs; do
      if [[ -s $dir/init.zsh ]]; then
        files+=($dir/init.zsh)
      elif [[ -s $dir/${dir:t}.plugin.zsh ]]; then
        files+=($dir/${dir:t}.plugin.zsh)
      fi
    done
  } "$@"

  -z4m-cmd-source "${compile[@]}" -- "${files[@]}"
}

function -z4m-cmd-init() {
  if (( ARGC )); then
    print -ru2 -- ${(%):-"%F{3}z4m%f: unexpected %F{1}init%f argument"}
    return '_z4m_err()'
  fi
  if (( ${+_z4m_init_called} )); then
    if [[ ${funcfiletrace[-1]} != zsh:0 ]]; then
      if '[' "${ZDOTDIR:-$HOME}" '=' "$HOME" ']'; then
        >&2 'printf' '\033[33mz4m\033[0m: please use \033[4;32mexec\033[0m \033[32mzsh\033[0m instead of \033[32msource\033[0m \033[4m~/.zshrc\033[0m\n'
      else
        >&2 'printf' '\033[33mz4m\033[0m: please use \033[4;32mexec\033[0m \033[32mzsh\033[0m instead of \033[32msource\033[0m \033[4;33m"$ZDOTDIR"\033[0;4m/.zshrc\033[0m\n'
      fi
      'return' '1'
    fi
    print -ru2 -- ${(%):-"%F{3}z4m%f: %F{1}init%f cannot be called more than once"}
    return '_z4m_err()'
  fi
  -z4m-check-core-params || return
  typeset -gri _z4m_init_called=1

  () {
    emulate -L zsh -o typeset_silent -o pipe_fail -o extended_glob \
    -o prompt_percent -o no_prompt_subst -o no_prompt_bang -o no_bg_nice -o no_aliases

    (( _z4m_dangerous_root || $+Z4M_SSH ))                                                   ||
      ! zstyle -T :z4m: chsh                                                                 ||
      [[ ${SHELL-} == $_z4m_exe || ${SHELL-} -ef $_z4m_exe || -e $Z4M/stickycache/no-chsh ]] ||
      -z4m-chsh                                                                              ||
      true

    local -a start_tmux
    local -i install_tmux need_restart
    if [[ -n $MC_TMPDIR ]]; then
      start_tmux=(no)
    else
      # 'integrated', 'isolated', 'system', or 'command' <cmd> [arg]...
      zstyle -a :z4m: start-tmux start_tmux || start_tmux=(isolated)
      if (( $#start_tmux == 1 )); then
        case $start_tmux[1] in
          integrated|isolated) install_tmux=1;;
          system)     start_tmux=(command tmux -u);;
        esac
      fi
    fi

    if [[ -n $_Z4M_TMUX_TTY && $_Z4M_TMUX_TTY != $TTY ]]; then
      [[ $TMUX == $_Z4M_TMUX ]] && unset TMUX TMUX_PANE
      unset _Z4M_TMUX _Z4M_TMUX_PANE _Z4M_TMUX_CMD _Z4M_TMUX_TTY
    elif [[ -n $_Z4M_TMUX_CMD ]]; then
      install_tmux=1
    fi

    if ! [[ _z4m_zle -eq 1 && -o zle && -t 0 && -t 1 && -t 2 ]]; then
      unset _Z4M_TMUX _Z4M_TMUX_PANE _Z4M_TMUX_CMD _Z4M_TMUX_TTY
    else
      local -a match mbegin mend
      if [[ $TMUX == (#b)(/*),(|<->),(|<->) && -w $match[1] ]]; then
        if (( $+commands[tmux] )); then
          export _Z4M_TMUX=$TMUX
          export _Z4M_TMUX_PANE=$TMUX_PANE
          export _Z4M_TMUX_CMD=$commands[tmux]
          export _Z4M_TMUX_TTY=$TTY
          if [[ $TMUX == */z4m-tmux-* ]]; then
            unset TMUX TMUX_PANE
          fi
        else
          unset _Z4M_TMUX _Z4M_TMUX_PANE _Z4M_TMUX_CMD _Z4M_TMUX_TTY
          print -P '%F{yellow}z4m:%f tmux not found, some features disabled' >&2
        fi
        if [[ -n $_Z4M_TMUX && -t 1 ]] &&
           zstyle -T :z4m: prompt-at-bottom &&
           ! zselect -t0 -r 0; then
          local cursor_y cursor_x
          -z4m-get-cursor-pos 1 || cursor_y=0
          local -i n='LINES - cursor_y'
          print -rn -- ${(pl:$n::\n:)}
        fi
      elif (( install_tmux )) &&
           [[ -z $TMUX && ! -w ${_Z4M_TMUX%,(|<->),(|<->)} && -z $Z4M_SSH ]]; then
        unset _Z4M_TMUX _Z4M_TMUX_PANE _Z4M_TMUX_CMD _Z4M_TMUX_TTY TMUX TMUX_PANE
        if (( $+commands[tmux] )); then
          # We prefer /tmp over $TMPDIR for better compatibility with
          # wide character rendering in some terminals.
          local sock
          if [[ -n $TMUX_TMPDIR && -d $TMUX_TMPDIR && -w $TMUX_TMPDIR ]]; then
            sock=$TMUX_TMPDIR
          elif [[ -d /tmp && -w /tmp ]]; then
            sock=/tmp
          elif [[ -n $TMPDIR && -d $TMPDIR && -w $TMPDIR ]]; then
            sock=$TMPDIR
          fi
          if [[ -n $sock ]]; then
            local sock_suf=''
            local -a cmds=()
            sock=${sock%/}/z4m-tmux-$UID
            if (( terminfo[colors] >= 256 )); then
              cmds+=(set -g default-terminal tmux-256color ';')
              if [[ $COLORTERM == (24bit|truecolor) ]]; then
                cmds+=(set -ga terminal-features ',*:RGB:usstyle:overline' ';')
                sock_suf+='-tc'
              fi
            else
              cmds+=(set -g default-terminal screen ';')
            fi
            if [[ $start_tmux[1] == isolated ]]; then
              sock+=-$sysparams[pid]
            else
              sock+=-$TERM$sock_suf
              if [[ -e $Z4M/tmux/stamp ]]; then
                # Append a unique per-installation number to the socket path to work
                # around a bug in tmux. See https://github.com/romkatv/zsh4monkey/issues/71.
                local stamp
                IFS= read -r stamp <$Z4M/tmux/stamp || return
                sock+=-${stamp%%.*}
              fi
            fi
            # Propagate CWD to new tmux windows/panes (default: enabled)
            if zstyle -T :z4m: propagate-cwd && [[ -n $TTY && $TTY != *(.| )* ]]; then
              if [[ $PWD == /* && $PWD -ef . ]]; then
                local orig_dir=$PWD
              else
                local orig_dir=${${:-.}:a}
              fi
              if [[ -n "$TMPDIR" && ( ( -d "$TMPDIR" && -w "$TMPDIR" ) || ! ( -d /tmp && -w /tmp ) ) ]]; then
                local tmpdir=$TMPDIR
              else
                local tmpdir=/tmp
              fi
              local dir=$tmpdir/z4m-tmux-cwd-$UID-$$-${TTY//\//.}
              {
                zf_mkdir -p -- $dir &&
                  print -r -- "TMUX=${(q)sock} TMUX_PANE= ${(q)commands[tmux]} "'"$@"' >$dir/tmux &&
                  builtin cd -q -- $dir
              } 2>/dev/null
              if (( $? )); then
                zf_rm -rf -- "$dir" 2>/dev/null
                local exec=
              else
                export _Z4M_ORIG_CWD=$orig_dir
                local exec=
              fi
            else
              local exec=exec
            fi
            SHELL=$_z4m_exe _Z4M_LINES=$LINES _Z4M_COLUMNS=$COLUMNS \
              builtin $exec - $commands[tmux] -u -S $sock -f $Z4M/zsh4monkey/.tmux.conf -- \
              "${cmds[@]}" new >/dev/null || return
            [[ -z $exec ]] || return
            builtin cd /
            zf_rm -rf -- $dir 2>/dev/null
            builtin exit 0
          fi
        else
          need_restart=1
        fi
      elif [[ -z $TMUX && $start_tmux[1] == command ]] && (( $+commands[$start_tmux[2]] )); then
        if [[ -d $Z4M/terminfo ]]; then
          SHELL=$_z4m_exe exec - ${start_tmux:1} || return
        else
          need_restart=1
        fi
      fi
    fi

    _z4m_install_queue+=(
      zsh-completions
      terminfo fzf powerlevel10k)
    (( install_tmux )) && _z4m_install_queue+=(tmux)
    if ! -z4m-install-many; then
      [[ -e $Z4M/.updating ]] || -z4m-error-command init
      return 1
    fi
    if (( _z4m_installed_something )); then
      if [[ $TERMINFO != ~/.terminfo && -e ~/.terminfo/$TERM[1]/$TERM ]]; then
        export TERMINFO=~/.terminfo
      fi
      if (( need_restart )); then
        print -ru2 ${(%):-"%F{3}z4m%f: restarting %F{2}zsh%f"}
        exec -- $_z4m_exe -i || return
      else
        print -ru2 ${(%):-"%F{3}z4m%f: initializing %F{2}zsh%f"}
        export P9K_TTY=old
      fi
    fi

    if [[ -w $TTY ]]; then
      typeset -gi _z4m_tty_fd
      sysopen -o cloexec -rwu _z4m_tty_fd -- $TTY || return
      typeset -gri _z4m_tty_fd
    elif [[ -w /dev/tty ]]; then
      typeset -gi _z4m_tty_fd
      if sysopen -o cloexec -rwu _z4m_tty_fd -- /dev/tty 2>/dev/null; then
        typeset -gri _z4m_tty_fd
      else
        unset _z4m_tty_fd
      fi
    fi

    if [[ -v _z4m_tty_fd && (-n $Z4M_SSH && -n $_Z4M_SSH_MARKER || -n $_Z4M_TMUX) ]]; then
      typeset -gri _z4m_can_save_restore_screen=1  # this parameter is read by p10k
    else
      typeset -gri _z4m_can_save_restore_screen=0  # this parameter is read by p10k
    fi

    if (( _z4m_zle )) && zstyle -t :z4m:direnv enable && [[ -e $Z4M/cache/direnv ]]; then
      -z4m-direnv-init 0 || return '_z4m_err()'
    fi

    local rc_zwcs=($ZDOTDIR/{.zshenv,.zprofile,.zshrc,.zlogin,.zlogout}.zwc(N))
    if (( $#rc_zwcs )); then
      -z4m-check-rc-zwcs $rc_zwcs || return '_z4m_err()'
    fi

    typeset -gr _z4m_orig_shell=${SHELL-}
  } || return

  : ${ZLE_RPROMPT_INDENT:=0}

  # Enable Powerlevel10k instant prompt.
  (( ! _z4m_zle )) || zstyle -t :z4m:powerlevel10k channel none || () {
    local user=${(%):-%n}
    local XDG_CACHE_HOME=$Z4M/cache/powerlevel10k
    [[ -r $XDG_CACHE_HOME/p10k-instant-prompt-$user.zsh ]] || return 0
    builtin source $XDG_CACHE_HOME/p10k-instant-prompt-$user.zsh
  }

  () {
    emulate -L zsh -o typeset_silent -o pipe_fail -o extended_glob \
      -o prompt_percent -o no_prompt_subst -o no_prompt_bang -o no_bg_nice -o no_aliases
    if -z4m-init; then
      # Success: clear any failure marker and stale log
      zf_rm -f -- $Z4M/.last-init-failed $Z4M/cache/last-init-failed.log 2>/dev/null
      unset _z4m_init_failed_step _z4m_init_failed_rc
      return 0
    fi
    # Failure: create marker for next startup
    local -i rc=$?
    local -a lines=(
      "type=init"
      "epoch=$EPOCHSECONDS"
      "pid=$sysparams[pid]"
      "ppid=$sysparams[ppid]"
      "rc=$rc"
      "fail_step=${_z4m_init_failed_step-}"
      "fail_step_rc=${_z4m_init_failed_rc-}"
      "zsh_version=$ZSH_VERSION"
      "zsh_patchlevel=${ZSH_PATCHLEVEL-}"
      "ostype=$OSTYPE"
      "term=${TERM-}"
      "tty=${TTY-}"
      "z4m_dir=$Z4M"
      "zdotdir=${ZDOTDIR:-$HOME}"
      "exe=$_z4m_exe"
      "ssh=${Z4M_SSH-}"
    )
    zf_mkdir -p -- $Z4M/cache 2>/dev/null || true
    print -l -- "${lines[@]}" >$Z4M/cache/last-init-failed.log 2>/dev/null || true
    print -l -- "${lines[@]}" >$Z4M/.last-init-failed 2>/dev/null || true
    unset _z4m_init_failed_step _z4m_init_failed_rc
    [[ -e $Z4M/.updating ]] || -z4m-error-command init
    return 1
  }
  setopt hist_fcntl_lock
}

function -z4m-cmd-install() {
  emulate -L zsh -o typeset_silent -o pipe_fail -o extended_glob \
    -o prompt_percent -o no_prompt_subst -o no_prompt_bang -o no_bg_nice -o no_aliases
  -z4m-check-core-params || return

	  local -a flush
	  zparseopts -D -F -- f=flush -flush=flush || return '_z4m_err()'

  local -a args=("$@")
	  local -i empty=0
	  local arg
	  for arg in "${args[@]}"; do
	    [[ -n $arg ]] || (( empty++ ))
	  done
	  if (( empty )); then
	    # Avoid failing update/init due to accidental empty arguments such as:
	    #   z4m install "$SOME_VAR"
	    # where $SOME_VAR is unset/empty.
	    args=("${(@)args:#}")
	    if (( ! ${+_z4m_warned_install_empty_arg} )); then
	      typeset -gi _z4m_warned_install_empty_arg=1
	      local where=${funcfiletrace[-1]-}
	      if [[ -n $where ]]; then
	        print -Pru2 -- "%F{3}z4m%f: %F{3}warning%f: ignoring empty project name passed to %Binstall%b (%F{4}${where//\%/%%}%f)"
	      else
	        print -Pru2 -- "%F{3}z4m%f: %F{3}warning%f: ignoring empty project name passed to %Binstall%b"
	      fi
	    fi
  fi

  local -a builtin_removed=(zsh-autosuggestions zsh-users/zsh-autosuggestions)
  local -a removed=()
  local pkg_name
  for pkg_name in "${args[@]}"; do
    (( ${builtin_removed[(Ie)$pkg_name]} )) && removed+=("$pkg_name")
  done
  if (( $#removed )); then
    print -Pru2 -- "%F{3}z4m%f: %Binstall%b: autosuggestions is built-in and no longer installable"
    print -Pru2 -- ""
    print -Pru2 -- "Remove this from %U.zshrc%u:"
    print -Prlu2 -- "  %F{1}${(q)^removed//\\%/%%}%f"
    return 1
  fi

  # Allow both user/repo format and simple names for built-in packages.
  local -a builtin_pkgs=(eza bat fd rg zoxide fzf carapace atuin)
	  local pattern="(([^/]##/)##[^/]##|${(j:|:)builtin_pkgs})"
	  local invalid=("${(@)args:#$~pattern}")
	  if (( $#invalid )); then
	    print -Pru2 -- '%F{3}z4m%f: %Binstall%b: invalid project name(s)'
	    print -Pru2 -- ''
	    print -Prlu2 -- '  %F{1}'${(q)^invalid//\%/%%}'%f'
    return 1
  fi
  _z4m_install_queue+=("${args[@]}")
  (( $#flush && $#_z4m_install_queue )) || return 0
  -z4m-install-many && return
  -z4m-error-command install
  return 1
}

# Main zsh4monkey function. Type `z4m help` for usage.
function z4m() {
  if (( ${+functions[-z4m-cmd-${1-}]} )); then
    -z4m-cmd-"$1" "${@:2}"
  else
    -z4m-cmd-help >&2
    return 1
  fi
}

[[ ${Z4M_SSH-} != <1->:* ]] || -z4m-ssh-maybe-update || return
