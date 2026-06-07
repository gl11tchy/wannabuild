# WannaBuild Design Phase

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Specialist judgment stays advisory unless a gate or acceptance criterion requires evidence.

> Phase 2 of 7 in the WannaBuild SDD pipeline. Transforms requirements into a technical blueprint with architecture, tech stack decisions, data models, API contracts, testing strategy, and risk assessment.

## Agents

Design always runs these specialist perspectives. The depth of each analysis scales
with the change; the set of agents that run does not. This follows doctrine Mandate 3
(completeness — full specialist set every run; see
`skills/internal/build/references/doctrine.md`).

| Agent | File | Role |
|-------|------|------|
| Architect | `wb-architect` | System architecture, data models, API contracts, testing strategy |
| Tech Advisor | `wb-tech-advisor` | Tech stack evaluation, build-vs-buy, dependencies |
| Risk Assessor | `wb-risk-assessor` | Risk identification, probability/impact scoring, mitigations |

`wb-architect` MUST run on every design — it owns architecture, data models, API
contracts, and testing strategy, which every design produces. `wb-tech-advisor` and
`wb-risk-assessor` MUST run under the deterministic conditions in the Agent Selection
table below. There is no single-owner shortcut and no "smallest useful set": an agent
may not opt out, and the orchestrator may not declare an analysis unnecessary.

## Agent Selection

Selection is deterministic: identical input produces the identical agent set, tier, and
effort on every run (doctrine Mandate 4 — fixed pipeline, adaptive depth only). Apply
these exact rules; do not score "uncertainty" or "blast radius" by judgment.

| Condition (observable) | Agent | Capability tier | Reasoning effort |
|---|---|---|---|
| Always (every design) | `wb-architect` | strong | high |
| >1 candidate stack, OR a new/changed framework, library, datastore, or hosting target | `wb-tech-advisor` | standard | medium |
| Design touches auth, user data, payments/money, external integrations, or a data migration | `wb-risk-assessor` | standard | high |

When neither additive condition applies, `wb-tech-advisor` and `wb-risk-assessor` still
run at `standard`/`medium` to confirm there is no hidden dependency or risk — their
absence is never assumed.

## Live Verification

Every tech-stack, data-model, and API-contract decision MUST be verified against live
reality before it is recorded, and the evidence logged to
`.wannabuild/outputs/design-verification.md` (doctrine Mandate 2 — exhaust resources,
record exactly what was executed). "I recall the API" is not verification.

- **Every library/framework choice:** resolve current docs via Context7
  (`resolve-library-id` then `get-library-docs`) and confirm the chosen version and the
  exact API surface you depend on exist. Cross-check against the installed version found
  in step 3.
- **Every data model:** provision a throwaway database branch (Supabase `create_branch`,
  Neon `create_branch`, or a local stack) and apply the model as a migration to prove
  the schema is valid before recording it. Branch creation that is billable or
  destructive is stop-and-ask; local/ephemeral creation is auto-acquired.
- **Every API contract:** confirm the assumed platform capability actually exists
  (e.g. function runtime limits, edge-function signature, service behavior) by reading
  live provider docs via Context7 or probing a preview/ephemeral environment.
- **On low confidence, acquire — do not defer.** You may NOT punt a stack, model, or
  contract decision to a future "spike" without first exhausting acquisition above. Only
  after a logged, failed acquisition attempt in
  `.wannabuild/outputs/acquisition-log.json` (which `assert-acquisition-attempted`
  reads) may a decision carry an explicit, evidence-backed open question — and even then
  it is surfaced to the user as a decision, never silently dropped.

## Trigger Conditions

**Explicit:**

- `/wannabuild-design` (auto-prefixed when installed as plugin)
- "Let's design this"
- "How should we build it?"

**Implicit (from orchestrator):**

- Requirements phase completes → auto-transition to Design

## Input

**Handoff from Requirements:**

```json
{
  "phase": "design",
  "from": "requirements",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md"
  },
  "codebase_path": "/path/to/project"
}
```

Selected agents read `spec/requirements.md` as their primary input and scan the codebase for existing patterns.

## Execution Flow

1. Read `spec/requirements.md`, including vision, desired feel, flows, assumptions, and acceptance criteria.
2. **Upstream-quality gate (fail-closed):** Before designing, verify `requirements.md`
   is complete — it has a vision, the primary user flows, named constraints, and an
   **Acceptance Criteria** section with at least one concrete, checkable criterion. If
   any of these is missing, vague, or untestable, STOP and return to discovery to grill
   the user (one question at a time, each with a recommended answer) until requirements
   pass `assert-discovery-ready`. Do not design against an incomplete spec.
3. Inspect the existing codebase to ground every decision in reality. You MUST read the
   project's package manifests and lockfiles (e.g. `package.json` + lockfile,
   `pyproject.toml`/`requirements.txt`, `go.mod`, `Cargo.toml`) to enumerate installed
   dependencies and pinned versions, and read the existing module/test layout. Record
   the installed versions you found; tech-stack choices MUST be consistent with them or
   explicitly justify the change.
4. Run the specialist set per the **Agent Selection** table below — `wb-architect`
   always, plus `wb-tech-advisor` and `wb-risk-assessor` whenever their conditions hold.
   Capability tier and reasoning effort come from the same table, not from judgment.
5. **Live verification (fail-closed):** Before recording any tech-stack, data-model, or
   API-contract decision, verify it against reality and log the evidence to
   `.wannabuild/outputs/design-verification.md`. See **Live Verification** below. A
   decision with no verification evidence is incomplete and fails the gate.
6. Synthesize verified outputs into `design.md`.
7. Collaborate with the user decision-by-decision (see **User Interaction**), presenting
   each material choice with options, a recommended answer, and the trade-off.
8. Record delegation rationale, the agent-selection conditions that fired, and every
   decision's recommended answer in `.wannabuild/decisions.md`.

## Agent Spawning

Use adaptive agent spawning:

```text
Task(subagent_type="<selected design specialist>", run_in_background=<true when independent>)
  capability_tier: <lightweight / standard / strong>
  reasoning_effort: <low / medium / high>
  ownership: <architecture / tech choice / risk / testing strategy>
  prompt: "Analyze the design for <specific ownership area>.
           Requirements: {requirements_path}. Codebase: {codebase_path}.
           Write your full analysis to .wannabuild/outputs/<agent>-design.md.
           Return ONLY: 'COMPLETE - [one sentence]. Report at <path>'"
```

Selected agents write their full analysis to `.wannabuild/outputs/` and return a one-line status to the main conversation.

## Synthesis

After the specialist set completes, the orchestrator reads every `.wannabuild/outputs/`
report and `design-verification.md`, then:

1. **Merge architecture and tech stack decisions** from the architect and tech-advisor reports.
2. **Resolve and surface decisions:** Present every material decision — each tech-stack row, each architecture decision, each high-impact risk — to the user as options + recommended answer + trade-off (see **User Interaction**). Conflicts between specialists are surfaced this way too; non-conflicting but consequential choices are surfaced just the same — silent single-owner picks are forbidden.
3. **Incorporate risks** from the risk-assessor report into architecture decisions.
4. **Ensure testing strategy** is present and complete (framework, boundaries, mock strategy, CI requirements). A testing strategy is always producible; "too uncertain" is not an exit.
5. **Completeness gate (fail-closed):** The design FAILS — and the phase does not advance — if any of the following hold: a template token remains (`[field]`, `[type]`, `[chosen]`, `[risk]`, `[what]`, etc.), or `TBD`/`to-do`/`stub`/`mock`/`placeholder` appears as an unresolved escape; any required section is empty; any tech-stack, data-model, or API-contract decision lacks verification evidence in `design-verification.md`; or any requirements acceptance criterion maps to no architecture or risk entry. Run `scripts/validate-wannabuild-artifacts.sh <project_root> design` and treat a non-zero exit as a hard stop.
6. **Collaborate with the user** decision-by-decision before advancing.

## Output Artifact

The phase produces `.wannabuild/spec/design.md`:

```markdown
# Design Spec

## Architecture
[High-level system description]

### Architecture Diagram
```

[ASCII diagram]

```text

### File Structure
```

[Proposed directory layout]

```text

## Tech Stack Decisions
| Decision | Choice | Rationale | Alternative Considered |
|----------|--------|-----------|----------------------|
| [what] | [chosen] | [why] | [what else] |

## Data Models
### [Model Name]
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| [field] | [type] | Yes/No | [details] |

## API Contracts
### [Endpoint/Function]
- **Method/Signature:** [details]
- **Input:** [schema]
- **Output:** [schema]
- **Errors:** [error cases]

## Testing Strategy
### Test Framework
[Framework choice and rationale]

### Integration Boundaries
| Boundary | Components | Mock Strategy |
|----------|------------|---------------|
| [boundary] | [what connects] | [how to mock] |

### Test Data Strategy
[How test data is managed]

### CI Pipeline Requirements
[What runs in CI, in what order]

## Risks
| # | Risk | Category | Prob | Impact | Score | Mitigation |
|---|------|----------|------|--------|-------|------------|
| 1 | [risk] | [cat] | 1-5 | 1-5 | P×I | [mitigation] |

## Architecture Decisions
| Decision | Choice | Rationale | Trade-offs |
|----------|--------|-----------|------------|
| [what] | [chosen] | [why] | [what we give up] |

## Constraints
- [Technical constraints, compatibility requirements, performance targets]
```

## State Update

Merge into existing state.json (preserving `mode` and all other existing keys):

```json
{
  "current_phase": "design",
  "phase_status": "complete",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "design": ".wannabuild/spec/design.md"
  },
  "next_phase": "tasks"
}
```

## Handoff to Tasks Phase

```json
{
  "phase": "tasks",
  "from": "design",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "design": ".wannabuild/spec/design.md"
  },
  "codebase_path": "/path/to/project"
}
```

## User Interaction

After synthesis, collaborate decision-by-decision rather than dumping the whole design.
For each material decision — every tech-stack row, each architecture decision, each
high-impact risk — present:

> Decision: <what>. Options: <options considered>. Recommended: <choice>, because
> <reasoning, citing the live-verification evidence>. Trade-off: <what we give up>.

Walk open or conflicting decisions one at a time, each with its recommended answer, and
wait for the user's choice before recording it. Then close the boundary:

> Here's the technical design for your project. Pay special attention to the architecture decisions and testing strategy. If any tech stack choices or architectural patterns don't feel right, now is the time to change them — it's much cheaper to change a design than to change code.

**Hard-stop boundary (doctrine Mandate 4):** Design → Tasks does not cross until the
user gives an explicit approval word ("go", "proceed", "approved", "continue", "next",
"lgtm", "do it"). A vague acknowledgment ("ok", "sure") keeps refining the *current*
design; it never advances the phase.

The user can:

- **Approve:** Give an explicit approval word to move to the Tasks phase.
- **Modify:** Adjust specific decisions; re-run the affected agent(s) and re-verify.
- **Override:** Choose a different tech stack or architecture than recommended; the override is still live-verified before it is recorded.
- **Use existing design:** Permitted only if `.wannabuild/spec/design.md` already exists, passes `scripts/validate-wannabuild-artifacts.sh <project_root> design`, contains no template placeholders, and maps every requirements acceptance criterion. Otherwise the phase runs in full — there is no free skip.

## Quality Checklist

- [ ] Architecture diagram exists and is accurate
- [ ] Every tech stack decision has a rationale and live-verification evidence in `design-verification.md`
- [ ] Every data model was applied to a real (throwaway/local) database branch and the migration succeeded
- [ ] Every API contract is confirmed against live provider docs or a probed environment
- [ ] Data models cover all entities from requirements
- [ ] API contracts exist for all user-facing interactions
- [ ] Testing strategy is complete (framework, boundaries, mocks, CI)
- [ ] Risks are identified with concrete mitigations
- [ ] File structure is defined
- [ ] Design addresses all acceptance criteria from requirements
- [ ] No conflicts between tech stack and architecture decisions
- [ ] No template tokens, `TBD`, `to-do`, `stub`, `mock`, or `placeholder` remain in `design.md`
- [ ] `scripts/validate-wannabuild-artifacts.sh <project_root> design` exits 0

## Contract Validation

- The output spec must include all required sections:
  - `# Design Spec`
  - `## Architecture`
  - `## Tech Stack Decisions`
  - `## Data Models`
  - `## API Contracts`
  - `## Testing Strategy`
  - `## Risks`
  - `## Architecture Decisions`
- Every high-level decision in requirements must map to at least one architecture or risk entry.
- Testing strategy must define:
  - framework
  - integration boundaries
  - CI requirement
- If conflicting recommendations occur (e.g., tech stack + architecture), halt and request explicit user resolution.

## Edge Cases

- **Existing codebase with established architecture:** Agents adapt their recommendations to extend the existing architecture rather than replace it.
- **Conflicting agent recommendations:** Orchestrator presents each conflicting choice to the user with options, a recommended answer, and the trade-off, and waits for the decision (it is not merely "flagged").
- **Unknown tech stack:** You may NOT defer a stack choice to a "spike" without first exhausting acquisition — read live docs via Context7, stand up a throwaway database branch / ephemeral service / preview environment, and probe the behavior. Resolve the choice now. Only after a logged, failed acquisition attempt in `.wannabuild/outputs/acquisition-log.json` may a residual open question be surfaced to the user as a decision.
- **Testing strategy uncertainty:** A testing strategy is always producible — "too uncertain" is not an exit. If the stack is unsettled, resolve it via acquisition (run the stack in a sandbox, read framework docs, stand up a CI dry-run), then write the strategy. The strategy is never punted downstream undefined.
