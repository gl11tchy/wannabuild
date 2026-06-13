# Trust Model

Most agent frameworks enforce their rules with prose: a markdown file tells the
model to write tests, and a markdown file cannot fail a build. WannaBuild's
position is different — **the agent can't mark its own homework** — and this
page is the honest map of exactly where that holds, how strongly, and where the
line is. We would rather you find the limits here than on camera.

## The enforcement ladder

Every rule in WannaBuild sits on one of three rungs. Knowing which rung a
guarantee sits on tells you how much it can be trusted.

| Rung | Mechanism | Can the model talk its way past it? |
|---|---|---|
| **Recorded** | The runtime performs the action itself and signs the record (integration evidence) | No — a hand-written or edited record fails signature verification |
| **Checked** | A program inspects artifacts and exits non-zero (`wb-runtime` gates via `wannabuild-gate-check.sh`, the hook's `verify-test-evidence` CLI, the artifact validators) | Not by arguing — only by fabricating artifacts, which the checks are built to catch |
| **Instructed** | Contract prose in skills and agent prompts | Yes, in principle — prose constrains behavior, it does not verify it |

The design goal: everything that decides whether work **ships** sits on the
top two rungs, and anything that sits on the bottom rung is labeled as such.

## What is enforced, per gate

| Gate | What it checks | Rung |
|---|---|---|
| `assert-workflow-active` | `.wannabuild/` runtime layout and live state exist | Checked |
| `assert-concrete-task` | A real goal exists before any workflow runs | Checked |
| `assert-discovery-ready` | Discovery artifacts exist, are non-empty, and `requirements.md` has acceptance criteria | Checked |
| `assert-plan-ready` | `design.md` + `tasks.md` exist before any implementation edit | Checked |
| `assert-review-ready` | Every required reviewer has a PASS verdict for the **latest** iteration (stale verdicts rejected) **and** the integration PASS is backed by a verifying evidence record | Checked + Recorded |
| `assert-qa-ready` | QA summary carries positive markers, no failure signals anywhere in state/history/events, verdict counts prove tests ran, every acceptance criterion maps to a covered entry, **and** the evidence record verifies | Checked + Recorded |
| `assert-summary-ready` | Review + QA gates both pass and nothing is blocked | Checked + Recorded |
| `assert-acquisition-attempted` | A blocked/failed status without a logged acquisition attempt is rejected | Checked |

## The integration evidence record

The integration tester's PASS is the gate that decides shipping, so it gets
the strongest treatment:

1. During Plan, `.wannabuild/config.json` records `integration_test_command`
   from the design's test strategy (and if Plan omits it, the integration
   tester sets it from the canonical command it identifies before recording).
2. At QA time, `wb-runtime record-test-evidence` **executes that command
   itself** — the model does not run the tests and report back; the runtime
   runs them — and writes
   `.wannabuild/review/wb-integration-tester-iter-<N>.evidence.json`
   containing the command, exit code, output SHA-256 (full output in a sidecar
   log), timing, and a hash of the current spec files, signed with an
   HMAC-SHA256 key stored **outside the project tree**
   (`~/.wannabuild/evidence.key`).
3. `assert-review-ready` and `assert-qa-ready` verify the record: valid
   signature, exit code 0, spec hash equal to the **current** spec (evidence
   recorded before a spec change is stale and rejected), and command equal to
   the **current** configured command (editing the config after the run is
   rejected).

What this kills, concretely:

- A verdict JSON with `"status": "PASS"` and healthy-looking test counts,
  written by the model without running anything → **fails** (no record).
- An evidence record edited after the fact, even by one character → **fails**
  (HMAC mismatch).
- Reusing a real, green record after the requirements changed → **fails**
  (spec hash).
- Quietly swapping the test command for `true` after recording → **fails**
  (command match).

We ship red-team tests that perform exactly these forgeries against our own
gates and assert they fail — see `tests/unit/test_gate_check.bats` and the
forged-verdict scenario in `scripts/validate-wannabuild-dry-runs.sh`. Run them
yourself.

## Audit a finished run

You never have to take a transcript's word for it. From any project root:

```bash
wb-runtime verify-test-evidence --project .     # signature, exit, freshness
wb-runtime assert-summary-ready --project .     # the full ship bar
scripts/validate-wannabuild-artifacts.sh . document
```

If an agent claims it shipped clean, these commands either agree or they
don't.

## Per-host coverage

| Host | Gate execution | Evidence recorder |
|---|---|---|
| Claude Code | Hook injects live runtime state and the computed gate verdicts as context each turn (surfacing the same pass/fail the binary derives, not blocking by exit code); `wannabuild-gate-check.sh` / `wb-runtime` / the hook's `verify-test-evidence` CLI are the hard, fail-closed checks | `wb-runtime` if present, else the hook's `record-test-evidence` subcommand (same signed format) |
| Codex | `wb-runtime` binary installed to `~/.codex/bin` by the installer; gates run fail-closed via `scripts/wannabuild-gate-check.sh` | `wb-runtime record-test-evidence` |
| Factory Droid | Same hook + Python mirrors as Claude Code | Same as Claude Code |
| Cursor | Rule file only — **Instructed** rung. Gates run only if the agent invokes the scripts | `wb-runtime` if installed |

On hosts without the binary (Claude Code, Factory Droid), the hook computes the
same verdicts from the artifacts and surfaces them in context every turn — so
the model cannot quietly claim a gate passed that did not — but the hook injects
context, it does not exit non-zero. The fail-closed, non-zero-exit gate on those
hosts is `wb-runtime` (if installed), `wannabuild-gate-check.sh`, or the hook's
`verify-test-evidence` CLI. The **Recorded** evidence guarantee holds on all
hosts: the recorder and verifier are byte-compatible across the binary and the
Python mirror, so a record one produces verifies under the other.

## What this does NOT defend against (non-goals)

Honesty is the feature, so here is the line:

- **A hostile operator.** The HMAC key lives on your machine with your file
  permissions. A human (or an agent given free shell access and the explicit
  goal of cheating) can read the key and forge a record. This is
  tamper-evidence against an agent taking shortcuts, not cryptographic
  attestation against an adversary who owns the machine.
- **A weak test command.** If `integration_test_command` is set to something
  trivial during Plan, the runtime will faithfully record that something
  trivial passed. The command lives in `.wannabuild/config.json` in your
  diff, and the recorded command is in the evidence file — review it.
- **Test files edited after recording.** Freshness is checked against the spec
  files (`requirements.md`, `design.md`, `tasks.md`), not against the test
  files themselves. Recording green, then weakening a test without touching
  the spec, is not caught by the spec hash — the reviewer set and code review
  are the defense there. Changing the spec *does* invalidate the evidence.
- **Fixture mode.** `WB_EVIDENCE_MODE=fixture` skips evidence verification so
  committed example projects (like `docs/golden-path-demo`) can be
  schema-validated without machine-local signatures. The `wb-runtime` gates,
  `wannabuild-gate-check.sh`, and the hook's `verify-test-evidence` CLI all
  print a `FIXTURE MODE` line when they skip on it (and `wb-runtime` records it
  in the event log). Fixture mode is for committed examples only; if you see
  that label in a run that claims to be real, it isn't.
- **Hosts on the Instructed rung.** Cursor (and any host without hooks or the
  binary) gets the contracts but not the enforcement. The table above says so.

## Why this matters

Prompt-level discipline drifts: models summarize, rationalize, and skip under
context pressure, and frameworks built only from prompts have no way to notice.
WannaBuild's gates are programs. They exit non-zero. The difference between
"the agent says QA passed" and "the runtime recorded QA passing" is the
difference between a report card the student wrote and one the school did.
