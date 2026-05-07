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
    if not isinstance(state, dict) or state.get("workflow_status") != "in_progress":
        return ""

    project_root = state_path.parent.parent
    public_stage = safe_context_value(state.get("public_stage"), "unknown")
    current_phase = safe_context_value(state.get("current_phase"), "unknown")
    phase_status = safe_context_value(state.get("phase_status"), "unknown")
    control_mode = safe_context_value(state.get("control_mode"), "autonomous")
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
    pause_required = bool(adapter_context.get("pause_required") or runtime.get("pause_required"))

    lines = [
        "WannaBuild runtime state is active.",
        f"- state_file: {safe_context_value(runtime.get('state_file'))}",
        f"- public_stage: {safe_context_value(runtime.get('public_stage'))}",
        f"- current_phase: {safe_context_value(runtime.get('current_phase'))}",
        f"- phase_status: {safe_context_value(runtime.get('phase_status'))}",
        f"- allowed_next_action: {safe_context_value(adapter_context.get('allowed_next_action') or runtime.get('allowed_next_action'))}",
    ]
    if forbidden_actions:
        lines.append(f"- forbidden_actions: {', '.join(forbidden_actions)}")
    if required_gates:
        lines.append(f"- required_gates: {', '.join(required_gates)}")
    if pause_required:
        lines.append("- pause_required: true")
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
    discovery_only_terms = (
        r"\b(requirements-only|discovery-only|brainstorming-only)\b"
        r"|\b(discovery only|discover only|requirements only|brainstorm only|"
        r"only brainstorm|only discover|only discovery|only clarify|"
        r"just brainstorm|just discover|just discovery|just requirements|"
        r"before we plan|before planning|before we build|before building)\b"
    )

    if has(discovery_terms, text) and has(discovery_only_terms, text):
        return ("wb-discover", "discovery-only/requirements language")

    if has(r"\b(work on this|ideas? we could add|what should we add|thinking of (some )?ideas|let's brainstorm|lets brainstorm)\b", text):
        return ("wannabuild", "open-ended ideation language")

    if has(discovery_terms, text):
        return ("wannabuild", "open-ended discovery/ideation language")

    if has(r"\b(i want|i wanna|i need|we need|i'd like|id like|let's build|lets build|build me|build a|create a|add|new feature|functionality)\b", text):
        return ("wannabuild", "broad feature/change language")

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
