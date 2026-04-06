# Codex Getting Started

Codex is the primary WannaBuild path.

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

Then restart Codex and invoke:

```text
$wannabuild
```

WannaBuild runs one standard workflow mode. It does not ask the user to choose between Full, Light, or Spark.
In git repos, it should create an isolated workspace/worktree before it starts the actual workflow.

Optional intro skill:

```text
$using-wannabuild
```

## Flow

1. Open the repo in Codex.
2. Read [AGENTS.md](../AGENTS.md).
3. Follow [skills/build/SKILL.md](../skills/build/SKILL.md) and the phase skills under `skills/`.
4. Run [scripts/validate-wannabuild-artifacts.sh](../scripts/validate-wannabuild-artifacts.sh) before phase transitions.
5. Treat `.wannabuild/` in the target project as the source of truth.

## Key Files

- [AGENTS.md](../AGENTS.md)
- [skills/build/SKILL.md](../skills/build/SKILL.md)
- [skills/wannabuild/SKILL.md](../skills/wannabuild/SKILL.md)
- [scripts/validate-wannabuild-artifacts.sh](../scripts/validate-wannabuild-artifacts.sh)
- [scripts/install-codex-skill.sh](../scripts/install-codex-skill.sh)
- [docs/host-capability-matrix.md](host-capability-matrix.md)

## Rule

If it only works through adapter packaging, it is not core.
