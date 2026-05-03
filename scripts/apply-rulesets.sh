#!/usr/bin/env bash
# apply-rulesets.sh — apply WannaBuild's GitHub branch/tag rulesets.
#
# Iterates every JSON file under .github/rulesets/ and ensures a matching
# ruleset exists on the target repository (created or updated as needed).
#
# Requires: gh CLI authenticated as a user with admin rights on the target repo.
#
# Usage:
#   scripts/apply-rulesets.sh [--dry-run] [--owner OWNER] [--repo REPO]
#
# Defaults:
#   --owner gl11tchy
#   --repo  wannabuild
#
# Examples:
#   scripts/apply-rulesets.sh --dry-run
#   scripts/apply-rulesets.sh --owner gl11tchy --repo wannabuild

set -euo pipefail

OWNER="gl11tchy"
REPO="wannabuild"
DRY_RUN=0

print_help() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --owner)
      OWNER="${2:-}"
      if [[ -z "$OWNER" ]]; then
        echo "ERROR: --owner requires a value" >&2
        exit 2
      fi
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      if [[ -z "$REPO" ]]; then
        echo "ERROR: --repo requires a value" >&2
        exit 2
      fi
      shift 2
      ;;
    -h | --help)
      print_help
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      echo "Try: $0 --help" >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RULESETS_DIR="${REPO_ROOT}/.github/rulesets"

if [[ ! -d "${RULESETS_DIR}" ]]; then
  echo "ERROR: rulesets directory not found: ${RULESETS_DIR}" >&2
  exit 1
fi

shopt -s nullglob
RULESET_FILES=("${RULESETS_DIR}"/*.json)
shopt -u nullglob

if [[ ${#RULESET_FILES[@]} -eq 0 ]]; then
  echo "No ruleset JSON files found under ${RULESETS_DIR}; nothing to do." >&2
  exit 0
fi

if [[ "${DRY_RUN}" -eq 0 ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh CLI not found in PATH. Install from https://cli.github.com/" >&2
    exit 1
  fi
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found in PATH. Install from https://jqlang.github.io/jq/ (brew install jq)." >&2
  echo "       jq is required to strip non-schema _comment_* keys before sending payloads to GitHub." >&2
  exit 1
fi

# Strip any "_comment_*" keys (top-level) from a ruleset JSON before POST/PATCH.
# Writes the cleaned payload to a temp file and prints its path on stdout.
strip_comment_keys() {
  local in_file="$1"
  local out_file
  out_file="$(mktemp -t wb-ruleset.XXXXXX)"
  jq 'with_entries(select(.key | startswith("_comment") | not))' "${in_file}" >"${out_file}"
  printf '%s' "${out_file}"
}

API_LIST_PATH="repos/${OWNER}/${REPO}/rulesets"

echo "Target repository: ${OWNER}/${REPO}"
echo "Ruleset files:     ${#RULESET_FILES[@]}"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "Mode:              DRY RUN (no API calls)"
else
  echo "Mode:              APPLY"
fi
echo

EXISTING_JSON=""
if [[ "${DRY_RUN}" -eq 0 ]]; then
  if ! EXISTING_JSON="$(gh api "${API_LIST_PATH}" 2>/dev/null)"; then
    echo "WARNING: failed to list existing rulesets; will attempt creation only." >&2
    EXISTING_JSON="[]"
  fi
fi

CLEANED_FILES=()
cleanup_cleaned() {
  for f in "${CLEANED_FILES[@]}"; do
    [[ -n "${f}" && -f "${f}" ]] && rm -f "${f}"
  done
}
trap cleanup_cleaned EXIT

for ruleset_file in "${RULESET_FILES[@]}"; do
  name="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["name"])' "${ruleset_file}")"
  echo "----- ${name} (${ruleset_file##*/}) -----"

  cleaned_file="$(strip_comment_keys "${ruleset_file}")"
  CLEANED_FILES+=("${cleaned_file}")

  existing_id=""
  if [[ "${DRY_RUN}" -eq 0 && -n "${EXISTING_JSON}" ]]; then
    existing_id="$(printf '%s' "${EXISTING_JSON}" \
      | python3 -c 'import json,sys
data=json.load(sys.stdin)
target=sys.argv[1]
for rs in data:
    if rs.get("name")==target:
        print(rs.get("id",""))
        break' "${name}")"
  fi

  if [[ -n "${existing_id}" ]]; then
    method="PATCH"
    api_path="repos/${OWNER}/${REPO}/rulesets/${existing_id}"
    action="update existing ruleset id=${existing_id}"
  else
    method="POST"
    api_path="${API_LIST_PATH}"
    action="create new ruleset"
  fi

  echo "  -> ${action}"
  echo "  -> gh api -X ${method} ${api_path} --input ${cleaned_file}"
  echo "  -> payload (sanitized, _comment_* stripped):"
  sed 's/^/       /' "${cleaned_file}"

  if [[ "${DRY_RUN}" -eq 0 ]]; then
    if gh api -X "${method}" "${api_path}" --input "${cleaned_file}" >/dev/null; then
      echo "  -> OK"
    else
      echo "  -> FAILED" >&2
      exit 1
    fi
  fi
  echo
done

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "Dry run complete. No changes were made."
else
  echo "All rulesets applied successfully."
fi
