#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

TOOLBOX_SKILLS=(
  "wb-build"
  "wb-debug"
  "wb-discover"
  "wb-plan"
  "wb-qa"
  "wb-review"
  "wb-ship"
)

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

check_contains() {
  local path="$1"
  local needle="$2"
  local label="${3:-$path contains $needle}"
  if [[ -f "$ROOT/$path" ]] && grep -Fq "$needle" "$ROOT/$path"; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s\n' "$label"
    return 1
  fi
}

check_not_contains() {
  local path="$1"
  local needle="$2"
  local label="${3:-$path does not contain $needle}"
  if [[ -f "$ROOT/$path" ]] && ! grep -Fq "$needle" "$ROOT/$path"; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s\n' "$label"
    return 1
  fi
}

check_command() {
  local label="$1"
  shift
  local output
  if output="$("$@" 2>&1)"; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s\n' "$label"
    printf '%s\n' "$output"
    return 1
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
check_file "skills/build/references/advisor-escalation.md" || status=1
check_file "skills/wannabuild/SKILL.md" || status=1
check_file "skills/using-wannabuild/SKILL.md" || status=1
check_file "skills/research/SKILL.md" || status=1
check_file "commands/wannabuild.md" || status=1
check_file "commands/using-wannabuild.md" || status=1
check_file "scripts/validate-wannabuild-artifacts.sh" || status=1
check_file "scripts/validate-wannabuild-dry-runs.sh" || status=1
check_file "scripts/wannabuild-doctor.sh" || status=1
check_file "scripts/install-codex-skill.sh" || status=1
check_file "scripts/install-claude-skill.sh" || status=1
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
check_file ".factory/droids/wb-advisor.md" || status=1
check_file ".claude-plugin/plugin.json" || status=1
check_file ".claude-plugin/marketplace.json" || status=1
echo
echo "Toolbox surfaces"
check_dir "skills" || status=1
check_dir "commands" || status=1
for skill in "${TOOLBOX_SKILLS[@]}"; do
  check_file "skills/${skill}/SKILL.md" || status=1
  check_file "commands/${skill}.md" || status=1
  check_contains "skills/${skill}/SKILL.md" "Toolbox Bootstrap" "Toolbox skill ${skill} defines bootstrap behavior" || status=1
  check_contains "commands/${skill}.md" "Use the \`${skill}\` skill" "Toolbox command /${skill} routes to skill" || status=1
  check_contains ".codex/INSTALL.md" "${skill}" "Codex manual install includes ${skill}" || status=1
  check_contains "README.md" "/${skill}" "README docs expose /${skill}" || status=1
done
check_contains ".codex/INSTALL.md" "toolbox work" "Codex install docs mention toolbox work" || status=1
echo
echo "Quality & governance surfaces"
check_file ".pre-commit-config.yaml" || status=1
check_file ".markdownlint-cli2.jsonc" || status=1
check_file ".jscpd.json" || status=1
check_file ".shellcheckrc" || status=1
check_file ".editorconfig" || status=1
check_file ".gitleaks.toml" || status=1
check_file ".secrets.baseline" || status=1
check_file ".gitattributes" || status=1
check_file ".env.example" || status=1
check_file "renovate.json" || status=1
check_file "SECURITY.md" || status=1
check_file "CHANGELOG.md" || status=1
check_file "release-please-config.json" || status=1
check_file ".release-please-manifest.json" || status=1
check_file ".github/CODEOWNERS" || status=1
check_file ".github/dependabot.yml" || status=1
check_file ".github/pull_request_template.md" || status=1
check_file ".github/workflows/ci.yml" || status=1
check_file ".github/workflows/security.yml" || status=1
check_file ".github/workflows/release-please.yml" || status=1
check_file ".github/rulesets/main.json" || status=1
check_file ".devcontainer/devcontainer.json" || status=1
check_file "scripts/lint.sh" || status=1
check_file "scripts/format.sh" || status=1
check_file "scripts/check-complexity.sh" || status=1
check_file "scripts/check-large-files.sh" || status=1
check_file "scripts/check-dead-refs.sh" || status=1
check_file "scripts/check-tech-debt.sh" || status=1
check_file "scripts/check-secrets.sh" || status=1
check_file "scripts/wb-log.sh" || status=1
check_file "scripts/wb-metrics.sh" || status=1
check_file "scripts/wb-trace.sh" || status=1
check_file "scripts/scrub-log.sh" || status=1
check_file "scripts/apply-rulesets.sh" || status=1
check_file "scripts/generate-docs.sh" || status=1
check_file "tests/run.sh" || status=1
check_file "tests/test_helper.bash" || status=1
check_dir "tests/unit" || status=1
check_dir "tests/integration" || status=1
echo
echo "Host docs"
check_file "docs/codex-getting-started.md" || status=1
check_file "docs/claude-code-getting-started.md" || status=1
check_file "docs/host-capability-matrix.md" || status=1
check_file "docs/golden-path-demo/README.md" || status=1
check_file ".cursor/rules/wannabuild.mdc" || status=1
check_file ".codex/INSTALL.md" || status=1
check_file ".claude/INSTALL.md" || status=1
echo
echo "Schemas"
check_file "skills/build/schemas/state.schema.json" || status=1
check_file "skills/build/schemas/loop-state.schema.json" || status=1
check_file "skills/build/schemas/review-verdict.schema.json" || status=1
check_file "skills/build/schemas/checkpoint.schema.json" || status=1
check_file "skills/build/schemas/config.schema.json" || status=1
check_file "skills/build/schemas/workspace.schema.json" || status=1
echo
echo "Daily-use trust harness"
check_file "skills/build/dry-runs/daily-use-trust-scenarios.json" || status=1
check_file "skills/build/dry-runs/no-task-invocation.json" || status=1
check_file "skills/build/dry-runs/workspace-bootstrap-state.json" || status=1
check_file "skills/build/dry-runs/workspace-bootstrap-workspace.json" || status=1
check_file "skills/build/dry-runs/review-failure-loop.json" || status=1
check_file "skills/build/dry-runs/qa-failure-remediation-loop.json" || status=1
check_file "skills/build/dry-runs/summary-complete-state.json" || status=1
echo
echo "Host-native invocation surfaces"
check_contains "commands/wannabuild.md" "/wannabuild" "Claude command exposes /wannabuild" || status=1
check_not_contains "commands/wannabuild.md" "[WB-START]" "Claude command leaves start banner to skill" || status=1
check_not_contains "commands/wannabuild.md" "[WB-RESUME]" "Claude command leaves resume banner to skill" || status=1
check_not_contains "commands/wannabuild.md" "Respond with exactly" "Claude command does not force direct visible response" || status=1
check_contains "commands/using-wannabuild.md" "/using-wannabuild" "Claude command exposes /using-wannabuild" || status=1
check_contains "docs/codex-getting-started.md" "\$wannabuild" "Codex docs expose \$wannabuild" || status=1
check_contains "docs/codex-getting-started.md" "\$using-wannabuild" "Codex docs expose \$using-wannabuild" || status=1
check_contains "docs/claude-code-getting-started.md" "/wannabuild" "Claude docs expose /wannabuild" || status=1
check_contains "docs/claude-code-getting-started.md" "/using-wannabuild" "Claude docs expose /using-wannabuild" || status=1
echo
echo "Golden path validation"
check_command "golden path artifacts validate" "$ROOT/scripts/validate-wannabuild-artifacts.sh" "$ROOT/docs/golden-path-demo" document || status=1
check_command "golden path summary gate passes" "$ROOT/scripts/wannabuild-gate-check.sh" "$ROOT/docs/golden-path-demo" summary || status=1
check_command "daily-use dry runs pass" "$ROOT/scripts/validate-wannabuild-dry-runs.sh" "$ROOT" || status=1
echo
echo "Codex install"
check_link_target "${HOME}/.codex/skills/wannabuild" "$ROOT/skills/wannabuild"
check_link_target "${HOME}/.codex/skills/using-wannabuild" "$ROOT/skills/using-wannabuild"
for skill in "${TOOLBOX_SKILLS[@]}"; do
  check_link_target "${HOME}/.codex/skills/${skill}" "$ROOT/skills/${skill}"
done
echo
echo "Claude install"
check_link_target "${HOME}/.claude/plugins/cache/gl11tchy/wannabuild/local" "$ROOT"
if [[ -f "${HOME}/.claude/plugins/installed_plugins.json" ]]; then
  printf 'PASS  %s\n' "${HOME}/.claude/plugins/installed_plugins.json"
else
  printf 'WARN  %s (not found)\n' "${HOME}/.claude/plugins/installed_plugins.json"
fi
if [[ -f "${HOME}/.claude/settings.json" ]]; then
  printf 'PASS  %s\n' "${HOME}/.claude/settings.json"
else
  printf 'WARN  %s (not found)\n' "${HOME}/.claude/settings.json"
fi
echo
if [[ $status -eq 0 ]]; then
  echo "Repo surfaces ready:"
  echo "- Codex + Claude co-primary repo usage is documented"
  echo "- Codex skill install surface exists"
  echo "- Claude install surface exists"
echo "- Optional implementation worktree surface exists"
  echo "- Daily-use trust dry runs pass"
  echo "- Golden path demo validates"
  echo "- Cursor rule surface exists"
  echo "- Claude adapter docs and install surfaces exist"
  echo
  echo "Next:"
  echo "- Run ./scripts/install-codex-skill.sh"
  echo "- Run ./scripts/install-claude-skill.sh"
  echo "- Restart Codex and invoke \$wannabuild"
  echo "- Reload Claude plugins and invoke /wannabuild"
  echo "- In Cursor, load .cursor/rules/wannabuild.mdc"
  exit 0
fi

echo "One or more required surfaces are missing."
exit 1
