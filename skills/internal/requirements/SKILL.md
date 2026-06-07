---
name: wannabuild-requirements
description: Vision-first requirements discovery for WannaBuild. Interviews the user conversationally, synthesizes the product brief, and derives requirements, acceptance criteria, and integration scenarios after the vision is clear.
---

# WannaBuild Requirements Phase

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Specialist judgment stays advisory unless a gate or acceptance criterion requires evidence.

Discover is a conversational interview and synthesis phase. Act as a strong product-minded engineer: drive the interview, propose recommendations, and resolve every decision WITH the user. This is not a test-case intake form.

Discovery is mandatory and collaborative on every task, including one-line changes, per Mandate 1 of `skills/internal/build/references/doctrine.md`. It is never optional, never auto-skipped, and never bypassed by a "trivial" classification. Only the user shortens it, by answering quickly.

The user does not need to arrive with complete requirements. The orchestrator draws out the vision, infers structure from the conversation, and derives acceptance criteria and verification scenarios. An item becomes a recorded assumption ONLY after resource acquisition (see Resource Exhaustion) has failed to resolve it; every assumption names the resources consulted.

## Analysis Agents

Requirements must use a required research bundle once the user's initial intent is clear enough to research. Additional specialists are selected by the deterministic table in "Choose adaptive research"; a specialist whose trigger fires is always run, not added by judgment.

| Agent | File | Role |
|---|---|---|
| Scope Analyst | `wb-scope-analyst` | MVP boundaries, feature priority, scope risks, size assessment |
| UX Perspective | `wb-ux-perspective` | Audience, desired feel, user flows, experience risks, testable journeys |
| Feasibility Analyst | `wb-feasibility-analyst` | Implementation path, dependencies, unknowns, complexity, and effort risk |
| Alternatives Analyst | `wb-alternatives-analyst` | Direct competitors, adjacent alternatives, existing tools/libraries, manual workflows, and do-nothing options |
| Failure Forecast Analyst | `wb-failure-forecast` | Pre-mortem-style failure causes, warning signs, mitigations, and qualifying questions |

The required bundle (feasibility, alternatives/competition, Failure Forecast) is always produced as three distinct artifacts on every task. Whether they come from delegated sub-agents or from the orchestrator directly does not change the obligation — the artifacts and their acquired evidence are mandatory.

- The required bundle is feasibility, alternatives/competition, and Failure Forecast — always three distinct artifacts, never folded or dropped.
- You MUST attempt delegation via the host's sub-agent mechanism for the bundle. If the host cannot delegate, the orchestrator produces the same three artifacts directly at the same depth and records in the Delegation Rationale that delegation was unavailable and why. "Tiny" or "clear" is never grounds to drop an artifact.
- Delegation shape (single-owner / one specialist / parallel specialists) is selected by the Size Rubric below, not by self-assessed effort. Larger sizes add parallel specialists; they never remove the bundle.
- Choose capability tier and reasoning effort per the adaptive delegation policy in `skills/internal/build/SKILL.md`; do not name concrete model IDs in the requirements plan.
- Record the delegation rationale in `.wannabuild/decisions.md` or the phase checkpoint: which shape was used and why, what each owner produced, and the acquired evidence behind each artifact.

## Size Rubric

The Size Assessment is deterministic, not a feel. Compute it from the change surface and apply the matching delegation shape every run:

| Size | Objective criteria (any one qualifies the size up) | Delegation shape |
|---|---|---|
| Tiny | 1 affected surface, 0 new external dependencies, 0 data-model changes, ~1 slice | Single-owner bundle (3 artifacts) |
| Small | ≤2 affected surfaces, 0 new external dependencies, 0 data-model changes, ≤2 slices | Single-owner bundle (3 artifacts) |
| Medium | 3–5 affected surfaces, or 1 new external dependency, or a non-breaking data-model change, or 3–5 slices | Bundle + every adaptive specialist whose trigger fires |
| Large | 6–10 affected surfaces, or ≥2 new external dependencies, or a breaking data-model change, or 6–10 slices | Bundle + adaptive specialists, run as parallel perspectives |
| Epic | >10 affected surfaces, or new external system/service, or >10 slices | Bundle + adaptive specialists in parallel; stop and ask the user whether to narrow, split, or scope a first milestone |

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

2. **Run the vision interview before planning, using the Grill rules.**
   The vision interview is a Grill. It is mandatory — discovery cannot progress to research or planning without it — and it follows the same contract as `wb-discover`:
   - Ask one question at a time. Do not batch.
   - For every question, propose a recommended answer with the reasoning behind it. The user confirms, redirects, or overrides — they should never have to invent the answer from scratch.
   - Walk the decision tree depth-first; resolve each decision before asking ones that depend on it.
   - Before asking, resolve the question yourself from available resources per Resource Exhaustion: read the codebase, manifests, lockfiles, and config; read live library/API docs via Context7; probe connectors and CLIs. Cite exactly what you found and move on. Only ask the user when the answer cannot be acquired or the decision is a product/scope/cost/dependency choice the user owns.
   - Continue the one-question-at-a-time Grill until every decision that affects scope, product direction, risk, cost, external dependencies, or success is explicitly resolved with the user. Do not advance to research while any such decision remains open.
   - Short affirmatives ("ok", "sure", "fine") accept a single-recommendation question ONLY when the decision does not change product scope, architecture, cost, or external dependencies. For scope-, product-, cost-, or dependency-affecting decisions, and for every multi-option question, require an explicit choice — re-ask with the options if the user only says "ok". Phase boundaries (Discover → Plan, etc.) require an explicit approval word ("go", "proceed", "approved", "lgtm", "do it", "continue", "next") regardless of question shape; a vague acknowledgment never crosses a boundary.

   Explore, in natural language:
   - the product vision and why it matters
   - audience, users, and contexts of use
   - desired experience, tone, feel, and quality bar
   - core workflows from start to finish
   - feature inventory, priorities, and must-have vs later ideas
   - constraints, integrations, deadlines, data, platforms, and compatibility needs
   - budget, time tolerance, operating constraints, and maintenance appetite
   - decision tradeoffs where the user may prefer speed, quality, flexibility, cost, or control
   - explicit non-goals and things the user does not want
   - success signals: what would make the user say "yes, that's it"

3. **Synthesize the initial interview.**
   - Produce a concise problem brief.
   - Separate confirmed intent from assumptions; record an assumption only after Resource Exhaustion failed to resolve it, naming the resources consulted.
   - List open questions that materially affect scope or implementation — but only after you attempted to answer each from the codebase, live docs (Context7), and connectors/CLIs, and recorded what you tried. Never record a question you could have answered yourself.
   - Keep grilling until every scope-, product-, risk-, cost-, or success-affecting decision is resolved with the user before advancing to research.

4. **Run the required research bundle.**
   Once the intent is clear enough to research without guessing, always produce all three:
   - `.wannabuild/outputs/discovery/feasibility.md`
   - `.wannabuild/outputs/discovery/alternatives-competition.md`
   - `.wannabuild/outputs/discovery/failure-forecast.md`

   You MUST attempt delegation via the host's sub-agent mechanism. If the host cannot delegate, the orchestrator produces the same three artifacts directly at the same depth and records the unavailability in the Delegation Rationale. Each artifact must carry a "Resources consulted" subsection (codebase paths, Context7 lookups, connector/CLI probes) and concrete findings — an artifact built only from guesses fails the gate.

5. **Choose adaptive research.**
   Run every adaptive specialist whose trigger fires; the trigger, not judgment, decides. Each fired specialist produces a bounded, independently useful artifact with its own "Resources consulted" subsection:
   - UX or accessibility — when the change touches a user-facing flow, screen, or interaction
   - security or privacy — when the change touches auth, secrets, personal data, permissions, or external input
   - external integrations — when the change calls or depends on any external API, service, or connector; exercise the real surface (MCP connectors such as Supabase/Railway/Neon/Vercel, provider CLIs, live API docs via Context7), do not infer it
   - data model, migration, or compatibility — when the change adds, alters, or migrates persisted data
   - compliance or policy — when the change touches regulated data, billing, or policy-governed behavior
   - performance or scale — when the change affects a hot path, large dataset, or concurrency
   - monetization, pricing, or market positioning — when the change affects what is sold or how it is priced
   - domain-specific research — when the task names a domain whose rules you cannot derive from the codebase

   Record in the Delegation Rationale every specialist that fired and every one whose trigger did not, with the concrete reason its trigger was absent.

6. **Ask research-informed qualifying questions.**
   Synthesize the required bundle and adaptive findings into `.wannabuild/outputs/discovery/followup-questions.md`. Surface every question that materially changes scope, product direction, risk, cost, or success. A question reaches the user only after Resource Exhaustion failed to answer it; questions you could have resolved from the codebase, live docs, or connectors are answered, not asked. Where a question offers a path forward, present it as options with a recommended answer.

7. **Derive requirements after the vision is qualified.**
   Turn the interview, research, and any agent outputs into:
   - feature priorities
   - user stories or jobs-to-be-done
   - scope boundaries
   - acceptance criteria
   - integration test scenarios
   - risks, assumptions, and success metrics
   - research synthesis, qualified decisions, and Failure Forecast impact

   Derive test scenarios after the clarified vision, main flows, and desired behavior are understood.

8. **Present the synthesized requirements and stop at the boundary.**
   Always present the captured vision, core flows, scope, assumptions (each with the resources consulted), and verification direction to the user. In guided mode (the default), STOP at the Discover → Plan boundary and require an explicit approval word ("go", "proceed", "approved", "continue", "next", "lgtm", "do it") before planning. A vague acknowledgment ("ok", "sure") never crosses the boundary. In autonomous mode, continue automatically, but still present the synthesis and still stop to ask when an unresolved ambiguity changes product direction, scope, cost, or risk.

## Agent Invocation Pattern

When delegating, pass the interview transcript and the specific question each agent owns. The required research bundle is always represented by its three artifacts, whether delegated or produced directly when the host cannot delegate. Example shape:

```text
Task(subagent_type="<selected specialist>", run_in_background=<true when independent>)
  prompt: "Analyze the discovery transcript and codebase for <specific ownership area>.
           Focus on <scope/UX/risk/etc.>.
           Write full findings to .wannabuild/outputs/discovery/<artifact>.md.
           Return ONLY: 'COMPLETE - [one sentence]. Report at <path>'"
```

The orchestrator selects specialists by the adaptive-research triggers, parallelism by the Size Rubric, and capability tier and reasoning effort from the task evidence. Do not use fixed model names; the bundle's three artifacts are fixed and never optional.

## Resource Exhaustion (mandatory)

Before recording any fact as an unknown, assumption, open question, or blocker, you MUST first attempt to obtain it from available resources and record exactly what you tried, per Mandate 2 of `skills/internal/build/references/doctrine.md`:

1. Read the real codebase, package manifests, lockfiles, and config to resolve how the project actually works today.
2. Read live library, framework, and API docs via Context7 to resolve version, capability, and feasibility questions instead of guessing.
3. Probe the actual integration surface for any external dependency — MCP connectors (Supabase, Railway, Neon, Vercel), provider CLIs, and live API docs — rather than inferring behavior.
4. Generate fixtures, read existing data shapes, or stand up a local/ephemeral environment when a question needs runtime evidence.

"Missing env", "no access", or "can't check" is never grounds to stop or to skip an artifact — it is grounds to acquire the resource (anything safe, local, and reversible: run locally, spin an ephemeral DB branch, drive a real browser, read live docs) or, only for billable, outward-facing, or destructive acquisition, to stop and ask the user with the specific resource named.

If an acquisition attempt fails, log it in `.wannabuild/outputs/acquisition-log.json` (what was needed, which tools/connectors/CLIs were attempted, the result) so `assert-acquisition-attempted` can verify it. A blocker, unknown, or assumption with no logged attempt does not pass.

## Synthesis

After analysis completes, the orchestrator writes `.wannabuild/spec/requirements.md`.

Merge all inputs into one coherent spec:

- user interview transcript
- existing requirements or docs
- codebase facts
- required research outputs
- specialist outputs, if any
- orchestrator assumptions and decisions

If specialist outputs conflict, resolve the conflict explicitly in the spec or ask the user when the choice changes product intent.

Runtime verifies the durable artifacts and `.wannabuild/state.json` discovery evidence. It cannot prove a host truly spawned an agent, so the skill contract owns delegation behavior.

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

## Research Synthesis
### Feasibility
- [Implementation path, dependencies, unknowns, and effort risks]
- **Resources consulted:** [codebase paths, Context7 doc lookups, connector/CLI probes used to verify dependency/version reality — a dependency or version is "unknown" only after these failed]

### Alternatives and Competition
- [Direct competitors, adjacent alternatives, existing tools/libraries, manual workflow, do-nothing option]

### Failure Forecast Impact
- [Likely failure causes, warning signs, mitigations, and requirements changes]

## Qualified Decisions
- [Decision clarified after research and user follow-up]

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
- [Inference made by the orchestrator] — **resources consulted:** [codebase paths, Context7 lookups, connector/CLI probes that were tried and failed to resolve this before it became an assumption]

### Open Questions
- [Question that still matters, with the resources already tried and why they did not resolve it, or "None"]

## Scope Risks
| Risk | Severity | Notes |
|---|---|---|
| [risk] | High/Med/Low | [details] |

## Success Metrics
- [How to know the project succeeded]

## Delegation Rationale
- **Shape:** [single-owner / one specialist / parallel specialists, per the Size Rubric]
- **Delegation:** [attempted via host sub-agents, or produced directly because the host cannot delegate]
- **Specialists fired:** [each adaptive specialist that ran and why; each whose trigger was absent and the concrete reason]
- **Evidence:** [the acquired evidence behind each artifact — codebase paths, Context7 lookups, connector/CLI probes]
```

## State Update

After writing the required discovery artifacts and `requirements.md`, update `.wannabuild/state.json`:

```json
{
  "current_phase": "requirements",
  "phase_status": "complete",
  "public_stage": "discover",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "discovery_feasibility": ".wannabuild/outputs/discovery/feasibility.md",
    "discovery_alternatives_competition": ".wannabuild/outputs/discovery/alternatives-competition.md",
    "discovery_failure_forecast": ".wannabuild/outputs/discovery/failure-forecast.md",
    "discovery_followup_questions": ".wannabuild/outputs/discovery/followup-questions.md"
  },
  "discovery": {
    "interview": {"status": "complete"},
    "research": {
      "feasibility": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/feasibility.md"},
      "alternatives_competition": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/alternatives-competition.md"},
      "failure_forecast": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/failure-forecast.md"}
    },
    "followup_questions": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/followup-questions.md"},
    "synthesis": {"status": "complete", "artifact": ".wannabuild/spec/requirements.md"}
  }
}
```

## Handoff

Next public step: Plan.

In guided mode (the default), present the synthesis and STOP at the Discover -> Plan boundary; require an explicit approval word ("go", "proceed", "approved", "continue", "next", "lgtm", "do it") before planning. A vague acknowledgment ("ok", "sure") holds at the boundary. In autonomous mode, still present the synthesis, then continue automatically, stopping to ask when unresolved ambiguity changes product direction, scope, cost, or risk.

## User Interaction

After synthesis, always present the requirements to the user and hold at the boundary until an explicit approval word arrives:

```text
Here's what I've captured: the vision, core flows, feature priorities, scope
boundaries, assumptions (with what I checked to resolve each), and how we'll
verify the work. Say "go" / "proceed" / "approved" to move on to Plan, or tell
me what to change.
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
- [ ] Each assumption names the resources consulted and was recorded only after acquisition failed
- [ ] Each open question records the resources already tried, and materially changes scope, product direction, risk, cost, or success
- [ ] Every user story and every core flow has at least one acceptance criterion
- [ ] Acceptance criteria are testable and derived from the clarified vision
- [ ] Integration test scenarios exist for every core flow
- [ ] Edge cases are captured for every core flow
- [ ] Scope boundaries are explicit
- [ ] Size assessment is computed from the Size Rubric with rationale
- [ ] Delegation rationale records shape, delegation availability, specialists fired/not-fired, and acquired evidence
- [ ] Feasibility artifact carries a "Resources consulted" subsection with concrete findings, and affected follow-up questions or requirements
- [ ] Alternatives/competition artifact carries a "Resources consulted" subsection with concrete findings, and affected follow-up questions or requirements
- [ ] Failure Forecast artifact carries a "Resources consulted" subsection with concrete findings, and affected follow-up questions or requirements
- [ ] Every adaptive specialist whose trigger fired produced an artifact with a "Resources consulted" subsection
- [ ] Any blocker, unknown, or unmet need has a logged attempt in `.wannabuild/outputs/acquisition-log.json`
- [ ] The user explicitly approved the synthesis at the Discover -> Plan boundary (guided mode)
- [ ] `scripts/wannabuild-session.sh assert-discovery-ready .` passes before Plan

## Contract Validation

Before handoff to Design:

```bash
scripts/wannabuild-session.sh assert-discovery-ready .
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
- **User changes mind mid-phase:** Re-synthesize affected sections and re-run the specialists whose inputs changed. The required bundle's three artifacts are always refreshed when the vision changes materially; never drop one to save effort.
- **Greenfield vs. existing project:** Adapt the interview and analysis to the actual codebase and user context.
- **Testing conversation overwhelms the user:** Move test derivation later; capture the user's desired behavior first.
