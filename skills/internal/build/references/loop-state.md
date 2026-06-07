# Review Loop State Reference

The loop state is persisted in `.wannabuild/loop-state.json`.

## Top-level schema

```json
{
  "mode": "standard",
  "current_iteration": 2,
  "max_iterations": 3,
  "base_reviewer_count": 6,
  "status": "in_progress",
  "guardrails": {
    "max_agent_runs_per_phase": 18,
    "max_total_review_runs": 12,
    "max_prompt_chars_per_reviewer": 12000,
    "on_limit": "pause-and-ask"
  },
  "iterations": []
}
```

## Iteration record schema

Each entry in `iterations` must include:

- `iteration`
- `timestamp`
- `active_reviewers`
- `verdicts` map keyed by agent name
- `pass_count`
- `fail_count`
- `feedback_sent` (optional)
- `routing_reason` (string: always `full_set` — the full reviewer set runs every iteration; legacy values like `impacted`/`fast_track_fallback` are no longer produced)

## Terminal statuses

- `approved`: the latest iteration passed the FULL reviewer set unanimously, each reviewer covered the entire changed surface, and the integration tester PASS carries execution evidence (tests ran; every acceptance criterion covered)
- `escalated`: max iterations reached without approval — surfaced to the user
- `blocked`: a hard gate failed with no override path (ex: integration tester still failing). A resource blocker may become `blocked` only after `assert-acquisition-attempted` passes (a logged acquisition attempt exists) — never on an unattempted "missing env" claim

## Update discipline

- Append a new entry per review iteration.
- Increment `current_iteration` only after verdict aggregation.
- Preserve all historical iterations for traceability.
