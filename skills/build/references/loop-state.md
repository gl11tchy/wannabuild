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
- `routing_reason` (string: `base_set`, `impacted`, `fallback`, `fast_track_fallback`, `ambiguous_impact`)

## Terminal statuses
- `approved`: latest iteration passed active-set unanimously
- `escalated`: max iterations reached without approval
- `blocked`: hard gate failed with no override path (ex: integration tester still failing)

## Update discipline
- Append a new entry per review iteration.
- Increment `current_iteration` only after verdict aggregation.
- Preserve all historical iterations for traceability.
