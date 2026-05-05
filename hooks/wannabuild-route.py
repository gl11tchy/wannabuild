#!/usr/bin/env python3
"""Claude Code hook for natural-language WannaBuild routing.

The hook never rewrites or blocks user prompts. It only adds routing context
when the prompt clearly matches a WannaBuild full-loop or toolbox intent.
"""

from __future__ import annotations

import json
import re
import sys
from typing import Any


ROUTE_CONTEXT = {
    "wannabuild": (
        "broad product, feature, change, or open-ended ideation request",
        "Use the `wannabuild` skill and start the full Discover -> Plan -> "
        "Implement -> Validate -> QA -> Summary loop.",
    ),
    "wb-discover": (
        "discovery-only, brainstorming-only, or requirements-only request",
        "Use the `wb-discover` skill for a vision-first discovery pass only.",
    ),
    "wb-plan": (
        "planning, architecture, or task decomposition request",
        "Use the `wb-plan` skill for design direction, risks, tasks, and "
        "verification expectations.",
    ),
    "wb-build": (
        "focused implementation request against an existing task or plan",
        "Use the `wb-build` skill to implement the requested slice.",
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
- Discovery-only, brainstorming-only, idea clarification-only, and
  requirements-only prompts map to `wb-discover`.
- Planning, architecture, and task breakdown prompts map to `wb-plan`.
- Focused planned implementation prompts map to `wb-build`.
- Bugs, failures, and regressions map to `wb-debug`.
- Review requests map to `wb-review`.
- QA and acceptance validation requests map to `wb-qa`.
- Ship, handoff, commit, PR, and release prompts map to `wb-ship`.

Commands are optional shortcuts. If the user's intent is clear, select the
matching skill automatically before answering."""


def load_event() -> dict[str, Any]:
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return {}
        data = json.loads(raw)
        return data if isinstance(data, dict) else {}
    except json.JSONDecodeError:
        return {}


def normalized(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip().lower())


def has(pattern: str, text: str) -> bool:
    return re.search(pattern, text, flags=re.IGNORECASE) is not None


def classify(prompt: str) -> tuple[str, str] | None:
    text = normalized(prompt)
    if not text:
        return None

    if text.startswith(("/", "$")):
        return None

    if has(r"\b(do not|don't|dont|without|skip|avoid)\s+(use\s+)?wannabuild\b", text):
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
        emit("SessionStart", SESSION_CONTEXT)
        return 0

    if event_name != "UserPromptSubmit":
        return 0

    prompt = str(event.get("prompt") or "")
    route = classify(prompt)
    if route is None:
        return 0

    skill, reason = route
    route_reason, instruction = ROUTE_CONTEXT[skill]
    context = (
        f"WannaBuild autoroute: this prompt matches `{skill}` because it is a "
        f"{route_reason} ({reason}). {instruction} Do not ask the user to type "
        "a slash command first."
    )
    emit("UserPromptSubmit", context)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
