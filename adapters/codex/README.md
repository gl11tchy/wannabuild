# Codex Adapter

Primary WannaBuild adapter.

Use the repo directly:
- `AGENTS.md`
- `skills/`
- `agents/`
- `scripts/`

Advisor escalation is model-agnostic in core. In Codex, use a higher-reasoning read-only advisor equivalent when available; otherwise rely on the `.wannabuild/outputs/advisor/` report and `state.json.advisor` contract.

Install:

```bash
./scripts/install-codex-skill.sh
```

Then restart Codex and invoke:

```text
$wannabuild
```

See:
- [docs/codex-getting-started.md](../../docs/codex-getting-started.md)
- [docs/host-capability-matrix.md](../../docs/host-capability-matrix.md)
