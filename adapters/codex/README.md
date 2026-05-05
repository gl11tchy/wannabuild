# Codex Adapter

Primary WannaBuild adapter.

Use the repo directly:

- `AGENTS.md`
- `skills/`
- `agents/`
- `scripts/`

Advisor escalation and delegation are model-agnostic in core. In Codex, map WannaBuild capability tiers and reasoning effort to the available model/reasoning controls; otherwise rely on the `.wannabuild/outputs/` reports, `.wannabuild/decisions.md`, and `state.json` contracts.

Install:

```bash
./scripts/install-codex-skill.sh
```

Then restart Codex and start with natural language:

```text
I want to build a Stripe billing flow for my SaaS
```

Codex should select the installed WannaBuild skill automatically when natural-language prompts match build, planning, debug, review, QA, ship, or open-ended ideation intent. `$wannabuild` and the `wb-*` skills are explicit shortcuts.

Verify the repo-native contract:

```bash
./scripts/wannabuild-doctor.sh
./scripts/validate-wannabuild-dry-runs.sh
```

See:

- [docs/codex-getting-started.md](../../docs/codex-getting-started.md)
- [docs/host-capability-matrix.md](../../docs/host-capability-matrix.md)
