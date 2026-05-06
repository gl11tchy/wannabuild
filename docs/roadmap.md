# Roadmap

What's shipped, what's next, what's deferred. The shape is intentional — items
move from **Next** to **Done** as PRs land, and from **Considered** to **Next**
when they earn priority. New ideas land in **Considered** until a maintainer
takes ownership.

This document is the source of truth for "is X on the roadmap?" The README
links here so contributors and adopters can answer that question without
opening an issue.

> Last reviewed: 2026-05-06.

---

## Done — recent quality push

Mass-adoption polish landed in v2.2.5 and the surrounding round.

- **Plugin hooks shape fix** — the v2.2.4 `/reload-plugins` crash is fixed
  and regression-pinned by both a unit test (`tests/unit/test_plugin_hooks_shape.bats`)
  and an integration test that drives `install-claude-skill.sh` against a
  synthetic `CLAUDE_HOME` (`tests/integration/test_install_claude_skill.bats`).
- **Release version sync** — `release-please-config.json` has `extra-files`
  for `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and
  `adapters/factory/.factory-plugin/plugin.json`, so every release auto-bumps
  all four version files in lockstep.
- **Install-time hooks shape verification** — `scripts/install-claude-skill.sh`
  rejects a wrapped hooks file at install time instead of in the user's first
  session.
- **Install script prereq detection** — the install scripts fail fast with
  actionable per-OS errors when no Python interpreter is on PATH.
- **Troubleshooting runbook** — `docs/runbooks/install-and-load-failures.md`
  catalogues nine real failure modes with diagnostics and fixes.
- **README Quickstart** — three install steps and a first natural-language
  prompt above the fold for Claude Code, Codex, and Cursor.
- **Live CI badge** in the README.
- **Markdown link checker** in CI (`.github/workflows/lychee.yml`) — runs on
  every markdown PR plus a daily cron, so doc rot is caught instead of
  accumulating.
- **Factory / Droid host docs** in the README.

## Next — committed, in flight or up next

Items here are scoped, owned, and expected within the next round.

- **Cold-install smoke test in CI** — drive `install-claude-skill.sh` from
  a fresh GitHub Actions runner against a synthetic `CLAUDE_HOME`, then run
  doctor. The bats integration test in
  `tests/integration/test_install_claude_skill.bats` is half of this — the
  CI workflow that exercises a full marketplace clone path is the missing
  half.
- **Cross-host parity test** — single natural-language prompt → identical
  state transitions across Claude Code, Codex, Cursor, and Factory. Today
  the "co-primary" claim is a contract, not a tested invariant.
- **Per-host quickstart deep-dives** — `docs/quickstart-{claude,codex,cursor,factory}.md`
  with screenshots/asciicasts. Only worth doing if usage data shows the
  README Quickstart isn't enough.
- **Doctor output polish** — color, structured PASS/WARN/FAIL grouping,
  suggested next command per WARN. Low priority — most users don't run
  doctor.

## Considered — possible, not yet committed

Items here have been thought about; we are not committed to building them.
If you want one of these to advance, open an issue describing the use case.

- **Supply-chain hardening** — harden-runner egress allowlist on every
  workflow, signed-tag policy, tighter `permissions:` blocks. Provenance
  attestation is awkward for a docs repo (no compiled artifacts), so this
  is the better-fit supply-chain story.
- **Anonymous opt-in telemetry** — which phases users get stuck in,
  which agents escalate, time-per-phase. Would need a privacy review and
  a clear opt-in default.
- **Contributor onboarding doc** — which directories are safe for
  community PRs vs maintainer-only, with a reading order.
- **AGENTS / CLAUDE preamble dedupe** — the 33-line working-principles
  preamble is duplicated intentionally (both files are auto-loaded by
  their respective hosts). Revisit if jscpd is ever escalated to a hard
  fail.
- **Per-host marketplace publish smoke** — actually publish to the
  marketplace from CI on a release, then verify a fresh install works.
- **Public Discord / Slack** — community channel. Only when there is
  enough real adoption to need one.

## Process

- This roadmap is reviewed at every release.
- Items move from **Considered** → **Next** when a maintainer takes
  ownership and there is a concrete acceptance criterion.
- Items move from **Next** → **Done** when the corresponding PR(s) merge.
- "Deferred" status sits inside an item's description rather than a
  separate column — the why-it's-deferred note is the most useful part.

## Out of scope

Things WannaBuild deliberately does not do, so contributors don't waste
time on PRs that won't land:

- **Hosting** — WannaBuild is repo-native. We do not run a SaaS or a
  hosted orchestrator.
- **Replacing the host model** — Claude Code, Codex, Cursor, and Factory
  are the surface. WannaBuild does not ship its own model or its own
  agent runtime.
- **Frontend UI** — there is no dashboard. The user experience is the
  host's chat UI plus repo artifacts under `.wannabuild/`.
- **Feature flags / experimentation** — out of scope for the framework
  itself. Target projects can layer this on top.
