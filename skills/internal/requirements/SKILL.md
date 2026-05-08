---
name: wannabuild-requirements
description: Vision-first requirements discovery for WannaBuild. Interviews the user conversationally, synthesizes the product brief, and derives requirements, acceptance criteria, and integration scenarios after the vision is clear.
---

# WannaBuild Requirements Phase

Discover is a conversational interview and synthesis phase. It should feel like a strong product-minded engineer helping the user articulate what they actually want, not like a test-case intake form.

The user does not need to arrive with complete requirements. The orchestrator should draw out the vision, infer structure from the conversation, mark assumptions honestly, and only then derive acceptance criteria and verification scenarios.

## Analysis Agents

Requirements may use these specialist perspectives when they materially improve the synthesis:

| Agent | File | Role |
|---|---|---|
| Scope Analyst | `wb-scope-analyst` | MVP boundaries, feature priority, scope risks, size assessment |
| UX Perspective | `wb-ux-perspective` | Audience, desired feel, user flows, experience risks, testable journeys |

Do not hard-code agent count or force both agents every time.

- Tiny, clear requests can stay single-owner.
- Medium or ambiguous requests can use one or more focused analysis agents.
- Complex, high-risk, or multi-surface requests can use parallel perspectives if they are independently useful.
- Choose capability tier and reasoning effort per the adaptive delegation policy in `skills/internal/build/SKILL.md`; do not name concrete model IDs in the requirements plan.
- Record the delegation rationale in `.wannabuild/decisions.md` or the phase checkpoint: why agents were or were not used, what each owned, and what evidence they produced.

## Trigger Conditions

Run this phase when:

- the user starts a new build or feature request
- the user gives an exploratory improvement prompt such as "I want to work on this some", "I was thinking of ideas", "let's brainstorm this", or "what should we add?"
- the user says they want to define requirements
- no `.wannabuild/spec/requirements.md` exists
- existing requirements need to be refreshed because the user's intent changed materially

Do not start this phase without a concrete task, stage intent, or exploratory idea intent. If the user gives a rough or broad idea, interview to make it concrete instead of bouncing the prompt back.

## Input

Expected input:

- user goal or project idea
- current conversation transcript
- target codebase path
- any existing product/docs/design context
- optional existing requirements or sketches

The first user prompt is raw material, not a complete spec. Treat it as the beginning of discovery unless it is already fully specified.

## Execution Flow

1. **Confirm the concrete task.**
   - If the task is missing, ask for the actual goal.
   - If the task is too broad or exploratory, keep interviewing before narrowing.

2. **Run the vision interview before planning.**
   Explore, in natural language:
   - the product vision and why it matters
   - audience, users, and contexts of use
   - desired experience, tone, feel, and quality bar
   - core workflows from start to finish
   - feature inventory, priorities, and must-have vs later ideas
   - constraints, integrations, deadlines, data, platforms, and compatibility needs
   - explicit non-goals and things the user does not want
   - success signals: what would make the user say "yes, that's it"

3. **Synthesize the interview.**
   - Produce a concise problem brief.
   - Separate confirmed intent from inferred assumptions.
   - List open questions that would materially affect scope or implementation.
   - Ask follow-up questions only when the answer changes the plan or success criteria.

4. **Choose the analysis shape.**
   Decide whether specialist agents would improve the synthesis:
   - no agents for tiny, obvious, low-risk work
   - one focused agent for a single uncertain dimension
   - multiple parallel agents for independent perspectives or high uncertainty

   Each delegated task must be bounded, independently useful, and assigned an ownership area.

5. **Derive requirements after the vision is stable.**
   Turn the interview and any agent outputs into:
   - feature priorities
   - user stories or jobs-to-be-done
   - scope boundaries
   - acceptance criteria
   - integration test scenarios
   - risks, assumptions, and success metrics

   Derive test scenarios after the clarified vision, main flows, and desired behavior are understood.

6. **Present the synthesized requirements when useful.**
   Show the captured vision, scope, assumptions, and verification direction when it helps clarity. Continue to planning by default unless user judgment is needed.

## Agent Invocation Pattern

When agents are useful, pass the interview transcript and the specific question each agent should answer. Example shape:

```text
Task(subagent_type="<selected specialist>", run_in_background=<true when independent>)
  prompt: "Analyze the discovery transcript and codebase for <specific ownership area>.
           Focus on <scope/UX/risk/etc.>.
           Write full findings to .wannabuild/outputs/<agent>-requirements.md.
           Return ONLY: 'COMPLETE - [one sentence]. Report at <path>'"
```

The orchestrator chooses selected specialists, parallelism, capability tier, and reasoning effort from the task evidence. Do not use fixed model names or fixed agent counts.

## Synthesis

After analysis completes, the orchestrator writes `.wannabuild/spec/requirements.md`.

Merge all inputs into one coherent spec:

- user interview transcript
- existing requirements or docs
- codebase facts
- specialist outputs, if any
- orchestrator assumptions and decisions

If specialist outputs conflict, resolve the conflict explicitly in the spec or ask the user when the choice changes product intent.

## Output Artifact

The phase produces `.wannabuild/spec/requirements.md`:

```markdown
# Requirements Spec

## Vision Brief
[What the user wants to create, why it matters, and what "great" should feel like.]

## Project Overview
[1-2 sentences: what this is and who it is for.]

## Audience and Use Context
- **Primary users:** [who, goals, context]
- **Secondary users:** [optional]

## Desired Experience and Feel
- [Tone, pacing, quality bar, UX personality, trust/safety expectations, visual or interaction feel if relevant]

## Core User Flows
### [Flow Name]
1. [User/system step]
2. [User/system step]
3. [Successful end state]

## Feature Inventory and Priorities
### Must Have
- [Feature] - [why it matters]

### Should Have
- [Feature] - [why it matters]

### Later / Deferred
- [Feature] - [why deferred]

## Size Assessment
**Estimate:** [Tiny/Small/Medium/Large/Epic]
**Confidence:** [High/Medium/Low]
**Rationale:** [Why this size]

## User Stories / Jobs To Be Done
1. As a [user], I want [feature], so that [value]

## Acceptance Criteria
- [ ] [Testable criterion derived from the clarified vision]

## Scope
### In Scope
- [Capability that will be built]

### Out of Scope
- [Capability explicitly deferred]

## Integration Test Scenarios
### [Flow or Story Name]
- **Happy path:** [expected flow and assertion]
- **Failure path:** [failure mode and expected behavior]
- **Edge cases:** [important boundaries derived after the main flow is understood]

## Assumptions and Open Questions
### Assumptions
- [Inference made by the orchestrator]

### Open Questions
- [Question that still matters, or "None"]

## Scope Risks
| Risk | Severity | Notes |
|---|---|---|
| [risk] | High/Med/Low | [details] |

## Success Metrics
- [How to know the project succeeded]

## Delegation Rationale
- **Shape:** [single-owner / one specialist / parallel specialists]
- **Why:** [complexity, uncertainty, independence, risk]
- **Evidence:** [outputs consulted or reason agents were unnecessary]
```

## State Update

After writing `requirements.md`, update `.wannabuild/state.json`:

```json
{
  "current_phase": "requirements",
  "phase_status": "complete",
  "public_stage": "discover",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md"
  }
}
```

## Handoff

Next public step: Plan.

Continue autonomously by default. Ask only when unresolved ambiguity changes product direction, scope, or risk.

## User Interaction

After synthesis, present the requirements to the user:

```text
Here's what I've captured so far: the vision, core flows, feature priorities,
scope boundaries, assumptions, and how we'll verify the work. I'll continue
unless something here changes the direction.
```

The user can:

- approve and continue
- clarify the vision or desired feel
- add/remove/reprioritize features
- change scope
- answer open questions

If the user changes the vision materially, re-run only the affected synthesis or specialist analysis.

## Quality Checklist

- [ ] Vision, audience, desired feel, and core flows are captured
- [ ] Feature priorities distinguish must-have from deferred ideas
- [ ] Assumptions are explicit and not disguised as facts
- [ ] Open questions are limited to decisions that materially change scope or success
- [ ] Every user story or core flow has at least one acceptance criterion
- [ ] Acceptance criteria are testable and derived from the clarified vision
- [ ] Integration test scenarios exist for the important flows
- [ ] Edge cases are included without dominating the interview
- [ ] Scope boundaries are explicit
- [ ] Size assessment is honest with rationale
- [ ] Delegation rationale is recorded

## Contract Validation

Before handoff to Design:

```bash
scripts/validate-wannabuild-artifacts.sh . design
```

If validation fails:

1. Read the exact error
2. Fix the artifact or state
3. Re-run validation
4. Only proceed once it passes

## Edge Cases

- **User has existing requirements:** Treat them as input, then interview for missing vision, flows, feel, priorities, assumptions, and non-goals before formatting.
- **User only knows the vibe:** Keep asking vision and flow questions until a concrete task and success signal exist.
- **Scope is too large:** Mark it Epic and ask whether to narrow, split, or plan a first milestone.
- **User changes mind mid-phase:** Re-synthesize affected sections and re-run only relevant agents.
- **Greenfield vs. existing project:** Adapt the interview and analysis to the actual codebase and user context.
- **Testing conversation overwhelms the user:** Move test derivation later; capture the user's desired behavior first.
