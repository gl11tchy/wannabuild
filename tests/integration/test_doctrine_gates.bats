#!/usr/bin/env bats
#
# Dogfood proof that the doctrine gates fail closed and pass only on real evidence:
# discovery requires acceptance criteria, review requires the full reviewer set,
# QA requires real test execution, and a blocker requires a logged acquisition attempt.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup_file() {
  cargo build --quiet --manifest-path "$REPO_ROOT/Cargo.toml" --bin wb-runtime
  export WB_RUNTIME_BIN="$REPO_ROOT/target/debug/wb-runtime"
}

setup() {
  TARGET="$(setup_tmpdir)/proj"
  make_target_repo "$TARGET" >/dev/null
}

seed_discovery() {
  # $1 = requirements.md body
  write_spec "$TARGET" requirements.md "$1"
  mkdir -p "$TARGET/.wannabuild/outputs/discovery"
  printf 'feasible\n' >"$TARGET/.wannabuild/outputs/discovery/feasibility.md"
  printf 'alternatives\n' >"$TARGET/.wannabuild/outputs/discovery/alternatives-competition.md"
  printf 'forecast\n' >"$TARGET/.wannabuild/outputs/discovery/failure-forecast.md"
  printf 'questions\n' >"$TARGET/.wannabuild/outputs/discovery/followup-questions.md"
  python3 - "$TARGET/.wannabuild/state.json" <<'PY'
import json, sys
from pathlib import Path

p = Path(sys.argv[1])
s = json.loads(p.read_text()) if p.exists() else {}
s["discovery"] = {
    "interview": {"status": "complete"},
    "research": {
        "feasibility": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/feasibility.md"},
        "alternatives_competition": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/alternatives-competition.md"},
        "failure_forecast": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/failure-forecast.md"},
    },
    "followup_questions": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/followup-questions.md"},
    "synthesis": {"status": "complete", "artifact": ".wannabuild/spec/requirements.md"},
}
p.write_text(json.dumps(s, indent=2) + "\n")
PY
}

@test "doctrine: discovery blocks without acceptance criteria, passes with them" {
  seed_discovery "# Requirements\n\nA vision with no measurable criteria.\n"
  run "$WB_RUNTIME_BIN" assert-discovery-ready --project "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Acceptance Criteria"* ]]

  seed_discovery "# Requirements\n\n## Acceptance Criteria\n\n- The feature works end to end\n"
  run "$WB_RUNTIME_BIN" assert-discovery-ready --project "$TARGET"
  [ "$status" -eq 0 ]
}

@test "doctrine: review blocks an impacted-only subset and requires the full set" {
  mkdir -p "$TARGET/.wannabuild/review"
  for agent in wb-security-reviewer wb-integration-tester; do
    cat >"$TARGET/.wannabuild/review/${agent}-iter-1.json" <<JSON
{"agent":"${agent}","status":"PASS","summary":"ok","issues":[]}
JSON
  done
  run "$WB_RUNTIME_BIN" assert-review-ready --project "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"wb-performance-reviewer"* ]]
}

@test "doctrine: QA blocks an integration PASS that executed zero tests" {
  mkdir -p "$TARGET/.wannabuild/outputs" "$TARGET/.wannabuild/review"
  printf '# QA\n\nstatus: PASS\nacceptance_coverage: covered\nintegration_coverage: covered\n' \
    >"$TARGET/.wannabuild/outputs/qa-summary.md"
  cat >"$TARGET/.wannabuild/review/wb-integration-tester-iter-1.json" <<'JSON'
{"agent":"wb-integration-tester","status":"PASS","summary":"ok","issues":[],"hard_gate":true,"test_execution":{"total":0,"passed":0,"failed":0,"errored":0,"duration_ms":0},"coverage_map":[{"criterion":"login","status":"covered"}]}
JSON
  run "$WB_RUNTIME_BIN" assert-qa-ready --project "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"executed 0 tests"* ]]
}

@test "doctrine: acquisition gate rejects a blocked state with no attempt log, accepts it with one" {
  python3 - "$TARGET/.wannabuild/state.json" <<'PY'
import json, sys
from pathlib import Path

p = Path(sys.argv[1])
s = json.loads(p.read_text()) if p.exists() else {}
s["phase_status"] = "blocked"
s["workflow_status"] = "in_progress"
p.write_text(json.dumps(s, indent=2) + "\n")
PY
  run "$WB_RUNTIME_BIN" assert-acquisition-attempted --project "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no logged acquisition attempts"* ]]

  mkdir -p "$TARGET/.wannabuild/outputs"
  printf '[{"need":"postgres","tools_tried":["supabase create_branch"],"result":"asked user"}]\n' \
    >"$TARGET/.wannabuild/outputs/acquisition-log.json"
  run "$WB_RUNTIME_BIN" assert-acquisition-attempted --project "$TARGET"
  [ "$status" -eq 0 ]
}
