#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${HOME}/.codex/skills"

mkdir -p "$TARGET"

installed=()

install_repo_skill() {
  local name="$1"
  ln -sfn "$ROOT/skills/$name" "$TARGET/$name"
  installed+=("$TARGET/$name")
}

install_repo_skill "wannabuild"
install_repo_skill "using-wannabuild"

if [[ -d "$ROOT/skills" ]]; then
  while IFS= read -r skill_file; do
    install_repo_skill "$(basename "$(dirname "$skill_file")")"
  done < <(find "$ROOT/skills" -mindepth 2 -maxdepth 2 -type f -path '*/wb-*/SKILL.md' | LC_ALL=C sort)
fi

echo "Installed Codex skills:"
for path in "${installed[@]}"; do
  echo "- $path"
done
echo
echo "Restart Codex, then invoke:"
echo "  \$wannabuild"
