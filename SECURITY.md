# Security Policy

## Release Trust Model

Three mechanisms protect a stable installation. They are not equally strong, and
treating them as interchangeable is the most common way to end up with less
protection than expected:

- **GitHub artifact attestation** is the only independent anchor. It binds the
  archive to this repository's release workflow through Sigstore, so it still
  holds if a release asset is replaced after publication. Stable bootstrap and
  update require GitHub CLI for exactly this check.
- **The `.sha256` sidecar** is served by the same host as the archive it
  describes. It detects transport corruption and nothing more: whoever can
  replace the archive can replace the sidecar. It is not a second opinion.
- **`Z4M_BOOTSTRAP_SHA256`**, written into the generated `~/.zshenv`, pins the
  bootstrap file observed at install time. It keeps a later cache refetch honest
  but is trust-on-first-use; it cannot authenticate the first download.

`Z4M_ALLOW_CHECKSUM_ONLY_RELEASES=1` therefore does not weaken authentication
slightly. It removes the only independent anchor and leaves the installation
resting on trust-on-first-use plus transport integrity. Use it only where GitHub
CLI genuinely cannot run, and verify the installer out of band in that case.

Note that `$Z4M` defaults to a location under `$XDG_CACHE_HOME`. A cache cleaner
that removes it also removes the recorded update state, after which `~/.zshenv`
refetches the ref and digest pinned at install time. That is fail-closed but it
silently returns to the originally installed version; re-run `z4m update` after
losing the cache.

## Supported Distribution Channels

Versioned GitHub releases are the supported production distribution channel.
The release installer embeds the expected hashes for every bootstrap file and
persists the bootstrap hash for fail-closed cache recovery.

Publishing is triggered through a `repository_dispatch` event, so GitHub loads
the privileged workflow from the protected default branch. It accepts only an
existing version tag whose commit is already contained in `origin/main`, and
refuses a tag that is not newer than the current published release. It uses the
protected `release` environment. Repository administrators must configure that
environment with required reviewers and restrict version tags with a GitHub
ruleset.

Maintainers request a release after pushing the reviewed tag:

```shell
gh api repos/arcthur/zsh4monkey/dispatches \
  -F event_type=release \
  -F 'client_payload[tag]=v1.2.3'
```

Verify a downloaded installer before execution when GitHub CLI is available:

```shell
gh attestation verify install \
  --repo arcthur/zsh4monkey \
  --signer-workflow arcthur/zsh4monkey/.github/workflows/release.yml
```

Public attestations can normally be fetched without authentication. If GitHub
requests credentials or the anonymous API limit is exhausted, run
`gh auth login` or set `GH_TOKEN`.

The `main` branch is a development channel. It is mutable, emits an explicit
warning during bootstrap, and should not be used where reproducible installation
or supply-chain provenance is required.

## Dependency Policy

Built-in remote dependencies are recorded in `dependencies.lock` with:

- an exact 40-character commit;
- a SHA-256 digest;
- an HTTPS artifact URL.

Custom GitHub plugins must also provide an exact commit and a configured digest.
The `allow-unverified-downloads` compatibility switch is an explicit security
opt-out.

Archive extraction rejects absolute paths, parent path segments, absolute or
parent-traversing symbolic-link targets, and hard-link members. Archives are
still treated as authenticated packages rather than sandboxed content.

These checks exist twice on purpose: `z4m.zsh` runs before `sc/supply-chain` is
on disk, so it inlines the same two awk programs. `test/bootstrap_duplication.zsh`
fails if the two copies diverge, and `test/supply_chain.zsh` covers the
behavior itself.

## Reporting a Vulnerability

Report vulnerabilities privately through the repository's GitHub Security
Advisory interface. Include affected versions, reproduction steps, impact, and
any suggested mitigations. Do not open a public issue for an unpatched
vulnerability.
