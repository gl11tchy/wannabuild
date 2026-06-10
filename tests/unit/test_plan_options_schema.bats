#!/usr/bin/env bats
# Unit tests for the plan-options schema and its validator wiring
# (scripts/validate-wannabuild-artifacts.sh validate_plan_options).

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup() {
  VALIDATE="$SCRIPTS_DIR/validate-wannabuild-artifacts.sh"
  SCHEMA="$REPO_ROOT/skills/internal/build/schemas/plan-options.schema.json"
  TARGET="$(make_target_repo "$BATS_TEST_TMPDIR/proj")"
  make_state_json "$TARGET" design
  mkdir -p "$TARGET/.wannabuild/outputs/plan"
}

put() {
  cp "$FIXTURES_DIR/$1" "$TARGET/.wannabuild/outputs/plan/plan-options.json"
}

@test "schema declares plans 2..5 with a required critique_of_others" {
  run jq -e '.properties.plans.minItems==2 and .properties.plans.maxItems==5 and (.properties.plans.items.required | index("critique_of_others") != null)' "$SCHEMA"
  [ "$status" -eq 0 ]
}

@test "a valid plan-options.json passes the validator" {
  put plan-options.json
  run bash "$VALIDATE" "$TARGET"
  [ "$status" -eq 0 ]
}

@test "recommended_id not matching a plan id fails" {
  put plan-options-invalid-recommended.json
  run bash "$VALIDATE" "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"recommended_id"* ]]
}

@test "a plan missing critique_of_others fails" {
  put plan-options-invalid-critique.json
  run bash "$VALIDATE" "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"critique_of_others"* ]]
}

@test "fewer than two plans fails" {
  put plan-options-invalid-count.json
  run bash "$VALIDATE" "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"2-5 entries"* ]]
}

@test "an absent plan-options.json is accepted (optional artifact)" {
  run bash "$VALIDATE" "$TARGET"
  [ "$status" -eq 0 ]
}

@test "a valid chosen_id (matching a plan id) is accepted" {
  put plan-options-chosen.json
  run bash "$VALIDATE" "$TARGET"
  [ "$status" -eq 0 ]
}

@test "a chosen_id not matching any plan id fails" {
  put plan-options-invalid-chosen.json
  run bash "$VALIDATE" "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"chosen_id"* ]]
}

@test "a plan list with an empty or non-string item fails" {
  put plan-options-invalid-list-item.json
  run bash "$VALIDATE" "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be a non-empty string"* ]]
}

@test "AC5: no Claude-only placement of the feature in .claude-plugin/" {
  if [ -d "$REPO_ROOT/.claude-plugin" ]; then
    run grep -rq -e wb-plan-options -e wb-render-plan-html -e plan_adversarial "$REPO_ROOT/.claude-plugin"
    [ "$status" -ne 0 ]
  fi
}
