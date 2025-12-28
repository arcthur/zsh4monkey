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

Z4M_URL="https://raw.githubusercontent.com/arcthur/zsh4monkey/main"
: "${Z4M:=${XDG_CACHE_HOME:-$HOME/.cache}/zsh4monkey}"

umask o-w

if [ ! -e "$Z4M"/z4m.zsh ]; then
  mkdir -p -- "$Z4M" || return
  >&2 printf '\033[33mz4m\033[0m: fetching \033[4mz4m.zsh\033[0m\n'
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -- "$Z4M_URL"/z4m.zsh >"$Z4M"/z4m.zsh.$$ || return
  elif command -v wget >/dev/null 2>&1; then
    wget -O-   -- "$Z4M_URL"/z4m.zsh >"$Z4M"/z4m.zsh.$$ || return
  else
    >&2 printf '\033[33mz4m\033[0m: please install \033[32mcurl\033[0m or \033[32mwget\033[0m\n'
    return 1
  fi
  mv -- "$Z4M"/z4m.zsh.$$ "$Z4M"/z4m.zsh || return
fi

. "$Z4M"/z4m.zsh || return

setopt rcs
