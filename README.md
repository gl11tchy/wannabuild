<div align="center">

# WannaBuild

Spec-driven development for indie builders.

Condensed workflow: Discover -> control mode -> optional Research -> Plan -> Implement -> Review -> QA -> Summary.

[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
![Specialists](https://img.shields.io/badge/specialists-20-blue?style=flat-square)
![Workflow](https://img.shields.io/badge/workflow-adaptive-0a7ea4?style=flat-square)
![Codex](https://img.shields.io/badge/codex-first-111827?style=flat-square)
![Claude Code](https://img.shields.io/badge/claude--code-supported-5B21B6?style=flat-square)
![Cursor](https://img.shields.io/badge/cursor-supported-0f766e?style=flat-square)

[Workflow](#workflow) · [Install](#install) · [Usage](#usage) · [Artifacts](#artifacts)

</div>

---

## Overview

WannaBuild is a repo-native framework for running a disciplined product-development loop with AI agents. The user experience stays compact:

1. Discover the real goal
2. Choose guided or autonomous progression
3. Decide whether optional research will improve planning
4. Produce a plan
5. Verify the approach
6. Implement in solo or parallel mode
7. Review from the right specialist angles
8. Run QA against acceptance criteria
9. Return a concise summary with gaps and remaining work

Under the hood, WannaBuild uses structured specs, checkpoints, adaptive review routing, and specialist prompts so the workflow stays rigorous without feeling bureaucratic.
Every real run should start in an isolated workspace so parallel chats cannot collide in the same repo.

## Why

Most AI coding flows fail in predictable ways:

- scope gets fuzzy
- plans stay implicit
- implementation drifts
- reviews are shallow
- QA is hand-wavy
- final summaries are noisy or incomplete

WannaBuild fixes that by making specs and verification first-class while keeping the visible workflow short.

## Workflow

```text
DISCOVER -> CONTROL MODE -> OPTIONAL RESEARCH -> PLAN -> IMPLEMENT -> REVIEW -> QA -> SUMMARY
```

### Discover

- Ask focused questions to clarify goals, constraints, scope, and flavor.
- Produce a crisp problem brief instead of jumping straight into code.

### Control Mode

- After Discover, WannaBuild should ask whether to continue in guided mode or switch to autonomous mode.
- Guided mode asks for preference at each later gate.
- Autonomous mode continues adaptively after that point.

### Plan

- Generate a concrete plan.
- Verify architecture and direction before implementation begins.

### Optional Research

- When uncertainty is still high, WannaBuild can ask whether to kick off research agents or move straight to planning.
- Research is adaptive and user-approved, not a permanent required phase.

### Implement

- Offer solo owner mode or parallel mode.
- Use checkpoints so progress, verification, and resume paths stay explicit.

### Review

- Run the right reviewer hats for the change.
- Keep review adaptive; not every hat needs to run every time.

### QA

- Validate acceptance criteria and integration behavior.
- Missing coverage or failing tests block completion.

### Summary

- Return what changed.
- Report what passed.
- Call out gaps, risks, and remaining work.

Parallelism is selective. In practice, Discover, Plan, QA, and Summary are usually single-lane. Fan-out is most useful during implementation and review when the work splits cleanly.
Research is the other place where bounded multi-agent fan-out can help.

## Install

### Claude Code

Primary path for Claude Code users.

**Marketplace:**

```
/plugin marketplace add gl11tchy/wannabuild
/plugin install wannabuild@gl11tchy
```

Restart Claude Code, then:

```
/wannabuild
```

**From repo:**

```bash
./scripts/install-claude-skill.sh
```

Then run `/reload-plugins` and invoke `/wannabuild`.

See [adapters/claude-code/README.md](adapters/claude-code/README.md) and [.claude/INSTALL.md](.claude/INSTALL.md).

### Codex / Repo-First

Use WannaBuild directly from the repo in Codex:

- [AGENTS.md](AGENTS.md)
- [.codex/INSTALL.md](.codex/INSTALL.md)
- [docs/codex-getting-started.md](docs/codex-getting-started.md)
- [docs/host-capability-matrix.md](docs/host-capability-matrix.md)
- [scripts/validate-wannabuild-artifacts.sh](scripts/validate-wannabuild-artifacts.sh)
- [scripts/wannabuild-doctor.sh](scripts/wannabuild-doctor.sh)
- [scripts/install-codex-skill.sh](scripts/install-codex-skill.sh)

Install the Codex skills:

```bash
./scripts/install-codex-skill.sh
```

Then restart Codex and invoke:

```text
$wannabuild
```

### Cursor

Cursor is supported via the same repo-native contracts and scripts.

- [adapters/cursor/README.md](adapters/cursor/README.md)
- [docs/host-capability-matrix.md](docs/host-capability-matrix.md)
- [.cursor/rules/wannabuild.mdc](.cursor/rules/wannabuild.mdc)
- [.cursor-plugin/plugin.json](.cursor-plugin/plugin.json)

## Usage

### Start with natural language

```text
I wanna build a user authentication system with OAuth and magic links
```

WannaBuild begins with the startup banner:

```text
[WB-START] WannaBuild STARTED | intent=build | mode=standard
```

Then it starts discovery and drives the workflow for you.

If the repo is under git, WannaBuild should first create an isolated workspace/worktree and continue there.

### Typical prompts

```text
I wanna build a Stripe billing flow for my SaaS
```

```text
Research this first, then plan
```

```text
Let's plan the architecture for a collaborative editor
```

```text
Implement this in solo mode
```

```text
Run review and QA, then summarize gaps
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

- `requirements.md`: goals, scope, acceptance criteria, test scenarios
- `design.md`: architecture, contracts, risks, testing direction
- `tasks.md`: ordered implementation slices with verification expectations
- `checkpoints/`: implementation evidence and resume anchors
- `review/`: structured review verdicts

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

The specialist system exists to improve output quality, not to force the user through a committee-shaped workflow.

## Portability

WannaBuild is being aligned as:

- Codex + Claude Code co-primary
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
