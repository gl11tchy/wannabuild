#!/usr/bin/env bash
# lint.sh — run the full read-only quality suite for WannaBuild.
#
# Continues on individual failures so the user sees every issue in one pass,
# then exits non-zero if any check failed.

set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}" || exit 1

declare -a results=()
overall=0

run_check() {
  local label="$1"
  shift
  echo
  echo "==> ${label}"
  if "$@"; then
    results+=("PASS  ${label}")
  else
    overall=1
    results+=("FAIL  ${label}")
  fi
}

skip_check() {
  local label="$1" reason="$2"
  echo
  echo "==> ${label}: SKIPPED (${reason})"
  results+=("SKIP  ${label} (${reason})")
}

have() { command -v "$1" >/dev/null 2>&1; }

# 1. shellcheck
if have shellcheck; then
  run_check "shellcheck scripts/*.sh" \
    bash -c 'shellcheck --severity=warning scripts/*.sh'
else
  skip_check "shellcheck scripts/*.sh" "shellcheck not installed"
fi

# 2. shfmt -d (diff)
if have shfmt; then
  run_check "shfmt -d scripts/*.sh" \
    bash -c 'shfmt -i 2 -ci -bn -d scripts/*.sh'
else
  skip_check "shfmt -d scripts/*.sh" "shfmt not installed"
fi

# 3. markdownlint-cli2
if have markdownlint-cli2; then
  run_check "markdownlint-cli2" \
    markdownlint-cli2
elif have npx; then
  run_check "markdownlint-cli2 (via npx)" \
    npx --yes markdownlint-cli2@0.13
else
  skip_check "markdownlint-cli2" "markdownlint-cli2 / npx not installed"
fi

# 4. jscpd (duplicate code)
if have jscpd; then
  run_check "jscpd" jscpd .
elif have npx; then
  run_check "jscpd (via npx)" \
    npx --yes jscpd@4 .
else
  skip_check "jscpd" "jscpd / npx not installed"
fi

# 5. complexity
if have lizard; then
  run_check "scripts/check-complexity.sh" \
    bash scripts/check-complexity.sh
else
  skip_check "scripts/check-complexity.sh" "lizard not installed"
fi

# 6. large files
run_check "scripts/check-large-files.sh" \
  bash scripts/check-large-files.sh

# 7. dead refs
run_check "scripts/check-dead-refs.sh" \
  bash scripts/check-dead-refs.sh

# 8. tech debt
run_check "scripts/check-tech-debt.sh" \
  bash scripts/check-tech-debt.sh

echo
echo "================ lint summary ================"
printf '  %s\n' "${results[@]}"
echo "=============================================="

exit "${overall}"
