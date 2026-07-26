#!/usr/bin/env zsh

emulate -L zsh -o no_aliases -o pipe_fail

cd -- "${0:A:h:h}" || exit 1

typeset -gi failures=0
typeset test_dir
test_dir=$(mktemp -d) || exit 1
trap 'rm -rf -- "$test_dir"' EXIT

if ! command tar --version 2>/dev/null | command grep -q 'GNU tar'; then
  exit 0
fi
if ! git show HEAD:install | command grep -q "^z4m_default_install_ref='main'$"; then
  exit 0
fi

typeset release_tag
release_tag=$(command sh tools/version-tag) || exit 1
command sh tools/build-release "$release_tag" "$test_dir/release" || exit 1
command sh tools/build-release "$release_tag" "$test_dir/release-repeat" || exit 1

if ! (
  cd -- "$test_dir/release" &&
    command sha256sum -c SHA256SUMS >/dev/null
); then
  print -ru2 -- 'release checksum verification failed'
  (( ++failures ))
fi

if ! command cmp -s \
    "$test_dir/release/SHA256SUMS" \
    "$test_dir/release-repeat/SHA256SUMS"; then
  print -ru2 -- 'release artifacts are not deterministic'
  (( ++failures ))
fi

typeset package_name=zsh4monkey-$release_tag
typeset archive=$test_dir/release/$package_name.tar.gz
typeset extracted=$test_dir/extracted
mkdir -p -- "$extracted" || exit 1
command tar -C "$extracted" -xzf "$archive" || exit 1
for required in \
    version \
    z4m.zsh \
    main.zsh \
    dependencies.lock \
    sc/supply-chain \
    tools/version-tag; do
  if [[ ! -e $extracted/$package_name/$required ]]; then
    print -ru2 -- "release archive is missing: $required"
    (( ++failures ))
  fi
done
if [[ $(command sh "$extracted/$package_name/tools/version-tag") != $release_tag ]]; then
  print -ru2 -- 'release archive version does not match its tag'
  (( ++failures ))
fi

if ! command grep -q "^z4m_default_install_ref='$release_tag'$" "$test_dir/release/install"; then
  print -ru2 -- 'release installer ref was not pinned'
  (( ++failures ))
fi

for variable in \
    z4m_default_z4m_sha256 \
    z4m_default_zshenv_sha256 \
    z4m_default_zshrc_sha256 \
    z4m_default_zshrc_mac_sha256; do
  if ! command grep -Eq "^${variable}='[0-9a-f]{64}'$" "$test_dir/release/install"; then
    print -ru2 -- "release installer digest was not embedded: $variable"
    (( ++failures ))
  fi
done

typeset expected_bootstrap_sha
expected_bootstrap_sha=$(command sha256sum "$extracted/$package_name/z4m.zsh")
expected_bootstrap_sha=${expected_bootstrap_sha%% *}
if ! command grep -q \
    "^z4m_default_z4m_sha256='$expected_bootstrap_sha'$" \
    "$test_dir/release/install"; then
  print -ru2 -- 'release installer bootstrap digest does not match archive content'
  (( ++failures ))
fi

for pattern in \
    'actions/attest@[0-9a-f]{40}' \
    repository_dispatch \
    'environment: release' \
    'latest_tag=.*gh release view' \
    'sort -V' \
    'gh release create.*--draft' \
    'gh release upload.*--clobber' \
    'gh release edit.*--draft=false'; do
  if ! rg -n --color=never "$pattern" .github/workflows/release.yml >/dev/null; then
    print -ru2 -- "release workflow is missing contract: $pattern"
    (( ++failures ))
  fi
done

for parser in z4m.zsh README.md SECURITY.md; do
  if ! rg -F -- '--signer-workflow' "$parser" >/dev/null ||
     ! rg -F -- 'arcthur/zsh4monkey/.github/workflows/release.yml' \
       "$parser" >/dev/null; then
    print -ru2 -- "release verification does not bind the signer workflow: $parser"
    (( ++failures ))
  fi
done

(( failures == 0 ))
