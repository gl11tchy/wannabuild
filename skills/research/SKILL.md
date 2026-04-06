# WannaBuild Research Burst

> Optional multi-agent research before planning.

Use this when discovery has surfaced meaningful uncertainty and the user chooses research before planning.

## Purpose

Research is not a permanent public phase. It is a bounded pre-planning burst used when more investigation would materially improve the plan.

## When To Use

Trigger research when one or more of these are true:

- architecture direction is still unclear
- external dependencies or frameworks need comparison
- the codebase needs deeper reconnaissance
- domain, API, auth, billing, or infra uncertainty is high
- risk is high enough that parallel investigation will improve planning quality

## Research Agents

Use a bounded set of existing specialists:

- `wb-tech-advisor`
- `wb-architect`
- `wb-risk-assessor`

Optionally include:

- `wb-scope-analyst` when scope uncertainty remains high
- `wb-ux-perspective` when user journey uncertainty remains high

## Output

Write a concise synthesis into `.wannabuild/outputs/research-summary.md` with:

- key findings
- recommended direction
- open questions
- risks that still require explicit user choice

The research burst should end by handing off to planning.
