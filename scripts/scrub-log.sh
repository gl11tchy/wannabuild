#!/usr/bin/env bash
# scrub-log.sh — standalone CLI that runs wb-log.sh's redaction over stdin or files.
#
# Examples:
#   cat raw-log.txt | scripts/scrub-log.sh > clean-log.txt
#   scripts/scrub-log.sh path/to/file.log
#   scripts/scrub-log.sh --in-place path/to/file.log
#   scripts/scrub-log.sh --dry-run path/to/file.log

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wb-log.sh
. "$SCRIPT_DIR/wb-log.sh"

print_help() {
  cat <<'EOF'
scrub-log.sh — redact secret-looking patterns from log text.

Usage:
  scrub-log.sh [options] [file ...]

Reads from stdin if no files are given. Writes scrubbed output to stdout
unless --in-place is set.

Options:
  --in-place    Rewrite each file in place (a .bak backup is made first).
  --dry-run     Print a unified diff of what would change. Does not modify files.
  -h, --help    Show this message.

Exit codes:
  0   success
  1   IO error
  2   bad arguments
EOF
}

IN_PLACE=0
DRY_RUN=0
FILES=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help)
      print_help
      exit 0
      ;;
    --in-place)
      IN_PLACE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        FILES+=("$1")
        shift
      done
      ;;
    -*)
      printf 'scrub-log.sh: unknown option: %s\n' "$1" >&2
      print_help >&2
      exit 2
      ;;
    *)
      FILES+=("$1")
      shift
      ;;
  esac
done

if [ "$IN_PLACE" -eq 1 ] && [ "$DRY_RUN" -eq 1 ]; then
  printf 'scrub-log.sh: --in-place and --dry-run are mutually exclusive.\n' >&2
  exit 2
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  if [ "$IN_PLACE" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
    printf 'scrub-log.sh: --in-place/--dry-run require file arguments.\n' >&2
    exit 2
  fi
  wb_log_scrub
  exit $?
fi

rc=0
for f in "${FILES[@]}"; do
  if [ ! -r "$f" ]; then
    printf 'scrub-log.sh: cannot read %s\n' "$f" >&2
    rc=1
    continue
  fi
  if [ "$IN_PLACE" -eq 1 ]; then
    cp -- "$f" "$f.bak" || {
      rc=1
      continue
    }
    if ! wb_log_scrub <"$f.bak" >"$f"; then
      rc=1
    fi
  elif [ "$DRY_RUN" -eq 1 ]; then
    tmp=$(mktemp -t scrublog.XXXXXX) || {
      rc=1
      continue
    }
    wb_log_scrub <"$f" >"$tmp"
    diff -u -- "$f" "$tmp" || true
    rm -f -- "$tmp"
  else
    wb_log_scrub <"$f" || rc=1
  fi
done

exit "$rc"
