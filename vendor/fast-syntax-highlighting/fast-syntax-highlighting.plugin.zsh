# -------------------------------------------------------------------------------------------------
# Copyright (c) 2010-2016 zsh-syntax-highlighting contributors
# Copyright (c) 2017-2019 Sebastian Gniazdowski (modifications)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted
# provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice, this list of conditions
#    and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright notice, this list of
#    conditions and the following disclaimer in the documentation and/or other materials provided
#    with the distribution.
#  * Neither the name of the zsh-syntax-highlighting contributors nor the names of its contributors
#    may be used to endorse or promote products derived from this software without specific prior
#    written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------


# Resolve plugin directory from source path.
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

typeset -g FAST_HIGHLIGHT_VERSION=1.55
typeset -g FAST_BASE_DIR="${0:h}"
typeset -ga _FAST_MAIN_CACHE
typeset -ga _FAST_COMPLEX_BRACKETS

# FAST_WORK_DIR must be set by the caller (z4m sets it before sourcing).
typeset -g FAST_WORK_DIR=${FAST_WORK_DIR:-${FAST_BASE_DIR-}}
FAST_WORK_DIR=${~FAST_WORK_DIR}

if [[ -z ${fpath[(r)${0:h}]-} ]]; then
    fpath+=( "${0:h}" )
fi

if [[ ! -w $FAST_WORK_DIR ]]; then
    FAST_WORK_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/fsh"
    command mkdir -p "$FAST_WORK_DIR"
fi

# Invokes each highlighter that needs updating.
# This function is supposed to be called whenever the ZLE state changes.
_zsh_highlight()
{
  # Store the previous command return code to restore it whatever happens.
  local ret=$?

  # Remove all highlighting in isearch, so that only the underlining done by zsh itself remains.
  # For details see FAQ entry 'Why does syntax highlighting not work while searching history?'.
  if [[ $WIDGET == zle-isearch-update ]] && ! (( $+ISEARCHMATCH_ACTIVE )); then
    region_highlight=()
    return $ret
  fi

  emulate -LR zsh
  setopt extendedglob warncreateglobal typesetsilent noshortloops

  local REPLY # don't leak $REPLY into global scope
  local -a reply

  # Do not highlight if there are more than 300 chars in the buffer. It's most
  # likely a pasted command or a huge list of files in that case..
  [[ -n ${ZSH_HIGHLIGHT_MAXLENGTH:-} ]] && [[ $#BUFFER -gt $ZSH_HIGHLIGHT_MAXLENGTH ]] && return $ret

  # Do not highlight if there are pending inputs (copy/paste).
  [[ $PENDING -gt 0 ]] && return $ret

  # Reset region highlight to build it from scratch
  # may need to remove path_prefix highlighting when the line ends
  if [[ $WIDGET == zle-line-finish ]] || _zsh_highlight_buffer_modified; then
      -fast-highlight-init
      -fast-highlight-process "$PREBUFFER" "$BUFFER" 0
      (( FAST_HIGHLIGHT[use_brackets] )) && {
          _FAST_MAIN_CACHE=( $reply )
          -fast-highlight-string-process "$PREBUFFER" "$BUFFER"
      }
      region_highlight=( $reply )
  else
      local char="${BUFFER[CURSOR+1]}"
      if [[ "$char" = ["{([])}"] || "${FAST_HIGHLIGHT[prev_char]}" = ["{([])}"] ]]; then
          FAST_HIGHLIGHT[prev_char]="$char"
          (( FAST_HIGHLIGHT[use_brackets] )) && {
              reply=( $_FAST_MAIN_CACHE )
              -fast-highlight-string-process "$PREBUFFER" "$BUFFER"
              region_highlight=( $reply )
          }
      fi
  fi

  {
    local cache_place
    local -a region_highlight_copy

    # Re-apply zle_highlight settings

    # region
    if (( REGION_ACTIVE == 1 )); then
      _zsh_highlight_apply_zle_highlight region standout "$MARK" "$CURSOR"
    elif (( REGION_ACTIVE == 2 )); then
      () {
        local needle=$'\n'
        integer min max
        if (( MARK > CURSOR )) ; then
          min=$CURSOR max=$(( MARK + 1 ))
        else
          min=$MARK max=$CURSOR
        fi
        (( min = ${${BUFFER[1,$min]}[(I)$needle]} ))
        (( max += ${${BUFFER:($max-1)}[(i)$needle]} - 1 ))
        _zsh_highlight_apply_zle_highlight region standout "$min" "$max"
      }
    fi

    # yank / paste (zsh-5.1.1 and newer)
    (( $+YANK_ACTIVE )) && (( YANK_ACTIVE )) && _zsh_highlight_apply_zle_highlight paste standout "$YANK_START" "$YANK_END"

    # isearch
    (( $+ISEARCHMATCH_ACTIVE )) && (( ISEARCHMATCH_ACTIVE )) && _zsh_highlight_apply_zle_highlight isearch underline "$ISEARCHMATCH_START" "$ISEARCHMATCH_END"

    # suffix
    (( $+SUFFIX_ACTIVE )) && (( SUFFIX_ACTIVE )) && _zsh_highlight_apply_zle_highlight suffix bold "$SUFFIX_START" "$SUFFIX_END"

    return $ret

  } always {
    typeset -g _ZSH_HIGHLIGHT_PRIOR_BUFFER="$BUFFER"
    typeset -g _ZSH_HIGHLIGHT_PRIOR_RACTIVE="$REGION_ACTIVE"
    typeset -gi _ZSH_HIGHLIGHT_PRIOR_CURSOR=$CURSOR
  }
}

# Apply highlighting based on entries in the zle_highlight array.
# This function takes four arguments:
# 1. The exact entry (no patterns) in the zle_highlight array:
#    region, paste, isearch, or suffix
# 2. The default highlighting that should be applied if the entry is unset
# 3. and 4. Two integer values describing the beginning and end of the
#    range. The order does not matter.
_zsh_highlight_apply_zle_highlight() {
  local entry="$1" default="$2"
  integer first="$3" second="$4"

  # read the relevant entry from zle_highlight
  local region="${zle_highlight[(r)${entry}:*]}"

  if [[ -z "$region" ]]; then
    # entry not specified at all, use default value
    region=$default
  else
    # strip prefix
    region="${region#${entry}:}"

    # no highlighting when set to the empty string or to 'none'
    if [[ -z "$region" ]] || [[ "$region" == none ]]; then
      return
    fi
  fi

  integer start end
  if (( first < second )); then
    start=$first end=$second
  else
    start=$second end=$first
  fi
  region_highlight+=("$start $end $region")
}


# -------------------------------------------------------------------------------------------------
# API/utility functions for highlighters
# -------------------------------------------------------------------------------------------------

# Whether the command line buffer has been modified or not.
#
# Returns 0 if the buffer has changed since _zsh_highlight was last called.
_zsh_highlight_buffer_modified()
{
  [[ "${_ZSH_HIGHLIGHT_PRIOR_BUFFER:-}" != "$BUFFER" ]] || [[ "$REGION_ACTIVE" != "$_ZSH_HIGHLIGHT_PRIOR_RACTIVE" ]] || { _zsh_highlight_cursor_moved && [[ "$REGION_ACTIVE" = 1 || "$REGION_ACTIVE" = 2 ]] }
}

# Whether the cursor has moved or not.
#
# Returns 0 if the cursor has moved since _zsh_highlight was last called.
_zsh_highlight_cursor_moved()
{
  [[ -n ${_ZSH_HIGHLIGHT_PRIOR_CURSOR-} ]] && (( _ZSH_HIGHLIGHT_PRIOR_CURSOR != CURSOR ))
}

# -------------------------------------------------------------------------------------------------
# Setup functions
# -------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------------
# Setup
# -------------------------------------------------------------------------------------------------

# Reset scratch variables when commandline is done.
_zsh_highlight_preexec_hook()
{
  typeset -g _ZSH_HIGHLIGHT_PRIOR_BUFFER=
  typeset -gi _ZSH_HIGHLIGHT_PRIOR_CURSOR=0
  typeset -ga _FAST_MAIN_CACHE
  _FAST_MAIN_CACHE=()
}

# Load zsh/parameter module if available
zmodload zsh/parameter 2>/dev/null
zmodload zsh/system 2>/dev/null

autoload -Uz -- .fast-run-git-command \
                .fast-make-targets .fast-run-command .fast-zts-read-all
autoload -Uz -- →chroma/-git.ch →chroma/-hub.ch →chroma/-lab.ch →chroma/-example.ch \
                →chroma/-grep.ch →chroma/-perl.ch →chroma/-make.ch →chroma/-awk.ch \
                →chroma/-vim.ch →chroma/-source.ch →chroma/-sh.ch →chroma/-docker.ch →chroma/-podman.ch \
                →chroma/-autoload.ch →chroma/-ssh.ch →chroma/-scp.ch →chroma/-which.ch \
                →chroma/-printf.ch →chroma/-ruby.ch →chroma/-whatis.ch →chroma/-alias.ch \
                →chroma/-subcommand.ch →chroma/-autorandr.ch →chroma/-nmcli.ch \
                →chroma/-node.ch →chroma/-fpath_peq.ch \
                →chroma/-precommand.ch →chroma/-subversion.ch →chroma/-ionice.ch \
                →chroma/-nice.ch →chroma/main-chroma.ch →chroma/-ogit.ch

source "${0:h}/fast-highlight"
source "${0:h}/fast-string-highlight"

local __fsyh_theme
zstyle -s :plugin:fast-syntax-highlighting theme __fsyh_theme

[[ ( "${+termcap}" != 1 || "${termcap[Co]}" != <-> || "${termcap[Co]}" -lt "256" ) && "$__fsyh_theme" = (default|) ]] && {
    FAST_HIGHLIGHT_STYLES[defaultvariable]="none"
    FAST_HIGHLIGHT_STYLES[defaultglobbing-ext]="fg=blue,bold"
    FAST_HIGHLIGHT_STYLES[defaulthere-string-text]="bg=blue"
    FAST_HIGHLIGHT_STYLES[defaulthere-string-var]="fg=cyan,bg=blue"
    FAST_HIGHLIGHT_STYLES[defaultcorrect-subtle]="bg=blue"
    FAST_HIGHLIGHT_STYLES[defaultsubtle-bg]="bg=blue"
    [[ "${FAST_HIGHLIGHT_STYLES[variable]}" = "fg=113" ]] && FAST_HIGHLIGHT_STYLES[variable]="none"
    [[ "${FAST_HIGHLIGHT_STYLES[globbing-ext]}" = "fg=13" ]] && FAST_HIGHLIGHT_STYLES[globbing-ext]="fg=blue,bold"
    [[ "${FAST_HIGHLIGHT_STYLES[here-string-text]}" = "bg=18" ]] && FAST_HIGHLIGHT_STYLES[here-string-text]="bg=blue"
    [[ "${FAST_HIGHLIGHT_STYLES[here-string-var]}" = "fg=cyan,bg=18" ]] && FAST_HIGHLIGHT_STYLES[here-string-var]="fg=cyan,bg=blue"
    [[ "${FAST_HIGHLIGHT_STYLES[correct-subtle]}" = "fg=12" ]] && FAST_HIGHLIGHT_STYLES[correct-subtle]="bg=blue"
    [[ "${FAST_HIGHLIGHT_STYLES[subtle-bg]}" = "bg=18" ]] && FAST_HIGHLIGHT_STYLES[subtle-bg]="bg=blue"
}

unset __fsyh_theme

-fast-highlight-fill-option-variables

if [[ ! -e $FAST_WORK_DIR/secondary_theme.zsh ]] {
    command rm -f "$FAST_WORK_DIR/secondary_theme.zsh.zwc" 2>/dev/null
    if [[ -r ${0:h}/share/free_theme.zsh ]]; then
        command cp -f -- ${0:h}/share/free_theme.zsh "$FAST_WORK_DIR/secondary_theme.zsh" 2>/dev/null || :
    fi
    [[ -e $FAST_WORK_DIR/secondary_theme.zsh ]] || : >| "$FAST_WORK_DIR/secondary_theme.zsh"
}

if [[ $OSTYPE = darwin* ]] {
    typeset -gA FAST_HIGHLIGHT
    FAST_HIGHLIGHT[chroma-man]=
}

[[ ${COLORTERM-} == (24bit|truecolor) || ${terminfo[colors]} -eq 16777216 ]] || zmodload zsh/nearcolor &>/dev/null || true
