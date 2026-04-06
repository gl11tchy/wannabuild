# WannaBuild: Document Phase

> "What would confuse future-you? Write that down."

Phase 7 of 7 in the WannaBuild SDD pipeline. Updates documentation to reflect what was built — README, API docs, and changelog. Documentation is generated from spec artifacts, not from memory.

## Agents

The document phase uses all 3 documentation agents:

| Agent | File | Role |
|-------|------|------|
| README Updater | `wb-readme-updater` | Updates README with new features, setup, usage |
| API Doc Generator | `wb-api-doc-generator` | Generates/updates API documentation from code and design spec |
| Changelog Writer | `wb-changelog-writer` | Writes changelog entry following Keep a Changelog format |

## Trigger Conditions

**Explicit:**
- `/wannabuild-document` (auto-prefixed when installed as plugin)
- "Update the docs" / "Write documentation"

**Implicit (from orchestrator):**
- Ship phase completes → auto-transition to Document

## Input

**Handoff from Ship:**
```json
{
  "phase": "document",
  "from": "ship",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "design": ".wannabuild/spec/design.md",
    "tasks": ".wannabuild/spec/tasks.md"
  },
  "ship": {
    "pr_number": 42,
    "pr_url": "...",
    "merge_commit": "abc1234",
    "checkpoint_summary": ".wannabuild/checkpoints/"
  }
}
```

## Execution Flow

**All 3 agents in parallel:**
```
Spec artifacts + merged code (input)
        │
        ▼
┌──────────────────────────────────────────────────┐
│  All 3 Agents in Parallel (background)           │
│                                                  │
│  ┌──────────┐ ┌──────────┐ ┌───────────────┐    │
│  │  README  │ │ API Doc  │ │  Changelog    │    │
│  │ Updater  │ │Generator │ │   Writer      │    │
│  └────┬─────┘ └────┬─────┘ └──────┬────────┘    │
│       │             │              │             │
└───────┼─────────────┼──────────────┼─────────────┘
        │             │              │
        ▼             ▼              ▼
  ┌──────────────────────────────────────┐
  │  Orchestrator: Verify and commit     │
  │  documentation updates               │
  └──────────────────────────────────────┘
```

## Agent Spawning

All 3 agents run as parallel background tasks:

```
Task(subagent_type="wb-readme-updater", run_in_background=true)
  prompt: "Update README. Specs at .wannabuild/spec/. Recent changes: {summary}.
           Write your full output to .wannabuild/outputs/readme-updater.md.
           Return ONLY: 'COMPLETE — [one sentence summary]. Report at .wannabuild/outputs/readme-updater.md'"

Task(subagent_type="wb-api-doc-generator", run_in_background=true)
  prompt: "Generate API docs. Design spec at .wannabuild/spec/design.md. Codebase: {path}.
           Write your full output to .wannabuild/outputs/api-doc-generator.md.
           Return ONLY: 'COMPLETE — [one sentence summary]. Report at .wannabuild/outputs/api-doc-generator.md'"

Task(subagent_type="wb-changelog-writer", run_in_background=true)
  prompt: "Write changelog. Requirements at .wannabuild/spec/requirements.md. Change evidence: {recent_commits_or_checkpoints}.
           Write your full output to .wannabuild/outputs/changelog-writer.md.
           Return ONLY: 'COMPLETE — [one sentence summary]. Report at .wannabuild/outputs/changelog-writer.md'"
```

## Documentation Sources

Each agent uses spec artifacts as the source of truth:

- **README Updater:** Reads `spec/requirements.md` for feature descriptions, `spec/design.md` for setup/configuration
- **API Doc Generator:** Reads `spec/design.md` for API contracts, then validates against actual code
- **Changelog Writer:** Reads `spec/requirements.md` for user-facing descriptions of what was built

This ensures documentation matches what was specified and built, not what someone remembers.

## Output

### README Updates
- New features added to features section
- Setup instructions updated if dependencies changed
- Usage examples updated if behavior changed
- Configuration section updated if new config options added

### API Documentation
- New endpoints documented with request/response schemas
- Existing endpoint changes updated
- Discrepancies between spec and code flagged

### Changelog Entry
```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- [Feature in user-facing language]

### Changed
- [What changed and why it matters]
```

## Commit Strategy

After all agents complete, commit documentation updates:

```
docs: update documentation for [feature name]
```

Single commit for all documentation changes (they're logically one unit).

## State Update

Merge into existing state.json (preserving `mode` and all other existing keys):

```json
{
  "current_phase": "document",
  "phase_status": "complete",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "design": ".wannabuild/spec/design.md",
    "tasks": ".wannabuild/spec/tasks.md"
  },
  "documentation": {
    "readme_updated": true,
    "api_docs_updated": true,
    "changelog_updated": true,
    "commit": "xyz7890"
  }
}
```

## Completion Message

After all documentation is updated:

> **Project complete!** Here's what we built:
>
> **Requirements:** [N] user stories, [N] acceptance criteria
> **Design:** [architecture summary]
> **Implementation:** [N] tasks completed, [N] integration tests
> **Review:** Active-set unanimous PASS in [N] iterations (adaptive reruns)
> **Shipped:** PR #[N] merged
> **Documentation:** README, API docs, and changelog updated
>
> All spec artifacts are in `.wannabuild/spec/` for future reference.

## When to Skip

- **Tiny changes:** Bug fixes that don't change public behavior → skip README and API docs, write changelog only
- **Internal refactoring:** No user-facing changes → skip all documentation
- **No API:** Skip API doc generator if the project has no API

## Edge Cases

- **No README exists:** README Updater creates one from the spec artifacts.
- **No CHANGELOG exists:** Changelog Writer creates one with standard header.
- **No API:** API Doc Generator reports "no API found" and skips.
- **Existing docs conflict with spec:** Flag the discrepancy, update docs to match spec (spec is source of truth).

## Quality Checklist

- [ ] README reflects current features and setup
- [ ] API docs match actual endpoints (not just spec)
- [ ] Changelog entry uses user-facing language
- [ ] All commands and paths in docs are accurate
- [ ] No broken links or references
- [ ] Documentation committed

## Contract Validation

- The document phase updates README, API docs, and changelog.
- Changelog entry should reference the implemented acceptance criteria in user-facing language.
- Documentation updates must be internally consistent with `requirements.md` and `tasks.md`; conflicts require user sign-off before commit.
