#!/usr/bin/env bash
# check-large-files.sh — flag oversized tracked files.
#
# Rules:
#   - Any tracked file > 500 KB fails.
#   - Any *.sh or *.md > 800 lines fails, EXCEPT skills/build/SKILL.md which
#     CLAUDE.md documents as "deliberately the largest file" (orchestrator
#     spec). It is currently 633 lines; we exempt it with a soft cap of 700
#     lines so unbounded growth still trips the check.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

BYTES_MAX=$((500 * 1024))
LINES_MAX=800

# See header rationale: skills/build/SKILL.md is intentionally the largest
# file in the repo (orchestrator spec). Soft cap protects against drift.
EXEMPT_PATH="skills/build/SKILL.md"
EXEMPT_LINES_MAX=700

byte_size() {
  if stat -f%z "$1" >/dev/null 2>&1; then
    stat -f%z "$1"
  else
    stat -c%s "$1"
  fi
}

violations=0
report=""

while IFS= read -r file; do
  [[ -f "${file}" ]] || continue

  size_bytes="$(byte_size "${file}")"
  if (( size_bytes > BYTES_MAX )); then
    report+=$'\n'"  too-large (>${BYTES_MAX}B): ${file} (${size_bytes} bytes)"
    violations=$((violations + 1))
  fi

  case "${file}" in
    *.sh|*.md)
      lines="$(wc -l <"${file}" | tr -d ' ')"
      if [[ "${file}" == "${EXEMPT_PATH}" ]]; then
        if (( lines > EXEMPT_LINES_MAX )); then
          report+=$'\n'"  exempt-cap-exceeded (>${EXEMPT_LINES_MAX} lines): ${file} (${lines} lines)"
          violations=$((violations + 1))
        fi
      else
        if (( lines > LINES_MAX )); then
          report+=$'\n'"  too-long (>${LINES_MAX} lines): ${file} (${lines} lines)"
          violations=$((violations + 1))
        fi
      fi
      ;;
  esac
done < <(git ls-files)

if (( violations > 0 )); then
  echo "check-large-files: ${violations} violation(s)${report}" >&2
  exit 1
fi

echo "check-large-files: OK (no tracked file exceeds ${BYTES_MAX}B or ${LINES_MAX} lines)"
