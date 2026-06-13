# Release

WannaBuild releases are tag-based: a release is a git tag plus auto-generated
release notes published to the GitHub Releases page. Each release also gets
prebuilt `wb-runtime` binary archives (linux-x86_64, macos-arm64, macos-x86_64)
plus `.sha256` checksums, attached automatically by the `release-binaries` job
in `.github/workflows/release-please.yml`.

Releases are driven by [release-please](https://github.com/googleapis/release-please).

## Conventional Commits are required

Every commit on `main` must follow the
[Conventional Commits](https://www.conventionalcommits.org/) spec. The commit
type drives both the changelog section and the version bump:

| Commit type | Section | Version effect |
|---|---|---|
| `feat:` | Features | minor bump |
| `fix:` | Fixes | patch bump |
| `docs:` | Docs | patch bump |
| `refactor:` | Refactor | patch bump |
| `perf:` | Performance | patch bump |
| `chore:` | Chores | patch bump |
| `test:` | Tests | patch bump |
| `feat!:` / `BREAKING CHANGE:` footer | — | major bump |

Configuration lives in `release-please-config.json`. The current version is
tracked in `.release-please-manifest.json`.

## Normal release flow

1. Land conventional commits on `main`.
2. The `release-please` workflow opens (or updates) a "release PR" with a
   bumped version, an updated `CHANGELOG.md`, and an updated manifest.
3. Review the release PR. Edits to the changelog go inside the release PR; do
   not edit `CHANGELOG.md` directly outside that PR.
4. Merge the release PR. release-please then:
   - creates the git tag (e.g., `v2.3.0`)
   - publishes a GitHub Release with auto-generated notes (categorized via
     `.github/release.yml`)
   - the `release-binaries` job builds and attaches the `wb-runtime` archives
     and `.sha256` checksums for each supported platform

That's the whole release.

## Hotfix flow

For an urgent fix on the latest released version:

1. Branch from the latest tag: `git checkout -b hotfix/x v2.2.3`.
2. Land the fix as a `fix:` commit.
3. Open a PR against `main`.
4. Once merged, release-please picks it up like any other commit and produces
   a patch release.

If the hotfix must skip `main` (e.g., backporting), cut a release branch from
the tag and run release-please's manual workflow against that branch.

## Manual release trigger

If automation is unavailable, you can manually:

1. Bump the version in `.release-please-manifest.json`.
2. Update `CHANGELOG.md` under a new heading.
3. Commit (`chore: release x.y.z`).
4. Tag: `git tag -a vX.Y.Z -m "vX.Y.Z"` and push tag.
5. Create the release in the GitHub UI; it will pull notes from
   `.github/release.yml` and the PR labels.

Re-enable automation afterwards by merging a release-please PR through the
normal flow.

## CHANGELOG.md

`CHANGELOG.md` is the canonical changelog. After the first release-please
release, do not edit it by hand — release-please rewrites the file on each
release. The `## [Unreleased]` section is regenerated from commit history on
each run.
