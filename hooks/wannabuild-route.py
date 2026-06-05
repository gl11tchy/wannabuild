#!/usr/bin/env python3
"""Claude Code hook for natural-language WannaBuild routing and runtime state.

The hook never rewrites or blocks user prompts. It only adds routing context
when the prompt clearly matches a WannaBuild full-loop or phase intent, and it
reinjects active workflow state so agents do not skip required phases.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Optional


ROUTE_CONTEXT = {
    "wannabuild": (
        "broad product, feature, change, or open-ended ideation request",
        "Use the `wannabuild` skill and start the full Discover -> Plan -> "
        "Implement -> Validate -> QA -> Summary loop.",
    ),
    "wb-discover": (
        "discovery, brainstorming, or requirements request",
        "Use the `wb-discover` skill as the Discover phase entrypoint. Continue "
        "to Plan unless the user explicitly limited the request to discovery only.",
    ),
    "wb-plan": (
        "planning, architecture, or task decomposition request",
        "Use the `wb-plan` skill for design direction, risks, tasks, and "
        "verification expectations.",
    ),
    "wb-build": (
        "focused implementation request against an existing task or plan",
        "Use the `wb-build` skill to implement the requested slice only after "
        "the planning gate is satisfied.",
    ),
    "wb-debug": (
        "bug, failure, error, or regression request",
        "Use the `wb-debug` skill to reproduce, diagnose, fix, and verify.",
    ),
    "wb-review": (
        "review or readiness-check request",
        "Use the `wb-review` skill for targeted review.",
    ),
    "wb-qa": (
        "QA, acceptance, or integration validation request",
        "Use the `wb-qa` skill for acceptance and integration validation.",
    ),
    "wb-ship": (
        "ship, handoff, release, commit, PR, or final summary request",
        "Use the `wb-ship` skill for final delivery preparation.",
    ),
}


SESSION_CONTEXT = """WannaBuild automatic routing is active.

Natural-language software requests should route to WannaBuild skills without
requiring slash commands:
- Broad product, feature, open-ended ideation, or "I want to build/add/change"
  prompts map to the `wannabuild` full-loop skill.
- Discovery, brainstorming, idea clarification, and requirements prompts map to
  `wb-discover` or the full `wannabuild` loop depending on whether the user
  explicitly limited the phase.
- Planning, architecture, and task breakdown prompts map to `wb-plan`.
- Focused planned implementation prompts map to `wb-build`, but implementation
  is forbidden until Plan is complete.
- Bugs, failures, and regressions map to `wb-debug`.
- Review requests map to `wb-review`.
- QA and acceptance validation requests map to `wb-qa`.
- Ship, handoff, commit, PR, and release prompts map to `wb-ship`.

Commands are optional shortcuts. If the user's intent is clear, select the
matching skill automatically before answering. Vague acknowledgments such as
"ok" continue the active phase; they are not permission to skip planning,
implementation, validation, QA, or summary."""


NEXT_ACTIONS = {
    "discover": "continue Discover until the requirements brief is crisp, then move to Plan",
    "research": "finish bounded research, synthesize findings, then move to Plan",
    "plan": "complete design and task planning before any code edits",
    "implement": "run the planning gate, then implement the smallest planned slice",
    "review": "validate against the plan and fix actionable findings",
    "qa": "run acceptance and integration QA",
    "summary": "prepare the verified handoff or delivery path",
}


def explicit_phase_limit(prompt: str) -> bool:
    text = normalized(prompt)
    return has(
        r"\b(discovery only|discover only|plan only|planning only|do not implement|"
        r"don't implement|dont implement|qa only|review only|debug only|build only)\b",
        text,
    )


def vague_ack(prompt: str) -> bool:
    return normalized(prompt) in {
        "ok",
        "okay",
        "k",
        "kk",
        "uh ok",
        "uh okay",
        "sounds good",
        "sure",
        "yep",
        "yes",
    }


def approval_ack(prompt: str) -> bool:
    """An explicit approval to cross exactly one guided phase boundary.

    Distinct from vague acknowledgments: these advance the workflow one phase.
    """
    # "ship it" is intentionally excluded: the prompt classifier routes any
    # "ship" language to wb-ship, so treating it as a boundary approval would
    # both clear the pause and steer toward final delivery instead of
    # advancing exactly one boundary.
    return normalized(prompt) in {
        "go",
        "go ahead",
        "proceed",
        "continue",
        "approved",
        "approve",
        "lgtm",
        "do it",
        "next",
    }


# Canonical discovery artifact requirements, mirroring
# DISCOVERY_REQUIRED_ARTIFACTS in crates/wb-runtime/src/gates.rs. Each entry is
# (state lookup path under "discovery", canonical artifact path).
_DISCOVERY_REQUIRED_ARTIFACTS: tuple[tuple[tuple[str, ...], str], ...] = (
    (("research", "feasibility"), ".wannabuild/outputs/discovery/feasibility.md"),
    (
        ("research", "alternatives_competition"),
        ".wannabuild/outputs/discovery/alternatives-competition.md",
    ),
    (("research", "failure_forecast"), ".wannabuild/outputs/discovery/failure-forecast.md"),
    (("followup_questions",), ".wannabuild/outputs/discovery/followup-questions.md"),
    (("synthesis",), ".wannabuild/spec/requirements.md"),
)


def discovery_ready(state: dict[str, Any], project_root: Path) -> bool:
    """Degraded-path mirror of wb-runtime's assert_discovery_ready.

    The real gate requires the completed discovery interview plus the research
    artifacts (feasibility, alternatives/competition, failure forecast),
    follow-up questions, and the synthesized requirements brief. For each it
    verifies the node is marked complete, its recorded artifact path matches
    the canonical expected path, and the file at that path exists and is
    non-empty. The fallback mirrors all three checks so it does not pause
    Discover on a partial brief, a touched/empty file, or a non-canonical
    artifact path.
    """
    discovery = state.get("discovery")
    if not isinstance(discovery, dict):
        return False

    def node_at(path: tuple[str, ...]) -> Any:
        node: Any = discovery
        for key in path:
            if not isinstance(node, dict):
                return None
            node = node.get(key)
        return node

    def status_complete(node: Any) -> bool:
        return isinstance(node, dict) and node.get("status") == "complete"

    if not status_complete(discovery.get("interview")):
        return False
    for path, expected in _DISCOVERY_REQUIRED_ARTIFACTS:
        node = node_at(path)
        if not status_complete(node) or node.get("artifact") != expected:
            return False
        artifact_path = project_root / expected
        try:
            if not artifact_path.is_file() or not artifact_path.read_text(
                encoding="utf-8"
            ).strip():
                return False
        except OSError:
            return False
    return True


# Default required reviewers, mirroring REQUIRED_REVIEWERS / INTEGRATION_TESTER
# in crates/wb-runtime/src/gates.rs.
_REQUIRED_REVIEWERS = (
    "wb-security-reviewer",
    "wb-performance-reviewer",
    "wb-architecture-reviewer",
    "wb-testing-reviewer",
    "wb-integration-tester",
    "wb-code-simplifier",
)
_INTEGRATION_TESTER = "wb-integration-tester"
_QA_NEGATIVE_TOKENS = {
    "blocked",
    "fail",
    "failed",
    "failure",
    "missing",
    "no",
    "none",
    "not",
    "pending",
    "todo",
}
_QA_POSITIVE_TOKENS = {
    "checked",
    "complete",
    "covered",
    "ok",
    "pass",
    "passed",
    "success",
    "successful",
    "validated",
    "verified",
}
_FAILURE_STATUSES = {"blocked", "failed", "fail", "failure"}


def _read_json_file(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def _latest_loop_iteration(project_root: Path) -> Optional[dict[str, Any]]:
    data = _read_json_file(project_root / ".wannabuild" / "loop-state.json")
    if not isinstance(data, dict):
        return None
    iterations = data.get("iterations")
    if not isinstance(iterations, list):
        return None
    dict_items = [item for item in iterations if isinstance(item, dict)]
    if not dict_items:
        return None

    def iteration_number(item: dict[str, Any]) -> int:
        value = item.get("iteration")
        return value if isinstance(value, int) else 0

    return max(dict_items, key=iteration_number)


def _verdict_from_payload(payload: Any, fallback_agent: str) -> Optional[tuple[str, str]]:
    agent = fallback_agent
    status = "UNKNOWN"
    if isinstance(payload, dict):
        if isinstance(payload.get("agent"), str):
            agent = payload["agent"]
        if isinstance(payload.get("status"), str):
            status = payload["status"]
    if agent == "unknown" or not agent.strip():
        return None
    return (agent, status)


def _required_reviewers(project_root: Path) -> set[str]:
    latest = _latest_loop_iteration(project_root)
    if isinstance(latest, dict):
        active = latest.get("active_reviewers")
        if isinstance(active, list):
            names = {item for item in active if isinstance(item, str)}
            if names:
                return names
    return set(_REQUIRED_REVIEWERS)


def _loop_state_verdicts(project_root: Path) -> Optional[tuple[set[str], dict[str, str]]]:
    latest = _latest_loop_iteration(project_root)
    if not isinstance(latest, dict):
        return None
    active = latest.get("active_reviewers")
    active_set = {item for item in active if isinstance(item, str)} if isinstance(active, list) else set()
    verdicts: dict[str, str] = {}
    payloads = latest.get("verdicts")
    if isinstance(payloads, dict):
        for key, payload in payloads.items():
            verdict = _verdict_from_payload(payload, key)
            if verdict is not None:
                verdicts[verdict[0]] = verdict[1]
    if not verdicts:
        return None
    return (active_set, verdicts)


def _iteration_from_path(path: Path) -> int:
    name = path.name
    for marker in ("iter-", "iter_"):
        index = name.find(marker)
        if index != -1:
            digits = ""
            for ch in name[index + len(marker):]:
                if ch.isdigit():
                    digits += ch
                else:
                    break
            if digits:
                return int(digits)
    return 0


def _file_verdicts(project_root: Path) -> Optional[dict[str, str]]:
    review_dir = project_root / ".wannabuild" / "review"
    if not review_dir.is_dir():
        return None
    files = sorted(p for p in review_dir.iterdir() if p.suffix == ".json")
    if not files:
        return None
    best: dict[str, tuple[tuple[int, str, str], str]] = {}
    for path in files:
        payload = _read_json_file(path)
        if payload is None:
            return None
        iteration = _iteration_from_path(path)
        timestamp = ""
        if isinstance(payload, dict):
            if isinstance(payload.get("iteration"), int):
                iteration = payload["iteration"]
            if isinstance(payload.get("timestamp"), str):
                timestamp = payload["timestamp"]
        verdict = _verdict_from_payload(payload, "unknown")
        if verdict is None:
            continue
        agent, status = verdict
        sort_key = (iteration, timestamp, path.name)
        if agent not in best or sort_key >= best[agent][0]:
            best[agent] = (sort_key, status)
    return {agent: value[1] for agent, value in best.items()}


def review_ready(state: dict[str, Any], project_root: Path) -> bool:
    """Degraded-path mirror of wb-runtime's assert_review_ready.

    Requires a PASS verdict from every required reviewer (loop-state active
    reviewers when present, else the default reviewer set) plus the
    integration tester. Verdicts come from the latest loop-state iteration,
    falling back to per-agent files under .wannabuild/review only to fill
    gaps, exactly as the runtime gate does.
    """
    required = _required_reviewers(project_root)
    required.add(_INTEGRATION_TESTER)
    verdicts: dict[str, str] = {}
    loop = _loop_state_verdicts(project_root)
    if loop is not None:
        active, verdicts = loop[0], dict(loop[1])
        if active:
            required = set(active)
            required.add(_INTEGRATION_TESTER)
    if not verdicts or any(agent not in verdicts for agent in required):
        files = _file_verdicts(project_root)
        if files is None:
            return False
        for agent, status in files.items():
            verdicts.setdefault(agent, status)
    if any(agent not in verdicts for agent in required):
        return False
    return all(
        verdicts[agent].upper() == "PASS" for agent in required if agent in verdicts
    )


def _is_failure_status(status: str) -> bool:
    return status in _FAILURE_STATUSES


def _normalized_field(field: str) -> str:
    return "".join(ch for ch in field if ch.isalnum()).lower()


def _is_status_field(field: str) -> bool:
    return _normalized_field(field) in {"status", "qastatus", "result", "verdict"}


def _qa_summary_field(line: str) -> Optional[tuple[str, str]]:
    line = line.strip().lstrip("-*# ").strip()
    if ":" not in line:
        return None
    field, value = line.split(":", 1)
    return (field.strip().lower(), value.strip())


def _alnum_tokens(value: str) -> list[str]:
    return [token.lower() for token in re.split(r"[^A-Za-z0-9]", value) if token]


def _value_is_positive(value: str) -> bool:
    tokens = _alnum_tokens(value)
    if any(token in _QA_NEGATIVE_TOKENS for token in tokens):
        return False
    return any(token in _QA_POSITIVE_TOKENS for token in tokens)


def _latest_history_status(history: Any, key: str, value: str) -> Optional[str]:
    if not isinstance(history, list):
        return None
    for item in reversed(history):
        if isinstance(item, dict) and item.get(key) == value:
            status = item.get("status")
            if isinstance(status, str):
                return status
    return None


def _qa_current_state_failed(state: dict[str, Any]) -> bool:
    qa_active = state.get("public_stage") == "qa" or state.get("current_phase") == "qa"
    if not qa_active:
        return False
    phase_status = state.get("phase_status")
    workflow_status = state.get("workflow_status")
    return (isinstance(phase_status, str) and _is_failure_status(phase_status)) or (
        isinstance(workflow_status, str) and _is_failure_status(workflow_status)
    )


def _qa_summary_failure_marker(qa_summary: Path) -> bool:
    try:
        raw = qa_summary.read_text(encoding="utf-8")
    except OSError:
        return False
    for line in raw.splitlines():
        parsed = _qa_summary_field(line)
        if parsed is None:
            continue
        field, value = parsed
        if _is_status_field(field) and any(
            _is_failure_status(token) for token in _alnum_tokens(value)
        ):
            return True
    return False


def _latest_qa_event(project_root: Path) -> Optional[str]:
    """Latest qa_failed/qa_passed event type, or raises ValueError on a
    malformed events file (mirroring the runtime, which fails the gate)."""
    path = project_root / ".wannabuild" / "events.jsonl"
    if not path.is_file():
        return None
    latest: Optional[str] = None
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            event = json.loads(line)
            if isinstance(event, dict) and event.get("type") in ("qa_failed", "qa_passed"):
                latest = event["type"]
    return latest


def _qa_failed(state: dict[str, Any], project_root: Path, qa_summary: Path) -> bool:
    if isinstance(state, dict):
        if _qa_current_state_failed(state):
            return True
        status = _latest_history_status(state.get("public_stage_history"), "stage", "qa")
        if status is None:
            status = _latest_history_status(state.get("phase_history"), "phase", "qa")
        if status is not None and _is_failure_status(status):
            return True
    if _qa_summary_failure_marker(qa_summary):
        return True
    return _latest_qa_event(project_root) == "qa_failed"


def _qa_has_pass_evidence(qa_summary: Path) -> bool:
    try:
        raw = qa_summary.read_text(encoding="utf-8")
    except OSError:
        return False
    pass_marker = acceptance = integration = False
    for line in raw.splitlines():
        parsed = _qa_summary_field(line)
        if parsed is None:
            continue
        field, value = parsed
        if _is_status_field(field) and _value_is_positive(value):
            pass_marker = True
        normalized = _normalized_field(field)
        if "acceptance" in normalized and _value_is_positive(value):
            acceptance = True
        if "integration" in normalized and _value_is_positive(value):
            integration = True
    return pass_marker and acceptance and integration


def qa_ready(state: dict[str, Any], project_root: Path) -> bool:
    """Degraded-path mirror of wb-runtime's assert_qa_ready.

    Requires .wannabuild/outputs/qa-summary.md to exist with positive PASS
    evidence covering acceptance and integration, and no QA failure signal in
    state, phase/stage history, the summary markers, or QA events.
    """
    qa_summary = project_root / ".wannabuild" / "outputs" / "qa-summary.md"
    if not qa_summary.is_file():
        return False
    try:
        if _qa_failed(state, project_root, qa_summary):
            return False
        return _qa_has_pass_evidence(qa_summary)
    except (OSError, ValueError):
        return False


def at_phase_boundary(state: dict[str, Any], project_root: Path) -> bool:
    """Degraded-path mirror of the runtime boundary check.

    A guided pause is only warranted at a real boundary: the current phase is
    marked complete AND there is verifiable evidence that it produced an
    approvable result. Phases still in progress keep running (e.g. the
    Discover interview). Every gate is mirrored from wb-runtime so degraded
    installs (no runtime binary) still pause for the documented approvals,
    including Validate -> QA (review gate) and QA -> Summary (qa gate).
    """
    if state.get("phase_status") != "complete":
        return False
    public_stage = state.get("public_stage")
    if public_stage in {"plan", "implement"}:
        return plan_ready(state, project_root)
    if public_stage in {"discover", "research"}:
        return discovery_ready(state, project_root)
    if public_stage == "review":
        return review_ready(state, project_root)
    if public_stage == "qa":
        return qa_ready(state, project_root)
    return False


def load_event() -> dict[str, Any]:
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return {}
        data = json.loads(raw)
        return data if isinstance(data, dict) else {}
    except json.JSONDecodeError:
        return {}


def candidate_roots(event: dict[str, Any]) -> list[Path]:
    roots: list[Path] = []
    for key in ("cwd", "project_root", "workspace", "workspace_path"):
        value = event.get(key)
        if isinstance(value, str) and value.strip():
            roots.append(Path(value).expanduser())
    env_pwd = os.environ.get("PWD")
    if env_pwd:
        roots.append(Path(env_pwd).expanduser())
    roots.append(Path.cwd())
    return roots


def find_state_path(event: dict[str, Any]) -> Optional[Path]:
    seen: set[Path] = set()
    for root in candidate_roots(event):
        try:
            root = root.resolve()
        except OSError:
            continue
        for path in (root, *root.parents):
            if path in seen:
                continue
            seen.add(path)
            state_path = path / ".wannabuild" / "state.json"
            if state_path.is_file():
                return state_path
    return None


def has_complete(history: Any, key: str, value: str) -> bool:
    if not isinstance(history, list):
        return False
    for item in history:
        if not isinstance(item, dict):
            continue
        if item.get(key) == value and item.get("status") == "complete":
            return True
    return False


def plan_ready(state: dict[str, Any], project_root: Path) -> bool:
    spec = project_root / ".wannabuild" / "spec"
    artifacts_ready = (spec / "design.md").is_file() and (spec / "tasks.md").is_file()
    phase_history = state.get("phase_history")
    phase_plan_complete = has_complete(phase_history, "phase", "design") and has_complete(
        phase_history, "phase", "tasks"
    )
    return artifacts_ready or phase_plan_complete


def fallback_runtime_context(
    event: dict[str, Any],
    prompt: str = "",
    route_skill: Optional[str] = None,
) -> str:
    state_path = find_state_path(event)
    if state_path is None:
        return ""
    try:
        state = json.loads(state_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return ""
    # A manually paused workflow must still surface its runtime/pause context
    # in the fallback path, so an explicit hold is preserved even when
    # wb-runtime is unavailable.
    if not isinstance(state, dict) or state.get("workflow_status") not in (
        "in_progress",
        "paused",
    ):
        return ""

    project_root = state_path.parent.parent
    public_stage = safe_context_value(state.get("public_stage"), "unknown")
    current_phase = safe_context_value(state.get("current_phase"), "unknown")
    phase_status = safe_context_value(state.get("phase_status"), "unknown")
    control_mode = safe_context_value(state.get("control_mode"), "guided")
    ready = plan_ready(state, project_root)
    next_action = NEXT_ACTIONS.get(public_stage, "continue the active WannaBuild phase")

    lines = [
        "WannaBuild runtime state is active.",
        f"- state_file: {safe_context_value(state_path)}",
        f"- public_stage: {public_stage}",
        f"- current_phase: {current_phase}",
        f"- phase_status: {phase_status}",
        f"- control_mode: {control_mode}",
        f"- allowed_next_action: {next_action}",
        "- preserve this workflow across turns until completion or explicit user stop/exit",
    ]
    # An explicit pause (pause_reason / workflow paused) is never cleared by an
    # approval word; only a computed guided boundary pause is releasable.
    explicit_pause = (
        state.get("pause_reason") not in (None, "")
        or state.get("workflow_status") == "paused"
    )
    boundary_pause = control_mode == "guided" and at_phase_boundary(state, project_root)
    if prompt and approval_ack(prompt) and boundary_pause and not explicit_pause:
        # The user just supplied the approval for this pending boundary:
        # advance exactly one phase rather than re-emitting the pause.
        boundary_pause = False
        lines.append(
            "- approval_received: advance exactly one phase boundary, then resume guided gating"
        )
    if boundary_pause or explicit_pause:
        lines.append(
            "- pause_required: true (guided mode: stop at this phase boundary and get explicit user approval before advancing)"
        )
    if prompt and vague_ack(prompt):
        lines.append(
            "- vague_acknowledgment: continue the current phase; do not skip phases or treat this as implementation approval"
        )
    if explicit_phase_limit(prompt):
        lines.append("- explicit_phase_limit: stop after the requested phase boundary")
    if not ready:
        lines.append(
            "- FORBIDDEN: do not implement or edit code; complete Plan first and satisfy the planning gate"
        )
    if route_skill == "wb-build":
        lines.append(
            "- before_build: run `scripts/wannabuild-session.sh assert-plan-ready <project_root>`; stop if it fails or the runtime cannot execute"
        )
    return "\n".join(lines)


def runtime_binary() -> Optional[str]:
    env_bin = os.environ.get("WB_RUNTIME_BIN")
    if env_bin and Path(env_bin).is_file():
        return env_bin
    path_bin = shutil.which("wb-runtime")
    if path_bin:
        return path_bin
    repo_bin = Path(__file__).resolve().parents[1] / "target" / "debug" / "wb-runtime"
    if repo_bin.is_file():
        return str(repo_bin)
    return None


def runtime_project_root(event: dict[str, Any]) -> Path:
    state_path = find_state_path(event)
    if state_path is not None:
        return state_path.parent.parent
    for root in candidate_roots(event):
        try:
            root = root.resolve()
        except OSError:
            continue
        if root.is_dir():
            return root
    return Path.cwd().resolve()


def runtime_adapter_context(
    event: dict[str, Any],
    event_name: str,
    prompt: str = "",
) -> Optional[dict[str, Any]]:
    binary = runtime_binary()
    if not binary:
        return None
    args = [
        binary,
        "adapter",
        "context",
        "--project",
        str(runtime_project_root(event)),
        "--host",
        "claude-code",
        "--event",
        event_name,
    ]
    if prompt:
        args.extend(["--prompt", prompt])
    try:
        completed = subprocess.run(
            args,
            check=False,
            capture_output=True,
            text=True,
            timeout=3,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if completed.returncode != 0:
        return None
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError:
        return None
    return payload if isinstance(payload, dict) else None


def runtime_context_from_adapter(
    adapter_context: dict[str, Any],
    prompt: str = "",
    route_skill: Optional[str] = None,
) -> str:
    runtime = adapter_context.get("runtime_context")
    if not isinstance(runtime, dict) or not runtime.get("runtime_active"):
        return ""

    forbidden_actions = string_list(
        adapter_context.get("forbidden_actions", runtime.get("forbidden_actions"))
    )
    required_gates = string_list(adapter_context.get("required_gates", runtime.get("required_gates")))
    # The adapter's top-level pause_required is authoritative: it already
    # reflects approval clearing. Only fall back to the nested runtime value
    # when the adapter omits the key entirely, otherwise an approval-cleared
    # false would be ORed back to the stale nested true and keep the loop.
    if "pause_required" in adapter_context:
        pause_required = bool(adapter_context.get("pause_required"))
    else:
        pause_required = bool(runtime.get("pause_required"))

    lines = [
        "WannaBuild runtime state is active.",
        f"- state_file: {safe_context_value(runtime.get('state_file'))}",
        f"- public_stage: {safe_context_value(runtime.get('public_stage'))}",
        f"- current_phase: {safe_context_value(runtime.get('current_phase'))}",
        f"- phase_status: {safe_context_value(runtime.get('phase_status'))}",
        f"- allowed_next_action: {safe_context_value(adapter_context.get('allowed_next_action') or runtime.get('allowed_next_action'))}",
    ]
    control_mode = safe_context_value(
        adapter_context.get("control_mode") or runtime.get("control_mode"), "guided"
    )
    lines.append(f"- control_mode: {control_mode}")
    if forbidden_actions:
        lines.append(f"- forbidden_actions: {', '.join(forbidden_actions)}")
    if required_gates:
        lines.append(f"- required_gates: {', '.join(required_gates)}")
    # The runtime adapter already clears a guided boundary pause when the
    # prompt is an approval (and never clears an explicit pause), surfacing it
    # via approval_acknowledged. Trust that signal here rather than re-deriving
    # it from the raw prompt, which would risk clearing explicit pauses or
    # acknowledging when no boundary was pending.
    approval_acknowledged = bool(
        adapter_context.get("approval_acknowledged")
        or runtime.get("approval_acknowledged")
    )
    if approval_acknowledged:
        lines.append(
            "- approval_received: advance exactly one phase boundary, then resume guided gating"
        )
    if pause_required:
        lines.append(
            "- pause_required: true (guided mode: stop at this phase boundary and get explicit user approval before advancing)"
        )
    lines.append("- preserve this workflow across turns until completion or explicit user stop/exit")
    if prompt and vague_ack(prompt):
        lines.append(
            "- vague_acknowledgment: continue the current phase; do not skip phases or treat this as implementation approval"
        )
    if explicit_phase_limit(prompt):
        lines.append("- explicit_phase_limit: stop after the requested phase boundary")
    if "implement_before_plan" in forbidden_actions or "assert-plan-ready" in required_gates:
        lines.append(
            "- FORBIDDEN: do not implement or edit code; complete Plan first and satisfy the planning gate"
        )
    if route_skill == "wb-build":
        lines.append(
            "- before_build: run `scripts/wannabuild-session.sh assert-plan-ready <project_root>`; stop if it fails or the runtime cannot execute"
        )
    return "\n".join(lines)


def string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [safe_context_value(item) for item in value if safe_context_value(item)]


def route_from_adapter(adapter_context: dict[str, Any]) -> tuple[Optional[str], str]:
    route = adapter_context.get("route")
    if not isinstance(route, dict):
        return None, ""
    skill = route.get("skill")
    if not isinstance(skill, str) or not skill:
        return None, safe_context_value(route.get("reason"), "")
    return safe_context_value(skill, ""), safe_context_value(route.get("reason"), "")


def route_context(skill: str, reason: str) -> str:
    route_reason, instruction = ROUTE_CONTEXT[skill]
    return (
        f"WannaBuild autoroute: this prompt matches `{skill}` because it is a "
        f"{route_reason} ({reason}). {instruction} Do not ask the user to type "
        "a slash command first."
    )


def safe_context_value(value: Any, default: str = "unknown") -> str:
    if value is None:
        value = default
    text = re.sub(r"[\x00-\x1f\x7f]+", " ", str(value))
    text = re.sub(r"\s+", " ", text).strip().replace("`", "'")
    if not text:
        text = default
    if len(text) > 300:
        text = f"{text[:297]}..."
    return text


def normalized(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip().lower())


def has(pattern: str, text: str) -> bool:
    return re.search(pattern, text, flags=re.IGNORECASE) is not None


def classify(prompt: str) -> Optional[tuple[str, str]]:
    text = normalized(prompt)
    if not text:
        return None

    if leave_prompt_alone(text):
        return None

    discovery_only_terms = (
        r"\b(requirements-only|discovery-only|brainstorming-only)\b"
        r"|\b(discovery only|discover only|requirements only|brainstorm only|"
        r"only brainstorm|only discover|only discovery|only clarify|"
        r"just brainstorm|just discover|just discovery|just requirements|"
        r"before we plan|before planning|before we build|before building)\b"
    )

    # Grill requests are always Discover, regardless of other keywords in the
    # prompt ("grill me on this plan/bug/PR/architecture" / "grill me before
    # we build"). Hoisted above every skill-language check so it wins. Match
    # exact phrases only so "grilling recipes" / "show me grill menu" do not
    # false-positive.
    if has(r"\b(grill me|grill this)\b", text):
        if has(discovery_only_terms, text):
            return ("wb-discover", "grill request, discovery-only")
        return ("wannabuild", "grill request")

    if has(r"\b(debug|diagnose|reproduce|trace|traceback|exception|crash|broken|failing|failure|bug|regression)\b", text):
        return ("wb-debug", "bug/failure language")

    if has(r"\b(code review|review this|review the|audit|readiness check|is this ready)\b", text):
        return ("wb-review", "review/readiness language")

    if has(r"\b(qa|acceptance criteria|acceptance test|integration validation|validate acceptance|did we cover|verify requirements)\b", text):
        return ("wb-qa", "QA/acceptance language")

    if has(r"\b(ship|handoff|release|publish|pull request|open a pr|create a pr|commit|final summary)\b", text):
        return ("wb-ship", "ship/handoff language")

    if has(r"\b(implement|build|code|change|modify|update|wire up|finish)\b", text) and has(
        r"\b(next planned|planned slice|from the plan|existing plan|task \d+|slice)\b", text
    ):
        return ("wb-build", "focused planned implementation language")

    if has(r"\b(plan|planning|architect|architecture|design direction|technical approach|break.*tasks|task breakdown|decompose)\b", text):
        return ("wb-plan", "planning/architecture language")

    discovery_terms = r"\b(brainstorm|discover|discovery|requirements|scope|clarify|figure out what|talk through|idea|ideas)\b"

    if has(discovery_terms, text) and has(discovery_only_terms, text):
        return ("wb-discover", "discovery-only/requirements language")

    if has(r"\b(work on this|ideas? we could add|what should we add|thinking of (some )?ideas|let's brainstorm|lets brainstorm)\b", text):
        return ("wannabuild", "open-ended ideation language")

    if has(discovery_terms, text):
        return ("wannabuild", "open-ended discovery/ideation language")

    if has(r"\b(i want|i wanna|i need|we need|i'd like|id like|let's build|lets build|build me|build a|create a|add|new feature|functionality)\b", text):
        return ("wannabuild", "broad feature/change language")

    if has(
        r"\b(fix this|fix the|clean ?up|tidy up|tidy this|weird|messy|"
        r"duplicate|duplicates|duplicated|"
        r"why are there|why is there|why do we have|why does this|"
        r"slash command|slash commands|slash menu|"
        r"plugin packaging|plugin loader|repo plumbing|plumbing|"
        r"this plugin|the plugin|our plugin|"
        r"packaging|tooling|devtools|dev tools)\b",
        text,
    ):
        return ("wannabuild", "repo-meta/cleanup/complaint language")

    return None


def leave_prompt_alone(text: str) -> bool:
    if text.startswith(("/", "$")):
        return True
    return has(r"\b(do not|don't|dont|without|skip|avoid)\s+(use\s+)?wannabuild\b", text)


def emit(event_name: str, context: str) -> None:
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": event_name,
                    "additionalContext": context,
                }
            },
            separators=(",", ":"),
        )
    )


def main() -> int:
    event = load_event()
    event_name = str(event.get("hook_event_name") or event.get("hookEventName") or "")

    if event_name == "SessionStart":
        adapter_context = runtime_adapter_context(event, "SessionStart")
        runtime = (
            runtime_context_from_adapter(adapter_context)
            if adapter_context is not None
            else fallback_runtime_context(event)
        )
        context = "\n\n".join(part for part in [SESSION_CONTEXT, runtime] if part)
        emit("SessionStart", context)
        return 0

    if event_name != "UserPromptSubmit":
        return 0

    prompt = str(event.get("prompt") or "")
    if leave_prompt_alone(normalized(prompt)):
        return 0

    adapter_context = runtime_adapter_context(event, event_name, prompt)
    if adapter_context is not None:
        skill, reason = route_from_adapter(adapter_context)
        runtime = runtime_context_from_adapter(adapter_context, prompt, skill)
        if skill in ROUTE_CONTEXT:
            context = "\n\n".join(part for part in [route_context(skill, reason), runtime] if part)
            emit("UserPromptSubmit", context)
        elif runtime:
            emit("UserPromptSubmit", runtime)
        return 0

    route = classify(prompt)
    runtime = fallback_runtime_context(event, prompt)
    if route is None:
        if runtime:
            emit("UserPromptSubmit", runtime)
        return 0

    skill, reason = route
    context = "\n\n".join(
        part for part in [route_context(skill, reason), fallback_runtime_context(event, prompt, skill)] if part
    )
    emit("UserPromptSubmit", context)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
