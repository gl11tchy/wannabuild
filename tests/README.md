# WannaBuild Test Suite

Real, executable tests for the shell scripts and contract validation in
`scripts/`. Tests are written in [Bats](https://github.com/bats-core/bats-core)
(Bash Automated Testing System) and run hermetically in temp directories — no
test reads or writes outside its `$BATS_TEST_TMPDIR` or `tests/results/`.

## Quick start

```bash
# Run everything (parallelized, 4 jobs by default)
bash tests/run.sh

# Run only unit tests
bash tests/run.sh --unit

# Run only integration tests
bash tests/run.sh --integration

# Or use the Makefile
make -C tests test
make -C tests unit
make -C tests integration
make -C tests coverage
make -C tests clean
```

If `bats` is not on your `PATH`, `tests/run.sh` will clone `bats-core` into
`tests/.bats/` for the duration of the run. Nothing is installed system-wide.
The companion libraries `bats-support`, `bats-assert`, and `bats-file` are
also fetched into `tests/.bats-libs/` so individual tests may opt in via
`load`. None are required by the existing test files.

## Layout

```text
tests/
├── README.md              ← you are here
├── Makefile               ← convenience targets
├── bats.conf              ← default options (BATS_JOBS, output dir, …)
├── run.sh                 ← entry point
├── coverage.sh            ← kcov-based coverage with configurable threshold
├── test_helper.bash       ← shared helpers (loaded by every .bats file)
├── fixtures/              ← minimal-valid JSON fixtures used by helpers/tests
│   ├── state-requirements.json
│   ├── state-design.json
│   ├── state-tasks.json
│   ├── state-implement.json
│   ├── state-invalid-missing-id.json
│   ├── loop-state-pass.json
│   ├── loop-state-fail.json
│   ├── review-verdict-valid.json
│   └── checkpoint-valid.json
├── unit/                  ← per-script behavioral tests
│   ├── test_validate_artifacts_cli.bats
│   ├── test_doctor_script.bats
│   ├── test_gate_check.bats
│   ├── test_workspace_bootstrap.bats
│   └── test_session_script.bats
├── integration/           ← multi-script flows
│   ├── test_phase_transition_flow.bats
│   ├── test_doctor_full_repo.bats
│   └── test_artifact_schema_conformance.bats
└── results/               ← junit.xml & friends are written here
```

## Naming conventions

* **Files**: `test_<area>.bats` under either `tests/unit/` (one script,
  isolated behavior) or `tests/integration/` (more than one script or
  multi-file flows).
* **`@test` names**: `"<script>: <observable behavior>"`, e.g.
  `@test "validate_artifacts: rejects unknown phase"`. The `<script>` prefix
  makes it easy to filter test output and grep for the script under test.
* **Fixtures**: `snake-case.json` under `tests/fixtures/`. Each fixture is
  the smallest legal-valid (or smallest illegal-invalid) instance of its
  artifact, suitable for copying into a temp target.

## Parallel execution

`tests/run.sh` invokes `bats --jobs ${BATS_JOBS:-4}`. This is safe because:

* Each test gets its own `$BATS_TEST_TMPDIR` (bats provides this).
* Helpers never write outside that tmpdir or `tests/results/`.
* `with_clean_env` re-points `$HOME` to a tmp dir before invoking install
  scripts, so two parallel tests can each call `install-claude-skill.sh`
  (or similar) without clobbering each other or the user's real `$HOME`.
* No test depends on absolute time, system clock skew, or network access.

Override the job count with `BATS_JOBS=N bash tests/run.sh`.

## Isolation guarantees

* **No real `$HOME` mutation.** Tests that exercise install scripts use
  `with_clean_env`, which sets `HOME=$BATS_TEST_TMPDIR/home`.
* **No real `.wannabuild/` mutation.** Tests build a fake target project
  under `$BATS_TEST_TMPDIR` via `make_target_repo`. The repo's own
  `.wannabuild/` (if any) is never read or written.
* **No network.** The only network access is in `tests/run.sh` itself when
  cloning bats-core — and only when bats is not already on `PATH`.
* **Deterministic.** No time-based assertions, no fuzz inputs that depend on
  system entropy.

## Coverage

```bash
bash tests/coverage.sh
```

Uses [`kcov`](https://github.com/SimonKagstrom/kcov) to measure line coverage
on `scripts/`. If kcov is not installed, the script prints install
instructions and exits 0 (so CI can be conditional). When kcov is present,
the script enforces `COVERAGE_THRESHOLD` (default 60%) and exits non-zero on
regression. Output lands in `tests/coverage-out/`.

## Adding a new test

1. Decide whether it belongs in `unit/` (one script, mocked surroundings) or
   `integration/` (multi-script flow).
2. Create `tests/<scope>/test_<area>.bats`. Start with:

   ```bash
   #!/usr/bin/env bats
   load "${BATS_TEST_DIRNAME}/../test_helper.bash"

   setup() {
     TARGET="$(setup_tmpdir)/proj"
     make_target_repo "$TARGET" >/dev/null
   }

   @test "<script>: <observable behavior>" {
     # arrange — set up files in $TARGET
     # act
     run_script <script>.sh <args>
     # assert
     [ "$status" -eq 0 ]
     [[ "$output" == *"expected substring"* ]]
   }
   ```

3. Use the helpers in `test_helper.bash`. Avoid reaching outside the helpers
   to manipulate `$HOME` or repo state directly — that is the only thing
   that breaks parallel isolation.
4. Run `bash tests/run.sh --unit` (or `--integration`) and verify it passes
   on its own before pushing.
