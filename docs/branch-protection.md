# Branch protection

WannaBuild ships its branch and tag protection as version-controlled rulesets
under `.github/rulesets/`, applied via `scripts/apply-rulesets.sh`. This keeps
governance reviewable, diffable, and reproducible across forks.

## Files

| File | Target | Purpose |
|---|---|---|
| `.github/rulesets/main.json` | `~DEFAULT_BRANCH` (currently `main`) | Protect the default branch from direct pushes, force-pushes, deletion, and merges that lack required review and CI signal. |
| `.github/rulesets/release-tags.json` | tags matching `refs/tags/v*.*.*` | Protect release tags from deletion, force-update, and unsigned overwrites. |

## What `main.json` enforces

- **No direct pushes.** All changes flow through pull requests (`update` rule
  requires PR; `creation` is blocked).
- **No deletion or non-fast-forward updates** to `main`.
- **At least one approving review** before merge, with stale reviews dismissed
  on push and required code-owner review (`pull_request` rule).
- **All review threads must be resolved** before merge.
- **Required status checks** (must be green and up-to-date with `main`):
  - `lint`
  - `test (ubuntu-latest)`
  - `test (macos-latest)`
  - `validate-contracts`
  - `pre-commit`

  These names match the job IDs/matrix labels in the repo's CI workflows.
  When you add or rename a CI job, update both the workflow and this ruleset
  in the same PR.
- **Linear history.** Merge commits are blocked; rebase or squash only.

## What `release-tags.json` enforces

- **No deletion** of `v*.*.*` tags.
- **No force-update** of release tags (immutable history).
- **Signed tags** required (set to `evaluate` first if signing isn't yet rolled
  out across all maintainers).

## Bypass actors

`main.json` ships with an empty `bypass_actors: []` so the file can be applied
verbatim. If you need a bypass actor (a release bot, a break-glass admin), add
it after the initial apply rather than committing it to the JSON — that way the
checked-in policy stays portable across forks.

`actor_type` values: `RepositoryRole` | `Team` | `Integration` | `OrganizationAdmin`.
`bypass_mode` should almost always be `pull_request` (the actor still needs an
approved PR to push, but bypasses required status checks for an emergency
hotfix). Use `always` only for break-glass automation accounts.

### Adding bypass actors

1. Look up the `actor_id`:

   ```bash
   # Repository roles: Admin = 5, Maintain = 4, Write = 3, Triage = 2, Read = 1
   # (List collaborators to confirm against your org's permission model.)
   gh api repos/gl11tchy/wannabuild/collaborators

   # Team-based bypass
   gh api orgs/<org>/teams/<team-slug> --jq .id

   # GitHub App / Integration
   gh api /repos/gl11tchy/wannabuild/installations --jq '.installations[] | {id,app_slug:.app.slug}'
   ```

2. Find the existing ruleset id:

   ```bash
   gh api repos/gl11tchy/wannabuild/rulesets --jq '.[] | select(.name=="Protect main") | .id'
   ```

3. PATCH the ruleset to add the bypass actor (replace `<ruleset_id>` and
   `<actor_id>`):

   ```bash
   gh api -X PATCH repos/gl11tchy/wannabuild/rulesets/<ruleset_id> \
     -f 'bypass_actors[][actor_id]=<actor_id>' \
     -f 'bypass_actors[][actor_type]=RepositoryRole' \
     -f 'bypass_actors[][bypass_mode]=pull_request'
   ```

   For multiple actors, repeat the three `-f bypass_actors[]…` flags per
   actor, or send a JSON body with `--input -`:

   ```bash
   gh api -X PATCH repos/gl11tchy/wannabuild/rulesets/<ruleset_id> --input - <<'JSON'
   {
     "bypass_actors": [
       { "actor_id": 5,  "actor_type": "RepositoryRole",   "bypass_mode": "pull_request" },
       { "actor_id": 42, "actor_type": "Team",             "bypass_mode": "pull_request" }
     ]
   }
   JSON
   ```

4. Verify:

   ```bash
   gh api repos/gl11tchy/wannabuild/rulesets/<ruleset_id> --jq .bypass_actors
   ```

Keeping bypass actors out of `main.json` (and applying them post-hoc) avoids
hard-coded `actor_id`s — they're org-specific and silently break on forks.

## Applying

Dry run first to preview the API calls:

```bash
bash scripts/apply-rulesets.sh --dry-run
```

Apply (requires `gh auth login` as a repo admin):

```bash
bash scripts/apply-rulesets.sh
```

Override the target repo (e.g. for a fork):

```bash
bash scripts/apply-rulesets.sh --owner my-fork --repo wannabuild
```

The script:

1. Lists existing rulesets via `GET /repos/{owner}/{repo}/rulesets`.
2. For each JSON file, matches by `name` and either `PATCH`es the existing
   ruleset or `POST`s a new one.
3. Exits non-zero on the first failure.

## Updating

1. Edit the JSON under `.github/rulesets/`.
2. Run `python3 -c "import json; json.load(open('.github/rulesets/main.json'))"`
   (and the equivalent for any other file you changed) to confirm valid JSON.
3. `bash scripts/apply-rulesets.sh --dry-run` to preview.
4. Open a PR. CODEOWNERS will request the maintainer's review.
5. After merge, the maintainer runs `bash scripts/apply-rulesets.sh` against
   the live repository.

## Reference

- GitHub REST: <https://docs.github.com/en/rest/repos/rules>
- Repository rulesets concept: <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets>
