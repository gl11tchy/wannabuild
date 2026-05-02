#!/usr/bin/env bash
# format.sh — apply canonical formatting to shell scripts and markdown.
#
# Tools used:
#   - shfmt    : shell formatter (indent=2, case-indent, binary-next-line)
#   - prettier : markdown / json / yaml formatter
#
# This script writes changes in place. Use `scripts/lint.sh` for read-only
# verification.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

have() { command -v "$1" >/dev/null 2>&1; }

status=0

if have shfmt; then
  echo "==> shfmt scripts/*.sh"
  shfmt -i 2 -ci -bn -w scripts/*.sh
else
  echo "==> shfmt not installed; skipping shell formatting" >&2
  status=1
fi

if have prettier; then
  echo "==> prettier (markdown, json, yaml)"
  prettier --write \
    "**/*.md" \
    "**/*.json" \
    "**/*.jsonc" \
    "**/*.yml" \
    "**/*.yaml"
elif have npx; then
  echo "==> prettier via npx"
  npx --yes prettier@3 --write \
    "**/*.md" \
    "**/*.json" \
    "**/*.jsonc" \
    "**/*.yml" \
    "**/*.yaml"
else
  echo "==> prettier / npx not installed; skipping markdown formatting" >&2
  status=1
fi

exit "${status}"
