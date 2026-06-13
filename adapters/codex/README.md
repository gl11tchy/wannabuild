# Codex Adapter

Primary WannaBuild adapter.

Use the repo directly:

- `AGENTS.md`
- `skills/`
- `agents/`
- `scripts/`

Advisor escalation and delegation are model-agnostic in core. In Codex, map WannaBuild capability tiers and reasoning effort to the available model/reasoning controls; otherwise rely on the `.wannabuild/outputs/` reports, `.wannabuild/decisions.md`, and `state.json` contracts.

## Install

### npx (recommended)

```bash
npx wannabuild --codex
```

This links the repo-native skills into `~/.codex/skills/` and places a
prebuilt, checksum-verified `wb-runtime` at `~/.codex/bin/wb-runtime` — no Rust
or cargo required. Then restart Codex and start with natural language:

```text
I want to build a Stripe billing flow for my SaaS
```

### From source (contributors)

```bash
./scripts/install-codex-skill.sh
```

From a dev clone the installer builds `wb-runtime` with cargo before copying it
into `~/.codex/bin/`; with a prebuilt binary it copies that instead and skips
cargo.

Codex should select the installed WannaBuild skill automatically when natural-language prompts match build, planning, debug, review, QA, ship, or open-ended ideation intent. `$wannabuild` and the `wb-*` skills are explicit shortcuts and phase entrypoints into the full loop by default. Codex does not use Claude Code hooks; it resolves the host-neutral Rust `wb-runtime` from `~/.codex/bin` (add it to `PATH` if Codex cannot find it), and `scripts/wannabuild-session.sh assert-plan-ready <project_root>` fails closed if that runtime cannot execute.

Verify the repo-native contract:

```bash
./scripts/wannabuild-doctor.sh
./scripts/validate-wannabuild-dry-runs.sh
```

See:

- [docs/codex-getting-started.md](../../docs/codex-getting-started.md)
- [docs/host-capability-matrix.md](../../docs/host-capability-matrix.md)
