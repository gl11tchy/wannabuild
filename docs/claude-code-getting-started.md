# Claude Code Getting Started

Claude Code is a co-primary WannaBuild path (alongside Codex).

Use the repo directly:

- `AGENTS.md`
- `skills/`
- `commands/`
- `agents/`
- `scripts/`

## Install

### Option 1: From Marketplace (Recommended)

In Claude Code, open the plugin marketplace:

```text
/plugin marketplace add gl11tchy/wannabuild
```

Then install the plugin:

```text
/plugin install wannabuild@gl11tchy
```

Reload plugins in Claude Code:

```text
/reload-plugins
```

### Option 2: From Repository

Clone or navigate to the WannaBuild repository root, then run:

```bash
./scripts/install-claude-skill.sh
```

Then reload plugins in Claude Code:

```text
/reload-plugins
```

After installation, start with natural language:

```text
I want to build a Stripe billing flow for my SaaS
```

Claude Code installs a `SessionStart` and `UserPromptSubmit` hook for WannaBuild. Natural feature, planning, debug, review, QA, and ship prompts should route to the matching skill automatically; `/wannabuild` and `/wb-*` are explicit shortcuts.
Open-ended ideation prompts such as "I want to work on this some" or "let's brainstorm ideas" should start Discover automatically, then continue through the full loop once the goal is crisp enough.

WannaBuild runs one standard workflow mode. It does not ask the user to choose between Full, Light, or Spark.
When used in git repositories, it uses the current checkout for discovery and planning. It only creates an isolated worktree when implementation-time isolation is selected.

Optional intro shortcut:

```text
/using-wannabuild
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

Use natural toolbox prompts when you only want one stage:

- "brainstorm the onboarding flow": discovery and requirements
- "plan this change": design, tasks, risks, and verification expectations
- "implement the next planned slice": implementation
- "debug this failing behavior": diagnosis and targeted fix
- "review this change": targeted review
- "QA this against the acceptance criteria": acceptance and integration validation
- "prepare the handoff": final handoff

Toolbox skills display as `WannaBuild: <Skill>` in skill UI surfaces. The `wb-*` names remain stable shortcuts and install paths.

Command shortcuts remain available as fallback entrypoints: `/wannabuild`, `/wb-discover`, `/wb-plan`, `/wb-build`, `/wb-debug`, `/wb-review`, `/wb-qa`, and `/wb-ship`.

## Flow

1. Open the repo in Claude Code (or your target project folder).
2. Read [AGENTS.md](../AGENTS.md).
3. Follow [skills/build/SKILL.md](../skills/build/SKILL.md) and the phase skills under `skills/`.
4. Run [scripts/validate-wannabuild-artifacts.sh](../scripts/validate-wannabuild-artifacts.sh) before phase transitions.
5. Run [scripts/wannabuild-doctor.sh](../scripts/wannabuild-doctor.sh) when checking local readiness.
6. Treat `.wannabuild/` in the target project as the source of truth.

## Trust Checks

Claude Code and Codex share the same host-neutral trust harness:

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
- [commands/](../commands)
- [scripts/validate-wannabuild-artifacts.sh](../scripts/validate-wannabuild-artifacts.sh)
- [scripts/validate-wannabuild-dry-runs.sh](../scripts/validate-wannabuild-dry-runs.sh)
- [docs/golden-path-demo](golden-path-demo)
- [scripts/install-claude-skill.sh](../scripts/install-claude-skill.sh)
- [docs/host-capability-matrix.md](host-capability-matrix.md)

## Rule

If it only works through adapter packaging, it is not core.
