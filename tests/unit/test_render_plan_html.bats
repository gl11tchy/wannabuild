#!/usr/bin/env bats
# Unit tests for scripts/wb-render-plan-html.sh (Plan-phase adversarial HTML renderer).

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup() {
  RENDER="$SCRIPTS_DIR/wb-render-plan-html.sh"
  OUT="$BATS_TEST_TMPDIR/out.html"
}

@test "renders one section per plan and marks the recommended plan" {
  CI=1 run bash "$RENDER" --input "$FIXTURES_DIR/plan-options.json" --out "$OUT"
  [ "$status" -eq 0 ]
  assert_file_exists "$OUT"
  run grep -c '<section class="card' "$OUT"
  [ "$output" -eq 3 ]
  assert_file_contains "$OUT" "Recommended"
}

@test "every plan carries an adversarial critique section" {
  CI=1 run bash "$RENDER" --input "$FIXTURES_DIR/plan-options.json" --out "$OUT"
  [ "$status" -eq 0 ]
  run grep -c 'Critique of the others' "$OUT"
  [ "$output" -eq 3 ]
}

@test "output is self-contained: no external network references" {
  CI=1 run bash "$RENDER" --input "$FIXTURES_DIR/plan-options.json" --out "$OUT"
  [ "$status" -eq 0 ]
  run grep -Eic 'https?://|src=|@import|<link|fonts\.' "$OUT"
  [ "$output" -eq 0 ]
}

@test "html-escapes special characters (no injection)" {
  CI=1 run bash "$RENDER" --input "$FIXTURES_DIR/plan-options-escape.json" --out "$OUT"
  [ "$status" -eq 0 ]
  refute_file_contains "$OUT" "<script>alert"
  assert_file_contains "$OUT" "&lt;script&gt;"
  assert_file_contains "$OUT" "&amp;"
}

@test "--count caps and clamps to [2,5]; unset renders every configured plan" {
  sections() {
    CI=1 bash "$RENDER" --input "$FIXTURES_DIR/plan-options-5.json" --out "$OUT" "$@" >/dev/null 2>&1 || return 1
    grep -c '<section class="card' "$OUT"
  }
  [ "$(sections --count 2)" -eq 2 ]
  [ "$(sections --count 4)" -eq 4 ]
  [ "$(sections --count 99)" -eq 5 ]
  [ "$(sections --count 0)" -eq 2 ]
  [ "$(sections)" -eq 5 ]
}

@test "unset count never truncates: a 3-plan artifact renders 3 sections" {
  CI=1 run bash "$RENDER" --input "$FIXTURES_DIR/plan-options.json" --out "$OUT"
  [ "$status" -eq 0 ]
  run grep -c '<section class="card' "$OUT"
  [ "$output" -eq 3 ]
}

@test "headless/CI prints absolute path + file URL and exits 0" {
  CI=1 run bash "$RENDER" --input "$FIXTURES_DIR/plan-options.json" --out "$OUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$OUT"* ]]
  [[ "$output" == *"file://"* ]]
}

@test "--no-open prints the path instead of opening, exits 0" {
  run env -u CI bash "$RENDER" --input "$FIXTURES_DIR/plan-options.json" --out "$OUT" --no-open
  [ "$status" -eq 0 ]
  [[ "$output" == *"file://"* ]]
}

@test "a failing browser opener is non-blocking (exit 0, path printed)" {
  bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\nexit 1\n' >"$bin/open"
  chmod +x "$bin/open"
  PATH="$bin:$PATH" run env -u CI bash "$RENDER" --input "$FIXTURES_DIR/plan-options.json" --out "$OUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"file://"* ]]
}

@test "marks the chosen plan when chosen_id is set" {
  CI=1 run bash "$RENDER" --input "$FIXTURES_DIR/plan-options-chosen.json" --out "$OUT"
  [ "$status" -eq 0 ]
  assert_file_contains "$OUT" "Chosen"
  assert_file_contains "$OUT" "Recommended"
}

@test "missing --input is a usage error (exit 2)" {
  run bash "$RENDER" --out "$OUT"
  [ "$status" -eq 2 ]
}
