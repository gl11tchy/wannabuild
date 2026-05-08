# Advisor Escalation

WannaBuild uses executor-led, advisor-assisted escalation for high-impact uncertainty. The executor keeps ownership of tools, edits, validation, and handoff. The advisor provides bounded guidance only.

## Trigger Matrix

Use advisor escalation when one or more are true:

| Trigger | Examples |
|---|---|
| Architecture risk | irreversible data model, cross-service boundary, migration strategy |
| Material ambiguity | requirement changes scope, acceptance criteria conflict |
| High-risk integration | auth, billing, secrets, infra policy, DB schema, deployment |
| Uncertain remediation | failing review has multiple plausible fix paths |
| Conflicting specialists | reviewer or planning outputs disagree materially |
| Wrong-path suspicion | executor suspects current approach may worsen risk |
| Validation strategy risk | unclear integration test mapping for acceptance criteria |
| Review guardrail edge | max iterations or budget limit is near |

Do not use advisor escalation for routine implementation details, one-line fixes, style-only questions, or generic double checks.

## Runtime Mapping

| Host | Advisor mechanism |
|---|---|
| Factory/Droid | invoke project droid `wb-advisor` |
| Claude Platform API | use native `advisor_20260301` if available |
| Claude Code | use read-only advisor subagent when available |
| Codex | use higher-reasoning read-only advisor equivalent |
| Cursor | use prompt/report fallback |
| Generic | write advisor report and update state manually |

## Invocation Contract

Before high-risk design, implementation, uncertain remediation, or max-iteration-adjacent review decisions:

```text
IF advisor escalation criteria match:
  IF advisor budget remains:
    invoke host adapter advisor mechanism
    save advisor report under .wannabuild/outputs/advisor/
    update state.json advisor metadata
    record decision if impact is material
    resume executor
  ELSE:
    pause and ask user
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
Context Provided:
- <spec or repo summary excerpt>
Recommendation:
- <advisor guidance>
Stop Signal: yes|no
Decision Impact: none|scope|architecture|implementation|validation
Record In Decisions: yes|no
```

If `Decision Impact` is not `none`, `Record In Decisions` should be `yes` and the executor should append a concise entry to `.wannabuild/decisions.md`.

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

Advisor state is optional, but when present it must be merge-updated and never replace the full `state.json`.
