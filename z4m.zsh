'[' '-n' "${TERM-}" ']' || 'export' TERM='xterm-256color'

'[' '-n' "${WT_SESSION-}" ']' && 'export' COLORTERM="${COLORTERM:-truecolor}"

if '[' '-n' "${ZSH_VERSION-}" ']'; then
  if '[' '-n' "${_z4m_source_called+x}" ']'; then
    if '[' "${ZDOTDIR:-$HOME}" '=' "$HOME" ']'; then
      >&2 'printf' '\033[33mz4m\033[0m: please use \033[4;32mexec\033[0m \033[32mzsh\033[0m instead of \033[32msource\033[0m \033[4m~/.zshenv\033[0m\n'
    else
      >&2 'printf' '\033[33mz4m\033[0m: please use \033[4;32mexec\033[0m \033[32mzsh\033[0m instead of \033[32msource\033[0m \033[4;33m"$ZDOTDIR"\033[0;4m/.zshenv\033[0m\n'
    fi
    'return' '1'
  fi

  'typeset' '-gri' _z4m_source_called='1'

  'emulate' 'zsh'
  'setopt'                                                                     \
    'always_to_end'          'auto_cd'                'auto_param_slash'       \
    'auto_pushd'             'c_bases'                'auto_menu'              \
    'extended_glob'          'extended_history'       'hist_expire_dups_first' \
    'hist_find_no_dups'      'hist_ignore_dups'       'hist_ignore_space'      \
    'hist_verify'            'interactive_comments'   'multios'                \
    'no_aliases'             'no_bg_nice'                                      \
    'no_flow_control'        'no_prompt_bang'         'no_prompt_subst'        \
    'prompt_cr'              'prompt_percent'         'prompt_sp'              \
    'share_history'          'typeset_silent'         'hist_save_no_dups'      \
    'no_auto_remove_slash'   'no_list_types'          'no_beep'

  if '[' '!' '-e' "${${TMPPREFIX:-/tmp/zsh}:h}" ']'; then
    if '[' '-n' "$TMPDIR" '-a' '-d' "$TMPDIR" '-a' '-w' "$TMPDIR" ']'; then
      'export' TMPPREFIX="${TMPDIR%/}/zsh"
    elif '[' '-d' "/tmp" '-a' '-w' "/tmp" ']'; then
      'export' TMPPREFIX="/tmp/zsh"
    fi
  fi

  if '[' "$TERMINFO" '!=' ~/'.terminfo' ']' && '[' '-e' ~/".terminfo/$TERM[1]/$TERM" ']'; then
    'export' TERMINFO=~/'.terminfo'
  fi

  'set' '-A' '_z4m_script_argv' "$@"

  # Save original shell options for propagation on re-exec
  'typeset' '-ga' '_z4m_original_opts'
  _z4m_original_opts=()
  [[ -o login ]] && _z4m_original_opts+=('-l')

  if '[' '-n' "${ZSH_SCRIPT+X}${ZSH_EXECUTION_STRING+X}" ']'; then
    'typeset' '-gri' _z4m_zle='0'
  else
    'typeset' '-gri' _z4m_zle='1'

    PS1="%B%F{2}%n@%m%f %F{4}%~%f
%F{%(?.2.1)}%#%f%b "
    RPS1="%B%F{3}z4m recovery mode%f%b"

    WORDCHARS=''
    ZLE_REMOVE_SUFFIX_CHARS=''
    HISTSIZE='1000000000'
    SAVEHIST='1000000000'

    if '[' '-n' "$HISTFILE" ']'; then
      'typeset' '-gri' _z4m_custom_histfile='1'
    else
      'typeset' '-gri' _z4m_custom_histfile='0'
      HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"
    fi

    if '[' '-n' "${_z4m_ssh_feedback-}" ']'; then
      { 'print' '-r' '--' "HISTFILE=${(q)HISTFILE}" >"$_z4m_ssh_feedback"; } 2>'/dev/null'
      'unset' '_z4m_ssh_feedback'
    fi

    if '[' '-n' "${_Z4M_LINES-}" '-a' '-n' "${_Z4M_COLUMNS-}" ']'; then
      'typeset' '-gi' LINES='_Z4M_LINES'
      'typeset' '-gi' COLUMNS='_Z4M_COLUMNS'
      'unset' '_Z4M_LINES' '_Z4M_COLUMNS'
    fi

    'bindkey' '-d'
    'bindkey' '-e'

    'bindkey' '-s' '^[OM'    '^M'
    'bindkey' '-s' '^[Ok'    '+'
    'bindkey' '-s' '^[Om'    '-'
    'bindkey' '-s' '^[Oj'    '*'
    'bindkey' '-s' '^[Oo'    '/'
    'bindkey' '-s' '^[OX'    '='
    'bindkey' '-s' '^[OH'    '^[[H'
    'bindkey' '-s' '^[OF'    '^[[F'
    'bindkey' '-s' '^[OA'    '^[[A'
    'bindkey' '-s' '^[OB'    '^[[B'
    'bindkey' '-s' '^[OD'    '^[[D'
    'bindkey' '-s' '^[OC'    '^[[C'
    'bindkey' '-s' '^[[1~'   '^[[H'
    'bindkey' '-s' '^[[4~'   '^[[F'
    'bindkey' '-s' '^[Od'    '^[[1;5D'
    'bindkey' '-s' '^[Oc'    '^[[1;5C'
    'bindkey' '-s' '^[^[[D'  '^[[1;3D'
    'bindkey' '-s' '^[^[[C'  '^[[1;3C'
    'bindkey' '-s' '^[[7~'   '^[[H'
    'bindkey' '-s' '^[[8~'   '^[[F'
    'bindkey' '-s' '^[[3\^'  '^[[3;5~'
    'bindkey' '-s' '^[^[[3~' '^[[3;3~'
    'bindkey' '-s' '^[[1;9D' '^[[1;3D'
    'bindkey' '-s' '^[[1;9C' '^[[1;3C'

    'bindkey' '^[[H'    'beginning-of-line'
    'bindkey' '^[[F'    'end-of-line'
    'bindkey' '^[[3~'   'delete-char'
    'bindkey' '^[[3;5~' 'kill-word'
    'bindkey' '^[[3;3~' 'kill-word'
    'bindkey' '^[k'     'backward-kill-line'
    'bindkey' '^[K'     'backward-kill-line'
    'bindkey' '^[j'     'kill-buffer'
    'bindkey' '^[J'     'kill-buffer'
    'bindkey' '^[/'     'redo'
    'bindkey' '^[[1;3D' 'backward-word'
    'bindkey' '^[[1;5D' 'backward-word'
    'bindkey' '^[[1;3C' 'forward-word'
    'bindkey' '^[[1;5C' 'forward-word'

    if '[' '-n' "${_Z4M_ORIG_CWD-}" ']'; then
      'builtin' 'cd' '-q' '--' "${(g:oce:)_Z4M_ORIG_CWD}" 2>'/dev/null' || 'builtin' 'cd' '-q'
      'builtin' 'unset' '_Z4M_ORIG_CWD'
      'builtin' 'eval' 'dirstack=()'
    else
      "builtin" "eval" '
        if [[ "${(%):-%1/}" == "z4m-tmux-cwd-"<->-<->-* ]]; then
          [[ -r "./tmux"(#qNU) ]] &&
            _z4m_x="$("builtin" "source" "--" "./tmux" "list-clients" "-F" "#{client_tty} #{pane_id}" 2>"/dev/null")" &&
            _z4m_x="${${(@M)${(f)_z4m_x}:#${${${(%):-%1/}#z4m-tmux-cwd-<->-<->-}//.//} %<->}##* }" &&
            [[ "$_z4m_x" == "%"<-> ]] &&
            _z4m_x="$("builtin" "source" "--" "./tmux" "display-message" "-t" "$_z4m_x" "-p" "#{pane_current_path}" 2>"/dev/null")" &&
            [[ -n "$_z4m_x" ]] &&
            "builtin" "cd" "-q" "--" "$_z4m_x" 2>"/dev/null" || "builtin" "cd" "-q"
          "builtin" "unset" "_z4m_x"
          dirstack=()
        fi'
    fi
  fi
fi

if '[' '-z' "${Z4M_UPDATING-}" '-a' '-n' "${Z4M-}" '-a' '-z' "${Z4M##/*}" '-a' '-e' "$Z4M"/.updating ']'; then
  'unset' '_z4m_update_pid'
  if '[' '-r' "$Z4M"/.updating ']'; then
    while 'IFS'='=' 'read' '-r' '_z4m_update_key' '_z4m_update_value'; do
      case "$_z4m_update_key" in
        'pid')
          case "$_z4m_update_value" in
            (''|*[!0-9]*) ;;
            (*) _z4m_update_pid="$_z4m_update_value" ;;
          esac
        ;;
      esac
    done <"$Z4M"/.updating
    'unset' '_z4m_update_key' '_z4m_update_value'
  fi
  _z4m_wait='0'
  while '[' "$_z4m_wait" '-lt' '400' '-a' '-e' "$Z4M"/.updating ']'; do
    if '[' '-n' "${_z4m_update_pid-}" ']'; then
      if ! 'command' 'kill' '-0' "$_z4m_update_pid" 2>'/dev/null'; then
        'command' 'rm' '-f' '--' "$Z4M"/.updating 2>'/dev/null'
        'break'
      fi
    fi
    'command' 'sleep' '0.05' 2>'/dev/null' || 'break'
    _z4m_wait="$((_z4m_wait + 1))"
  done
  'unset' '_z4m_wait' '_z4m_update_pid'
fi

if '[' '-n' "${Z4M_UPDATE_SOURCE_URL-}" ']'; then
  Z4M_URL=$Z4M_UPDATE_SOURCE_URL
  'unset' 'Z4M_UPDATE_SOURCE_URL'
fi

_z4m_cached_ref=
if '[' '-r' "${Z4M-}"/zsh4monkey/.z4m-source-ref ']'; then
  IFS= 'read' '-r' '_z4m_cached_ref' <"$Z4M"/zsh4monkey/.z4m-source-ref ||
    _z4m_cached_ref=
fi

_z4m_update_source_configured=
_z4m_update_source_effective=
_z4m_update_source_extra=
if '[' '-r' "${Z4M-}"/.update-source ']'; then
  IFS='|' 'read' '-r' \
    '_z4m_update_source_configured' \
    '_z4m_update_source_effective' \
    '_z4m_update_source_extra' <"$Z4M"/.update-source || :
  case "$_z4m_update_source_configured|$_z4m_update_source_effective|$_z4m_update_source_extra" in
    'https://raw.githubusercontent.com/arcthur/zsh4monkey/'*'|https://raw.githubusercontent.com/arcthur/zsh4monkey/'*'|')
      _z4m_update_source_configured_ref="${_z4m_update_source_configured##*/}"
      _z4m_update_source_effective_ref="${_z4m_update_source_effective##*/}"
      case "$_z4m_update_source_configured_ref" in
        ''|*[!A-Za-z0-9._-]*) ;;
        *) case "$_z4m_update_source_effective_ref" in
          ''|*[!A-Za-z0-9._-]*) ;;
          *)
          if '[' "${Z4M_URL-}" '=' "$_z4m_update_source_configured" -o \
                 "${Z4M_URL-}" '=' "$_z4m_update_source_effective" ']'; then
            Z4M_URL=$_z4m_update_source_effective
          fi
          ;;
        esac
        ;;
      esac
    ;;
  esac
fi
'unset' \
  '_z4m_update_source_configured' \
  '_z4m_update_source_effective' \
  '_z4m_update_source_extra' \
  '_z4m_update_source_configured_ref' \
  '_z4m_update_source_effective_ref'

if '[' '-n' "${Z4M-}" ']' &&
   '[' '-z' "${Z4M##/*}" '-a' '-r' "$Z4M"/zsh4monkey/main.zsh ']' &&
   {
     '[' "$_z4m_cached_ref" '=' "${Z4M_URL##*/}" ']' ||
       { '[' '-z' "$_z4m_cached_ref" ']' &&
         '[' "${Z4M_URL-}" '=' 'https://raw.githubusercontent.com/arcthur/zsh4monkey/main' ']'; }
   }; then
  'unset' '_z4m_cached_ref'
  if '.' "$Z4M"/zsh4monkey/main.zsh; then
    'setopt' 'aliases'
    'return'
  fi
  'unset' '_z4m_bootstrap'
else
  'unset' '_z4m_cached_ref'
  _z4m_bootstrap='1'
fi

if '[' '-n' "${_z4m_bootstrap-}" ']'; then
  'unset' '_z4m_bootstrap'
  (
    if '[' '-z' "${Z4M-}" ]; then
      >&2 'printf' '\033[33mz4m\033[0m: missing required parameter: \033[31mZ4M\033[0m\n'
      >&2 'printf' '\n'
      if '[' "${ZDOTDIR:-$HOME}" '=' "$HOME" ']'; then
        >&2 'printf' 'It must be set in \033[4m~/.zshenv\033[0m:\n'
      else
        >&2 'printf' 'It must be set in \033[4;33m"$ZDOTDIR"\033[0;4m/.zshenv\033[0m:\n'
      fi
      >&2 'printf' '\n'
      >&2 'printf' '  \033[32m:\033[0m \033[33m"${Z4M:=${XDG_CACHE_HOME:-$HOME/.cache}/zsh4monkey}"\033[0m\n'
      >&2 'printf' '\n'
      >&2 'printf' 'Note: The leading colon (\033[32m:\033[0m) is necessary.\n'
      'exit' '1'
    fi

    if '[' '-n' "${Z4M##/*}" ']'; then
      >&2 'printf' '\033[33mz4m\033[0m: invalid \033[1mZ4M\033[0m parameter: \033[31m%s\033[0m\n' "$Z4M"
      >&2 'printf' '\n'
      if '[' "${ZDOTDIR:-$HOME}" '=' "$HOME" ']'; then
        >&2 'printf' 'It comes from \033[4m~/.zshenv\033[0m. Correct value example:\n'
      else
        >&2 'printf' 'It comes from \033[4;33m"$ZDOTDIR"\033[0;4m/.zshenv\033[0m. Correct value example:\n'
      fi
      >&2 'printf' '\n'
      >&2 'printf' '  \033[32m:\033[0m \033[33m"${Z4M:=${XDG_CACHE_HOME:-$HOME/.cache}/zsh4monkey}"\033[0m\n'
      >&2 'printf' '\n'
      >&2 'printf' 'Note: The leading colon (\033[32m:\033[0m) is necessary.\n'
      'exit' '1'
    fi

    if '[' '!' '-r' "$Z4M"/z4m.zsh ']'; then
      >&2 'printf' '\033[33mz4m\033[0m: confusing \033[4mz4m.zsh\033[0m location\n'
      >&2 'printf' '\n'
      if '[' "${ZDOTDIR:-$HOME}" '=' "$HOME" ']'; then
        >&2 'printf' 'Please fix \033[4m~/.zshenv\033[0m. Correct initialization example:\n'
      else
        >&2 'printf' 'Please fix \033[4;33m"$ZDOTDIR"\033[0;4m/.zshenv\033[0m. Correct initialization example:\n'
      fi
      >&2 'printf' '\n'
      >&2 'printf' '  \033[32m:\033[0m \033[33m"${Z4M:=${XDG_CACHE_HOME:-$HOME/.cache}/zsh4monkey}"\033[0m\n'
      >&2 'printf' '  \033[32m.\033[0m \033[4;33m"$Z4M"\033[0;4m/z4m.zsh\033[0m || \033[32mreturn\033[0m\n'
      >&2 'printf' '\n'
      >&2 'printf' 'Note: The leading colon (\033[32m:\033[0m) and dot (\033[32m.\033[0m) are necessary.\n'
      'exit' '1'
    fi

    if '[' '-z' "${Z4M_URL-}" ']'; then
      >&2 'printf' '\033[33mz4m\033[0m: missing required parameter: \033[31mZ4M_URL\033[0m\n'
      >&2 'printf' '\n'
      if '[' "${ZDOTDIR:-$HOME}" '=' "$HOME" ']'; then
        >&2 'printf' 'It must be set at the top of \033[4m~/.zshenv\033[0m:\n'
      else
        >&2 'printf' 'It must be set at the top of \033[4;33m"$ZDOTDIR"\033[0;4m/.zshenv\033[0m:\n'
      fi
      >&2 'printf' '\n'
      >&2 'printf' '  Z4M_URL=\033[33m"https://raw.githubusercontent.com/arcthur/zsh4monkey/main"\033[0m\n'
      'exit' '1'
    fi

    v="${Z4M_URL#https://raw.githubusercontent.com/arcthur/zsh4monkey/}"

    if '[' '-z' "$v" ']' || '[' "$v" '=' "$Z4M_URL" ']'; then
      >&2 'printf' '\033[33mz4m\033[0m: invalid \033[1mZ4M_URL\033[0m: \033[31m%s\033[0m\n' "$Z4M_URL"
      >&2 'printf' '\n'
      if '[' "${ZDOTDIR:-$HOME}" '=' "$HOME" ']'; then
        >&2 'printf' 'It comes from \033[4m~/.zshenv\033[0m. Correct value example:\n'
      else
        >&2 'printf' 'It comes from \033[4;33m"$ZDOTDIR"\033[0;4m/.zshenv\033[0m. Correct value example:\n'
      fi
      >&2 'printf' '\n'
      >&2 'printf' '  Z4M_URL=\033[33m"https://raw.githubusercontent.com/arcthur/zsh4monkey/main"\033[0m\n'
      'exit' '1'
    fi

    case "$v" in
      ''|*[!A-Za-z0-9._-]*)
        >&2 'printf' '\033[33mz4m\033[0m: unsafe ref in \033[1mZ4M_URL\033[0m: \033[31m%s\033[0m\n' "$v"
        'exit' '1'
      ;;
    esac

    if '[' '-e' "$Z4M"/.updating ']'; then
      >&2 'printf' '\033[33mz4m\033[0m: updating \033[1m%s\033[0m\n' "zsh4monkey"
    else
      >&2 'printf' '\033[33mz4m\033[0m: installing \033[1m%s\033[0m\n' "zsh4monkey"
    fi

    if '[' '-n' "${HOME-}" ']'                    &&
       '[' "$Z4M" = "$HOME"/.cache/zsh4monkey ']' &&
       command -v 'id' >'/dev/null' 2>&1; then
      euid="$('command' 'id' '-u')" || 'exit'
      if '[' "$euid" '=' '0' ']'; then
        home_ls="$('command' 'ls' '-ld' '--' "$HOME")" || 'exit'
        home_owner="$('printf' '%s\n' "$home_ls" | 'command' 'awk' 'NR==1 {print $3}')" || 'exit'
        if '[' "$home_owner" '!=' 'root' ']'; then
          >&2 'printf' '\033[33mz4m\033[0m: refusing to \033[1minstall\033[0m as \033[31mroot\033[0m\n'
          'command' 'rm' '-rf' '--' "$HOME"/.cache/zsh4monkey 2>'/dev/null' &&
            'command' 'rmdir' '--' "$HOME"/.cache 2>'/dev/null'
          'exit' '1'
        fi
      fi
    fi

    dir="$Z4M"/zsh4monkey

    if command -v 'mktemp' >'/dev/null' 2>&1; then
      tmpdir="$('command' 'mktemp' '-d' "$dir".XXXXXXXXXX)"
    else
      tmpdir="$dir".tmp."$$"
      'command' 'rm' '-rf' '--' "$tmpdir" || 'exit'
      'command' 'mkdir' '--' "$tmpdir"    || 'exit'
    fi

    (
      if '[' '-n' "${Z4M_BOOTSTRAP_COMMAND-}" ']'; then
        Z4M_PACKAGE_NAME='zsh4monkey'
        Z4M_PACKAGE_DIR="$tmpdir"/zsh4monkey-"$v"
        'eval' "$Z4M_BOOTSTRAP_COMMAND" || 'exit'
      fi

      if '[' '-z' "${Z4M_BOOTSTRAP_COMMAND-}" ']'; then
        case "$v" in
          v[0-9]*)
            url="https://github.com/arcthur/zsh4monkey/releases/download/$v/zsh4monkey-$v.tar.gz"
            checksum_url="$url.sha256"
          ;;
          *)
            url="https://github.com/arcthur/zsh4monkey/archive/$v.tar.gz"
            checksum_url=
          ;;
        esac

        download_rc='0'
        checksum_rc='0'
        if command -v 'curl' >'/dev/null' 2>&1; then
          err="$('command' 'curl' '--connect-timeout' '10' '--max-time' '120' '--retry' '2' '-fsSL' '--' "$url" 2>&1 >"$tmpdir"/snapshot.tar.gz)" ||
            download_rc="$?"
          if '[' "$download_rc" '=' '0' ']' && '[' '-n' "$checksum_url" ']'; then
            checksum_err="$('command' 'curl' '--connect-timeout' '10' '--max-time' '120' '--retry' '2' '-fsSL' '--' "$checksum_url" 2>&1 >"$tmpdir"/snapshot.tar.gz.sha256)" ||
              checksum_rc="$?"
          fi
        elif command -v 'wget' >'/dev/null' 2>&1; then
          err="$('command' 'wget' '--timeout=120' '--tries=2' '-O-' '--' "$url" 2>&1 >"$tmpdir"/snapshot.tar.gz)" ||
            download_rc="$?"
          if '[' "$download_rc" '=' '0' ']' && '[' '-n' "$checksum_url" ']'; then
            checksum_err="$('command' 'wget' '--timeout=120' '--tries=2' '-O-' '--' "$checksum_url" 2>&1 >"$tmpdir"/snapshot.tar.gz.sha256)" ||
              checksum_rc="$?"
          fi
        else
          >&2 'printf' '\033[33mz4m\033[0m: please install \033[32mcurl\033[0m or \033[32mwget\033[0m\n'
          'exit' '1'
        fi

        if '[' "$download_rc" '!=' '0' ']'; then
          >&2 'printf' "%s\n" "$err"
          >&2 'printf' '\033[33mz4m\033[0m: failed to download \033[31m%s\033[0m\n' "$url"
          'exit' '1'
        fi

        if '[' '-n' "$checksum_url" ']'; then
          if '[' "$checksum_rc" '!=' '0' ']' ||
             '[' '!' '-s' "$tmpdir"/snapshot.tar.gz.sha256 ']'; then
            >&2 'printf' "%s\n" "$checksum_err"
            >&2 'printf' '\033[33mz4m\033[0m: failed to download checksum \033[31m%s\033[0m\n' "$checksum_url"
            'exit' '1'
          fi
          expected="$('command' 'awk' 'NR == 1 { print $1 }' "$tmpdir"/snapshot.tar.gz.sha256)" || 'exit'
          case "$expected" in
            *[!0-9a-f]*|'')
              >&2 'printf' '\033[33mz4m\033[0m: invalid SHA-256 for \033[31m%s\033[0m\n' "$url"
              'exit' '1'
            ;;
          esac
          if '[' "${#expected}" '!=' '64' ']'; then
            >&2 'printf' '\033[33mz4m\033[0m: invalid SHA-256 for \033[31m%s\033[0m\n' "$url"
            'exit' '1'
          fi

          if command -v 'sha256sum' >'/dev/null' 2>&1; then
            actual="$('command' 'sha256sum' "$tmpdir"/snapshot.tar.gz)"
            actual="${actual%% *}"
          elif command -v 'shasum' >'/dev/null' 2>&1; then
            actual="$('command' 'shasum' '-a' '256' "$tmpdir"/snapshot.tar.gz)"
            actual="${actual%% *}"
          elif command -v 'openssl' >'/dev/null' 2>&1; then
            actual="$('command' 'openssl' 'dgst' '-sha256' "$tmpdir"/snapshot.tar.gz)"
            actual="${actual##* }"
          else
            >&2 'printf' '\033[33mz4m\033[0m: SHA-256 tool required for release verification\n'
            'exit' '1'
          fi
          actual="$('printf' '%s' "$actual" | 'command' 'tr' '[A-F]' '[a-f]')" || 'exit'
          if '[' "$actual" '!=' "$expected" ']'; then
            >&2 'printf' '\033[33mz4m\033[0m: SHA-256 verification failed for \033[31m%s\033[0m\n' "$url"
            'exit' '1'
          fi
          if command -v 'gh' >'/dev/null' 2>&1; then
            if ! attestation_err="$('command' 'gh' 'attestation' 'verify' "$tmpdir"/snapshot.tar.gz \
                '--repo' 'arcthur/zsh4monkey' \
                '--signer-workflow' 'arcthur/zsh4monkey/.github/workflows/release.yml' \
                2>&1 >'/dev/null')"; then
              >&2 'printf' '\033[33mz4m\033[0m: release provenance verification failed for \033[31m%s\033[0m\n' "$url"
              '[' '-z' "$attestation_err" ']' || >&2 'printf' '%s\n' "$attestation_err"
              >&2 'printf' '\033[33mz4m\033[0m: authenticate with \033[32mgh auth login\033[0m or set \033[1mGH_TOKEN\033[0m if GitHub requires credentials\n'
              'exit' '1'
            fi
          elif '[' "${Z4M_ALLOW_CHECKSUM_ONLY_RELEASES-}" '=' '1' ']' ; then
            >&2 'printf' '\033[33mz4m\033[0m: \033[33mwarning\033[0m: accepting checksum-only release without provenance verification\n'
          else
            >&2 'printf' '\033[33mz4m\033[0m: GitHub CLI is required for release provenance verification\n'
            >&2 'printf' '\033[33mz4m\033[0m: install \033[32mgh\033[0m or explicitly set \033[1mZ4M_ALLOW_CHECKSUM_ONLY_RELEASES=1\033[0m\n'
            'exit' '1'
          fi
        elif '[' "$v" '=' 'main' ']' && '[' '-z' "${Z4M_UNVERIFIED_WARNING_SHOWN-}" ']'; then
          >&2 'printf' '\033[33mz4m\033[0m: \033[33mwarning\033[0m: development channel is not release-verified\n'
          'export' Z4M_UNVERIFIED_WARNING_SHOWN='1'
        fi

        # sc/supply-chain does not exist yet during bootstrap, so the archive
        # safety check is inlined here. The two awk programs are kept textually
        # identical and test/bootstrap_duplication.zsh fails if they drift.
        if ! 'command' 'tar' '-tzf' "$tmpdir"/snapshot.tar.gz >"$tmpdir"/snapshot.list 2>'/dev/null' ||
           ! 'command' 'tar' '-tvzf' "$tmpdir"/snapshot.tar.gz >"$tmpdir"/snapshot.verbose 2>'/dev/null' ||
           ! 'command' 'awk' '
             BEGIN { safe = 1 }
             /^\// { safe = 0 }
             {
               count = split($0, parts, "/")
               for (i = 1; i <= count; i++) {
                 if (parts[i] == "..") {
                   safe = 0
                 }
               }
             }
             END { exit safe ? 0 : 1 }
           ' "$tmpdir"/snapshot.list ||
           ! 'command' 'awk' '
             BEGIN { safe = 1 }
             substr($0, 1, 1) == "h" { safe = 0 }
             substr($0, 1, 1) == "l" {
               marker = " -> "
               offset = index($0, marker)
               if (!offset) {
                 safe = 0
                 next
               }
               target = substr($0, offset + length(marker))
               if (index(target, marker)) {
                 safe = 0
                 next
               }
               if (target ~ /^\//) {
                 safe = 0
                 next
               }
               count = split(target, parts, "/")
               for (i = 1; i <= count; i++) {
                 if (parts[i] == "..") {
                   safe = 0
                 }
               }
             }
             END { exit safe ? 0 : 1 }
           ' "$tmpdir"/snapshot.verbose; then
          >&2 'printf' '\033[33mz4m\033[0m: unsafe archive content for \033[31m%s\033[0m\n' "$url"
          'exit' '1'
        fi
        'command' 'tar' '-C' "$tmpdir" '-xzf' "$tmpdir"/snapshot.tar.gz || 'exit'
      fi

      package_dir="$tmpdir"/zsh4monkey-"$v"
      if '[' '!' '-e' "$package_dir"/version ']' &&
         '[' '-d' "$package_dir" ']' &&
         '[' '-r' "$Z4M"/zsh4monkey/version ']'; then
        if '[' '-r' "$Z4M"/z4m.zsh ']'; then
          'command' 'cp' '-p' -- "$Z4M"/z4m.zsh "$package_dir"/z4m.zsh || 'exit'
          'command' 'rm' '-f' -- "$package_dir"/z4m.zsh.zwc || 'exit'
        fi
        for overlay in \
          'version' \
          'fn/-z4m-read-version' \
          'fn/-z4m-cmd-ssh' \
          'fn/-z4m-cmd-version' \
          'fn/-z4m-ssh-maybe-update'; do
          '[' '-r' "$Z4M"/zsh4monkey/"$overlay" ']' || continue
          'command' 'cp' '-p' -- "$Z4M"/zsh4monkey/"$overlay" "$package_dir"/"$overlay" || 'exit'
          'command' 'rm' '-f' -- "$package_dir"/"$overlay".zwc || 'exit'
        done
      fi

      '[' '-d' "$package_dir" ']' || 'exit'
      'printf' '%s\n' "$v" >"$package_dir"/.z4m-source-ref || 'exit'

      if '[' '-e' "$Z4M"/.updating ']'; then
        if '[' '-z' "${Z4M_UPDATING-}" ']'; then
          >&2 'printf' '\033[33mz4m\033[0m: \033[1mZ4M_UPDATING\033[0m does not propagate through \033[32mzsh\033[0m\n'
          >&2 'printf' '\n'
          >&2 'printf' 'Change \033[32mzsh\033[0m startup files to keep \033[1mZ4M_UPDATING\033[0m intact.\n'
          'exit' '1'
        fi
        "sh" "$tmpdir"/zsh4monkey-"$v"/sc/setup '-n' "$Z4M" '-o' "$Z4M_UPDATING" || 'exit'
      else
        "sh" "$tmpdir"/zsh4monkey-"$v"/sc/setup '-n' "$Z4M"                      || 'exit'
      fi
      'command' 'rm' '-rf' '--' "$dir"                          || 'exit'
      'command' 'mv' '-f' '--' "$tmpdir"/zsh4monkey-"$v" "$dir" || 'exit'
    )

    ret="$?"
    'command' 'rm' '-rf' '--' "$tmpdir" || 'exit'
    'exit' "$ret"
  ) && '.' "$Z4M"/zsh4monkey/main.zsh && 'setopt' 'aliases' && 'return'
fi

'[' '-n' "${ZSH_VERSION-}" ']' && 'setopt' 'aliases'

>&2 'printf' '\n'
>&2 'printf' '\033[33mz4m\033[0m: \033[31mcommand failed\033[0m: \033[32m.\033[0m \033[4;33m"$Z4M"\033[0m\033[4m/z4m.zsh\033[0m\n'

'[' '-e' "$Z4M"/.updating ']' && 'return' '1'

# Create failure marker for next startup
'[' '-n' "$Z4M" ']' && 'printf' '' >"$Z4M"/.last-init-failed 2>/dev/null

>&2 'printf' '\033[33mz4m\033[0m: entering \033[1mrecovery shell\033[0m\n'
>&2 'printf' '\n'

# Try to enter full recovery shell if we have zsh and the recovery function
if '[' '-n' "${ZSH_VERSION-}" ']' && '[' '-r' "$Z4M"/zsh4monkey/fn/-z4m-recovery-shell ']'; then
  >&2 'printf' 'Loading recovery environment...\n'
  >&2 'printf' '\n'
  'autoload' '-Uz' "$Z4M"/zsh4monkey/fn/-z4m-recovery-shell
  -z4m-recovery-shell
  'return' '0'
fi

# Fallback: provide manual recovery instructions
>&2 'printf' 'See error messages above to identify the culprit.\n'
>&2 'printf' '\n'
>&2 'printf' 'Edit Zsh configuration:\n'
>&2 'printf' '\n'
if [ "${ZDOTDIR:-$HOME}" '=' "$HOME" ]; then
  >&2 'printf' '  \033[32m%s\033[0m \033[4m~/.zshrc\033[0m\n' "${VISUAL:-${EDITOR:-vi}}"
else
  >&2 'printf' '  \033[32m%s\033[0m \033[4;33m"$ZDOTDIR"\033[0;4m/.zshrc\033[0m\n' "${VISUAL:-${EDITOR:-vi}}"
fi
if command -v 'zsh' >'/dev/null' 2>&1; then
  >&2 'printf' '\n'
  >&2 'printf' 'Retry Zsh initialization:\n'
  >&2 'printf' '\n'
  >&2 'printf' '  \033[4;32mexec\033[0m \033[32mzsh\033[0m\n'
fi
if '[' '-n' "${ZSH_VERSION-}" ']' && command -v 'z4m' >'/dev/null' 2>&1; then
  >&2 'printf' '\n'
  >&2 'printf' 'If errors persist and you are desperate:\n'
  >&2 'printf' '\n'
  >&2 'printf' '  \033[32mz4m\033[0m \033[1mreset\033[0m\n'
fi
if '[' '-n' "$Z4M" '-a' '-z' "${Z4M##/*}" '-a' '-r' "$Z4M"/z4m.zsh ']'; then
  >&2 'printf' '\n'
  >&2 'printf' 'Preserve the current cache before a clean reinstall:\n'
  >&2 'printf' '\n'
  >&2 'printf' '  \033[32mmv\033[0m -- \033[4;33m"%s"\033[0m \033[4;33m"%s.failed.$$"\033[0m\n' "$Z4M" "$Z4M"
fi
if command -v 'curl' >'/dev/null' 2>&1; then
  >&2 'printf' '\n'
  >&2 'printf' 'Download, verify, and run the stable installer:\n'
  >&2 'printf' '\n'
  >&2 'printf' '  z4m_installer=$(\033[32mmktemp\033[0m)\n'
  >&2 'printf' '  \033[32mcurl\033[0m -fsSLo "$z4m_installer" \033[4mhttps://github.com/arcthur/zsh4monkey/releases/latest/download/install\033[0m\n'
  >&2 'printf' '  \033[32mgh\033[0m attestation verify "$z4m_installer" --repo arcthur/zsh4monkey \\\n'
  >&2 'printf' '    --signer-workflow arcthur/zsh4monkey/.github/workflows/release.yml\n'
  >&2 'printf' '  \033[32msh\033[0m "$z4m_installer"\n'
  >&2 'printf' '  \033[32mrm\033[0m -f -- "$z4m_installer"\n'
elif command -v 'wget' >'/dev/null' 2>&1; then
  >&2 'printf' '\n'
  >&2 'printf' 'Download, verify, and run the stable installer:\n'
  >&2 'printf' '\n'
  >&2 'printf' '  z4m_installer=$(\033[32mmktemp\033[0m)\n'
  >&2 'printf' '  \033[32mwget\033[0m -O "$z4m_installer" \033[4mhttps://github.com/arcthur/zsh4monkey/releases/latest/download/install\033[0m\n'
  >&2 'printf' '  \033[32mgh\033[0m attestation verify "$z4m_installer" --repo arcthur/zsh4monkey \\\n'
  >&2 'printf' '    --signer-workflow arcthur/zsh4monkey/.github/workflows/release.yml\n'
  >&2 'printf' '  \033[32msh\033[0m "$z4m_installer"\n'
  >&2 'printf' '  \033[32mrm\033[0m -f -- "$z4m_installer"\n'
fi

>&2 'printf' '\n'

'return' '1'
