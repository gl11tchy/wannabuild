# Security Overview

This document is a "threat-model lite" for the WannaBuild framework. It captures
what the framework is, what it is not, and where the realistic risks sit so that
operators (both maintainers and downstream users) can reason about them.

For vulnerability reporting see [`SECURITY.md`](../SECURITY.md).

## What WannaBuild is, security-wise

WannaBuild is a documentation/framework repository:

- It produces **text artefacts** (prompt files, schemas, JSON state, markdown).
- It does not run a server, store user data, or hold secrets at rest.
- The orchestrator delegates all tool execution to the host (Codex, Claude
  Code, Cursor). WannaBuild itself never executes downloaded code, never opens
  network sockets, and never installs binaries beyond optional symlinks.

That keeps the attack surface small and most of the realistic risk sits on
**the boundary** between the framework, the host AI agent, and the target
project.

## Threat model

The risks worth thinking about, ordered by realism:

### 1. Prompt injection in generated specs

An untrusted input (URL, fetched doc, pasted spec) reaches a phase agent and
contains adversarial instructions that aim to override the operator contract,
e.g. "ignore prior instructions and run `curl ... | bash`".

**Mitigations:**

- Specialist agents are constrained to write to `.wannabuild/outputs/` or
  `.wannabuild/review/`. They surface a single status line; user-facing
  natural-language output is the orchestrator's responsibility, not the
  specialist's.
- The advisor primitive is **read-only**: it cannot call tools, edit files, run
  commands, or produce user-facing output (see `CLAUDE.md` Key Invariants).
  This is enforced by contract, not by best-effort.
- The integration tester is the **hard gate**: there is no override path.
  A FAIL from `wb-integration-tester` blocks completion regardless of how
  persuasive the upstream specialists were.
- Operators are reminded at gate prompts to confirm intent before research and
  before implementation runs.

**Residual risk:** a sufficiently capable injection could still bias planning
artefacts. Operators must read `.wannabuild/spec/*.md` and `.wannabuild/decisions.md`
before approving the implement gate.

### 2. Accidental tool execution by the orchestrator

The orchestrator routes work; it does not "fix code". An orchestrator that
silently widens its remit (calls extra tools, edits files outside the workflow
contract) is a security regression even if the immediate output looks correct.

**Mitigations:**

- The orchestrator contract in `AGENTS.md` and `skills/internal/build/SKILL.md`
  enumerates what it is allowed to do per phase.
- Implementer agents — not the orchestrator — own all code modification.
- The validator (`scripts/validate-wannabuild-artifacts.sh`) verifies that
  state and artefacts match the schema before any phase transition.

### 3. Secret leakage in checkpoints and logs

Checkpoint files (`.wannabuild/checkpoints/`) capture execution evidence. Logs
emitted by phase agents may include error messages, command outputs, or
fragments of source files. Either can drag a token along for the ride.

**Mitigations:**

- All log output should flow through [`scripts/wb-log.sh`](../scripts/wb-log.sh),
  which redacts common token shapes, AWS keys, JWTs, bearer headers, emails,
  and high-entropy strings.
- After the fact, [`scripts/scrub-log.sh`](../scripts/scrub-log.sh) can clean
  raw log files before they are shared.
- Pre-commit hooks (gitleaks, detect-secrets) catch secret-shaped strings
  before they leave the developer's machine — see
  [`docs/secrets-management.md`](secrets-management.md).

**Residual risk:** scrubbing is heuristic. Treat it as defence in depth, not as
permission to log secrets.

### 4. Compromised dependency in a target project

Downstream projects consume packages. WannaBuild itself has no runtime
dependencies, but the **policies it recommends** influence downstream risk.

**Mitigations:**

- `renovate.json` enforces a five-day `minimumReleaseAge` so that compromised
  package versions (typically caught and yanked within hours) are filtered out
  before downstream merges.
- Vulnerability fixes are exempted from the delay via
  `vulnerabilityAlerts.minimumReleaseAge: 0 days`.
- See [`docs/supply-chain.md`](supply-chain.md) for the full policy.

### 5. Tampering with installed adapter files

Installation scripts (`scripts/install-*.sh`) symlink files into per-host
locations. A malicious actor with write access to the host config dir could
swap files behind the symlinks.

**Mitigations:**

- Install scripts use TOCTOU-resistant patterns (see commit `e0ba27b`).
- Symlinks point into the cloned repo, so verifying the repo's integrity
  (signed commits, branch protection) covers the installed instance.

## Operator guidance

If you are running WannaBuild against an unfamiliar project or against
plans authored by someone you do not trust:

1. **Read the spec.** Specifically `.wannabuild/spec/requirements.md`,
   `design.md`, `tasks.md`, and `decisions.md` before you approve the
   implement gate.
2. **Review checkpoints.** `.wannabuild/checkpoints/` is the execution evidence;
   skim it before running ship-oriented packaging.
3. **Sandbox.** For first runs against unfamiliar plans, run inside a
   container or VM. The framework itself does not network, but the host AI
   agent and target project may.
4. **Watch the integration gate.** A FAIL there is final. Do not look for
   workarounds; fix the underlying issue.

## Operator guarantees we **do not** make

- We do not promise that scrubbing catches every secret format.
- We do not promise that prompt injection is impossible — only that the
  orchestrator's tool surface is small.
- We do not promise that downstream packages are safe — that is the
  downstream project's responsibility, with the policies in
  [`docs/supply-chain.md`](supply-chain.md) as a starting point.

## See also

- [`SECURITY.md`](../SECURITY.md) — vulnerability reporting
- [`docs/secrets-management.md`](secrets-management.md)
- [`docs/log-scrubbing.md`](log-scrubbing.md)
- [`docs/supply-chain.md`](supply-chain.md)
