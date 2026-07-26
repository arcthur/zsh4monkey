# Documentation: https://github.com/arcthur/zsh4monkey/blob/main/README.md.
#
# Do not modify this file unless you know exactly what you are doing.
# It is strongly recommended to keep all shell customization and configuration
# (including exported environment variables such as PATH) in ~/.zshrc or in
# files sourced from ~/.zshrc. If you are certain that you must export some
# environment variables in ~/.zshenv, do it where indicated by comments below.

if [ -n "${ZSH_VERSION-}" ]; then
  # If you are certain that you must export some environment variables
  # in ~/.zshenv (see comments at the top!), do it here:
  #
  #   export GOPATH=$HOME/go
  #
  # Do not change anything else in this file.

  : ${ZDOTDIR:=~}
  setopt no_global_rcs
  [[ -o no_interactive && -z "${Z4M_BOOTSTRAPPING-}" ]] && return
  setopt no_rcs
  unset Z4M_BOOTSTRAPPING
fi

: "${Z4M_URL:=https://raw.githubusercontent.com/arcthur/zsh4monkey/main}"
Z4M_BOOTSTRAP_SHA256=''
: "${Z4M:=${XDG_CACHE_HOME:-$HOME/.cache}/zsh4monkey}"

umask o-w

if [ ! -e "$Z4M"/z4m.zsh ]; then
  mkdir -p -- "$Z4M" || return
  >&2 printf '\033[33mz4m\033[0m: fetching \033[4mz4m.zsh\033[0m\n'
  if command -v curl >/dev/null 2>&1; then
    curl --connect-timeout 10 --max-time 120 --retry 2 -fsSL -- "$Z4M_URL"/z4m.zsh >"$Z4M"/z4m.zsh.$$ || return
  elif command -v wget >/dev/null 2>&1; then
    wget --timeout=120 --tries=2 -O- -- "$Z4M_URL"/z4m.zsh >"$Z4M"/z4m.zsh.$$ || return
  else
    >&2 printf '\033[33mz4m\033[0m: please install \033[32mcurl\033[0m or \033[32mwget\033[0m\n'
    return 1
  fi
  if [ -n "$Z4M_BOOTSTRAP_SHA256" ]; then
    case "$Z4M_BOOTSTRAP_SHA256" in
      *[!0-9a-f]*|'')
        >&2 printf '\033[33mz4m\033[0m: invalid bootstrap SHA-256\n'
        rm -f -- "$Z4M"/z4m.zsh.$$
        return 1
        ;;
    esac
    if [ "${#Z4M_BOOTSTRAP_SHA256}" -ne 64 ]; then
      >&2 printf '\033[33mz4m\033[0m: invalid bootstrap SHA-256\n'
      rm -f -- "$Z4M"/z4m.zsh.$$
      return 1
    fi
    if command -v sha256sum >/dev/null 2>&1; then
      z4m_bootstrap_actual="$(sha256sum "$Z4M"/z4m.zsh.$$)"
      z4m_bootstrap_actual="${z4m_bootstrap_actual%% *}"
    elif command -v shasum >/dev/null 2>&1; then
      z4m_bootstrap_actual="$(shasum -a 256 "$Z4M"/z4m.zsh.$$)"
      z4m_bootstrap_actual="${z4m_bootstrap_actual%% *}"
    elif command -v openssl >/dev/null 2>&1; then
      z4m_bootstrap_actual="$(openssl dgst -sha256 "$Z4M"/z4m.zsh.$$)"
      z4m_bootstrap_actual="${z4m_bootstrap_actual##* }"
    else
      >&2 printf '\033[33mz4m\033[0m: SHA-256 tool required for bootstrap verification\n'
      rm -f -- "$Z4M"/z4m.zsh.$$
      return 1
    fi
    z4m_bootstrap_actual="$(printf '%s' "$z4m_bootstrap_actual" | tr '[A-F]' '[a-f]')" || return
    if [ "$z4m_bootstrap_actual" != "$Z4M_BOOTSTRAP_SHA256" ]; then
      >&2 printf '\033[33mz4m\033[0m: bootstrap SHA-256 verification failed\n'
      rm -f -- "$Z4M"/z4m.zsh.$$
      unset z4m_bootstrap_actual
      return 1
    fi
    unset z4m_bootstrap_actual
  fi
  mv -- "$Z4M"/z4m.zsh.$$ "$Z4M"/z4m.zsh || return
fi

. "$Z4M"/z4m.zsh || return

setopt rcs
