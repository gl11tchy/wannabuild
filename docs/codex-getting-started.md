# Codex Getting Started

Codex is a co-primary WannaBuild path (alongside Claude Code).

Use the repo directly:

- `AGENTS.md`
- `skills/`
- `agents/`
- `scripts/`

## Install

From the repo root:

```bash
./scripts/install-codex-skill.sh
```

Then restart Codex and start with natural language:

```text
I want to build a Stripe billing flow for my SaaS
```

Codex should select the installed WannaBuild skills automatically when natural-language prompts match build, planning, debug, review, QA, or ship intent. `$wannabuild` and the `wb-*` skills are explicit shortcuts and phase entrypoints into the full loop by default. In skill UI surfaces, packaged metadata presents the phase skills as `WannaBuild: Build`, `WannaBuild: Debug`, `WannaBuild: Review`, `WannaBuild: Ship`, and the matching phase names.
Codex does not currently install the Claude hook runtime; before implementation, use the same hard planning gate through `scripts/wannabuild-session.sh assert-plan-ready <project_root>` when available.
Open-ended ideation prompts such as "I want to work on this some" or "let's brainstorm ideas" should start Discover automatically, then continue through the full loop once the goal is crisp enough.

WannaBuild runs one standard workflow mode. It does not ask the user to choose between Full, Light, or Spark.
In git repos, it should use the current checkout for discovery and planning. It should only create an isolated worktree when implementation-time isolation is selected.

Optional intro shortcut:

```text
$using-wannabuild
```

## Usage

Use natural language for the full loop:

```text
I want to add team billing to this app
```

That routes into:

```text
Discover -> Plan -> Implement -> Validate -> QA -> Summary
```

For phase-specific entry, ask for the phase directly:

- `Run discovery only for this idea`
- `Plan this from the requirements`
- `Build the next planned slice`
- `Debug this failing behavior`
- `Review this change`
- `QA this against the acceptance criteria`
- `Prepare the final handoff`

Phase skills display as `WannaBuild: <Skill>` in skill UI surfaces. The `wb-*` names remain stable shortcuts and install paths. They stop after one phase only when the user explicitly asks for "discovery only", "plan only", "do not implement", "QA only", or equivalent.

## Flow

1. Open the repo in Codex.
2. Read [AGENTS.md](../AGENTS.md).
3. Follow [skills/build/SKILL.md](../skills/build/SKILL.md) and the phase skills under `skills/`.
4. Run [scripts/validate-wannabuild-artifacts.sh](../scripts/validate-wannabuild-artifacts.sh) before phase transitions.
5. Run [scripts/wannabuild-doctor.sh](../scripts/wannabuild-doctor.sh) when checking local readiness.
6. Treat `.wannabuild/` in the target project as the source of truth.

## Trust Checks

Codex and Claude Code share the same host-neutral trust harness:

```bash
./scripts/wannabuild-doctor.sh
./scripts/validate-wannabuild-dry-runs.sh
./scripts/validate-wannabuild-artifacts.sh docs/golden-path-demo document
./scripts/wannabuild-gate-check.sh docs/golden-path-demo summary
```

The dry-run validator covers startup, exploratory discovery invocation, implementation workspace selection, resume, research, implementation, review failure, QA failure, and summary completion.

## Key Files

- [AGENTS.md](../AGENTS.md)
- [skills/build/SKILL.md](../skills/build/SKILL.md)
- [skills/wannabuild/SKILL.md](../skills/wannabuild/SKILL.md)
- [scripts/validate-wannabuild-artifacts.sh](../scripts/validate-wannabuild-artifacts.sh)
- [scripts/validate-wannabuild-dry-runs.sh](../scripts/validate-wannabuild-dry-runs.sh)
- [docs/golden-path-demo](golden-path-demo)
- [scripts/install-codex-skill.sh](../scripts/install-codex-skill.sh)
- [docs/host-capability-matrix.md](host-capability-matrix.md)

## Rule

If it only works through adapter packaging, it is not core.
