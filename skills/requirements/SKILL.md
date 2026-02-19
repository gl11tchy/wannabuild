# WannaBuild Requirements Phase

> Phase 1 of 7 in the WannaBuild SDD pipeline. Captures what the user wants to build as a formal requirements spec with user stories, acceptance criteria, and integration test scenarios.

## Agents

This phase uses 2 specialist agents running in parallel:

| Agent | File | Role |
|-------|------|------|
| Scope Analyst | `wb-scope-analyst` | MVP boundaries, scope risks, size assessment |
| UX Perspective | `wb-ux-perspective` | User stories, journeys, edge cases, test scenarios |

## Trigger Conditions

**Explicit:**
- `/wannabuild-requirements` (auto-prefixed when installed as plugin)
- "Let's define requirements"
- "What should we build?"

**Implicit (from orchestrator):**
- User says "I wanna build..." and orchestrator routes here
- Orchestrator hands off after project description is captured

## Input

The phase receives a project description from the user (via the orchestrator) and optionally an existing codebase path.

**Handoff from orchestrator:**
```json
{
  "phase": "requirements",
  "project_description": "User's description of what they want to build",
  "codebase_path": "/path/to/existing/project or null",
  "context": "Any additional context from conversation"
}
```

## Execution Flow

```
User describes project
        │
        ▼
┌───────────────────────────────────┐
│  Parallel Agent Execution         │
│                                   │
│  ┌─────────────┐ ┌─────────────┐ │
│  │   Scope     │ │     UX      │ │
│  │  Analyst    │ │ Perspective │ │
│  └──────┬──────┘ └──────┬──────┘ │
│         │               │        │
└─────────┼───────────────┼────────┘
          │               │
          ▼               ▼
    ┌─────────────────────────┐
    │   Orchestrator          │
    │   Synthesizes reports   │
    │   into requirements.md  │
    └────────────┬────────────┘
                 │
                 ▼
    Present to user for review
                 │
                 ▼
    Write .wannabuild/spec/requirements.md
```

## Agent Spawning

The orchestrator spawns both agents as parallel background tasks:

```
Task(subagent_type="wb-scope-analyst", run_in_background=true)
  prompt: "Analyze scope for: {project_description}. Codebase: {codebase_path}"

Task(subagent_type="wb-ux-perspective", run_in_background=true)
  prompt: "Analyze UX for: {project_description}. Codebase: {codebase_path}"
```

Both agents read the codebase (if it exists) and return structured markdown reports.

## Synthesis

After both agents complete, the orchestrator synthesizes their outputs into a unified requirements spec. The synthesis process:

1. **Merge user stories** from UX Perspective with scope boundaries from Scope Analyst
2. **Validate scope:** Ensure user stories fit within the MVP boundary
3. **Combine acceptance criteria** from both agents, deduplicating
4. **Incorporate integration test scenarios** from UX Perspective, ensuring every story has test coverage
5. **Present to user** for review and refinement

## Output Artifact

The phase produces `.wannabuild/spec/requirements.md`:

```markdown
# Requirements Spec

## Project Overview
[1-2 sentences: what this is and who it's for]

## Size Assessment
**Estimate:** [Tiny/Small/Medium/Large/Epic]
**Confidence:** [High/Medium/Low]

## User Stories
1. As a [user], I want [feature], so that [value]
2. ...

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- ...

## Scope
### In Scope
- [Feature/capability that will be built]
### Out of Scope
- [Feature/capability explicitly deferred]

## Integration Test Scenarios
### [Story Name]
- **Happy path:** [expected flow and assertion]
- **Error path:** [failure mode and expected behavior]
- **Edge cases:** [boundary conditions]

## Scope Risks
| Risk | Severity | Notes |
|------|----------|-------|
| [risk] | High/Med/Low | [details] |

## Success Metrics
- [How to know the project succeeded]
```

## State Update

```json
{
  "current_phase": "requirements",
  "phase_status": "complete",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md"
  },
  "next_phase": "design"
}
```

## Handoff to Design Phase

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

## User Interaction

After synthesis, present the requirements to the user:

> Here's what I've captured for your project. Review the requirements below — especially the scope boundaries and integration test scenarios. Let me know if anything needs adjustment before we move to design.

The user can:
- **Approve:** Move to Design phase
- **Modify:** Adjust specific sections, re-run affected agent
- **Restart:** Scrap and start over with a different description
- **Skip:** Jump directly to a later phase if they already have requirements

## Quality Checklist

- [ ] Every user story has at least one acceptance criterion
- [ ] Every acceptance criterion is testable (not subjective)
- [ ] Integration test scenarios exist for every user story
- [ ] Scope boundaries are explicit (in/out)
- [ ] Size assessment is honest with rationale
- [ ] Ambiguities are flagged, not assumed away
- [ ] Scope risks are identified with severity

## Edge Cases

- **User has existing requirements:** Skip agent execution, validate and format existing requirements into the spec template.
- **Scope is too large:** Scope Analyst flags it as Epic. Orchestrator asks user to narrow scope or break into multiple projects.
- **User changes mind mid-phase:** Re-run affected agent(s), re-synthesize.
- **Greenfield vs. existing project:** Both agents adapt — Scope Analyst assesses existing code, UX Perspective considers existing users.
