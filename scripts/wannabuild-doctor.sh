#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Color the PASS/WARN/FAIL prefixes when stdout is a TTY. When output is
# captured (e.g., in tests via `run`, or in CI logs), these expand to empty
# strings so the substring assertions in test_doctor_script.bats keep
# matching the literal "PASS  README.md" / "FAIL  ..." / "WARN  ..." text.
if [[ -t 1 ]]; then
  COLOR_GREEN=$'\033[32m'
  COLOR_YELLOW=$'\033[33m'
  COLOR_RED=$'\033[31m'
  COLOR_BOLD=$'\033[1m'
  COLOR_RESET=$'\033[0m'
else
  COLOR_GREEN=""
  COLOR_YELLOW=""
  COLOR_RED=""
  COLOR_BOLD=""
  COLOR_RESET=""
fi

# Counts populated by the check_* helpers; printed in the final summary.
DOCTOR_PASS_COUNT=0
DOCTOR_WARN_COUNT=0
DOCTOR_FAIL_COUNT=0

TOOLBOX_SKILLS=(
  "wb-build"
  "wb-debug"
  "wb-discover"
  "wb-plan"
  "wb-qa"
  "wb-review"
  "wb-ship"
)

UI_SKILLS=(
  "wannabuild"
  "using-wannabuild"
  "${TOOLBOX_SKILLS[@]}"
)

skill_display_name() {
  case "$1" in
    wannabuild) printf 'WannaBuild: Full Loop\n' ;;
    using-wannabuild) printf 'WannaBuild: Guide\n' ;;
    wb-build) printf 'WannaBuild: Build\n' ;;
    wb-debug) printf 'WannaBuild: Debug\n' ;;
    wb-discover) printf 'WannaBuild: Discover\n' ;;
    wb-plan) printf 'WannaBuild: Plan\n' ;;
    wb-qa) printf 'WannaBuild: QA\n' ;;
    wb-review) printf 'WannaBuild: Review\n' ;;
    wb-ship) printf 'WannaBuild: Ship\n' ;;
    *) return 1 ;;
  esac
}

resolve_host_home() {
  if [[ -n "${WANNABUILD_HOST_HOME:-}" ]]; then
    printf '%s\n' "$WANNABUILD_HOST_HOME"
  elif [[ -n "${USERPROFILE:-}" && -d "${USERPROFILE:-}" ]]; then
    printf '%s\n' "$USERPROFILE"
  elif [[ "$ROOT" =~ ^/mnt/([A-Za-z])/Users/([^/]+)(/|$) ]]; then
    printf '/mnt/%s/Users/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  elif [[ "$ROOT" =~ ^/([A-Za-z])/Users/([^/]+)(/|$) ]]; then
    printf '/%s/Users/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  else
    printf '%s\n' "$HOME"
  fi
}

resolve_path() {
  local path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$path" 2>/dev/null && return 0
  fi
  python3 - "$path" <<'PY' 2>/dev/null
from pathlib import Path
import sys
print(Path(sys.argv[1]).resolve())
PY
}

_pass() {
  printf '%s%s%s\n' "$COLOR_GREEN" "$1" "$COLOR_RESET"
  DOCTOR_PASS_COUNT=$((DOCTOR_PASS_COUNT + 1))
}

_warn() {
  printf '%s%s%s\n' "$COLOR_YELLOW" "$1" "$COLOR_RESET"
  DOCTOR_WARN_COUNT=$((DOCTOR_WARN_COUNT + 1))
}

_fail() {
  printf '%s%s%s\n' "$COLOR_RED" "$1" "$COLOR_RESET"
  DOCTOR_FAIL_COUNT=$((DOCTOR_FAIL_COUNT + 1))
}

check_file() {
  local path="$1"
  if [[ -f "$ROOT/$path" ]]; then
    _pass "PASS  $path"
  else
    _fail "FAIL  $path"
    return 1
  fi
}

check_absent_file() {
  local path="$1"
  local label="${2:-$path absent}"
  if [[ -e "$ROOT/$path" || -L "$ROOT/$path" ]]; then
    _fail "FAIL  $label"
    return 1
  else
    _pass "PASS  $label"
  fi
}

check_dir() {
  local path="$1"
  if [[ -d "$ROOT/$path" ]]; then
    _pass "PASS  $path/"
  else
    _fail "FAIL  $path/"
    return 1
  fi
}

check_no_symlinks_under() {
  local path="$1"
  local label="$2"
  local found
  found="$(find "$ROOT/$path" -type l -print -quit 2>/dev/null || true)"
  if [[ -z "$found" ]]; then
    _pass "PASS  $label"
  else
    _fail "FAIL  $label: ${found#"$ROOT/"}"
    return 1
  fi
}

check_same_file() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [[ -f "$ROOT/$expected" && -f "$ROOT/$actual" ]] && cmp -s "$ROOT/$expected" "$ROOT/$actual"; then
    _pass "PASS  $label"
  else
    _fail "FAIL  $label"
    return 1
  fi
}

check_link_target() {
  local link_path="$1"
  local expected_path="$2"
  if [[ -e "$link_path" || -L "$link_path" ]]; then
    local resolved expected
    resolved="$(resolve_path "$link_path" || true)"
    expected="$(resolve_path "$expected_path" || true)"
    if [[ -n "$resolved" && -n "$expected" && "$resolved" == "$expected"* ]]; then
      _pass "PASS  $link_path -> $resolved"
    else
      _warn "WARN  $link_path -> ${resolved:-unknown} (unexpected target; expected $expected_path)"
    fi
  else
    _warn "WARN  $link_path (not installed)"
  fi
}

check_contains() {
  local path="$1"
  local needle="$2"
  local label="${3:-$path contains $needle}"
  if [[ -f "$ROOT/$path" ]] && grep -Fq "$needle" "$ROOT/$path"; then
    _pass "PASS  $label"
  else
    _fail "FAIL  $label"
    return 1
  fi
}

check_not_contains() {
  local path="$1"
  local needle="$2"
  local label="${3:-$path does not contain $needle}"
  if [[ -f "$ROOT/$path" ]] && ! grep -Fq "$needle" "$ROOT/$path"; then
    _pass "PASS  $label"
  else
    _fail "FAIL  $label"
    return 1
  fi
}

check_json_key() {
  local path="$1"
  local key="$2"
  local label="$3"
  if [[ -f "$path" ]] && grep -Fq "$key" "$path"; then
    _pass "PASS  $label"
  elif [[ -f "$path" ]]; then
    _warn "WARN  $path (missing $key)"
  else
    _warn "WARN  $path (not found)"
  fi
}

check_optional_user_file() {
  local path="$1"
  local label="$2"
  if [[ -f "$path" ]]; then
    _pass "PASS  $label"
  else
    _warn "WARN  $path (not installed)"
  fi
}

check_command() {
  local label="$1"
  shift
  local output
  if output="$("$@" 2>&1)"; then
    _pass "PASS  $label"
  else
    _fail "FAIL  $label"
    printf '%s\n' "$output"
    return 1
  fi
}

# Fail closed when a host is installed but its Rust gate binary is absent or
# not executable: silent fallback to the degraded Python mirror must be loud.
# Accepts the bare path and also probes a .exe sibling for Windows installs.
check_runtime_binary() {
  local path="$1"
  local label="$2"
  if [[ -x "$path" ]]; then
    _pass "PASS  $label -> $path"
  elif [[ -x "${path}.exe" ]]; then
    _pass "PASS  $label -> ${path}.exe"
  elif [[ -e "$path" || -e "${path}.exe" ]]; then
    _fail "FAIL  $label: present but not executable ($path)"
    return 1
  else
    _fail "FAIL  $label: missing ($path); host would fall back to Python mirror"
    return 1
  fi
}

status=0
HOST_HOME="$(resolve_host_home)"
CODEX_BASE="${CODEX_HOME:-${HOST_HOME}/.codex}"
CODEX_SKILLS_DIR="${CODEX_SKILLS_DIR:-${CODEX_BASE}/skills}"
CODEX_RUNTIME_DIR="${CODEX_RUNTIME_DIR:-${CODEX_BASE}/bin}"
CLAUDE_HOME_DIR="${CLAUDE_HOME:-${HOST_HOME}/.claude}"
FACTORY_HOME_DIR="${FACTORY_HOME:-${HOST_HOME}/.factory}"
# Mirror install-factory-plugin.sh's marketplace/cache derivation so the
# runtime path below carries the same <marketplace> segment the Factory hook
# resolves against (parents[1]/target/debug/wb-runtime).
FACTORY_MARKETPLACE_NAME="${FACTORY_MARKETPLACE:-wannabuild}"
FACTORY_PLUGIN_CACHE="${FACTORY_HOME_DIR}/plugins/cache/${FACTORY_MARKETPLACE_NAME}/wannabuild/local"

echo "WannaBuild Doctor"
echo "================="
echo
echo "Core surfaces"
check_file "README.md" || status=1
check_file "AGENTS.md" || status=1
check_file "skills/internal/build/SKILL.md" || status=1
check_file "skills/internal/build/references/advisor-escalation.md" || status=1
check_file "skills/internal/build/references/ship-phase.md" || status=1
check_absent_file "skills/ship/SKILL.md" "legacy ship skill must stay out of top-level Claude-discoverable skills" || status=1
check_absent_file "skills/build/SKILL.md" "internal orchestrator must not be at top of skills/ (must live under skills/internal/)" || status=1
check_absent_file "skills/requirements/SKILL.md" "internal phase must not be at top of skills/" || status=1
check_absent_file "skills/design/SKILL.md" "internal phase must not be at top of skills/" || status=1
check_absent_file "skills/tasks/SKILL.md" "internal phase must not be at top of skills/" || status=1
check_absent_file "skills/implement/SKILL.md" "internal phase must not be at top of skills/" || status=1
check_absent_file "skills/review/SKILL.md" "internal phase must not be at top of skills/" || status=1
check_absent_file "skills/document/SKILL.md" "internal phase must not be at top of skills/" || status=1
check_absent_file "skills/research/SKILL.md" "internal phase must not be at top of skills/" || status=1
check_file "skills/wannabuild/SKILL.md" || status=1
check_file "skills/using-wannabuild/SKILL.md" || status=1
check_file "skills/internal/research/SKILL.md" || status=1
check_file "adapters/factory/commands/wannabuild.md" || status=1
check_file "adapters/factory/commands/using-wannabuild.md" || status=1
check_file "hooks/hooks.json" || status=1
check_file "hooks/wannabuild-route.py" || status=1
check_file "scripts/validate-wannabuild-artifacts.sh" || status=1
check_file "scripts/validate-wannabuild-dry-runs.sh" || status=1
check_file "scripts/wannabuild-doctor.sh" || status=1
check_file "scripts/install-codex-skill.sh" || status=1
check_file "scripts/install-claude-skill.sh" || status=1
check_file "scripts/install-factory-plugin.sh" || status=1
check_file "scripts/wannabuild-workspace.sh" || status=1
check_file "scripts/wannabuild-session.sh" || status=1
check_file "scripts/wannabuild-gate-check.sh" || status=1
check_file "Cargo.toml" || status=1
check_file "crates/wb-runtime/Cargo.toml" || status=1
check_file "crates/wb-runtime/src/main.rs" || status=1
check_file "crates/wb-runtime/src/lib.rs" || status=1

# Stale installed-binary guard. An installed wb-runtime that predates the
# evidence gate lacks `record-test-evidence` and silently accepts forged
# integration verdicts. Warn (not fail) so a returning user rebuilds; a fresh
# checkout that never installed the binary has nothing to flag here. Probe the
# Codex install dir (the exact RUNTIME_TARGET install-codex-skill.sh writes to)
# and PATH, deduplicated so the same file is not probed twice. Factory and
# Claude ship the Python hook mirror, not a binary, so there is no path there.
seen_runtimes=""
for runtime_bin in \
  "$(command -v wb-runtime 2>/dev/null || true)" \
  "${CODEX_RUNTIME_DIR:-${CODEX_BASE}/bin}/wb-runtime"; do
  [ -n "$runtime_bin" ] && [ -x "$runtime_bin" ] || continue
  resolved="$(resolve_path "$runtime_bin" || printf '%s' "$runtime_bin")"
  case " $seen_runtimes " in *" $resolved "*) continue ;; esac
  seen_runtimes="$seen_runtimes $resolved"
  if "$runtime_bin" record-test-evidence --help >/dev/null 2>&1; then
    _pass "PASS  installed wb-runtime supports evidence gate: $runtime_bin"
  else
    _warn "WARN  installed wb-runtime is STALE (no record-test-evidence) and will not enforce integration evidence: $runtime_bin — rebuild with scripts/install-codex-skill.sh"
  fi
done
check_contains "hooks/wannabuild-route.py" "WannaBuild runtime state is active" "Claude hook injects active workflow runtime state" || status=1
check_contains "hooks/wannabuild-route.py" "FORBIDDEN: do not implement or edit code" "Claude hook enforces implementation-before-plan guard" || status=1
check_contains "scripts/wannabuild-session.sh" "assert-plan-ready" "Session helper exposes hard planning gate" || status=1
check_contains "scripts/wannabuild-session.sh" "Runtime unavailable: wb-runtime is required to run" "Session helper fails closed when runtime is unavailable" || status=1
check_contains "scripts/install-codex-skill.sh" "cargo build --quiet --manifest-path" "Codex installer builds wb-runtime" || status=1
check_contains "scripts/install-codex-skill.sh" "Installed Codex runtime" "Codex installer reports runtime install" || status=1
check_contains "skills/wb-build/SKILL.md" "assert-plan-ready" "wb-build requires hard planning gate before editing" || status=1
check_contains "skills/wb-ship/SKILL.md" "check CI status after the delivery action" "wb-ship checks CI after PR or push delivery" || status=1
check_contains "skills/wb-ship/SKILL.md" "scripts/wannabuild-gate-check.sh <project_root> summary" "wb-ship runs runtime summary gate before final summary" || status=1
echo
echo "Adapters"
check_dir "adapters" || status=1
check_file "adapters/codex/README.md" || status=1
check_file "adapters/cursor/README.md" || status=1
check_file "adapters/claude-code/README.md" || status=1
check_dir "adapters/factory" || status=1
check_file ".cursor-plugin/plugin.json" || status=1
check_file ".factory/droids/wb-advisor.md" || status=1
check_file ".factory-plugin/marketplace.json" || status=1
check_file "adapters/factory/.factory-plugin/plugin.json" || status=1
check_no_symlinks_under "adapters/factory" "Factory adapter is self-contained (no symlinks)" || status=1
check_file "adapters/factory/hooks/hooks.json" || status=1
check_file "adapters/factory/hooks/wannabuild-route.py" || status=1
check_same_file "hooks/hooks.json" "adapters/factory/hooks/hooks.json" "Factory adapter hooks manifest mirrors canonical hooks manifest" || status=1
check_same_file "hooks/wannabuild-route.py" "adapters/factory/hooks/wannabuild-route.py" "Factory adapter hook router mirrors canonical hook router" || status=1
for skill in "${UI_SKILLS[@]}"; do
  check_file "adapters/factory/commands/${skill}.md" || status=1
  check_contains "adapters/factory/commands/${skill}.md" "Contracts live in the owning skill" "Factory command /${skill} forwards to its skill" || status=1
done
check_file ".claude-plugin/plugin.json" || status=1
check_file ".claude-plugin/marketplace.json" || status=1
echo
echo "Phase skill surfaces"
check_dir "skills" || status=1
check_dir "adapters/factory/commands" || status=1
for skill in "${UI_SKILLS[@]}"; do
  display_name="$(skill_display_name "${skill}")"
  check_file "skills/${skill}/agents/openai.yaml" || status=1
  check_contains "skills/${skill}/agents/openai.yaml" "display_name: \"${display_name}\"" "Skill UI metadata exposes ${display_name}" || status=1
  check_file "adapters/factory/skills/${skill}/SKILL.md" || status=1
  check_same_file "skills/${skill}/SKILL.md" "adapters/factory/skills/${skill}/SKILL.md" "Factory adapter skill ${skill} mirrors canonical skill" || status=1
done
for skill in "${TOOLBOX_SKILLS[@]}"; do
  check_file "skills/${skill}/SKILL.md" || status=1
  check_file "adapters/factory/commands/${skill}.md" || status=1
  check_contains "skills/${skill}/SKILL.md" "Phase Bootstrap" "Phase skill ${skill} defines bootstrap behavior" || status=1
  check_contains "adapters/factory/commands/${skill}.md" "Use the \`${skill}\` skill" "Phase command /${skill} routes to skill" || status=1
  check_contains ".codex/INSTALL.md" "${skill}" "Codex manual install includes ${skill}" || status=1
  check_contains "README.md" "/${skill}" "README docs expose /${skill}" || status=1
done
check_contains "skills/wb-review/SKILL.md" "current checkout changes as the review target by default" "wb-review defaults to current checkout changes when target is omitted" || status=1
check_contains ".codex/INSTALL.md" "phase entrypoints" "Codex install docs mention phase entrypoints" || status=1
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
check_file "scripts/validate-contracts.sh" || status=1
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
check_file "skills/internal/build/schemas/state.schema.json" || status=1
check_file "skills/internal/build/schemas/loop-state.schema.json" || status=1
check_file "skills/internal/build/schemas/review-verdict.schema.json" || status=1
check_file "skills/internal/build/schemas/checkpoint.schema.json" || status=1
check_file "skills/internal/build/schemas/config.schema.json" || status=1
check_file "skills/internal/build/schemas/workspace.schema.json" || status=1
echo
echo "Daily-use trust harness"
check_file "skills/internal/build/dry-runs/daily-use-trust-scenarios.json" || status=1
check_file "skills/internal/build/dry-runs/no-task-invocation.json" || status=1
check_file "skills/internal/build/dry-runs/workspace-bootstrap-state.json" || status=1
check_file "skills/internal/build/dry-runs/workspace-bootstrap-workspace.json" || status=1
check_file "skills/internal/build/dry-runs/review-failure-loop.json" || status=1
check_file "skills/internal/build/dry-runs/qa-failure-remediation-loop.json" || status=1
check_file "skills/internal/build/dry-runs/summary-complete-state.json" || status=1
echo
echo "Host-native invocation surfaces"
check_contains "AGENTS.md" "Do not tell the user to invoke a slash command" "Operator contract prevents command-first handoff" || status=1
check_contains "skills/wannabuild/SKILL.md" "Select the skill and begin the appropriate workflow" "WannaBuild skill starts matching workflows directly" || status=1
check_contains "adapters/factory/commands/using-wannabuild.md" "Commands are optional shortcuts, not the normal path" "Intro command preserves skill-first positioning" || status=1
check_contains "adapters/factory/commands/wannabuild.md" "/wannabuild" "Claude command exposes /wannabuild" || status=1
check_contains ".claude-plugin/plugin.json" "\"hooks\": {" "Claude plugin declares hooks inline" || status=1
check_contains ".claude-plugin/plugin.json" "\"SessionStart\"" "Claude plugin inline hooks include SessionStart" || status=1
check_contains ".claude-plugin/plugin.json" "\"UserPromptSubmit\"" "Claude plugin inline hooks include UserPromptSubmit" || status=1
check_not_contains ".claude-plugin/marketplace.json" "\"hooks\":" "Claude marketplace omits stray hooks field (a path string here crashes /plugin with v?.reduce is not a function)" || status=1
check_contains ".factory-plugin/marketplace.json" "\"source\": \"./adapters/factory\"" "Factory marketplace routes to Factory adapter" || status=1
check_contains "adapters/factory/.factory-plugin/plugin.json" "\"hooks\": \"./hooks/hooks.json\"" "Factory plugin declares hooks manifest" || status=1
check_contains "hooks/hooks.json" "\"hooks\": {" "Claude hooks file is wrapped under a top-level hooks key (loader requires record shape)" || status=1
check_contains "hooks/hooks.json" "SessionStart" "Claude hooks include SessionStart autoroute context" || status=1
check_contains "hooks/hooks.json" "UserPromptSubmit" "Claude hooks include UserPromptSubmit autorouter" || status=1
check_contains "hooks/wannabuild-route.py" "WannaBuild automatic routing is active" "Claude autorouter injects session routing context" || status=1
check_contains "hooks/wannabuild-route.py" "Do not ask the user to type" "Claude autorouter discourages command handoff" || status=1
check_not_contains "adapters/factory/commands/wannabuild.md" "[WB-START]" "Claude command avoids start banner output" || status=1
check_not_contains "adapters/factory/commands/wannabuild.md" "[WB-RESUME]" "Claude command avoids resume banner output" || status=1
check_not_contains "adapters/factory/commands/wannabuild.md" "Respond with exactly" "Claude command does not force direct visible response" || status=1
check_contains "adapters/factory/commands/using-wannabuild.md" "/using-wannabuild" "Claude command exposes /using-wannabuild" || status=1
check_contains "docs/codex-getting-started.md" "\$wannabuild" "Codex docs expose \$wannabuild" || status=1
check_contains "docs/codex-getting-started.md" "\$using-wannabuild" "Codex docs expose \$using-wannabuild" || status=1
check_contains "docs/claude-code-getting-started.md" "/wannabuild" "Claude docs expose /wannabuild" || status=1
check_contains "docs/claude-code-getting-started.md" "/using-wannabuild" "Claude docs expose /using-wannabuild" || status=1
echo
echo "Golden path validation"
check_command "golden path artifacts validate" "$ROOT/scripts/validate-wannabuild-artifacts.sh" "$ROOT/docs/golden-path-demo" document || status=1
check_command "golden path summary gate passes (fixture evidence mode)" env WB_EVIDENCE_MODE=fixture "$ROOT/scripts/wannabuild-gate-check.sh" "$ROOT/docs/golden-path-demo" summary || status=1
check_command "daily-use dry runs pass" "$ROOT/scripts/validate-wannabuild-dry-runs.sh" "$ROOT" || status=1
check_command "contract prompts validate" bash "$ROOT/scripts/validate-contracts.sh" || status=1
echo
echo "Codex install"
echo "Target: ${CODEX_SKILLS_DIR}"
check_link_target "${CODEX_SKILLS_DIR}/wannabuild" "$ROOT/skills/wannabuild"
check_link_target "${CODEX_SKILLS_DIR}/using-wannabuild" "$ROOT/skills/using-wannabuild"
for skill in "${TOOLBOX_SKILLS[@]}"; do
  check_link_target "${CODEX_SKILLS_DIR}/${skill}" "$ROOT/skills/${skill}"
done
echo
echo "Claude install"
echo "Target: ${CLAUDE_HOME_DIR}"
check_link_target "${CLAUDE_HOME_DIR}/plugins/cache/gl11tchy/wannabuild/local" "$ROOT"
check_json_key "${CLAUDE_HOME_DIR}/plugins/installed_plugins.json" "wannabuild@gl11tchy" "Claude installed_plugins.json enables wannabuild@gl11tchy"
check_json_key "${CLAUDE_HOME_DIR}/settings.json" "wannabuild@gl11tchy" "Claude settings.json enables wannabuild@gl11tchy"
echo
echo "Factory install"
echo "Target: ${FACTORY_HOME_DIR}"
check_link_target "${FACTORY_HOME_DIR}/plugins/cache/wannabuild/wannabuild/local" "$ROOT/adapters/factory"
check_json_key "${FACTORY_HOME_DIR}/plugins/known_marketplaces.json" "\"path\": \"$ROOT\"" "Factory known_marketplaces.json registers local WannaBuild marketplace"
check_json_key "${FACTORY_HOME_DIR}/plugins/installed_plugins.json" "wannabuild@wannabuild" "Factory installed_plugins.json enables wannabuild@wannabuild"
check_optional_user_file "${FACTORY_HOME_DIR}/droids/wb-architect.md" "Factory droid wb-architect installed"
check_optional_user_file "${FACTORY_HOME_DIR}/droids/wb-integration-tester.md" "Factory droid wb-integration-tester installed"
check_optional_user_file "${FACTORY_HOME_DIR}/droids/wb-advisor.md" "Factory droid wb-advisor installed"
echo
echo "Runtime binary"
echo "Each installed host must reach the Rust wb-runtime gate engine; a missing"
echo "binary silently degrades that host to the Python mirror, so this fails hard."
runtime_hosts_checked=0
if [[ -d "${CLAUDE_HOME_DIR}" ]]; then
  runtime_hosts_checked=1
  check_runtime_binary "${ROOT}/target/debug/wb-runtime" "Claude wb-runtime present and executable" || status=1
fi
if [[ -d "${CODEX_BASE}" ]]; then
  runtime_hosts_checked=1
  check_runtime_binary "${CODEX_RUNTIME_DIR}/wb-runtime" "Codex wb-runtime present and executable" || status=1
fi
if [[ -d "${FACTORY_HOME_DIR}" ]]; then
  runtime_hosts_checked=1
  check_runtime_binary "${FACTORY_PLUGIN_CACHE}/target/debug/wb-runtime" "Factory wb-runtime present and executable" || status=1
fi
if [[ "$runtime_hosts_checked" -eq 0 ]]; then
  echo "No host install directories found; skipping runtime binary checks."
fi
echo
printf '%s%d pass · %d warn · %d fail%s\n\n' \
  "$COLOR_BOLD" "$DOCTOR_PASS_COUNT" "$DOCTOR_WARN_COUNT" "$DOCTOR_FAIL_COUNT" "$COLOR_RESET"
if [[ $status -eq 0 ]]; then
  echo "Repo surfaces ready:"
  echo "- Codex + Claude co-primary repo usage is documented"
  echo "- Codex skill install surface exists"
  echo "- Claude install and autoroute hook surfaces exist"
  echo "- Factory plugin, skills, and droid surfaces exist"
  echo "- Optional implementation worktree surface exists"
  echo "- Daily-use trust dry runs pass"
  echo "- Golden path demo validates"
  echo "- Cursor rule surface exists"
  echo "- Claude adapter docs and install surfaces exist"
  echo
  echo "Next:"
  echo "- Run ./scripts/install-codex-skill.sh"
  echo "- Run ./scripts/install-claude-skill.sh"
  echo "- Run ./scripts/install-factory-plugin.sh"
  echo "- Restart Codex, then natural feature prompts should route automatically"
  echo "- Reload Claude plugins, then natural feature prompts should route automatically"
  echo "- Restart Droid, then natural feature prompts should route automatically"
  echo "- In Cursor, load .cursor/rules/wannabuild.mdc"
  exit 0
fi

echo "One or more required surfaces are missing."
exit 1
