#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail -o extended_glob

setopt local_options

cd -- "${0:A:h:h}" || exit 1
fpath=("$PWD/fn" $fpath)
autoload -Uz -- -z4m-ssh-parse-copy-spec

typeset -gi failures=0

assert_eq() {
  local expected=$1 actual=$2 label=$3
  if [[ $expected != $actual ]]; then
    print -ru2 -- "$label: expected [$expected], got [$actual]"
    ((failures++))
  fi
}

assert_ok() {
  local label=$1
  shift
  if ! "$@"; then
    print -ru2 -- "expected success: $label"
    ((failures++))
  fi
}

assert_fail() {
  local label=$1
  shift
  if "$@"; then
    print -ru2 -- "expected failure: $label"
    ((failures++))
  fi
}

tmpdir=$(command mktemp -d "${TMPDIR:-/tmp}/z4m-ssh-copy-spec.XXXXXXXXXX") || exit 1
trap 'rm -rf -- "$tmpdir"' EXIT

HOME=$tmpdir/home
mkdir -p -- "$HOME/.config/nvim" "$HOME/env-files" "$tmpdir/zdotdir" || exit 1
touch -- "$HOME/.nanorc" "$HOME/.config/nvim/init.lua" "$HOME/env-files/a" "$HOME/env-files/b" "$tmpdir/zdotdir/custom.zsh" || exit 1

typeset -a local_paths remote_paths exclude_specs

assert_ok 'plain home-relative source' -z4m-ssh-parse-copy-spec '~/.nanorc' "$tmpdir/zdotdir" local_paths remote_paths exclude_specs
assert_eq "$HOME/.nanorc" "$local_paths[1]" 'plain local path'
assert_eq '.nanorc' "$remote_paths[1]" 'plain remote path'
assert_eq '' "$exclude_specs[1]" 'plain exclude spec'

assert_ok 'explicit remote destination' -z4m-ssh-parse-copy-spec '--dest my-conf/zsh/.zshrc ~/.nanorc' "$tmpdir/zdotdir" local_paths remote_paths exclude_specs
assert_eq "$HOME/.nanorc" "$local_paths[1]" 'dest local path'
assert_eq 'my-conf/zsh/.zshrc' "$remote_paths[1]" 'dest remote path'

assert_ok 'glob source expansion' -z4m-ssh-parse-copy-spec '--glob env-files/*' "$tmpdir/zdotdir" local_paths remote_paths exclude_specs
assert_eq 2 "${#local_paths}" 'glob local count'
assert_eq "$HOME/env-files/a" "$local_paths[1]" 'glob first local path'
assert_eq 'env-files/a' "$remote_paths[1]" 'glob first remote path'
assert_eq "$HOME/env-files/b" "$local_paths[2]" 'glob second local path'
assert_eq 'env-files/b' "$remote_paths[2]" 'glob second remote path'

assert_ok 'zdotdir fallback when outside home' -z4m-ssh-parse-copy-spec '$ZDOTDIR/custom.zsh' "$tmpdir/zdotdir" local_paths remote_paths exclude_specs
assert_eq "$tmpdir/zdotdir/custom.zsh" "$local_paths[1]" 'zdotdir local path'
assert_eq 'custom.zsh' "$remote_paths[1]" 'zdotdir remote path'

assert_ok 'exclude patterns are captured' -z4m-ssh-parse-copy-spec "--exclude '*.tmp' --exclude '.git' ~/.config/nvim" "$tmpdir/zdotdir" local_paths remote_paths exclude_specs
assert_eq "$HOME/.config/nvim" "$local_paths[1]" 'exclude local path'
assert_eq '.config/nvim' "$remote_paths[1]" 'exclude remote path'
assert_eq $'*.tmp\n.git' "$exclude_specs[1]" 'exclude spec payload'

assert_fail 'dest with multi-match glob' -z4m-ssh-parse-copy-spec '--dest remote/path --glob env-files/*' "$tmpdir/zdotdir" local_paths remote_paths exclude_specs
assert_fail 'unsupported option' -z4m-ssh-parse-copy-spec '--unknown ~/.nanorc' "$tmpdir/zdotdir" local_paths remote_paths exclude_specs
assert_fail 'relative source with parent segment' -z4m-ssh-parse-copy-spec '../outside' "$tmpdir/zdotdir" local_paths remote_paths exclude_specs
assert_fail 'dest with parent segment' -z4m-ssh-parse-copy-spec '--dest ../remote/path ~/.nanorc' "$tmpdir/zdotdir" local_paths remote_paths exclude_specs
assert_fail 'absolute dest with dot segment' -z4m-ssh-parse-copy-spec '--dest /tmp/../remote ~/.nanorc' "$tmpdir/zdotdir" local_paths remote_paths exclude_specs

if (( failures )); then
  exit 1
fi
