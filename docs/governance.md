# Governance

WannaBuild is currently maintained by a single maintainer, **@gl11tchy**.
This document describes how decisions are made, how PRs are reviewed, and
how the project plans to evolve as more maintainers come on board.

## Maintainership model

- **Single maintainer.** @gl11tchy holds final authority on merges to `main`,
  release cuts, and contract changes.
- **Reviewers vs. maintainers.** Anyone can review and comment on PRs.
  Approval from a maintainer (today, @gl11tchy) is required for merge per
  CODEOWNERS and the `main` branch ruleset.
- **Adding a maintainer.** Open an issue or Discussion describing scope
  (which paths the new maintainer will own), rationale, and a proposed
  trial period. The PR that adds a maintainer must update:
  1. `.github/CODEOWNERS` (assign owner to specific paths).
  2. This file (`docs/governance.md`).
  3. `.github/rulesets/main.json` `bypass_actors` if the new maintainer
     should be able to bypass required checks for emergency hotfixes.

## CODEOWNERS philosophy

`.github/CODEOWNERS` mirrors the repo's layer model:

- The **operator contract** (`AGENTS.md`, `CLAUDE.md`, `README.md`) and the
  **orchestrator spec** (`skills/`) are the most sensitive — every change
  ripples downstream.
- **Specialist agents** (`agents/`) and **scripts** (`scripts/`) define
  runtime behavior.
- **CI, governance, and adapter packaging** (`.github/`, `adapters/`,
  `.claude-plugin/`, `.cursor-plugin/`) shape how external users adopt
  the framework.

All of these currently route to @gl11tchy. As the project grows, we will
split ownership along these lines rather than splitting horizontally (e.g.
"only the front-end").

## Issue triage

- **Default labels.** New issues are labeled `needs-triage` automatically
  via the issue templates.
- **Triage SLA.** Best-effort within **5 days** for `needs-triage` items.
  An indie-maintained project can't promise a corporate SLA, but stale
  triage gets pruned weekly so contributors aren't left guessing.
- **Spec impact.** Issues that touch `AGENTS.md`, `skills/internal/build/SKILL.md`,
  or any artifact contract are labeled `needs-design-review`. These are
  not merged without an explicit design discussion (linked from the issue).
- **Contract change.** Issues filed via the "Contract or schema change"
  template are auto-labeled `breaking-candidate`; a backward-compat plan
  must be agreed before implementation begins.

## Pull request review

- **Approval requirement.** One approving review from a code owner, all
  review threads resolved, all required status checks green (see
  [docs/branch-protection.md](branch-protection.md)).
- **Review SLA.** Best-effort. The maintainer aims to leave a first-pass
  comment within **5 days** of a PR being marked ready for review.
- **Stale-PR policy.** PRs idle for 30 days without contributor response
  may be closed with a friendly note; reopen any time once you can
  continue.
- **Fast-track.** Tiny, low-risk changes (typo fixes, dependency bumps
  via Dependabot, doc-only fixes) may be merged with a single quick
  review and minimal ceremony, per AGENTS.md.

## Release cadence

- Releases are continuous: every merge to `main` that includes a
  Conventional Commit (`feat:`, `fix:`, `feat!:`, …) triggers
  release-please to open or update a release PR. Merging that PR cuts a
  new version and tags it.
- Hotfixes follow the same path; there is no dedicated "release branch".
- Tags follow Semantic Versioning (`vMAJOR.MINOR.PATCH`).

## Conventional Commits

All commits to `main` must use [Conventional Commits](https://www.conventionalcommits.org/).
Examples:

```text
feat(orchestrator): add advisor escalation for review iterations
fix(scripts): handle missing .wannabuild/state.json in doctor
docs(governance): clarify triage SLA
chore(deps): bump actions/checkout from 4.1.7 to 4.2.0
```

A breaking change is signalled either with `!` after the type/scope
(`feat(api)!: …`) or a `BREAKING CHANGE:` footer.

## Backports and hotfixes

There is currently no backport policy: WannaBuild only supports the
latest minor version. A hotfix is just a `fix:` commit landed on `main`,
which release-please will publish as a new patch.

If the project starts maintaining multiple versions, this section will
be updated to describe maintenance branches (e.g. `release/0.4.x`) and
cherry-pick policy.

## Code of conduct

We don't ship a separate `CODE_OF_CONDUCT.md` yet. The expectation is
the same one expressed in `CONTRIBUTING.md`:

> Be kind. Engage with ideas, not people. Disagree clearly, decide
> openly, and assume good faith.

Concerns about behavior should be sent privately to @gl11tchy via
GitHub Discussions or email listed on the maintainer's GitHub profile.

## See also

- [docs/branch-protection.md](branch-protection.md) — how the `main`
  branch and release tags are protected.
- [.github/CODEOWNERS](../.github/CODEOWNERS) — path-to-owner mapping.
- [CONTRIBUTING.md](../CONTRIBUTING.md) — contributor guide.
- [AGENTS.md](../AGENTS.md) — operator contract.
