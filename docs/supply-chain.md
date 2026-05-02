# Supply-Chain Hardening

WannaBuild's supply-chain posture is intentionally minimal — the framework
itself has no runtime dependencies — but the policies it recommends and
enforces apply to both the framework's own CI and to downstream target
projects.

## Action pinning policy

Every GitHub Action invocation in `.github/workflows/` must reference a
**full 40-character commit SHA**, not a tag or branch. Tags are mutable;
SHAs are not. A repository typosquat or maintainer compromise that retags
`v1` cannot affect a workflow pinned to a specific SHA.

The workflow lint (Batch C) enforces this. Renovate (see below) is
configured with `pinDigests: true` so that updates land as SHA bumps with
the corresponding tag in a comment for human review.

## Renovate `minimumReleaseAge` policy

[`renovate.json`](../renovate.json) sets:

```json
{
  "minimumReleaseAge": "5 days",
  "vulnerabilityAlerts": { "minimumReleaseAge": "0 days" }
}
```

### Rationale

The dominant supply-chain attack pattern against package ecosystems
(npm, PyPI, RubyGems, crates.io, etc.) is a compromised maintainer publishing
a malicious version. Industry telemetry consistently shows that **most such
versions are detected and yanked within hours** — typically less than 48 —
because automated scanners watch the firehose of new releases.

A five-day cool-off therefore filters out the overwhelming majority of these
attacks at the cost of merging benign updates a few days later than otherwise.
This is a near-free win for downstream stability and security.

### Trade-offs

- **Slower benign updates.** If a dependency ships a non-security improvement
  on Monday, Renovate will not propose merging it until the following Saturday.
  This is acceptable for a framework repo and for most target projects; if
  your project is itself a security-sensitive *upstream* and needs fixes to
  flow faster, consider tightening to `3 days` and pairing with stronger
  scanners.
- **Security exception.** Genuine security fixes (flagged via OSV /
  GitHub vulnerability alerts) bypass the delay because
  `vulnerabilityAlerts.minimumReleaseAge` is `0 days`. The cost of merging a
  fix immediately is lower than waiting five days while attackers move.

## Auditing cadence

The repo runs two complementary scanners:

| Scanner    | Cadence                          | Responsibility                         |
| ---------- | -------------------------------- | -------------------------------------- |
| Dependabot | Weekly (Batch D `dependabot.yml`) | First-line ecosystem updates           |
| Renovate   | Continuous, gated by 5-day delay | Group rules, SHA pinning, vuln alerts  |

The two are deliberately redundant. Dependabot is GitHub-native and shows up
in the security tab; Renovate handles policy nuances Dependabot does not
support (per-ecosystem grouping, SHA pinning for actions, the cool-off
window).

## Reproducible builds

The framework itself produces no compiled artefacts, so reproducibility for
*WannaBuild* reduces to "the install scripts are deterministic given the
same commit SHA", which they are.

For target projects that *do* compile, document pinned tool versions in
`docs/build.md` (Batch B) and use lockfiles (`package-lock.json`, `poetry.lock`,
`Cargo.lock`, etc.). Renovate respects lockfiles when proposing updates.

## SBOM

WannaBuild does not generate or ship an SBOM because it has no compiled
output and no third-party runtime dependencies. The closest equivalent is
the list of pinned action SHAs in `.github/workflows/`, which is git-native.

For target projects, generate an SBOM at build time. Recommended tools:

- [Syft](https://github.com/anchore/syft) — language-agnostic SBOM generator.
- [Trivy](https://github.com/aquasecurity/trivy) — combined SBOM + vuln scan.
- [`docker scout sbom`](https://docs.docker.com/scout/) for container images.

Attach the SBOM as a release artefact (CycloneDX or SPDX JSON), and feed it
into a continuous vuln scanner so that issues affecting an *already-shipped*
release surface as soon as they are disclosed.

## Provenance

SLSA-style build provenance is not yet wired up for this repo. Tracked as
TODO(@gl11tchy); add a link here when the work is scheduled. For target projects, prefer
[`actions/attest-build-provenance`](https://github.com/actions/attest-build-provenance)
to attach signed provenance to release artefacts at build time.

## Pinned tool versions for CI

The CI workflows pin the major version of every tool they use. Specifically:

- `actions/checkout`, `actions/setup-node`, etc. — pinned to a SHA, see
  Batch C workflows.
- `gitleaks` — pinned in the pre-commit config.
- `detect-secrets` — pinned in the pre-commit config.
- `shellcheck` — pinned in the pre-commit config.
- `markdownlint-cli2` — pinned in the pre-commit config.

If you need to bump a tool, do it through Renovate so the change is reviewed
under the same five-day cool-off as everything else.

## Threat coverage summary

| Threat                                              | Mitigation                                            |
| --------------------------------------------------- | ----------------------------------------------------- |
| Compromised npm/PyPI/etc. package version           | Renovate `minimumReleaseAge: 5 days`                  |
| Mutable action tag retargeted to malicious SHA      | SHA-pinned actions, `pinDigests: true`                |
| Vulnerable dependency in target project             | Dependabot weekly, Renovate continuous, OSV alerts    |
| Stale lockfile drifting from declared deps          | Renovate lockfile maintenance (default in `config:recommended`) |
| Tampered installed adapter files                    | Install scripts symlink into the cloned repo         |
| Secrets exfiltrated via dependency execution        | No runtime deps in the framework; pre-commit gitleaks |

## See also

- [`SECURITY.md`](../SECURITY.md)
- [`docs/security.md`](security.md)
- [`docs/secrets-management.md`](secrets-management.md)
- [`docs/log-scrubbing.md`](log-scrubbing.md)
- [`renovate.json`](../renovate.json)
