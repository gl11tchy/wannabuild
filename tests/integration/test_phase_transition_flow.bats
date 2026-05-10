#!/usr/bin/env bats
#
# Integration tests for the phase-transition flow:
#   init → set-stage → set-stage → validate at each phase.
# Covers the canonical CLAUDE.md invariant that state.json fields are
# merge-updated, never replaced wholesale.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup() {
  TARGET="$(setup_tmpdir)/proj"
  make_target_repo "$TARGET" >/dev/null
}

@test "phase_flow: requirements fixture validates with exit 0" {
  make_state_json "$TARGET" requirements
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Validation passed"* ]]
}

@test "phase_flow: design phase validates with requirements.md present" {
  make_state_json "$TARGET" design
  write_spec "$TARGET" requirements.md
  run_script validate-wannabuild-artifacts.sh "$TARGET" design
  [ "$status" -eq 0 ]
}

@test "phase_flow: discovery state shape validates with exit 0" {
  make_state_json "$TARGET" requirements
  write_spec "$TARGET" requirements.md
  mkdir -p "$TARGET/.wannabuild/outputs/discovery"
  printf 'feasible\n' >"$TARGET/.wannabuild/outputs/discovery/feasibility.md"
  printf 'alternatives\n' >"$TARGET/.wannabuild/outputs/discovery/alternatives-competition.md"
  printf 'forecast\n' >"$TARGET/.wannabuild/outputs/discovery/failure-forecast.md"
  printf 'questions\n' >"$TARGET/.wannabuild/outputs/discovery/followup-questions.md"
  python3 - "$TARGET/.wannabuild/state.json" <<'PY'
import json, sys

p = sys.argv[1]
d = json.load(open(p))
d["discovery"] = {
    "interview": {"status": "complete"},
    "research": {
        "feasibility": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/feasibility.md"},
        "alternatives_competition": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/alternatives-competition.md"},
        "failure_forecast": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/failure-forecast.md"},
    },
    "followup_questions": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/followup-questions.md"},
    "synthesis": {"status": "complete", "artifact": ".wannabuild/spec/requirements.md"},
}
open(p, "w").write(json.dumps(d, indent=2) + "\n")
PY
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -eq 0 ]
}

@test "phase_flow: tasks phase validates with requirements.md and design.md" {
  make_state_json "$TARGET" tasks
  write_spec "$TARGET" requirements.md
  write_spec "$TARGET" design.md
  run_script validate-wannabuild-artifacts.sh "$TARGET" tasks
  [ "$status" -eq 0 ]
}

@test "phase_flow: implement phase validates with requirements.md and tasks.md" {
  make_state_json "$TARGET" implement
  write_spec "$TARGET" requirements.md
  write_spec "$TARGET" tasks.md
  write_checkpoint "$TARGET" T-001 1
  run_script validate-wannabuild-artifacts.sh "$TARGET" implement
  [ "$status" -eq 0 ]
}

@test "phase_flow: invalid mutation makes validate fail non-zero" {
  make_state_json "$TARGET" implement
  # Mutate to invalid state by removing a required field.
  python3 - "$TARGET/.wannabuild/state.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d.pop("artifacts", None)
open(p, "w").write(json.dumps(d, indent=2))
PY
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing required key: artifacts"* ]]
}

@test "phase_flow: state.json is merge-updated across set-stage calls (history grows)" {
  run_script wannabuild-session.sh init "$TARGET"
  [ "$status" -eq 0 ]

  # Capture the started_at timestamp from the initial state — it must persist
  # across subsequent stage transitions (the merge-update invariant).
  started_before="$(python3 -c '
import json,sys
print(json.load(open(sys.argv[1]))["started_at"])
' "$TARGET/.wannabuild/state.json")"
  [ -n "$started_before" ]

  run_script wannabuild-session.sh set-stage "$TARGET" plan in_progress
  [ "$status" -eq 0 ]
  run_script wannabuild-session.sh set-stage "$TARGET" implement in_progress
  [ "$status" -eq 0 ]
  run_script wannabuild-session.sh set-stage "$TARGET" review in_progress
  [ "$status" -eq 0 ]

  started_after="$(python3 -c '
import json,sys
print(json.load(open(sys.argv[1]))["started_at"])
' "$TARGET/.wannabuild/state.json")"
  [ "$started_before" = "$started_after" ]

  # public_stage_history should contain all four stages: discover (init),
  # plan, implement, review.
  hist_count="$(python3 -c '
import json,sys
print(len(json.load(open(sys.argv[1]))["public_stage_history"]))
' "$TARGET/.wannabuild/state.json")"
  [ "$hist_count" -ge 4 ]
}
