#!/usr/bin/env bash
set -euo pipefail

echo "[wannabuild devcontainer] post-create starting…"

# Install pre-commit hooks
if [[ -f .pre-commit-config.yaml ]]; then
  pre-commit install --install-hooks
fi

# Set up bats-libs locally
bash tests/run.sh --help >/dev/null 2>&1 || true

# Run doctor
bash scripts/wannabuild-doctor.sh || true

echo "[wannabuild devcontainer] post-create done."
