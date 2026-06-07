#!/usr/bin/env bash
# validate-contracts.sh — fail closed on weak WannaBuild prompt contracts.

set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACT_MARKER="Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions."
COMMAND_MARKER="Contracts live in the owning skill"

fail_count=0
check_count=0

fail() {
  printf 'FAIL  %s\n' "$1"
  fail_count=$((fail_count + 1))
}

pass() {
  check_count=$((check_count + 1))
}

require_file() {
  local rel="$1"
  if [[ -f "$ROOT/$rel" ]]; then
    pass
  else
    fail "$rel missing"
  fi
}

require_contains() {
  local rel="$1"
  local needle="$2"
  local label="$3"
  if [[ -f "$ROOT/$rel" ]] && grep -Fq "$needle" "$ROOT/$rel"; then
    pass
  else
    fail "$label"
  fi
}

require_same_file() {
  local left="$1"
  local right="$2"
  local label="$3"
  if [[ -f "$ROOT/$left" && -f "$ROOT/$right" ]] && cmp -s "$ROOT/$left" "$ROOT/$right"; then
    pass
  else
    fail "$label"
  fi
}

check_prompt_contract() {
  local rel="$1"
  require_contains "$rel" "## Contract Standard" "$rel missing Contract Standard section"
  require_contains "$rel" "$CONTRACT_MARKER" "$rel missing shared contract marker"
}

require_file "docs/contract-standard.md"
require_contains "docs/contract-standard.md" "$CONTRACT_MARKER" "docs/contract-standard.md missing canonical marker"

while IFS= read -r path; do
  rel="${path#"$ROOT/"}"
  check_prompt_contract "$rel"
done < <(find "$ROOT/skills" -path '*/SKILL.md' -type f | LC_ALL=C sort)

while IFS= read -r path; do
  rel="${path#"$ROOT/"}"
  check_prompt_contract "$rel"
done < <(find "$ROOT/agents" -maxdepth 1 -name '*.md' -type f | LC_ALL=C sort)

# Canonical commands/ was removed (Claude Code is skills-only); commands now live only in the
# Factory adapter. Validate that each Factory command forwards to its owning skill.
while IFS= read -r path; do
  rel="${path#"$ROOT/"}"
  require_contains "$rel" "$COMMAND_MARKER" "$rel missing command contract handoff marker"
done < <(find "$ROOT/adapters/factory/commands" -maxdepth 1 -name '*.md' -type f | LC_ALL=C sort)

while IFS= read -r path; do
  skill="$(basename "$(dirname "$path")")"
  require_same_file "skills/$skill/SKILL.md" "adapters/factory/skills/$skill/SKILL.md" "Factory skill mirror drift: $skill"
done < <(find "$ROOT/adapters/factory/skills" -path '*/SKILL.md' -type f | LC_ALL=C sort)

require_contains "docs/generated/skills.md" "Contract standard: docs/contract-standard.md" "docs/generated/skills.md missing contract standard reference"
require_contains "docs/generated/agents.md" "Contract standard: docs/contract-standard.md" "docs/generated/agents.md missing contract standard reference"
require_contains "docs/generated/index.md" "Contract standard" "docs/generated/index.md missing contract standard reference"

if [[ "$fail_count" -eq 0 ]]; then
  printf 'Contract validation OK: %d checks\n' "$check_count"
  exit 0
fi

printf 'Contract validation failed: %d failure(s), %d passing checks\n' "$fail_count" "$check_count"
exit 1
