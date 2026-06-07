# Advisor Escalation

WannaBuild uses executor-led, advisor-assisted escalation for high-impact uncertainty. The executor keeps ownership of tools, edits, validation, and handoff. The advisor provides bounded guidance only.

Escalation is a last resort, not a first response to "blocked". Before any escalation, the executor MUST exhaust obtainable resources under [Mandate 2](doctrine.md) — provision the missing resource via the host's connectors/MCP/CLIs and gather live evidence — and log every attempt. "Missing env", "no access", and "can't test" are never grounds to escalate or stop; they are grounds to obtain or to ask the user (billable/outward/destructive only).

Advisor guidance is NON-BINDING and may never override a hard gate. A `wb-integration-tester` FAIL stands regardless of any advisor recommendation; there is no override path. `Stop Signal` and any advisor recommendation are inputs to the executor's judgment only — they are never a pass, completeness, or gate-clear signal for `assert-review-ready`, `assert-qa-ready`, or any other gate. A read-only advisor report can never substitute for execution evidence.

## Trigger Matrix

`Material` (used below) = a change that alters acceptance criteria, a public contract/schema, data persistence, money/billing, auth, or security posture. Anything outside that set is not material.

Use advisor escalation when one or more measurable predicates below evaluate true. Each predicate is objective so the same state escalates identically on every run.

| Trigger | Measurable predicate |
|---|---|
| Architecture risk | the change introduces an irreversible data model, a new cross-service boundary, or a migration that rewrites existing rows |
| High-risk integration | the change touches auth, billing, secrets, infra policy, a DB schema, or a deployment — AND the resource was acquired/exercised (DB branch, deploy logs, browser auth run) yet the correct approach remains undetermined |
| Uncertain remediation | a failing review has ≥2 plausible fix paths that lead to materially different designs |
| Conflicting specialists | ≥2 reviewer or planning outputs give directly contradictory directives on the same material change |
| Wrong-path suspicion | the current approach has produced ≥2 consecutive failed review iterations on the same finding, or it changes a material surface in a way no acceptance criterion sanctions |
| Validation strategy risk | after acquiring the test resources, ≥1 acceptance criterion still has no integration-test mapping and ≥2 mappings are plausible |
| Review guardrail edge | `review iteration == max_iterations - 1` OR `uses_by_phase[phase] == max_uses_per_phase - 1` |

Material requirement, scope, or acceptance-criteria ambiguity is NOT in this matrix. A read-only advisor cannot talk to the user, so it MUST NOT be used to invent product intent. Route any such ambiguity back to collaborative discovery WITH the user (one question at a time, each with a recommended answer), reconfirm `.wannabuild/spec/requirements.md` acceptance criteria, and re-clear `assert-discovery-ready` before proceeding.

Do not use advisor escalation for routine implementation details, one-line fixes, style-only questions, generic double checks, or any blocker that has not first cleared the acquisition ladder in the Invocation Contract.

## Runtime Mapping

Resolve the advisor mechanism in the fixed order below and use the first host-native mechanism that exists on the active host. If none resolves, you MUST fall through to the Generic row (write the advisor report and update state manually). Declaring the mechanism "unavailable" never skips escalation — the Generic row always exists, so there is no path where a matched trigger goes unaddressed.

| Order | Host | Advisor mechanism |
|---|---|---|
| 1 | Factory/Droid | invoke project droid `wb-advisor` |
| 2 | Claude Platform API | invoke native `advisor_20260301`; if it does not resolve, fall to the Generic row |
| 3 | Claude Code | invoke the read-only advisor subagent; if it does not resolve, fall to the Generic row |
| 4 | Codex | invoke the higher-reasoning read-only advisor; if it does not resolve, fall to the Generic row |
| 5 | Cursor | use the prompt/report mechanism |
| 6 | Generic | write the advisor report and update state manually (terminal fallback — always available) |

## Invocation Contract

Before high-risk design, implementation, uncertain remediation, or max-iteration-adjacent review decisions:

**Precondition (all triggers).** No advisor may be invoked until the executor has attempted to obtain or exercise every missing resource the uncertainty depends on, using the host's connectors/MCP/CLIs, and recorded each attempt in `.wannabuild/outputs/acquisition-log.json` (per [Mandate 2](doctrine.md); enforced by `assert-acquisition-attempted`). Live evidence comes first: run the failing commands and capture exit codes/output; pull real logs (`get_logs` / `get_runtime_logs`); provision DB branches and `run_sql` (Supabase/Neon `create_branch`); deploy and read build/runtime logs (Railway/Vercel); drive auth/UI with a browser or computer-use; read live docs via Context7; generate fixtures. The advisor receives this evidence; it is never a substitute for gathering it.

```text
IF advisor escalation criteria match:
  REQUIRED FIRST: run the acquisition ladder for every missing resource;
                  capture commands, exit codes, logs, and results;
                  append each attempt to .wannabuild/outputs/acquisition-log.json
  IF acquisition resolved the uncertainty:
    proceed with the evidence; do NOT invoke the advisor
  ELSE IF advisor budget remains:
    invoke host adapter advisor mechanism (with acquisition evidence in Context)
    save advisor report under .wannabuild/outputs/advisor/
    update state.json advisor metadata
    IF decision_impact is not none:
      append a dated entry to .wannabuild/decisions.md  # mandatory, not optional
    resume executor
  ELSE (advisor budget exhausted):
    # Escalation is never the bail-out. Before any user pause, prove exhaustion.
    REQUIRED, recorded in the report and the acquisition log:
      1. Obtain the missing resource via every available MCP server / connector / CLI
         (Supabase/Neon create_branch + run_sql; Railway/Vercel deploy + get_logs /
          get_runtime_logs; browser / computer-use for auth/UI flows; Context7 for docs;
          generated fixtures and seed data) and record each attempt with its result.
      2. Re-derive the decision from the live evidence gathered in step 1.
    pause and ask the user ONLY for billable, outward-facing, or destructive acquisition
    (paid provisioning, deploys, production data, external sends), presenting the
    specific resource needed and why. Never pause to hand off a problem that obtainable
    local/ephemeral resources could have resolved.
```

For Factory/Droid, invoke `wb-advisor` with a bounded prompt:

```text
Goal: Advise the active WannaBuild executor.
Phase: <phase>
Trigger: <trigger>
Question: <bounded question>
Context:
- <targeted spec excerpts>
- <changed-file summary or review verdict summary>
- Acquisition attempted: <resource, tool/connector/CLI used, result or logs>
Constraints:
- Do not edit files.
- Do not run commands.
- Do not produce user-facing output.
- Return only the advisor report schema.
```

## Advisor Report

Path:

```text
.wannabuild/outputs/advisor/<phase>-escalation-<N>.md
```

Schema:

```md
# Advisor Escalation — <phase>-<N>

Phase: <phase>
Trigger: <why escalation was needed>
Question: <bounded question asked>
Acquisition Attempted:
- <resource needed, tool/connector/CLI used, result or logs>
Context Provided:
- <spec or repo summary excerpt>
Recommendation:
- <advisor guidance>
Stop Signal: yes|no
Stop Signal Justification: <required when yes — which obtainable resources were exhausted (with results) such that no acquisition could resolve the blocker>
Decision Impact: none|scope|architecture|implementation|validation
Record In Decisions: yes|no
```

`Acquisition Attempted` is mandatory and must enumerate exactly what was tried; an escalation with an empty acquisition record is a contract violation. `Stop Signal: yes` is invalid without a `Stop Signal Justification` proving obtainable resources were exhausted first — a `Stop Signal` may halt the loop only for a genuinely un-obtainable blocker, never for one that a DB branch, deploy log, or browser run could have resolved. `Stop Signal` is advisory: it is an input to the executor's judgment, never a pass, completeness, or gate-clear signal, and `Stop Signal: no` does not clear `assert-review-ready`, `assert-qa-ready`, or any phase.

If `Decision Impact` is not `none`, `Record In Decisions` MUST be `yes` and the executor MUST append a concise dated entry to `.wannabuild/decisions.md` before resuming. Omitting the entry is a contract violation.

## State Contract

`state.json` may include:

```json
{
  "advisor": {
    "enabled": true,
    "max_uses_per_phase": 3,
    "uses_by_phase": {
      "design": 0,
      "implement": 1,
      "review": 0
    },
    "escalations": [
      {
        "phase": "implement",
        "trigger": "uncertain remediation",
        "report": ".wannabuild/outputs/advisor/implement-escalation-1.md",
        "decision_impact": "implementation",
        "recorded_in_decisions": true
      }
    ]
  }
}
```

Whenever an escalation occurs, the executor MUST write the `advisor` block: record the escalation, its `report` path, `decision_impact`, and `recorded_in_decisions`, and increment `uses_by_phase[phase]`. The block is merge-updated and never replaces the full `state.json`. Skipping the write to avoid the escalation contract is a contract violation; the escalation-tracking primitive is never optional.
