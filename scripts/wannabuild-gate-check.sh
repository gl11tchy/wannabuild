#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/wannabuild-gate-check.sh <project_root> <gate>

Gates:
  review   - require review verdict JSON files including integration tester
  qa       - require qa-summary artifact
  summary  - require review and qa gates to be satisfied
USAGE
}

if [[ $# -ne 2 ]]; then
  usage >&2
  exit 1
fi

project_root="$(cd "$1" && pwd)"
gate="$2"

review_dir="$project_root/.wannabuild/review"
qa_summary="$project_root/.wannabuild/outputs/qa-summary.md"
loop_state="$project_root/.wannabuild/loop-state.json"

check_review() {
  [[ -d "$review_dir" ]] || { echo "Missing review directory: $review_dir" >&2; return 1; }
  compgen -G "$review_dir/*.json" >/dev/null || { echo "No review verdict files found in $review_dir" >&2; return 1; }
  python3 - "$review_dir" "$loop_state" <<'PY'
import json
from pathlib import Path
import sys

review_dir = Path(sys.argv[1])
loop_state_path = Path(sys.argv[2])
files = sorted(review_dir.glob("*.json"))
if not files:
    raise SystemExit("No review verdict files found")

required = {
    "wb-security-reviewer",
    "wb-performance-reviewer",
    "wb-architecture-reviewer",
    "wb-testing-reviewer",
    "wb-integration-tester",
    "wb-code-simplifier",
}
if loop_state_path.exists():
    try:
        loop = json.loads(loop_state_path.read_text(encoding="utf-8"))
        iterations = loop.get("iterations")
        if isinstance(iterations, list) and iterations:
            latest = max(iterations, key=lambda item: item.get("iteration", 0))
            active = latest.get("active_reviewers")
            if isinstance(active, list) and active:
                required = {item for item in active if isinstance(item, str)}
    except Exception:
        pass

seen = set()
failures = []

for path in files:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"Invalid review verdict JSON: {path} ({exc})")

    agent = payload.get("agent")
    status = payload.get("status")
    if isinstance(agent, str):
        seen.add(agent)
    if status != "PASS":
        failures.append(f"{path.name}:{agent}:{status}")

missing = sorted(required - seen)
if missing:
    raise SystemExit("Missing required review verdicts: " + ", ".join(missing))
if failures:
    raise SystemExit("Non-passing review verdicts: " + ", ".join(failures))
PY
}

check_qa() {
  [[ -f "$qa_summary" ]] || { echo "Missing QA summary: $qa_summary" >&2; return 1; }
}

case "$gate" in
  review)
    check_review
    ;;
  qa)
    check_qa
    ;;
  summary)
    check_review
    check_qa
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

echo "Gate OK: $gate"
