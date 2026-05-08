# Runbook: orchestrator misbehaved in a target project

## Symptom

A user reports the WannaBuild orchestrator (or one of its specialists) did
something wrong in a target project. Examples:

- Skipped a phase it shouldn't have skipped.
- Marked the integration tester gate as passing when it didn't.
- Wrote `.wannabuild/state.json` with stale or invalid data.
- A specialist agent produced output that violated its prompt contract.
- Loop got stuck or oscillated between two reviewers.

## Triage (≤ 10 min)

1. Capture state from the target project. **Scrub secrets first.**
2. Classify which component is at fault.
3. Open a structured issue with the captured artifacts.

## Step 1 — Capture state (with secrets scrubbed)

In the target project's worktree:

```bash
mkdir -p /tmp/wb-incident
cp -r .wannabuild /tmp/wb-incident/wannabuild
# Scrub the bundle:
bash /path/to/wannabuild/scripts/scrub-log.sh /tmp/wb-incident
# Pack:
tar -czf wb-incident-$(date +%Y%m%d-%H%M%S).tgz -C /tmp/wb-incident .
```

Verify that the scrubbed bundle no longer contains anything matching common
secret regexes (gitleaks default ruleset, or
[`../log-scrubbing.md`](../log-scrubbing.md) ruleset).

Include in the bundle:

- `.wannabuild/state.json`
- `.wannabuild/loop-state.json`
- `.wannabuild/checkpoints/` (recent N)
- `.wannabuild/review/` (verdicts)
- The transcript / log of the orchestrator run (if available).

## Step 2 — Classify

| Component | Symptom |
|---|---|
| **Orchestrator** | Wrong routing decision, premature transition, state.json fields wrong, loop didn't terminate, gate enforced wrong. |
| **Specialist agent** | Output didn't match agent's contract (wrong shape, missing fields, hallucinated content). |
| **Validator** | `validate-wannabuild-artifacts.sh` accepted (or rejected) an artifact incorrectly. |
| **Adapter** | Behavior only repros under one host (Codex, Claude Code, Cursor) — likely an adapter bug. |

If unclear, default to **orchestrator** and let triage move it.

## Step 3 — Open the right issue

Use one of these issue templates (the templates are owned by another batch;
file under the closest match if a template doesn't exist yet):

- **`contract_or_schema_change`** — when the bug is in `AGENTS.md`, a
  `skills/*/SKILL.md`, a `references/*.md` doc, or a JSON schema. Attach the
  captured bundle and a minimal repro fixture.
- **`specialist_agent_change`** — when the bug is in a single
  `agents/wb-*.md` prompt. Quote the offending output and the agent's
  contract.

In either case the issue must include:

- Bundle from Step 1 (zipped, attached).
- Host (Codex / Claude Code / Cursor) and version.
- Minimum repro instructions (a tiny `.wannabuild/` fixture is ideal).
- Whether the user can reproduce it on a fresh worktree.

## Step 4 — Rollback options

While the bug is being fixed, the user has two rollback paths:

### Option A — Revert to a previous checkpoint

```bash
# Inside the target project's worktree:
ls .wannabuild/checkpoints/
# Pick the last known-good checkpoint:
cp .wannabuild/checkpoints/<good-id>.json .wannabuild/state.json
# Re-run the orchestrator from that state:
$wannabuild  # or /wannabuild
```

### Option B — Clean and restart the failing phase

```bash
# Wipe loop state and let the orchestrator restart the phase fresh:
rm -f .wannabuild/loop-state.json
# Optionally rewind state.json's `current_phase` to the previous phase's name.
$wannabuild
```

Validate before continuing:

```bash
bash /path/to/wannabuild/scripts/validate-wannabuild-artifacts.sh "$(pwd)"
```

If the validator is unhappy, fix the offending artifact by hand or roll
back further.

## Escalation

- **Owner**: WannaBuild repo maintainers.
- **When**: if the user is blocked from shipping critical work AND no
  rollback path works.
- **Channel**: GitHub Issue with `area:orchestrator` + `severity:high`;
  ping `@wannabuild-maintainers` in `#wannabuild-help`.

## Post-incident

Every reproducible orchestrator misbehavior should produce:

- A **failing test fixture** added under `tests/` or `skills/internal/build/dry-runs/`
  that the validator/orchestrator must now reject.
- A doc update in the contract that was ambiguous.
- A note in CHANGELOG under `Fixed`.

## Cross-references

- [`../../AGENTS.md`](../../AGENTS.md) — operator contract.
- [`../../skills/internal/build/SKILL.md`](../../skills/internal/build/SKILL.md) — orchestrator
  spec.
- [`../../skills/internal/build/references/loop-state.md`](../../skills/internal/build/references/loop-state.md)
- [`../../skills/internal/build/references/exit-conditions.md`](../../skills/internal/build/references/exit-conditions.md)
- [`../log-scrubbing.md`](../log-scrubbing.md) — scrubbing the bundle.
