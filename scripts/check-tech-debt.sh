#!/usr/bin/env bash
# check-tech-debt.sh — enforce that every TODO/FIXME/XXX/HACK marker is
# attributable to a person or a tracking issue.
#
# Accepted forms:
#   TODO(name): ...
#   TODO(@name): ...
#   FIXME(#123): ...
#   FIXME(ISSUE-123): ...
#   FIXME(WB-12): ...
# Bare `TODO:` / `FIXME ` / `XXX` / `HACK` will fail the check.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) not installed" >&2
  exit 127
fi

# Match any of the markers as standalone words.
marker_regex='\b(TODO|FIXME|XXX|HACK)\b'

# An "attributed" marker has the form MARKER(...) where ... is non-empty.
attributed_regex='\b(TODO|FIXME|XXX|HACK)\(([^)]+)\)'

# Files we don't audit (this script and the style guide deliberately mention
# the markers as part of their documentation).
ignore_globs=(
  -g '!scripts/check-tech-debt.sh'
  -g '!docs/style-guide.md'
  -g '!CHANGELOG.md'
  -g '!.pre-commit-config.yaml'
  -g '!.wannabuild/**'
  -g '!.worktrees/**'
  -g '!.git/**'
  -g '!.factory/**'
  -g '!node_modules/**'
  -g '!docs/generated/**'
)

unreferenced=()
total=0
attributed=0

while IFS= read -r hit; do
  [[ -z "${hit}" ]] && continue
  total=$((total + 1))
  if grep -Eq "${attributed_regex}" <<<"${hit}"; then
    attributed=$((attributed + 1))
  else
    unreferenced+=("${hit}")
  fi
done < <(
  rg --no-heading --line-number \
    "${ignore_globs[@]}" \
    "${marker_regex}" \
    . 2>/dev/null || true
)

echo "check-tech-debt: ${total} marker(s) total, ${attributed} attributed."

if ((${#unreferenced[@]} > 0)); then
  echo "check-tech-debt: ${#unreferenced[@]} unreferenced marker(s):" >&2
  printf '  %s\n' "${unreferenced[@]}" >&2
  echo "  -> attribute each with TODO(name) or TODO(#NN)/TODO(ISSUE-NN)." >&2
  exit 1
fi

echo "check-tech-debt: OK"
