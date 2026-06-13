<div align="center">

# WannaBuild

**Your agent can't mark its own homework.**

Spec-driven development for coding agents — with ship gates that are programs, not prose.

[![CI](https://github.com/gl11tchy/wannabuild/actions/workflows/ci.yml/badge.svg)](https://github.com/gl11tchy/wannabuild/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/gl11tchy/wannabuild/badge)](https://scorecard.dev/viewer/?uri=github.com/gl11tchy/wannabuild)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
![Specialists](https://img.shields.io/badge/specialists-25-blue?style=flat-square)
![Codex](https://img.shields.io/badge/codex-supported-111827?style=flat-square)
![Claude Code](https://img.shields.io/badge/claude--code-supported-5B21B6?style=flat-square)
![Droid](https://img.shields.io/badge/droid-supported-0ea5e9?style=flat-square)
![Cursor](https://img.shields.io/badge/cursor-supported-0f766e?style=flat-square)

[Quickstart](#quickstart) · [Why](#why-wannabuild) · [Trust Model](#the-trust-model) · [Workflow](#workflow) · [Install](#install) · [Usage](#usage) · [Artifacts](#artifacts)

</div>

---

## The problem

You ask an agent to build something. It writes code fast, tells you the tests
pass, and hands you a confident summary. Then you open the diff: a
half-implemented feature, tests that never ran, a "QA report" that is a
paragraph of vibes. You got burned, so you tried an agent framework — and
found that almost every one of them enforces its discipline with markdown
files the model can rationalize past.

A markdown file cannot fail a build.

## Why WannaBuild

WannaBuild runs the loop a serious team would run — **Discover → Plan →
Implement → Validate → QA → Summary** — and enforces the parts that decide
shipping with a runtime, not a prompt:

- **Runtime-recorded test evidence.** At QA time, `wb-runtime
  record-test-evidence` executes your integration test command *itself* and
  signs the record with a key kept outside the project tree. The review and QA
  gates verify the signature, the exit code, that the spec hasn't changed
  since the run, and that the command matches your config. The model never
  gets to "report" that tests passed.
- **Fail-closed gates.** No planning without discovery and acceptance
  criteria. No implementation before an approved plan
  (`assert-plan-ready`). No ship without a unanimous reviewer set and
  verified QA evidence (`assert-summary-ready`). Gates are compiled checks
  that exit non-zero — when they cannot run, that is a stop, not a pass.
- **Red-team tested.** The test suite forges perfect-looking verdicts against
  our own gates and asserts they fail. Run
  `scripts/validate-wannabuild-dry-runs.sh` and watch the forgery get
  rejected.
- **An honest trust model.** [docs/trust-model.md](docs/trust-model.md) maps
  every guarantee to its enforcement rung — runtime-recorded, checked, or
  prose — including the limits and non-goals. We'd rather you find the line
  here than on camera.

### Try to cheat it

```bash
# Hand the gate a perfect-looking forged verdict: 100 passing tests, every criterion covered,
# plus a clean QA summary — exactly what a lazy agent would write instead of running tests.
cat > .wannabuild/review/wb-integration-tester-iter-1.json <<'EOF'
{"agent":"wb-integration-tester","status":"PASS","hard_gate":true,"summary":"all green","issues":[],
 "test_execution":{"total":100,"passed":100,"failed":0,"errored":0,"duration_ms":5000},
 "coverage_map":[{"criterion":"login works","status":"covered"}]}
EOF
printf '# QA\n\nstatus: PASS\nacceptance: covered\nintegration: covered\n' > .wannabuild/outputs/qa-summary.md

wb-runtime assert-qa-ready --project .
# QA gate failed: no runtime-recorded execution evidence for iteration 1
# (.wannabuild/review/wb-integration-tester-iter-1.evidence.json missing); run
# `wb-runtime record-test-evidence` — the runtime executes the integration test
# command itself and signs the result, so a hand-written verdict cannot pass this gate
```

The only path to a green QA gate is the runtime actually running your tests.
Edit the recorded evidence afterward — one character — and the signature
check kills it.

## Quickstart

Pick the host you already use.

### Claude Code

```text
/plugin marketplace add gl11tchy/wannabuild
/plugin install wannabuild@gl11tchy
/reload-plugins
```

### Codex

```bash
git clone https://github.com/gl11tchy/wannabuild
cd wannabuild
./scripts/install-codex-skill.sh
```

Then restart Codex.

### Factory Droid

```bash
git clone https://github.com/gl11tchy/wannabuild
cd wannabuild
./scripts/install-factory-plugin.sh
```

Then restart Droid.

### Cursor

Load `.cursor/rules/wannabuild.mdc` from a clone of this repo.

Then, on any host, type a natural feature request — no command needed:

```text
I want to add Stripe billing to my SaaS
```

## Workflow

```text
DISCOVER -> PLAN -> IMPLEMENT -> VALIDATE -> QA -> SUMMARY
```

- **Discover** — WannaBuild grills you, one question at a time with a
  recommended answer, until vision, flows, constraints, and acceptance
  criteria are crisp. It reads your codebase instead of asking when the code
  already holds the answer, then runs a research bundle (feasibility,
  alternatives, failure forecast) at proportionate depth.
- **Plan** — concrete design and tasks, plus N adversarial plan options
  rendered to a self-contained HTML you can open before choosing. The plan
  gate blocks all implementation until this exists.
- **Implement** — adaptive solo or parallel execution with checkpoints, so
  progress and resume paths stay explicit.
- **Validate** — the full reviewer set runs every iteration (security,
  performance, architecture, testing, integration, simplicity). No
  impacted-only shortcuts. Actionable findings are fixed and re-reviewed.
- **QA** — every acceptance criterion maps to an executed check; the
  integration suite runs through the runtime recorder against real, acquired
  resources. Missing coverage or failing tests block completion.
- **Summary** — what changed, what passed, what remains. Honest by
  construction, because the gates already verified the claims.

### Control mode

Guided by default: WannaBuild pauses at every phase boundary for your explicit
approval. Say "run autonomously" for unattended end-to-end runs; it then asks
only when scope, product direction, destructive actions, credentials, or paid
services genuinely need your judgment.

## The Trust Model

The full enforcement map lives in [docs/trust-model.md](docs/trust-model.md):
every gate, what it checks, which layer enforces it on which host, and —
because honesty is the feature — exactly what it does *not* defend against.

Audit any finished run yourself instead of trusting the transcript:

```bash
wb-runtime verify-test-evidence --project .     # signature, exit code, spec freshness
wb-runtime assert-summary-ready --project .     # the full ship bar
scripts/validate-wannabuild-artifacts.sh . document
```

The repo also ships a host-neutral trust harness covering the behaviors that
must hold everywhere — state preserved across resume, failed evidence blocking
completion, forged verdicts rejected, the golden path validating end to end:

```bash
scripts/wannabuild-doctor.sh
scripts/validate-wannabuild-dry-runs.sh
scripts/validate-wannabuild-artifacts.sh docs/golden-path-demo document
WB_EVIDENCE_MODE=fixture scripts/wannabuild-gate-check.sh docs/golden-path-demo summary
```

The committed demo at [docs/golden-path-demo](docs/golden-path-demo) shows
every artifact a real run produces. Its verdicts are illustrative fixtures —
which is why its gate check runs in loudly-labeled fixture mode, and why the
dry-run suite proves those same fixtures *fail* the gates outside it.

## Install

### Claude Code

Marketplace (above) or from the repo:

```bash
git clone https://github.com/gl11tchy/wannabuild
cd wannabuild
./scripts/install-claude-skill.sh
```

The installer registers and enables the local plugin under
`~/.claude/plugins/`, verifies the hook shape, and points Claude Code at this
checkout. Run `/reload-plugins` afterward. The hook injects live runtime state
(active phase, pending gates, forbidden actions) at session start and on each
prompt, and ships Python mirrors of every gate plus the evidence recorder, so
enforcement works even without the Rust binary. See
[adapters/claude-code/README.md](adapters/claude-code/README.md) and
[.claude/INSTALL.md](.claude/INSTALL.md).

### Codex

The installer links the repo-native skills into `~/.codex/skills/` and
installs the `wb-runtime` binary into `~/.codex/bin/` (add it to `PATH` if
Codex cannot find it). Runtime gates fail closed: `assert-workflow-active`
catches missing `.wannabuild/` evidence and `assert-plan-ready` blocks
implementation before Plan. See
[docs/codex-getting-started.md](docs/codex-getting-started.md) and
[.codex/INSTALL.md](.codex/INSTALL.md).

### Factory Droid

The repo installer registers the local marketplace/plugin, links the
self-contained `adapters/factory` plugin into Factory's plugin cache, and
writes generated `wb-*` droids to `~/.factory/droids/`. If you only need the
packaged commands and skills:

```bash
droid plugin marketplace add https://github.com/gl11tchy/wannabuild
droid plugin install wannabuild@wannabuild
```

### Cursor

Cursor consumes the same contracts via
[.cursor/rules/wannabuild.mdc](.cursor/rules/wannabuild.mdc) — note this is
the one host on the prose rung of the [trust model](docs/trust-model.md):
gates run only when the agent invokes the scripts. See
[adapters/cursor/README.md](adapters/cursor/README.md).

> **Hit a problem?** See
> [docs/runbooks/install-and-load-failures.md](docs/runbooks/install-and-load-failures.md)
> before opening an issue. Host capabilities are compared in
> [docs/host-capability-matrix.md](docs/host-capability-matrix.md).

## Usage

### Automatic start

Natural language routes automatically — commands are optional shortcuts, not
requirements:

```text
I want to build a user authentication system with OAuth and magic links
Add team invitations and roles to this app
Let's brainstorm what to work on next
```

### Command shortcuts

Claude Code and Droid: `/wannabuild <request>` · Codex: `$wannabuild <request>`

Phase shortcuts enter or resume the loop at a specific phase:

- `/wb-discover`: clarify vision, scope, flows, and acceptance criteria
- `/wb-plan`: turn requirements into design, tasks, risks, and verification expectations
- `/wb-build`: implement a planned slice with checkpoints and checks
- `/wb-debug`: reproduce, isolate, fix, and verify a failure
- `/wb-review`: run targeted reviewer hats and capture findings
- `/wb-qa`: validate acceptance criteria and integration behavior
- `/wb-ship`: prepare the final handoff after review and QA

In Codex, use the same phase intents as plain prompts. A phase entry continues
the full loop by default; say "discovery only" / "QA only" to stop after one
phase. Vague acknowledgments ("ok") continue the current phase — they never
skip gates.

### Jump in midstream

```text
Let's build it
Review the code in src/auth/
QA this against the requirements
Summarize what changed and what is left
```

## Artifacts

WannaBuild writes structured state and evidence into `.wannabuild/`. Three
artifacts carry the trust story:

- `spec/requirements.md` — the vision and acceptance criteria every later
  gate measures against
- `review/` — one structured verdict per reviewer per iteration, plus the
  runtime-recorded `*.evidence.json` that backs the integration PASS
- `outputs/qa-summary.md` — the QA report the summary gate verifies against
  the evidence, not against its own adjectives

```text
.wannabuild/
├── state.json          # merge-updated workflow state (never replaced wholesale)
├── config.json         # includes integration_test_command, set during Plan
├── spec/               # requirements.md, design.md, tasks.md
├── checkpoints/        # implementation evidence and resume anchors
├── review/             # verdicts + signed evidence records
├── outputs/            # QA summary, discovery research, acquisition log
└── loop-state.json     # review loop iterations and verdicts
```

## Internal Specialists

25 focused agents power the loop under the hood:

| Area | Specialists |
|---|---|
| Discovery | `wb-scope-analyst`, `wb-ux-perspective`, `wb-feasibility-analyst`, `wb-alternatives-analyst`, `wb-failure-forecast` |
| Planning | `wb-plan-options`, `wb-tech-advisor`, `wb-architect`, `wb-risk-assessor`, `wb-task-decomposer`, `wb-dependency-mapper`, `wb-scope-validator` |
| Implementation | `wb-implementer`, `wb-implementer-escalated` |
| Review / QA | `wb-security-reviewer`, `wb-performance-reviewer`, `wb-architecture-reviewer`, `wb-testing-reviewer`, `wb-integration-tester`, `wb-code-simplifier` |
| Handoff | `wb-pr-craftsman`, `wb-ci-guardian`, `wb-readme-updater`, `wb-api-doc-generator`, `wb-changelog-writer` |

The specialist system exists to improve output quality, not to force you
through a committee. Skills carry the workflow contracts; commands just route.
Core contracts express model choice as capability tiers, and each host adapter
maps tiers to whatever models it actually has — the framework is
model-agnostic by design.

## Development & Contribution

For working on the framework itself:

- [docs/build.md](docs/build.md) — local build, lint, and test commands
- [docs/ci.md](docs/ci.md) — CI workflow overview
- [docs/release.md](docs/release.md) — Conventional Commits + release-please
- [docs/governance.md](docs/governance.md) — maintainership, CODEOWNERS, triage
- [docs/security.md](docs/security.md) — security posture ([SECURITY.md](SECURITY.md) for reporting)
- [docs/roadmap.md](docs/roadmap.md) — what's shipped, next, and deferred
- [tests/README.md](tests/README.md) — bats unit + integration suite
- [.devcontainer/README.md](.devcontainer/README.md) — dev container setup

Issues and focused PRs are welcome:

1. Fork and branch.
2. Update prompts, skills, scripts, or docs.
3. Validate against a real target project (`scripts/wannabuild-doctor.sh` must stay green).
4. Open a focused PR with a clear rationale.

---

<div align="center">

**What do you wanna build?**

</div>
