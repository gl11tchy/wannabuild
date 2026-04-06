#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${HOME}/.codex/skills"

mkdir -p "$TARGET"

ln -sfn "$ROOT/skills/wannabuild" "$TARGET/wannabuild"
ln -sfn "$ROOT/skills/using-wannabuild" "$TARGET/using-wannabuild"

echo "Installed Codex skills:"
echo "- $TARGET/wannabuild"
echo "- $TARGET/using-wannabuild"
echo
echo "Restart Codex, then invoke:"
echo "  \$wannabuild"
