#!/usr/bin/env bash
# tests/run.sh — run the WannaBuild Bats test suite.
#
# Usage:
#   bash tests/run.sh                 # run all tests
#   bash tests/run.sh --unit          # only tests/unit/
#   bash tests/run.sh --integration   # only tests/integration/
#   bash tests/run.sh --help
#
# Environment variables (also configurable via tests/bats.conf):
#   BATS_JOBS               Parallel jobs to run (default: 4).
#   BATS_OUTPUT_DIR         Where junit XML is written (default: tests/results).
#
# If `bats` is not on PATH, this script clones bats-core and the standard
# bats-support / bats-assert / bats-file libs into tests/.bats and uses them
# only for the duration of the run. No system-wide install is performed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="${REPO_ROOT}/tests"
RESULTS_DIR="${BATS_OUTPUT_DIR:-${TESTS_DIR}/results}"
JOBS="${BATS_JOBS:-4}"
SCOPE="all"

# shellcheck disable=SC1091
[[ -f "${TESTS_DIR}/bats.conf" ]] && source "${TESTS_DIR}/bats.conf"

print_help() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --unit)        SCOPE=unit; shift ;;
    --integration) SCOPE=integration; shift ;;
    -h|--help)     print_help; exit 0 ;;
    *)             echo "Unknown argument: $1" >&2; print_help >&2; exit 1 ;;
  esac
done

mkdir -p "$RESULTS_DIR"

# 1. Locate / install bats.
ensure_bats() {
  if command -v bats >/dev/null 2>&1; then
    echo "Using system bats: $(command -v bats)"
    return 0
  fi
  local bats_dir="${TESTS_DIR}/.bats"
  if [[ ! -x "${bats_dir}/bin/bats" ]]; then
    echo "bats not found; installing into ${bats_dir} (no system changes)..."
    rm -rf "$bats_dir"
    git clone --depth 1 https://github.com/bats-core/bats-core.git "$bats_dir" >/dev/null 2>&1 || {
      echo "ERROR: failed to clone bats-core. Install bats manually (brew install bats-core or npm i -g bats)." >&2
      return 2
    }
  fi
  export PATH="${bats_dir}/bin:${PATH}"
  echo "Using bundled bats: ${bats_dir}/bin/bats"
}

ensure_bats_libs() {
  # Optional support libraries. We don't depend on them but install for
  # convenience so test files can opt-in via `load`.
  local libs_dir="${TESTS_DIR}/.bats-libs"
  mkdir -p "$libs_dir"
  for lib in bats-support bats-assert bats-file; do
    if [[ ! -d "${libs_dir}/${lib}" ]]; then
      git clone --depth 1 "https://github.com/bats-core/${lib}.git" "${libs_dir}/${lib}" >/dev/null 2>&1 || \
        echo "WARN: failed to clone ${lib} (non-fatal)"
    fi
  done
}

ensure_bats || exit $?
ensure_bats_libs || true

# 2. Determine which directories to run.
declare -a TARGETS
case "$SCOPE" in
  unit)        TARGETS=("${TESTS_DIR}/unit") ;;
  integration) TARGETS=("${TESTS_DIR}/integration") ;;
  all)         TARGETS=("${TESTS_DIR}/unit" "${TESTS_DIR}/integration") ;;
esac

# Skip empty target dirs (e.g. if user only wrote one half of the suite).
declare -a REAL_TARGETS
for t in "${TARGETS[@]}"; do
  if compgen -G "${t}/*.bats" >/dev/null; then
    REAL_TARGETS+=("$t")
  fi
done
if [[ ${#REAL_TARGETS[@]} -eq 0 ]]; then
  echo "No .bats files found for scope '$SCOPE'."
  exit 0
fi

# 3. Run bats.
JUNIT_FILE="${RESULTS_DIR}/junit.xml"

# bats only parallelises when GNU `parallel` is on PATH. Fall back gracefully
# so the suite runs everywhere; warn so the user knows why it's serial.
JOB_FLAGS=()
if [[ "$JOBS" -gt 1 ]] && command -v parallel >/dev/null 2>&1; then
  JOB_FLAGS+=("--jobs" "$JOBS")
elif [[ "$JOBS" -gt 1 ]]; then
  echo "NOTE: GNU 'parallel' not on PATH; running tests serially. Install it (e.g. brew install parallel) for BATS_JOBS=$JOBS."
fi

if [[ ${#JOB_FLAGS[@]} -gt 0 ]]; then
  echo "Running bats (${JOB_FLAGS[*]}) against: ${REAL_TARGETS[*]}"
else
  echo "Running bats (serial) against: ${REAL_TARGETS[*]}"
fi
echo "JUnit XML output -> ${JUNIT_FILE}"

set +e
if [[ ${#JOB_FLAGS[@]} -gt 0 ]]; then
  bats "${JOB_FLAGS[@]}" --timing \
       --report-formatter junit \
       --output "$RESULTS_DIR" \
       "${REAL_TARGETS[@]}"
else
  bats --timing \
       --report-formatter junit \
       --output "$RESULTS_DIR" \
       "${REAL_TARGETS[@]}"
fi
exit_code=$?
set -e

# 4. Timing summary (parsed from junit XML when available). Bats names the
#    file `report.xml` by default; we accept either name for forward-compat.
junit_path=""
for candidate in "$JUNIT_FILE" "${RESULTS_DIR}/report.xml"; do
  if [[ -f "$candidate" ]]; then junit_path="$candidate"; break; fi
done
if [[ -n "$junit_path" ]]; then
  echo
  echo "Timing summary (slowest 5):"
  python3 - "$junit_path" <<'PY'
import sys, xml.etree.ElementTree as ET
p = sys.argv[1]
try:
    root = ET.parse(p).getroot()
except Exception as e:
    print(f"  (could not parse junit: {e})")
    sys.exit(0)
cases = []
for tc in root.iter("testcase"):
    try:
        t = float(tc.get("time", "0"))
    except ValueError:
        t = 0.0
    cases.append((t, tc.get("classname", ""), tc.get("name", "")))
total = sum(t for t, _, _ in cases)
print(f"  total tests: {len(cases)}  total time: {total:.3f}s")
for t, cls, name in sorted(cases, reverse=True)[:5]:
    print(f"  {t:6.3f}s  {cls}::{name}")
PY
fi

exit "$exit_code"
