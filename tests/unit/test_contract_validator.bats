#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

_copy_repo() {
  local dest="$BATS_TEST_TMPDIR/repo-copy"
  mkdir -p "$dest"
  ( cd "$REPO_ROOT" && tar --exclude '.git' \
                              --exclude 'target' \
                              --exclude 'tests/results' \
                              -cf - . ) | \
    ( cd "$dest" && tar -xf - )
  printf '%s\n' "$dest"
}

@test "contract validator: passes for current repo" {
  run bash "$REPO_ROOT/scripts/validate-contracts.sh"
  if [[ "$status" -ne 0 ]]; then
    echo "$output" >&2
  fi
  [ "$status" -eq 0 ]
  [[ "$output" == *"Contract validation OK"* ]]
}

@test "contract validator: fails when a skill loses the shared marker" {
  copy="$(_copy_repo)"
  python3 - "$copy/skills/wb-build/SKILL.md" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
path.write_text(text.replace("Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.", "Shared contract removed."))
PY
  run bash "$copy/scripts/validate-contracts.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"skills/wb-build/SKILL.md missing shared contract marker"* ]]
}

@test "contract validator: fails when a Factory command stops handing off to the skill contract" {
  copy="$(_copy_repo)"
  python3 - "$copy/adapters/factory/commands/wb-build.md" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text(path.read_text().replace("Contracts live in the owning skill", "Contract handoff removed"))
PY
  run bash "$copy/scripts/validate-contracts.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"adapters/factory/commands/wb-build.md missing command contract handoff marker"* ]]
}
