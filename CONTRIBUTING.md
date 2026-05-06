# Contributing to WannaBuild

First off, thanks for considering contributing to WannaBuild! 🎉

## Where to start

If you're new, read in this order — each builds on the prior:

1. [`README.md`](README.md) — what WannaBuild does, install paths, the public
   workflow.
2. [`docs/operator-mental-model.md`](docs/operator-mental-model.md) — the
   mental model of running the loop end-to-end.
3. [`AGENTS.md`](AGENTS.md) — the operator contract. The orchestrator's
   golden path and gates live here.
4. [`CLAUDE.md`](CLAUDE.md) — Claude-Code-specific guidance and the **Key
   Invariants for Editing** section. Read before changing anything in
   `skills/build/` or `agents/`.
5. [`docs/roadmap.md`](docs/roadmap.md) — what's shipped, next, and out of
   scope. Confirm your idea isn't already explicitly out of scope.

## Where to make changes

| Want to | Edit |
|---|---|
| Fix a typo or improve docs | The relevant `*.md` file. Docs PRs are the lightest review. |
| Add a new specialist agent | New file under `agents/wb-*.md` matching the existing frontmatter shape. Add to the relevant phase in `skills/build/SKILL.md`. |
| Tighten an existing agent prompt | The agent's `agents/wb-*.md`. Don't restructure unless the change is requested. |
| Add a runbook for a new failure mode | `docs/runbooks/<topic>.md`. Follow the Symptom / Cause / Diagnose / Fix shape used in [`install-and-load-failures.md`](docs/runbooks/install-and-load-failures.md). |
| Add a new test | `tests/unit/test_<thing>.bats` or `tests/integration/test_<thing>.bats`. Use the helpers in `tests/test_helper.bash`. |
| Change runtime behavior | `crates/wb-runtime/src/`. Always pair the change with a unit test in the same module and an integration test in `tests/integration/`. |
| Touch the orchestrator contract | `AGENTS.md` first, then the matching `skills/*/SKILL.md`, then the reference under `skills/build/references/`, then the schema if artifact shape changes. In that order. |
| Change a host adapter | `adapters/<host>/`, plus host-specific packaging (`.claude-plugin/`, `.cursor-plugin/`, etc.). The core in `AGENTS.md`/`skills/` must stay host-neutral. |

If your change cuts across multiple of these, mention it in the PR description so reviewers can route it.

## How Can I Contribute?

### Reporting Bugs

- Check if the bug has already been reported in [Issues](https://github.com/gl11tchy/wannabuild/issues)
- If not, create a new issue with a clear title and description
- Include steps to reproduce, expected behavior, and actual behavior

### Suggesting Features

- Open an issue with the `enhancement` label
- Describe the feature and why it would be useful
- Be open to discussion about implementation

### Pull Requests

1. Fork the repo and create your branch from `main`
2. If you've added a skill, ensure it follows the existing structure
3. Update documentation if needed
4. Verify locally:
   - `bash scripts/lint.sh` (lint, format, complexity, large-file, dead-ref, tech-debt)
   - `bash tests/run.sh` (bats unit + integration suite)
   - `bash scripts/wannabuild-doctor.sh` (repo readiness)
   - `pre-commit run --all-files` (if you have pre-commit installed)
5. Commit using Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `perf:`, `test:`); release-please picks them up.
6. Submit the PR — fill out the template; link the issue; check the verification boxes.

## Skill Development Guidelines

### Structure

Each skill should have:

```text
skills/your-skill/
├── SKILL.md          # Main skill definition
└── references/       # Optional supporting docs
    └── *.md
```

### SKILL.md Format

```markdown
---
name: your-skill-name
description: "Brief description for skill discovery"
---

# Skill Name

[Full documentation]
```

### Best Practices

- **Single responsibility**: Each skill does one thing well
- **Clear triggers**: Document when the skill should activate
- **Artifacts**: Define what the skill produces
- **Handoffs**: Explain how it connects to other phases

## Code of Conduct

Be kind. We're all here to build cool stuff.

## Local Setup

The fastest way to get a working environment is the dev container — open the repo in VS Code and choose **Reopen in Container**. Everything below is preinstalled. See [.devcontainer/README.md](.devcontainer/README.md).

If you prefer a host install, you'll need:

- `shellcheck`, `shfmt`
- `jq`, `ripgrep` (`rg`)
- `bats` (with `bats-support`, `bats-assert`)
- `kcov` (for shell coverage)
- `pre-commit`
- `lizard` (cyclomatic complexity)
- `markdownlint-cli2`
- `jscpd`
- `prettier`

## Reporting Security Issues

Please do not file public issues for security vulnerabilities. See [SECURITY.md](SECURITY.md) for the disclosure process.

## Questions?

Open an issue or start a discussion. We're happy to help!
