#!/usr/bin/env bash
#
# record-demo-cast.sh — regenerate the forgery-rejection demo cast and GIF.
# Idempotent (precedent: scripts/generate-docs.sh). Records the standalone demo
# non-interactively — asciinema's --command spawns it in its own pty, so the
# demo's colors and pacing render even with no controlling terminal — then
# renders the committed GIF the README embeds.
#
#   scripts/record-demo-cast.sh
#
# The .cast (JSON source of truth) and .gif (artifact) are both committed; do not
# gate CI on GIF byte-equality — timestamps differ run to run. The meaningful
# diff is the .cast.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

MEDIA_DIR="docs/media"
CAST="${MEDIA_DIR}/forgery-rejection.cast"
GIF="${MEDIA_DIR}/forgery-rejection.gif"
DEMO="scripts/demo-forgery-rejection.sh"
COLS=92
ROWS=30

missing=0
for tool in asciinema agg; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "record-demo-cast: '${tool}' not found on PATH." >&2
    missing=1
  fi
done
if [ "${missing}" -ne 0 ]; then
  echo "Install the recording tools, then re-run:" >&2
  echo "  brew install asciinema agg      # macOS" >&2
  echo "  cargo install agg               # agg from source on any platform" >&2
  exit 2
fi

WB_RUNTIME_BIN="${WB_RUNTIME_BIN:-${REPO_ROOT}/target/debug/wb-runtime}"
if [ ! -x "${WB_RUNTIME_BIN}" ]; then
  echo "record-demo-cast: building wb-runtime (${WB_RUNTIME_BIN} absent)..." >&2
  cargo build -p wb-runtime
fi
export WB_RUNTIME_BIN

mkdir -p "${MEDIA_DIR}"

echo "Recording ${CAST} (${COLS}x${ROWS})..."
# --return: asciinema exits with the demo's status, so a failed forgery-rejection
# (the demo's own integrity check) fails this script instead of shipping a stale
# GIF.
asciinema record \
  --overwrite \
  --headless \
  --window-size "${COLS}x${ROWS}" \
  --idle-time-limit 2 \
  --return \
  --command "bash ${DEMO}" \
  "${CAST}"

echo "Rendering ${GIF}..."
agg --speed 1.4 --theme monokai "${CAST}" "${GIF}"

echo "Done:"
echo "  ${CAST}"
echo "  ${GIF}"
