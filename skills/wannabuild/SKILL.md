---
name: wannabuild
description: Codex-first WannaBuild workflow for discover -> plan -> implement -> review -> qa -> summary
---

# WannaBuild

Use this skill when the user wants WannaBuild itself, not generic coding help.

## Invocation Guard

If the user invokes `$wannabuild` with no concrete task or only asks what the workflow is:

- do **not** inspect the repo deeply
- do **not** infer the task from git diff, branch state, or uncommitted changes
- do **not** browse the web
- do **not** edit files
- do **not** start planning or implementation

Instead, respond with a short start prompt and ask for the actual goal.

Use this exact structure:

```text
[WB-START] WannaBuild STARTED | intent=build | mode=standard

Tell me what you want to build or change.
```

Only begin Discover after the user provides an actual task.

## Mandatory Workspace Bootstrap

If the current project is a git repo and the user has provided a concrete task:

1. create an isolated workspace before Discover
2. continue all reads and writes in that workspace only
3. never continue work in the original checkout

Use:

`../../scripts/wannabuild-workspace.sh --json`

Then initialize session state in the new workspace:

`../../scripts/wannabuild-session.sh init <workspace_path>`

Write `.wannabuild/workspace.json` and `.wannabuild/state.json` in the isolated workspace before continuing.

If workspace bootstrap fails, stop and report the failure instead of continuing in-place.

## Workflow

Run this condensed workflow:

1. Discover
2. Control mode gate
3. Research gate
4. Plan
5. Implement
6. Review
7. QA
8. Summary

## Defaults

- Keep Discover, Plan, QA, and Summary single-lane by default.
- Default to guided mode until the user explicitly switches to autonomous mode after Discover.
- Offer optional research before planning when uncertainty is still materially high.
- Offer implementation in:
  - solo-owner mode
  - parallel mode when work splits cleanly
- Keep review adaptive rather than maximal by default.
- The integration tester is the hard gate.

## Internal References

Use these repo contracts as needed:

- `../../AGENTS.md`
- `../build/SKILL.md`
- `../requirements/SKILL.md`
- `../design/SKILL.md`
- `../tasks/SKILL.md`
- `../implement/SKILL.md`
- `../review/SKILL.md`
- `../ship/SKILL.md`
- `../document/SKILL.md`
- `../../scripts/validate-wannabuild-artifacts.sh`

## Startup

Use:

`[WB-START] WannaBuild STARTED | intent=build | mode=standard`

If resuming from `.wannabuild/state.json`, use:

`[WB-RESUME] WannaBuild RESUME | mode=standard | phase=<current_phase> | progress=<done>/<total>`

Do not ask the user to choose between Full, Light, or Spark. Run one standard workflow.

For compatibility with older internal phase files, hidden state may still persist `mode: "full"`. That is an internal implementation detail, not a user-facing choice.

## Control Mode Gate

After Discover, ask exactly once:

1. Continue in guided mode
2. Switch to autonomous mode

Guided mode:

- ask for user preference at each later gate
- do not advance silently

Autonomous mode:

- continue adaptively through later gates without asking every time
- still stop for destructive actions, real blockers, or ambiguity that changes scope materially

Persist the choice in `.wannabuild/state.json`:

- `control_mode: "guided"`
- `control_mode: "autonomous"`

Use:

- `../../scripts/wannabuild-session.sh set-stage <workspace_path> control_mode_decision in_progress`
- `../../scripts/wannabuild-session.sh set-control-mode <workspace_path> guided`
- `../../scripts/wannabuild-session.sh set-control-mode <workspace_path> autonomous`

## Research Gate

After discovery, decide whether research would materially improve planning quality.

If `control_mode` is `guided` and research is warranted, offer the user exactly two paths:

1. Kick off research agents
2. Move to planning

Ask this only when at least one of these is true:

- architecture direction is still unclear
- external dependency choice matters
- codebase reconnaissance is incomplete
- domain or API uncertainty is high
- risk is high enough that parallel investigation would help

If research is chosen:

- run a bounded research burst using the existing specialist agents
- synthesize findings into a concise research summary
- then proceed to planning
- update stage to `research`

If research is not warranted:

- say that you have enough context to plan
- move directly to planning
- update stage to `plan`

If `control_mode` is `autonomous`, you may choose the better path adaptively.

## Implementation Gate

After planning is complete and the approach is verified:

If `control_mode` is `guided`, offer exactly two paths:

1. Implement in solo-owner mode
2. Implement with parallel agents

Default to solo-owner mode unless the work splits cleanly.

Do not begin implementation in guided mode until the user has selected a path or clearly delegated the choice.

If `control_mode` is `autonomous`, choose adaptively.

## Review Gate

After implementation completes, move to a distinct Review stage.

Run these agents as a separate post-implementation gate:

- `wb-security-reviewer`
- `wb-performance-reviewer`
- `wb-architecture-reviewer`
- `wb-testing-reviewer`
- `wb-integration-tester`
- `wb-code-simplifier`

Write verdicts into `.wannabuild/review/`.

Use:

`../../scripts/wannabuild-session.sh set-stage <workspace_path> review in_progress`

Do not treat implementation-time checks as the Review stage.

If `control_mode` is `guided`, ask before running Review:

1. Run review now
2. Adjust before review

If `control_mode` is `autonomous`, proceed adaptively.

## QA Gate

After Review passes, move to a distinct QA stage.

QA must:

- confirm acceptance criteria coverage
- confirm integration behavior
- write `.wannabuild/outputs/qa-summary.md`

Use:

`../../scripts/wannabuild-session.sh set-stage <workspace_path> qa in_progress`

Do not collapse QA into implementation verification.

If `control_mode` is `guided`, ask before running QA:

1. Run QA now
2. Adjust before QA

If `control_mode` is `autonomous`, proceed adaptively.

## Summary Guard

Do not emit the final Summary until Review and QA are both complete.

Before summarizing, require:

- `../../scripts/wannabuild-gate-check.sh <workspace_path> summary`

Then set:

`../../scripts/wannabuild-session.sh set-stage <workspace_path> summary complete`

If `control_mode` is `guided`, ask before final summary:

1. Summarize now
2. Continue working

If `control_mode` is `autonomous`, summarize once gates pass.

## Output Contract

Always finish with:

- what changed
- what passed
- gaps or risks
- remaining work

Keep the user experience compact even if the internal machinery is deeper.

## Discovery Budget

During Discover, before the user has approved planning:

- keep inspection bounded and relevant to the stated task
- prefer a few high-signal reads over broad repo spelunking
- do not anchor to unrelated in-flight diffs unless the user explicitly says the current diff is the task
- if the task is still unclear, ask instead of continuing to infer

## Stage Machine

Persist and update these public stages in `.wannabuild/state.json`:

1. `discover`
2. `control_mode_decision`
3. `research_decision`
4. `research`
5. `plan`
6. `implementation_decision`
7. `implement`
8. `review`
9. `qa`
10. `summary`

Use:

- `../../scripts/wannabuild-session.sh set-stage <workspace_path> <stage> in_progress`
- `../../scripts/wannabuild-session.sh set-stage <workspace_path> <stage> complete`

Do not skip stages silently.
