#!/usr/bin/env bash
# check-large-files.sh — flag oversized tracked files.
#
# Rules:
#   - Any tracked file > 500 KB fails.
#   - Any *.sh or *.md > 800 lines fails, with narrow soft caps for known
#     generated/contract surfaces that are intentionally larger.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

BYTES_MAX=$((500 * 1024))
LINES_MAX=800

# See header rationale: soft caps protect intentionally large files from
# unbounded growth while keeping the default line budget strict.
EXEMPT_PATH="skills/internal/build/SKILL.md"
EXEMPT_LINES_MAX=700
GENERATED_SCRIPTS_PATH="docs/generated/scripts.md"
GENERATED_SCRIPTS_LINES_MAX=1100

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
  if ((size_bytes > BYTES_MAX)); then
    report+=$'\n'"  too-large (>${BYTES_MAX}B): ${file} (${size_bytes} bytes)"
    violations=$((violations + 1))
  fi

  case "${file}" in
    *.sh | *.md)
      lines="$(wc -l <"${file}" | tr -d ' ')"
      if [[ "${file}" == "${EXEMPT_PATH}" ]]; then
        if ((lines > EXEMPT_LINES_MAX)); then
          report+=$'\n'"  exempt-cap-exceeded (>${EXEMPT_LINES_MAX} lines): ${file} (${lines} lines)"
          violations=$((violations + 1))
        fi
      elif [[ "${file}" == "${GENERATED_SCRIPTS_PATH}" ]]; then
        if ((lines > GENERATED_SCRIPTS_LINES_MAX)); then
          report+=$'\n'"  exempt-cap-exceeded (>${GENERATED_SCRIPTS_LINES_MAX} lines): ${file} (${lines} lines)"
          violations=$((violations + 1))
        fi
      else
        if ((lines > LINES_MAX)); then
          report+=$'\n'"  too-long (>${LINES_MAX} lines): ${file} (${lines} lines)"
          violations=$((violations + 1))
        fi
      fi
      ;;
  esac
done < <(git -c "safe.directory=${REPO_ROOT}" ls-files)

if ((violations > 0)); then
  echo "check-large-files: ${violations} violation(s)${report}" >&2
  exit 1
fi

echo "check-large-files: OK (no tracked file exceeds ${BYTES_MAX}B or configured line caps)"
