#!/usr/bin/env zsh
#
# Documentation must follow the code. Each contract below is derived from the
# implementation and then checked file by file, so adding a command, an ssh
# style, or a copy-spec option without documenting it fails here.

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

cd -- "${0:A:h:h}" || exit 1

typeset -gi failures=0

# Usage: require_literal <file> <literal> <what>
require_literal() {
  command grep -qF -- "$2" "$1" && return
  print -ru2 -- "$1: does not document $3"
  (( ++failures ))
}

# Usage: require_regex <file> <extended-regex> <what>
require_regex() {
  command grep -qE -- "$2" "$1" && return
  print -ru2 -- "$1: does not document $3"
  (( ++failures ))
}

# --- Commands -----------------------------------------------------------------
# Every `z4m <name>` dispatches to fn/-z4m-cmd-<name>.
local -a z4m_commands=(fn/-z4m-cmd-*(N:t))
z4m_commands=(${z4m_commands#-z4m-cmd-})
(( $#z4m_commands > 10 )) || { print -ru2 -- 'failed to enumerate z4m commands'; exit 1 }

local name
for name in $z4m_commands; do
  require_literal fn/-z4m-cmd-help "%F{2}z4m%f %B$name%b" "command $name in the help overview"
  require_regex man/man1/z4m.1 "^\.It Cm $name( |\$)" "command $name"
  require_literal fn/_z4m "'$name:" "command $name in completion"
  require_literal docs/commands.md "\`z4m $name" "command $name"
done

# --- SSH styles ---------------------------------------------------------------
local -a ssh_styles=(${(u)${(M)${(f)"$(<fn/-z4m-cmd-ssh)"}:#*-z4m-ssh-zstyle-[ast] [a-z-]##*}})
ssh_styles=(${(u)${${ssh_styles##*-z4m-ssh-zstyle-[ast] }%% *}})
(( $#ssh_styles >= 5 )) || { print -ru2 -- "failed to enumerate ssh styles: $ssh_styles"; exit 1 }

local style file
for style in $ssh_styles; do
  for file in docs/ssh.md man/man1/z4m-ssh.1 fn/-z4m-cmd-help; do
    require_regex $file ":z4m:ssh:[^ ']*'? $style( |\$)" "ssh style $style"
  done
done

# --- Copy specs ---------------------------------------------------------------
# z4m ssh send-extra-files and z4m pack extra-files share the spec syntax.
local parser option
local -A spec_docs=(
  fn/-z4m-ssh-parse-copy-spec  'docs/ssh.md man/man1/z4m-ssh.1 fn/-z4m-cmd-help'
  fn/-z4m-pack-parse-copy-spec 'docs/design-pack.md fn/-z4m-cmd-help'
)
for parser in ${(k)spec_docs}; do
  local -a spec_options=(${(M)${(f)"$(<$parser)"}:#[[:space:]]#--[a-z]##\)})
  spec_options=(${${spec_options##[[:space:]]#}%\)})
  (( $#spec_options >= 3 )) || { print -ru2 -- "failed to enumerate options of $parser"; exit 1 }
  for option in $spec_options; do
    for file in ${=spec_docs[$parser]}; do
      require_literal $file "$option" "copy-spec option $option"
    done
  done
done

# --- SSH session behavior -----------------------------------------------------
# test/ssh_teleport_integration.zsh asserts the behavior; these are the places
# that promise it.
for file in docs/ssh.md man/man1/z4m-ssh.1; do
  require_regex $file 'autosuggestions are disabled in SSH sessions' 'disabled SSH autosuggestions'
  require_regex $file '[Ss]yntax highlighting is disabled in SSH sessions' 'disabled SSH highlighting'
  require_regex $file '[Ss]implified prompt is used in SSH sessions' 'the simplified SSH prompt'
done
for file in README.md docs/commands.md fn/-z4m-cmd-help man/man1/z4m.1; do
  require_regex $file '[Ss]implified prompt|disable inline autosuggestions and syntax highlighting' \
    'the simplified SSH session'
done

(( failures == 0 ))
