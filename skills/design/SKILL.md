# WannaBuild Design Phase

> Phase 2 of 7 in the WannaBuild SDD pipeline. Transforms requirements into a technical blueprint with architecture, tech stack decisions, data models, API contracts, testing strategy, and risk assessment.

## Light Mode: This Phase Is Skipped

In Light mode, the orchestrator transitions directly from Requirements to Tasks. No design.md is written. The implementer infers architecture from the existing codebase. Use Full mode when you need to establish architecture, choose a tech stack, or assess risks before coding.

## Agents (Full Mode Only)

| Agent | File | Role |
|-------|------|------|
| Architect | `wb-architect` | System architecture, data models, API contracts, testing strategy |
| Tech Advisor | `wb-tech-advisor` | Tech stack evaluation, build-vs-buy, dependencies |
| Risk Assessor | `wb-risk-assessor` | Risk identification, probability/impact scoring, mitigations |

## Trigger Conditions

**Explicit:**
- `/wannabuild-design` (auto-prefixed when installed as plugin)
- "Let's design this"
- "How should we build it?"

**Implicit (from orchestrator):**
- Requirements phase completes → auto-transition to Design (Full mode only)

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

All three agents read `spec/requirements.md` as their primary input and scan the codebase for existing patterns.

## Execution Flow

```
spec/requirements.md (input)
        │
        ▼
┌──────────────────────────────────────────────┐
│  Parallel Agent Execution                    │
│                                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐ │
│  │ Architect│ │  Tech    │ │    Risk      │ │
│  │          │ │ Advisor  │ │  Assessor    │ │
│  └────┬─────┘ └────┬─────┘ └──────┬───────┘ │
│       │             │              │         │
└───────┼─────────────┼──────────────┼─────────┘
        │             │              │
        ▼             ▼              ▼
  ┌──────────────────────────────────────┐
  │  Orchestrator                        │
  │  Synthesizes into design.md          │
  │  Resolves conflicts between agents   │
  └──────────────────┬───────────────────┘
                     │
                     ▼
       Present to user for review
                     │
                     ▼
       Write .wannabuild/spec/design.md
```

## Agent Spawning

All 3 agents run as parallel background tasks:

```
Task(subagent_type="wb-architect", run_in_background=true)
  prompt: "Design architecture for project. Requirements: {requirements_path}. Codebase: {codebase_path}.
           Write your full analysis to .wannabuild/outputs/architect.md.
           Return ONLY: 'COMPLETE — [one sentence summary]. Report at .wannabuild/outputs/architect.md'"

Task(subagent_type="wb-tech-advisor", run_in_background=true)
  prompt: "Evaluate tech stack for project. Requirements: {requirements_path}. Codebase: {codebase_path}.
           Write your full analysis to .wannabuild/outputs/tech-advisor.md.
           Return ONLY: 'COMPLETE — [one sentence summary]. Report at .wannabuild/outputs/tech-advisor.md'"

Task(subagent_type="wb-risk-assessor", run_in_background=true)
  prompt: "Assess risks for project. Requirements: {requirements_path}. Codebase: {codebase_path}.
           Write your full analysis to .wannabuild/outputs/risk-assessor.md.
           Return ONLY: 'COMPLETE — [one sentence summary]. Report at .wannabuild/outputs/risk-assessor.md'"
```

All 3 agents write their full analysis to `.wannabuild/outputs/` and return a one-line status to the main conversation.

## Synthesis

After all 3 agents complete, the orchestrator reads `.wannabuild/outputs/architect.md`, `.wannabuild/outputs/tech-advisor.md`, and `.wannabuild/outputs/risk-assessor.md`, then:

1. **Merge tech stack decisions** from Tech Advisor with architecture from Architect
2. **Resolve conflicts:** If Tech Advisor recommends X but Architect designed for Y, flag it for the user
3. **Incorporate risks** into architecture decisions (risk-informed design)
4. **Ensure testing strategy** is present and complete (framework, boundaries, mock strategy, CI requirements)
5. **Verify completeness:** Every section of the design spec template has content
6. **Present to user** for review

## Output Artifact

The phase produces `.wannabuild/spec/design.md`:

```markdown
# Design Spec

## Architecture
[High-level system description]

### Architecture Diagram
```
[ASCII diagram]
```

### File Structure
```
[Proposed directory layout]
```

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

After synthesis:

> Here's the technical design for your project. Pay special attention to the architecture decisions and testing strategy. If any tech stack choices or architectural patterns don't feel right, now is the time to change them — it's much cheaper to change a design than to change code.

The user can:
- **Approve:** Move to Tasks phase
- **Modify:** Adjust specific decisions, re-run affected agent(s)
- **Override:** Choose a different tech stack or architecture than recommended
- **Skip:** Jump ahead if they already have a design

## Quality Checklist

- [ ] Architecture diagram exists and is accurate
- [ ] Every tech stack decision has a rationale
- [ ] Data models cover all entities from requirements
- [ ] API contracts exist for all user-facing interactions
- [ ] Testing strategy is complete (framework, boundaries, mocks, CI)
- [ ] Risks are identified with concrete mitigations
- [ ] File structure is defined
- [ ] Design addresses all acceptance criteria from requirements
- [ ] No conflicts between tech stack and architecture decisions

## Edge Cases

- **Existing codebase with established architecture:** Agents adapt their recommendations to extend the existing architecture rather than replace it.
- **Conflicting agent recommendations:** Orchestrator flags conflicts and asks user to decide.
- **Unknown tech stack:** If agents lack confidence, they recommend a spike/prototype task in the tasks phase.
- **No testing strategy possible yet:** If the tech stack is too uncertain, flag that testing strategy needs refinement during tasks phase.
