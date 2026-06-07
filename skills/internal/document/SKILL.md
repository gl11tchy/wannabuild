# WannaBuild: Document Phase

## Contract Standard

This prompt follows `docs/contract-standard.md` and the four mandates in
`skills/internal/build/references/doctrine.md` (mandatory collaborative discovery;
exhaust resources before declaring blocked; completeness with un-rationalizable gates;
collaboration plus determinism). Where this file is silent, the doctrine governs.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Specialist judgment is advisory; it never authorizes dropping a required documentation surface or skipping live verification.

> "What would confuse future-you? Write that down."

Phase 7 of 7 in the WannaBuild SDD pipeline. Updates documentation to reflect what was built — README, API docs, and changelog. Documentation is generated from spec artifacts, not from memory.

## Agents

The document phase runs documentation agents per the Documentation Matrix below. The matrix — not agent discretion — decides which surfaces are in scope:

| Agent | File | Role |
|-------|------|------|
| README Updater | `wb-readme-updater` | Updates README with new features, setup, usage |
| API Doc Generator | `wb-api-doc-generator` | Generates/updates API documentation from code and design spec |
| Changelog Writer | `wb-changelog-writer` | Writes changelog entry following Keep a Changelog format |

Every surface the Documentation Matrix marks in scope MUST be updated. A surface is never dropped on agent judgment; if a matched surface needs no change, that requires an explicit, evidence-backed "no change needed" note in `.wannabuild/outputs/document-rationale.md` recording why, citing the diff. "Nothing to document" is a claim that must be proven against the diff, never assumed.

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

1. Read spec artifacts, checkpoints, review/QA evidence, and the full diff of changed files.
2. Apply the Documentation Matrix to the diff to determine the in-scope surfaces. This is a lookup, not a judgment call — the same diff yields the same surface set every run.
3. Confirm scope with the user (mandatory boundary, see "Confirm Scope" below) before writing.
4. Acquire live ground truth for any API surface in scope (see "API documentation: acquire live ground truth" below) before documenting or recording "no API".
5. Run the documentation agents for every in-scope surface. Run independent agents in parallel; write-scope overlaps run sequentially (see "Parallelism" below).
6. Run the Document Gate. It fails closed; the phase cannot complete until every item passes with recorded evidence.
7. Commit documentation updates only after the Document Gate passes.
8. Record the matrix outcome and any evidence-backed "no change needed" notes in `.wannabuild/outputs/document-rationale.md`.

## Documentation Matrix (mandatory)

Classify the change from the diff and the spec, then apply ALL rows that match. Every matched row's surface MUST be updated, or an explicit "no change needed" note backed by the diff MUST be recorded in `.wannabuild/outputs/document-rationale.md`. There is no "tiny change" or "internal refactor" exemption: the matrix runs on every change, including one-line and refactor-only changes, and the depth of each update scales with the diff — it never drops to zero surfaces.

| Change signal (from diff/spec) | Required surface(s) |
|---|---|
| New or changed user-facing feature/behavior (per `requirements.md` acceptance criteria) | README + changelog |
| Added/changed/removed dependency, build step, env var, or setup command | README (setup/config) + changelog |
| Added/changed/removed route, handler, request/response schema, or public API contract | API docs (live-verified) + changelog |
| Added/changed/removed public CLI flag, command, or config option | README + changelog |
| Internal-only refactor with no user-facing or interface change | changelog (one line documenting the refactor); README/API only if a public surface moved |
| Any change at all | changelog entry is always required — every shipped change gets a user-facing line |

The changelog row always fires: there is no shipped change without a changelog entry. Refactor-only and bug-fix changes still produce a changelog line; they document at proportionate depth, never at zero surfaces.

## Confirm Scope (mandatory boundary)

Before writing any documentation, present to the user and wait for an explicit approval word ("go", "proceed", "approved", "continue") — a vague "ok"/"sure" does not cross this boundary:

1. The surfaces the matrix selected, plus any matched surface you propose to mark "no change needed", each with the diff evidence behind it.
2. The proposed changelog version bump, derived deterministically (see "Versioning"), stated as the recommended answer with a one-line reason, asking the user to confirm or override.
3. Any conflict between existing human-written docs and the spec (see "Edge Cases"), presented as options with a recommended resolution.

This is a collaboration boundary, not a checkpoint inside mechanical work: once scope is approved, run all in-scope agents to completion without further mid-work pauses.

## Agent Spawning

Use adaptive agent spawning:

```text
Task(subagent_type="<selected documentation specialist>", run_in_background=<true when independent>)
  capability_tier: <lightweight / standard / strong>
  reasoning_effort: <low / medium / high>
  ownership: <README / API docs / changelog / release notes>
  prompt: "Update <owned documentation surface>.
           Specs at .wannabuild/spec/. Evidence: {summary}.
           Write your full output to .wannabuild/outputs/<agent>-document.md.
           Return ONLY: 'COMPLETE - [one sentence]. Report at <path>'"
```

## Documentation Sources

Each agent uses spec artifacts as the source of truth and verifies them against the shipped code and live behavior:

- **README Updater:** Reads `spec/requirements.md` for feature descriptions, `spec/design.md` for setup/configuration, and runs every setup/usage command it documents to confirm it works as written (real command, real exit code).
- **API Doc Generator:** Reads `spec/design.md` for API contracts and enumerates the actual API from source and live behavior (see "API documentation: acquire live ground truth" below).
- **Changelog Writer:** Reads `spec/requirements.md` for user-facing descriptions of what was built and maps every implemented acceptance criterion to a changelog line.

This ensures documentation matches what was specified and built and runs, not what someone remembers.

### API documentation: acquire live ground truth before documenting OR declaring absent

Before documenting endpoints OR concluding "no API", the API Doc Generator MUST perform these steps in order and record what each produced in `.wannabuild/outputs/document-gate.md`:

1. Read the API contracts in `spec/design.md`.
2. Enumerate routes from source: grep the router/handler/route registration for the project's framework and list every declared endpoint.
3. Run the app locally (or hit an already-running preview/ephemeral environment) and exercise each endpoint — `curl`/HTTP call, or drive the running service — capturing method, path, status, and response shape. "Missing env", "no database", "can't run it", or "no access" is NOT grounds to skip this step: auto-acquire the resource (spin a local/ephemeral DB branch, seed fixtures, stand up a preview environment, read live framework docs via Context7) and only stop-and-ask the user for billable/outward/destructive acquisition. Any blocker requires a logged attempt in `.wannabuild/outputs/acquisition-log.json` per the `assert-acquisition-attempted` gate — a blocker is never a silent skip.
4. Document each live endpoint with its verified request/response schema, and flag every discrepancy between spec, source, and live behavior.

"No API" is a verified conclusion, not a default: it is permitted ONLY after steps 1–3 find zero declared routes in source AND zero reachable endpoints on the running app, with that negative evidence recorded. If the app could not be run, the acquisition log must show the attempt; an un-acquired environment never converts to "no API found".

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

#### Versioning (deterministic)

Derive the bump from the same diff signals the matrix uses, so two runs over the same change always produce the same version:

- Breaking public change (removed/renamed endpoint, incompatible schema/CLI change) → major.
- New backward-compatible feature or endpoint → minor.
- Fix-only or internal refactor → patch.

Fill `X.Y.Z` from the highest-severity matched row, and date the entry with the merge commit date from the Ship handoff (`YYYY-MM-DD`). Present this bump as the recommended answer in Confirm Scope; the user may override, but the agent never picks a version by feel.

#### Parallelism (deterministic)

README, API docs, and changelog own disjoint files, so run their agents in parallel. When two in-scope agents would write the same file (e.g. a combined docs file), run those two sequentially. The rule is fixed: disjoint write scope → parallel, overlapping write scope → sequential. It does not vary by run.

## Commit Strategy

After all agents complete, commit documentation updates:

```text
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
    "gate": ".wannabuild/outputs/document-gate.md",
    "rationale": ".wannabuild/outputs/document-rationale.md",
    "commit": "xyz7890"
  }
}
```

Each `*_updated` value is `true` only when that surface was actually written. A matrix-matched surface recorded as "no change needed" sets its value to `false` AND must have its evidence-backed entry in `document-rationale.md`; a `false` without that rationale is a Document Gate FAIL.

## Completion Message

Send only after the Document Gate has passed:

> **Project complete!** Here's what we built:
>
> **Requirements:** [N] user stories, [N] acceptance criteria
> **Design:** [architecture summary]
> **Implementation:** [N] tasks completed, [N] integration tests
> **Review:** Active-set unanimous PASS in [N] iterations (adaptive reruns)
> **Shipped:** PR #[N] merged
> **Documentation:** [surfaces updated, per the matrix and gate — e.g. README, API docs (live-verified), changelog]
>
> All spec artifacts are in `.wannabuild/spec/` for future reference.

## Edge Cases

- **No README exists:** README Updater creates one from the spec artifacts.
- **No CHANGELOG exists:** Changelog Writer creates one with the standard Keep a Changelog header, then adds this entry. The changelog is never skipped for lack of a file.
- **No API surface:** Reaching "no API" requires the full live-ground-truth acquisition above (read spec, grep routes, run the app) finding zero declared and zero reachable endpoints, with that negative evidence and any acquisition attempt recorded. The API Doc Generator never reports "no API found" without that evidence.
- **Existing docs conflict with spec:** Do not silently overwrite. Surface the conflict to the user as options — (A) update docs to match spec (recommended when the spec reflects the shipped behavior), (B) update the spec/code if the existing docs are correct, (C) a specific reconciliation — with a recommended answer, and wait for the user's choice in Confirm Scope before writing.

## Document Gate (fails closed)

The phase cannot complete until every item passes WITH evidence recorded in `.wannabuild/outputs/document-gate.md`. Each item is verified, not self-attested; a missing-evidence item is a FAIL and the phase does not advance.

- README features/setup match the diff — paste the diff-to-README mapping showing every matched matrix surface is covered.
- API docs match LIVE endpoints — paste the route list obtained from source (step 2) and the live exercise output (step 3); documented endpoints MUST equal the live set, or every difference is flagged. "No API" requires the recorded negative evidence.
- Every documented setup/usage command was executed — paste the command and its exit code (0 required).
- Changelog maps every implemented acceptance criterion to a user-facing line — paste the criterion-to-line mapping; an unmapped criterion is a FAIL.
- All commands, paths, and links in the docs resolve — paste the link/path check output; a broken reference is a FAIL.
- Any blocker encountered has a logged acquisition attempt in `.wannabuild/outputs/acquisition-log.json` (`assert-acquisition-attempted`); a blocked status without a logged attempt is a FAIL.
- Documentation committed only after every item above passes.

## Contract Validation

- The document phase updates every surface the Documentation Matrix marks in scope; the changelog is always one of them.
- Documentation MUST be consistent with `requirements.md`, `tasks.md`, AND the actual shipped code and live runtime behavior verified in the Document Gate — not the spec alone.
- The changelog MUST (not should) map every implemented acceptance criterion to a user-facing line; a missing mapping FAILS the Document Gate.
- Any conflict — docs vs spec, spec vs code, or documented vs live behavior — is surfaced to the user as options with a recommended answer and resolved by the user's explicit choice before commit; the agent never resolves a scope/behavior conflict unilaterally.
