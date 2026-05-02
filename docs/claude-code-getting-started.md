# Claude Code Getting Started

Claude Code is a co-primary WannaBuild path (alongside Codex).

Use the repo directly:

- `AGENTS.md`
- `skills/`
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

After installation, invoke WannaBuild:

```text
/wannabuild
```

WannaBuild runs one standard workflow mode. It does not ask the user to choose between Full, Light, or Spark.
When used in git repositories, it will create an isolated worktree before starting the actual workflow.

Optional intro skill:

```text
/using-wannabuild
```

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

The dry-run validator covers startup, workspace bootstrap, resume, research, implementation, review failure, QA failure, and summary completion.

## Key Files

- [AGENTS.md](../AGENTS.md)
- [skills/build/SKILL.md](../skills/build/SKILL.md)
- [skills/wannabuild/SKILL.md](../skills/wannabuild/SKILL.md)
- [scripts/validate-wannabuild-artifacts.sh](../scripts/validate-wannabuild-artifacts.sh)
- [scripts/validate-wannabuild-dry-runs.sh](../scripts/validate-wannabuild-dry-runs.sh)
- [docs/golden-path-demo](golden-path-demo)
- [scripts/install-claude-skill.sh](../scripts/install-claude-skill.sh)
- [docs/host-capability-matrix.md](host-capability-matrix.md)

## Rule

If it only works through adapter packaging, it is not core.
