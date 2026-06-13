# Runbook: release-please failed

## Symptom

- The `release-please` workflow run is red.
- No release PR is being created/updated despite recent commits to `main`.
- An existing release PR is stuck and won't merge.

## Triage (≤ 5 min)

1. Open the latest run of the release workflow under GitHub Actions.
2. Note which step failed:
   - **release-please action** — config/manifest issue.
   - **GitHub auth step** — token scope/missing.
   - **Tag creation / GH release creation** — token permissions.
   - **Asset upload** — packaging step (rare; we ship docs, not binaries).
3. Confirm `release-please-config.json` and `.release-please-manifest.json`
   are in their expected state on `main` (no merge conflicts left, no
   manual edits that diverged).

For background on how release-please is wired, see [`../release.md`](../release.md).

## Reproduce locally

The release-please tool runs as a GitHub Action; you can simulate it:

```bash
# Install the CLI:
npm install -g release-please

# Dry-run against the current main:
release-please release-pr \
  --repo-url=https://github.com/<owner>/<repo> \
  --token="$GH_TOKEN" \
  --target-branch=main \
  --dry-run
```

If the dry-run produces a sensible PR draft locally, the issue is most
likely the workflow's token or environment, not the config.

## Common causes & fixes

| Cause | Symptom | Fix |
|---|---|---|
| Commit not Conventional | release-please skips it; nothing is released. | Reword via `git commit --amend` (if not pushed) or open a follow-up `chore:` commit that explicitly adds the missing footer (`Release-As: x.y.z`). |
| Manifest version drift | release-please errors that a tag already exists or version moved backward. | Sync `.release-please-manifest.json` to the highest existing tag for each component. Open a PR with just that fix. |
| GH token scope | Workflow log shows 403 on tag/release creation. | Use a fine-grained PAT with `contents:write` AND `pull-requests:write` for this repo. Store as `GITHUB_TOKEN` (default) or a named secret if using a custom token. |
| Branch protection blocks PR | release-please PR can't merge automatically. | Either grant a bypass for the bot account or merge manually after status checks pass. See [`../branch-protection.md`](../branch-protection.md). |
| Conflicting release-please config | Workflow errors with "no release config found" or invalid schema. | Validate `release-please-config.json` against the [official schema](https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json). |
| Two release PRs open | release-please opened a duplicate. | Close one; rebase the keeper. |
| `GitHub Actions is not permitted to create or approve pull requests` | The release-please workflow log shows this exact error and no release PR is opened. | One-time repo setting. Owner / Settings → Actions → General → "Workflow permissions" → enable **Allow GitHub Actions to create and approve pull requests** AND select **Read and write permissions**. Equivalent API call: `gh api -X PUT repos/<owner>/<repo>/actions/permissions/workflow --field can_approve_pull_request_reviews=true --field default_workflow_permissions=write`. Re-run the workflow after enabling. |

## Manual release fallback

When release-please is wedged but you need to ship:

```bash
# 1. Bump version in the affected manifest entry.
edit .release-please-manifest.json

# 2. Update CHANGELOG.md manually with the new entries.
edit CHANGELOG.md

# 3. Create the tag.
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z

# 4. Create the GitHub release with notes.
gh release create vX.Y.Z --title "vX.Y.Z" --notes-file release-notes.md
```

After the manual release, file an issue to fix the underlying
release-please problem before the next cycle so the manual procedure isn't
the new normal.

## Escalation

- **Owner**: repo maintainers.
- **When**: release has been blocked for > 24 hours.
- **Channel**: `#wannabuild-release` Slack or repo issue with `area:release`.

## Post-incident

- Why release-please failed.
- Whether the manifest or workflow needs a guardrail (e.g., schema check
  in CI) so it can't recur.
- Whether to add a smoke check that opens a release PR weekly even if no
  conventional commits land, to catch staleness earlier.

## Cross-references

- [`../release.md`](../release.md) — how releases work here.
- [`../ci.md`](../ci.md) — workflow inventory.
- [`../branch-protection.md`](../branch-protection.md) — required checks.
