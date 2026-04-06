#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

check_file() {
  local path="$1"
  if [[ -f "$ROOT/$path" ]]; then
    printf 'PASS  %s\n' "$path"
  else
    printf 'FAIL  %s\n' "$path"
    return 1
  fi
}

check_dir() {
  local path="$1"
  if [[ -d "$ROOT/$path" ]]; then
    printf 'PASS  %s/\n' "$path"
  else
    printf 'FAIL  %s/\n' "$path"
    return 1
  fi
}

check_link_target() {
  local link_path="$1"
  local expected_prefix="$2"
  if [[ -L "$link_path" ]]; then
    local target
    target="$(readlink "$link_path" || true)"
    if [[ "$target" == "$expected_prefix"* ]]; then
      printf 'PASS  %s -> %s\n' "$link_path" "$target"
    else
      printf 'WARN  %s -> %s (unexpected target)\n' "$link_path" "${target:-unknown}"
    fi
  else
    printf 'WARN  %s (not installed)\n' "$link_path"
  fi
}

status=0

echo "WannaBuild Doctor"
echo "================="
echo
echo "Core surfaces"
check_file "README.md" || status=1
check_file "AGENTS.md" || status=1
check_file "skills/build/SKILL.md" || status=1
check_file "skills/wannabuild/SKILL.md" || status=1
check_file "skills/using-wannabuild/SKILL.md" || status=1
check_file "skills/research/SKILL.md" || status=1
check_file "commands/wannabuild.md" || status=1
check_file "commands/using-wannabuild.md" || status=1
check_file "scripts/validate-wannabuild-artifacts.sh" || status=1
check_file "scripts/wannabuild-doctor.sh" || status=1
check_file "scripts/install-codex-skill.sh" || status=1
check_file "scripts/wannabuild-workspace.sh" || status=1
check_file "scripts/wannabuild-session.sh" || status=1
check_file "scripts/wannabuild-gate-check.sh" || status=1
echo
echo "Adapters"
check_dir "adapters" || status=1
check_file "adapters/codex/README.md" || status=1
check_file "adapters/cursor/README.md" || status=1
check_file "adapters/claude-code/README.md" || status=1
check_file ".cursor-plugin/plugin.json" || status=1
echo
echo "Host docs"
check_file "docs/codex-getting-started.md" || status=1
check_file "docs/host-capability-matrix.md" || status=1
check_file ".cursor/rules/wannabuild.mdc" || status=1
check_file ".codex/INSTALL.md" || status=1
echo
echo "Codex install"
check_link_target "${HOME}/.codex/skills/wannabuild" "$ROOT/skills/wannabuild"
check_link_target "${HOME}/.codex/skills/using-wannabuild" "$ROOT/skills/using-wannabuild"
echo
if [[ $status -eq 0 ]]; then
  echo "Repo surfaces ready:"
  echo "- Codex-first repo usage is documented"
  echo "- Codex skill install surface exists"
  echo "- Mandatory workspace bootstrap surface exists"
  echo "- Cursor rule surface exists"
  echo "- Claude compatibility docs exist"
  echo
  echo "Next:"
  echo "- Run ./scripts/install-codex-skill.sh"
  echo "- Restart Codex and invoke \$wannabuild"
  echo "- In Cursor, load .cursor/rules/wannabuild.mdc"
  exit 0
fi

echo "One or more required surfaces are missing."
exit 1
