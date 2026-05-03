#!/usr/bin/env bash
# check-secrets.sh — run secret scanners against the working tree.
#
# Prefers gitleaks; falls back to detect-secrets. If neither is installed,
# prints clear install instructions. Exits 0 ("skipped") in that case unless
# --strict was passed, in which case it exits 1 so CI fails fast.
#
# Usage:
#   scripts/check-secrets.sh           # best-effort scan, never fails on missing tools
#   scripts/check-secrets.sh --strict  # fail if no scanner is installed

set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

print_help() {
  cat <<'EOF'
check-secrets.sh — run secret scanners against the working tree.

Usage:
  scripts/check-secrets.sh [--strict] [--help]

Options:
  --strict   Exit non-zero if neither gitleaks nor detect-secrets is installed.
  --help     Show this message.

Behavior:
  1. If `gitleaks` is available, runs:
       gitleaks detect --redact --no-banner --config .gitleaks.toml
  2. Otherwise, if `detect-secrets` is available, runs:
       detect-secrets scan --baseline .secrets.baseline
  3. Otherwise, prints install hints. Without --strict, exits 0.

Install hints:
  gitleaks:        https://github.com/gitleaks/gitleaks  (brew install gitleaks)
  detect-secrets:  https://github.com/Yelp/detect-secrets (pipx install detect-secrets)
EOF
}

STRICT=0
for arg in "$@"; do
  case "$arg" in
    -h | --help)
      print_help
      exit 0
      ;;
    --strict) STRICT=1 ;;
    *)
      printf 'check-secrets.sh: unknown argument: %s\n' "$arg" >&2
      print_help >&2
      exit 2
      ;;
  esac
done

cd "$REPO_ROOT" || exit 1

if command -v gitleaks >/dev/null 2>&1; then
  printf '[check-secrets] running gitleaks…\n' >&2
  gitleaks detect --redact --no-banner --config .gitleaks.toml
  exit $?
fi

if command -v detect-secrets >/dev/null 2>&1; then
  printf '[check-secrets] gitleaks not installed; falling back to detect-secrets…\n' >&2
  # `scan --baseline` updates the baseline in place if new secrets are found,
  # which we surface by diffing. Use `audit --report` semantics in CI for
  # stronger guarantees once a baseline is reviewed.
  detect-secrets scan --baseline .secrets.baseline
  exit $?
fi

printf '[check-secrets] WARNING: neither gitleaks nor detect-secrets is installed.\n' >&2
printf '  install one of:\n' >&2
printf '    gitleaks:       brew install gitleaks  (or see https://github.com/gitleaks/gitleaks)\n' >&2
printf '    detect-secrets: pipx install detect-secrets\n' >&2

if [ "$STRICT" -eq 1 ]; then
  printf '[check-secrets] --strict was set; failing.\n' >&2
  exit 1
fi

printf '[check-secrets] continuing without scan (skipped).\n' >&2
exit 0
