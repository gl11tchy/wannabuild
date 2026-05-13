# WannaBuild Research Burst

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Specialist judgment stays advisory unless a gate or acceptance criterion requires evidence.

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

Use the smallest useful set of existing specialists. Choose by uncertainty type, independence, expected evidence, capability tier, and reasoning effort.

Common specialist fits:

- `wb-tech-advisor` when technology choice, dependency, or build-vs-buy uncertainty matters
- `wb-architect` when system shape, contracts, or integration boundaries are unclear
- `wb-risk-assessor` when blast radius, security, migration, compliance, or operational risk is material
- `wb-scope-analyst` when scope boundaries or MVP priority remain unclear
- `wb-ux-perspective` when user journey, desired feel, or experience risk remains unclear

Record why each selected specialist was used, what it owned, and what evidence it produced. Do not use fixed agent counts or concrete model IDs.

## Output

Write a concise synthesis into `.wannabuild/outputs/research-summary.md` with:

- key findings
- recommended direction
- open questions
- risks that still require explicit user choice

The research burst should end by handing off to planning.
