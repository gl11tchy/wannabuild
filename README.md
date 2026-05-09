<div align="center">

# WannaBuild

Spec-driven development for indie builders.

Condensed workflow: Discover -> Plan -> Implement -> Validate -> QA -> Summary.

[![CI](https://github.com/gl11tchy/wannabuild/actions/workflows/ci.yml/badge.svg)](https://github.com/gl11tchy/wannabuild/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/gl11tchy/wannabuild/badge)](https://scorecard.dev/viewer/?uri=github.com/gl11tchy/wannabuild)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
![Specialists](https://img.shields.io/badge/specialists-21-blue?style=flat-square)
![Workflow](https://img.shields.io/badge/workflow-adaptive-0a7ea4?style=flat-square)
![Codex](https://img.shields.io/badge/codex-supported-111827?style=flat-square)
![Claude Code](https://img.shields.io/badge/claude--code-supported-5B21B6?style=flat-square)
![Droid](https://img.shields.io/badge/droid-supported-0ea5e9?style=flat-square)
![Cursor](https://img.shields.io/badge/cursor-supported-0f766e?style=flat-square)

[Quickstart](#quickstart) · [Workflow](#workflow) · [Install](#install) · [Usage](#usage) · [Artifacts](#artifacts) · [Trust Harness](#trust-harness)

</div>

---

## Quickstart

Three steps to your first WannaBuild-driven feature. Pick the host you already
use; commands are equivalent across hosts.

### Claude Code

```text
/plugin marketplace add gl11tchy/wannabuild
/plugin install wannabuild@gl11tchy
/reload-plugins
```

Then type a natural feature request:

```text
I want to add Stripe billing to my SaaS
```

### Codex

```bash
git clone https://github.com/gl11tchy/wannabuild
cd wannabuild
./scripts/install-codex-skill.sh
```

Restart Codex, then:

```text
$wannabuild I want to add Stripe billing to my SaaS
```

### Factory Droid

```bash
git clone https://github.com/gl11tchy/wannabuild
cd wannabuild
./scripts/install-factory-plugin.sh
```

Restart Droid, then type a natural feature request or use `/wannabuild`.

### Cursor

Load `.cursor/rules/wannabuild.mdc` from a clone of this repo, then describe the
feature in chat.

> **Hit a problem?** See
> [docs/runbooks/install-and-load-failures.md](docs/runbooks/install-and-load-failures.md)
> before opening an issue.

---

## Overview

WannaBuild is a repo-native framework for running a disciplined product-development loop with AI agents. The user experience stays conversational and compact:

1. Discover the real vision, flows, feel, and feature priorities
2. Produce a plan, with bounded research when needed
3. Verify the approach
4. Implement with an adaptive solo or parallel shape
5. Validate from the right specialist angles and autofix actionable findings
6. Run QA against acceptance criteria
7. Return a concise summary with gaps and remaining work

Under the hood, WannaBuild uses structured specs, checkpoints, adaptive review routing, and specialist prompts so the workflow stays rigorous without feeling bureaucratic.
Runs start in the current checkout. Worktrees are an implementation-time option for approved plans, parallel slices, or explicitly requested isolation.
Claude Code installs a lightweight hook runtime that reinjects active `.wannabuild/state.json` phase state on session start and prompt submit. It also forbids implementation until the Plan gate is satisfied. Codex installs the host-neutral Rust `wb-runtime` binary and uses fail-closed compatibility gates for the same runtime checks. Top-level workflow starts must pass `assert-workflow-active`, so a host-only "skill activated" banner without `.wannabuild/` evidence is a runtime failure.
Factory Droid installs a plugin surface plus generated `wb-*` droids so the same natural-language routing and specialist workflow are available in Droid.
After install, start with natural language: "I want to add billing", "plan this", "debug this failure", or "review this change". Commands such as `/wannabuild` in Claude Code and `$wannabuild` in Codex are shortcuts, not requirements.

## Why

Most AI coding flows fail in predictable ways:

- scope gets fuzzy
- plans stay implicit
- implementation drifts
- reviews are shallow
- QA is hand-wavy
- final summaries are noisy or incomplete

WannaBuild fixes that by making vision, specs, and verification first-class while keeping the visible workflow short.

## Workflow

```text
DISCOVER -> PLAN -> IMPLEMENT -> VALIDATE -> QA -> SUMMARY
```

### Discover

- Interview for vision, audience, desired feel, core flows, features, constraints, priorities, non-goals, and success signals.
- Infer and synthesize requirements after the interview instead of expecting the user to arrive with everything ready.
- Derive acceptance criteria and integration scenarios from the clarified vision rather than making tests the center of discovery.

### Autonomy

- After Discover, WannaBuild continues autonomously by default.
- It asks only when scope, product direction, destructive actions, credentials, paid services, or delivery strategy need user judgment.
- Guided mode remains available when explicitly requested.

### Plan

- Generate a concrete plan.
- Verify architecture and direction before implementation begins.

### Optional Research

- When uncertainty is still high, WannaBuild can kick off bounded research agents before planning.
- Research is adaptive, not a permanent required phase.
- The orchestrator chooses specialist count, capability tier, and reasoning effort from the uncertainty involved.

### Implement

- Offer or choose the implementation shape based on task independence, coupling, risk, and required expertise.
- Use parallel agents only when slices have distinct ownership and expected evidence.
- Use checkpoints so progress, verification, and resume paths stay explicit.

### Validate

- Run the right reviewer hats for the change.
- Keep review adaptive; not every hat needs to run every time.
- Autofix actionable findings and rerun impacted checks.

### QA

- Validate acceptance criteria and integration behavior.
- Missing coverage or failing tests block completion.

### Summary

- Return what changed.
- Report what passed.
- Call out gaps, risks, and remaining work.

Parallelism is selective. The orchestrator decides how many sub-agents to use, which capability tier they need, and how much reasoning effort is justified by task complexity, coupling, risk, and uncertainty.
Single-owner work is preferred when coherence matters. Fan-out is useful for independent discovery perspectives, disjoint implementation slices, and review hats with distinct risk ownership.

## Development & Contribution

For contributors and maintainers working on the framework itself:

- [docs/build.md](docs/build.md) — local build, lint, and test commands.
- [docs/release.md](docs/release.md) — Conventional Commits + release-please.
- [docs/ci.md](docs/ci.md) — workflow overview.
- [docs/governance.md](docs/governance.md) — CODEOWNERS and triage.
- [docs/branch-protection.md](docs/branch-protection.md) — applying ruleset JSON.
- [docs/style-guide.md](docs/style-guide.md) — naming and style.
- [docs/security.md](docs/security.md) — security posture.
- [docs/secrets-management.md](docs/secrets-management.md) — handling secrets.
- [docs/supply-chain.md](docs/supply-chain.md) — dependency hardening.
- [docs/log-scrubbing.md](docs/log-scrubbing.md) — runtime scrubbing primitives.
- [docs/observability.md](docs/observability.md) — metrics, traces, runbooks.
- [docs/runbooks/install-and-load-failures.md](docs/runbooks/install-and-load-failures.md) — troubleshooting install + plugin-load issues.
- [docs/roadmap.md](docs/roadmap.md) — what's shipped, next, and deferred.
- [tests/README.md](tests/README.md) — bats unit + integration suite.
- [.devcontainer/README.md](.devcontainer/README.md) — dev container setup.
- [SECURITY.md](SECURITY.md) — vulnerability reporting.

## Install

### Claude Code

Co-primary path (alongside Codex).

**Marketplace:**

```text
/plugin marketplace add gl11tchy/wannabuild
/plugin install wannabuild@gl11tchy
/reload-plugins
```

Then:

```text
I want to build a Stripe billing flow for my SaaS
```

Claude Code also supports `/wannabuild` and `/wb-*` command shortcuts. The installed hook injects routing context at session start and before matching user prompts, so natural feature, planning, debug, review, QA, and ship requests should wake up the right WannaBuild skill automatically. Downloaded skill metadata uses friendly UI names such as `WannaBuild: Review` and `WannaBuild: Ship` where the host supports skill display names.

**From repo:**

```bash
git clone https://github.com/gl11tchy/wannabuild
cd wannabuild
./scripts/install-claude-skill.sh
```

The repo installer registers and enables the local plugin under
`~/.claude/plugins/`, verifies the hook shape, and points Claude Code at this
checkout. Then run `/reload-plugins` and start with a natural feature or
ideation prompt.

See [adapters/claude-code/README.md](adapters/claude-code/README.md) and [.claude/INSTALL.md](.claude/INSTALL.md).

### Codex / Repo-First

Use WannaBuild directly from the repo in Codex. The installer links the
repo-native skills into `~/.codex/skills/` and installs `wb-runtime` into
`~/.codex/bin/`:

- [AGENTS.md](AGENTS.md)
- [.codex/INSTALL.md](.codex/INSTALL.md)
- [docs/codex-getting-started.md](docs/codex-getting-started.md)
- [docs/host-capability-matrix.md](docs/host-capability-matrix.md)
- [scripts/validate-wannabuild-artifacts.sh](scripts/validate-wannabuild-artifacts.sh)
- [scripts/validate-wannabuild-dry-runs.sh](scripts/validate-wannabuild-dry-runs.sh)
- [scripts/wannabuild-doctor.sh](scripts/wannabuild-doctor.sh)
- [scripts/install-codex-skill.sh](scripts/install-codex-skill.sh)

Install the Codex skills:

```bash
git clone https://github.com/gl11tchy/wannabuild
cd wannabuild
./scripts/install-codex-skill.sh
```

Then restart Codex and start with natural language:

```text
I want to build a Stripe billing flow for my SaaS
```

Codex also supports `$wannabuild` and the installed `wb-*` skills. A `wb-*` skill invocation starts or resumes the full loop at that phase by default; for one-stage work, say the limit directly, such as "run discovery only" or "QA only". In Codex skill lists and chips, the phase skills ship with friendly names like `WannaBuild: Build`, `WannaBuild: Review`, and `WannaBuild: Ship`. Runtime gates fail closed; `assert-workflow-active` catches missing `.wannabuild/` runtime evidence, and `assert-plan-ready` blocks implementation before Plan. Add `~/.codex/bin` to `PATH` if Codex cannot find `wb-runtime`.

### Factory / Droid

Full install from the repo is recommended for Factory Droid because it installs
both the plugin surface and the generated specialist droids:

```bash
git clone https://github.com/gl11tchy/wannabuild
cd wannabuild
./scripts/install-factory-plugin.sh
```

The installer registers the local marketplace/plugin, links the self-contained
`adapters/factory` plugin into Factory's plugin cache, and writes generated
`wb-*` droids to `~/.factory/droids/`. Restart Droid, then start with a natural
feature, planning, debug, review, QA, or ship request. Explicit `/wannabuild`
and `/wb-*` plugin commands remain available as shortcuts.

If you only need the packaged plugin commands and skills, you can install
through Droid's plugin manager instead:

```bash
droid plugin marketplace add https://github.com/gl11tchy/wannabuild
droid plugin install wannabuild@wannabuild
```

Use the repo installer for the complete generated `wb-*` Droid specialist set.

### Cursor

Cursor is supported via the same repo-native contracts and scripts.

- [adapters/cursor/README.md](adapters/cursor/README.md)
- [docs/host-capability-matrix.md](docs/host-capability-matrix.md)
- [.cursor/rules/wannabuild.mdc](.cursor/rules/wannabuild.mdc)
- [.cursor-plugin/plugin.json](.cursor-plugin/plugin.json)

> Or use the dev container: open in VS Code → Reopen in Container. See [.devcontainer/README.md](.devcontainer/README.md).

## Usage

### Automatic Start

Use natural language when you want WannaBuild to drive the work from discovery through summary:

```text
I want to build a user authentication system with OAuth and magic links
```

```text
Add team invitations and roles to this app
```

WannaBuild should route automatically, keep startup output plain, run discovery and planning in the current checkout, and offer an isolated worktree before implementation when isolation would help.
Open-ended ideation such as "I want to work on this some" or "let's brainstorm ideas" should also route automatically into Discover, then continue through the loop once the goal is crisp enough.

### Command Shortcuts

Commands remain available when you want to be explicit, but natural prompts are the primary interface.

Claude Code:

```text
/wannabuild I wanna build a user authentication system with OAuth and magic links
```

Codex:

```text
$wannabuild I wanna build a user authentication system with OAuth and magic links
```

Droid:

```text
/wannabuild I wanna build a user authentication system with OAuth and magic links
```

### Phase Skill Usage

Use natural phase prompts to enter or resume the loop at a specific phase:

- "brainstorm the onboarding flow"
- "plan the architecture"
- "implement the next planned slice"
- "debug this failing test"
- "review this change"
- "QA this against the acceptance criteria"
- "prepare the handoff"

Phase skills display as `WannaBuild: <Skill>` in skill UI surfaces, with `wb-*` retained as the stable command/file shortcut. They stop after one phase only when the user explicitly limits the request.

Claude Code and Droid command shortcuts:

- `/wb-discover`: clarify vision, scope, flows, and acceptance criteria
- `/wb-plan`: turn requirements into design, tasks, risks, and verification expectations
- `/wb-build`: implement a planned slice with checkpoints and checks
- `/wb-debug`: reproduce, isolate, fix, and verify a failure
- `/wb-review`: run targeted reviewer hats and capture findings
- `/wb-qa`: validate acceptance criteria and integration behavior
- `/wb-ship`: prepare the final handoff after review and QA

In Codex, use the same phase intents as plain prompts. Use explicit limits such as "run discovery only" when you want a single phase.

### Typical prompts

```text
I wanna build a Stripe billing flow for my SaaS
Brainstorm the onboarding flow before we plan
Plan the architecture for a collaborative editor
Implement the next planned slice in solo mode
Validate this against the acceptance criteria
```

### Jump in midstream

You can still jump straight to a step:

- `Let's build it`
- `Review the code in src/auth/`
- `QA this against the requirements`
- `Summarize what changed and what is left`

## Artifacts

WannaBuild writes structured state and evidence into `.wannabuild/`:

```text
.wannabuild/
├── state.json
├── spec/
│   ├── requirements.md
│   ├── design.md
│   └── tasks.md
├── outputs/
├── checkpoints/
├── review/
├── loop-state.json
└── decisions.md
```

Core artifact roles:

- `requirements.md`: vision brief, audience, desired feel, core flows, feature priorities, scope, assumptions, acceptance criteria, test scenarios
- `design.md`: architecture, contracts, risks, testing direction
- `tasks.md`: ordered implementation slices with verification expectations
- `checkpoints/`: implementation evidence and resume anchors
- `review/`: structured review verdicts

## Trust Harness

WannaBuild includes a host-neutral daily-use trust harness. It validates the behavior that must hold across Claude Code, Codex, and Factory Droid:

- no-task invocation asks for the actual goal instead of inferring from repo state
- concrete git tasks do not create worktrees until implementation-time isolation is selected
- resume, research, implementation, review, QA, and summary gates preserve state
- failed review or QA evidence blocks completion
- the golden path demo validates end to end

Run the readiness checks from the repo root:

```bash
scripts/wannabuild-doctor.sh
scripts/validate-wannabuild-dry-runs.sh
scripts/validate-wannabuild-artifacts.sh docs/golden-path-demo document
scripts/wannabuild-gate-check.sh docs/golden-path-demo summary
```

The committed demo project lives at [docs/golden-path-demo](docs/golden-path-demo).

## Review and QA

WannaBuild treats review and QA as real gates, not decoration.

- Review is adaptive.
- Specialist hats run where they add signal.
- The integration tester is the hard gate.
- Acceptance criteria must map to real test coverage.
- QA results feed the final summary, including remaining gaps.

## Internal Specialists

These specialists power the framework under the hood:

| Area | Specialists |
|---|---|
| Discovery | `wb-scope-analyst`, `wb-ux-perspective` |
| Planning | `wb-tech-advisor`, `wb-architect`, `wb-risk-assessor`, `wb-task-decomposer`, `wb-dependency-mapper`, `wb-scope-validator` |
| Implementation | `wb-implementer`, `wb-implementer-escalated` |
| Review / QA | `wb-security-reviewer`, `wb-performance-reviewer`, `wb-architecture-reviewer`, `wb-testing-reviewer`, `wb-integration-tester`, `wb-code-simplifier` |
| Handoff | `wb-pr-craftsman`, `wb-ci-guardian`, `wb-readme-updater`, `wb-api-doc-generator`, `wb-changelog-writer` |

The specialist system exists to improve output quality, not to force the user through a committee-shaped workflow. WannaBuild is skill-first: commands route requests, while skills carry the real workflow contracts.
Core workflow docs express model choice as capability tiers and reasoning effort. Host adapters map those tiers to whichever models and controls are available.

## Portability

WannaBuild is being aligned as:

- Codex + Claude Code co-primary
- Factory Droid-supported
- Cursor-supported

The portability contract lives in [docs/host-capability-matrix.md](docs/host-capability-matrix.md).

## Contributing

Issues, PRs, and framework improvements are welcome.

1. Fork and branch.
2. Update prompts, skills, scripts, or docs.
3. Validate against a real target project.
4. Open a focused PR with a clear rationale.

---

<div align="center">

**What do you wanna build?**

</div>
