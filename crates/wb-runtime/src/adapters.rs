use std::path::Path;

use serde::Serialize;

use crate::context::{self, RuntimeContext};
use crate::errors::{Result, RuntimeError};

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct PromptRoute {
    pub route: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub skill: Option<String>,
    pub reason: String,
    pub vague_acknowledgment: bool,
    pub explicit_phase_limit: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct AdapterContext {
    pub host: String,
    pub event: String,
    pub route: PromptRoute,
    pub runtime_context: RuntimeContext,
    pub allowed_next_action: String,
    pub forbidden_actions: Vec<String>,
    pub required_gates: Vec<String>,
    pub required_evidence: Vec<String>,
    pub next_handoff: String,
    pub control_mode: String,
    pub pause_required: bool,
    /// Set when the current prompt is an explicit approval that releases a
    /// pending guided boundary pause (advance exactly one boundary).
    pub approval_acknowledged: bool,
}

pub fn adapter_context(
    project_root: &Path,
    host: &str,
    event: &str,
    prompt: Option<&str>,
) -> Result<AdapterContext> {
    let host = normalize_host(host)?;
    let runtime_context = context::build_context(project_root);
    let prompt = prompt.unwrap_or("");
    let route = classify_prompt(prompt);
    // An explicit approval releases only a clearable guided boundary pause;
    // explicit pause_reason/paused state is never cleared this way.
    let approval_acknowledged =
        runtime_context.guided_boundary_pause && approval_ack(&normalized(prompt));
    let pause_required = if approval_acknowledged {
        false
    } else {
        runtime_context.pause_required
    };
    Ok(AdapterContext {
        host,
        event: event.to_string(),
        allowed_next_action: runtime_context.allowed_next_action.clone(),
        forbidden_actions: runtime_context.forbidden_actions.clone(),
        required_gates: runtime_context.required_gates.clone(),
        required_evidence: runtime_context.required_evidence.clone(),
        next_handoff: runtime_context.next_handoff.clone(),
        control_mode: runtime_context.control_mode.clone(),
        pause_required,
        approval_acknowledged,
        runtime_context,
        route,
    })
}

pub fn route_prompt(host: &str, prompt: &str) -> Result<PromptRoute> {
    normalize_host(host)?;
    Ok(classify_prompt(prompt))
}

pub fn classify_prompt(prompt: &str) -> PromptRoute {
    let text = normalized(prompt);
    let phase_limit = explicit_phase_limit(&text);
    if text.is_empty() {
        return no_route("empty prompt", false, phase_limit);
    }
    if text.starts_with('/') || text.starts_with('$') {
        return no_route("explicit command invocation", false, phase_limit);
    }
    if contains_any(
        &text,
        &[
            "do not use wannabuild",
            "don't use wannabuild",
            "dont use wannabuild",
            "without wannabuild",
            "skip wannabuild",
            "avoid wannabuild",
        ],
    ) {
        return no_route("explicit WannaBuild opt-out", false, phase_limit);
    }
    if vague_ack(&text) {
        return PromptRoute {
            route: "continue-current-phase".to_string(),
            skill: None,
            reason: "vague acknowledgment".to_string(),
            vague_acknowledgment: true,
            explicit_phase_limit: phase_limit,
        };
    }
    if contains_any(
        &text,
        &[
            "debug",
            "diagnose",
            "reproduce",
            "traceback",
            "exception",
            "crash",
            "broken",
            "failing",
            "failure",
            "bug",
            "regression",
        ],
    ) {
        return skill("wb-debug", "bug/failure language", phase_limit);
    }
    if contains_any(
        &text,
        &[
            "code review",
            "review this",
            "review the",
            "audit",
            "readiness check",
            "is this ready",
        ],
    ) {
        return skill("wb-review", "review/readiness language", phase_limit);
    }
    if contains_any(
        &text,
        &[
            "qa",
            "acceptance criteria",
            "acceptance test",
            "integration validation",
            "validate acceptance",
            "did we cover",
            "verify requirements",
        ],
    ) {
        return skill("wb-qa", "QA/acceptance language", phase_limit);
    }
    if contains_any(
        &text,
        &[
            "ship",
            "handoff",
            "release",
            "publish",
            "pull request",
            "open a pr",
            "create a pr",
            "commit",
            "final summary",
        ],
    ) {
        return skill("wb-ship", "ship/handoff language", phase_limit);
    }
    if contains_any(
        &text,
        &[
            "implement",
            "build",
            "code",
            "change",
            "modify",
            "update",
            "wire up",
            "finish",
        ],
    ) && contains_any(
        &text,
        &[
            "next planned",
            "planned slice",
            "from the plan",
            "existing plan",
            "task ",
            "slice",
        ],
    ) {
        return skill(
            "wb-build",
            "focused planned implementation language",
            phase_limit,
        );
    }
    if contains_any(
        &text,
        &[
            "plan",
            "planning",
            "architect",
            "architecture",
            "design direction",
            "technical approach",
            "task breakdown",
            "decompose",
        ],
    ) || (text.contains("break") && text.contains("tasks"))
    {
        return skill("wb-plan", "planning/architecture language", phase_limit);
    }

    let has_discovery = contains_any(
        &text,
        &[
            "brainstorm",
            "discover",
            "discovery",
            "requirements",
            "requirements-only",
            "scope",
            "clarify",
            "figure out what",
            "talk through",
            "idea",
            "ideas",
            "brainstorming-only",
        ],
    );
    if has_discovery && phase_limit {
        return skill(
            "wb-discover",
            "discovery-only/requirements language",
            phase_limit,
        );
    }
    if contains_any(
        &text,
        &[
            "work on this",
            "ideas we could add",
            "what should we add",
            "thinking of some ideas",
            "thinking of ideas",
            "let's brainstorm",
            "lets brainstorm",
        ],
    ) {
        return skill("wannabuild", "open-ended ideation language", phase_limit);
    }
    if has_discovery {
        return skill(
            "wannabuild",
            "open-ended discovery/ideation language",
            phase_limit,
        );
    }
    if contains_any(
        &text,
        &[
            "i want",
            "i wanna",
            "i need",
            "we need",
            "i'd like",
            "id like",
            "let's build",
            "lets build",
            "build me",
            "build a",
            "create a",
            "add",
            "new feature",
            "functionality",
        ],
    ) {
        return skill("wannabuild", "broad feature/change language", phase_limit);
    }
    if contains_any(
        &text,
        &[
            "fix this",
            "fix the",
            "clean up",
            "cleanup",
            "tidy up",
            "tidy this",
            "weird",
            "messy",
            "duplicate",
            "duplicates",
            "duplicated",
            "why are there",
            "why is there",
            "why do we have",
            "why does this",
            "slash command",
            "slash commands",
            "slash menu",
            "plugin packaging",
            "plugin loader",
            "repo plumbing",
            "plumbing",
            "this plugin",
            "the plugin",
            "our plugin",
            "packaging",
            "tooling",
            "devtools",
            "dev tools",
        ],
    ) {
        return skill(
            "wannabuild",
            "repo-meta/cleanup/complaint language",
            phase_limit,
        );
    }

    no_route("no WannaBuild route matched", false, phase_limit)
}

fn normalize_host(host: &str) -> Result<String> {
    let value = normalized(host);
    if value.is_empty() {
        return Err(RuntimeError::message("Adapter host is required"));
    }
    Ok(match value.as_str() {
        "claude" | "claude-code" => "claude-code".to_string(),
        "codex" => "codex".to_string(),
        "cursor" => "cursor".to_string(),
        "shell" | "manual" | "shell/manual" => "shell/manual".to_string(),
        _ => value,
    })
}

fn normalized(value: &str) -> String {
    value
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_lowercase()
}

fn contains_any(text: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| text.contains(needle))
}

fn vague_ack(text: &str) -> bool {
    matches!(
        text,
        "ok" | "okay" | "k" | "kk" | "uh ok" | "uh okay" | "sounds good" | "sure" | "yep" | "yes"
    )
}

/// An explicit approval to advance exactly one guided phase boundary.
/// Distinct from a vague acknowledgment, which only continues the current
/// phase. `text` must already be normalized.
fn approval_ack(text: &str) -> bool {
    // "ship it" is intentionally excluded: the prompt classifier routes any
    // "ship" language to wb-ship, so treating it as a boundary approval would
    // both clear the pause and steer toward final delivery instead of
    // advancing exactly one boundary.
    matches!(
        text,
        "go" | "go ahead"
            | "proceed"
            | "continue"
            | "approved"
            | "approve"
            | "lgtm"
            | "do it"
            | "next"
    )
}

fn explicit_phase_limit(text: &str) -> bool {
    contains_any(
        text,
        &[
            "discovery only",
            "discovery-only",
            "discover only",
            "requirements only",
            "requirements-only",
            "brainstorming-only",
            "brainstorm only",
            "only brainstorm",
            "only discover",
            "only discovery",
            "only clarify",
            "just brainstorm",
            "just discover",
            "just discovery",
            "just requirements",
            "plan only",
            "planning only",
            "do not implement",
            "don't implement",
            "dont implement",
            "qa only",
            "review only",
            "debug only",
            "build only",
            "before we build",
            "before building",
            "before we plan",
            "before planning",
        ],
    )
}

fn skill(skill: &str, reason: &str, explicit_phase_limit: bool) -> PromptRoute {
    PromptRoute {
        route: skill.to_string(),
        skill: Some(skill.to_string()),
        reason: reason.to_string(),
        vague_acknowledgment: false,
        explicit_phase_limit,
    }
}

fn no_route(reason: &str, vague_acknowledgment: bool, explicit_phase_limit: bool) -> PromptRoute {
    PromptRoute {
        route: "none".to_string(),
        skill: None,
        reason: reason.to_string(),
        vague_acknowledgment,
        explicit_phase_limit,
    }
}

#[cfg(test)]
mod tests {
    use std::fs;

    use tempfile::tempdir;

    use crate::state;

    use super::*;

    #[test]
    fn routes_prompt_intents() {
        assert_eq!(
            classify_prompt("I want to add Stripe billing").route,
            "wannabuild"
        );
        assert_eq!(classify_prompt("Plan the architecture").route, "wb-plan");
        assert_eq!(
            classify_prompt("Implement the next planned slice").route,
            "wb-build"
        );
        assert_eq!(classify_prompt("Debug the failing test").route, "wb-debug");
        assert_eq!(classify_prompt("Review this change").route, "wb-review");
        assert_eq!(
            classify_prompt("Run QA against acceptance criteria").route,
            "wb-qa"
        );
        assert_eq!(
            classify_prompt("Did we cover the requirements?").route,
            "wb-qa"
        );
        assert_eq!(classify_prompt("Create a PR").route, "wb-ship");
        assert_eq!(
            classify_prompt("Talk through requirements-only").route,
            "wb-discover"
        );
        assert_eq!(classify_prompt("ok").route, "continue-current-phase");
        assert_eq!(
            classify_prompt("fix this plugin, the slash menu has duplicates").route,
            "wannabuild"
        );
        assert_eq!(
            classify_prompt("clean up the duplicate slash commands").route,
            "wannabuild"
        );
        assert_eq!(
            classify_prompt("why are there so many /wannabuild commands showing up").route,
            "wannabuild"
        );
        assert_eq!(
            classify_prompt("the plugin packaging is weird").route,
            "wannabuild"
        );
    }

    #[test]
    fn adapter_context_preserves_runtime_fields_for_hosts() {
        let dir = tempdir().unwrap();
        state::ensure_state(dir.path()).unwrap();

        let claude = adapter_context(dir.path(), "claude-code", "SessionStart", None).unwrap();
        let codex = adapter_context(dir.path(), "codex", "bootstrap", None).unwrap();

        assert_eq!(claude.allowed_next_action, codex.allowed_next_action);
        assert_eq!(claude.host, "claude-code");
        assert_eq!(codex.host, "codex");
    }

    fn plan_boundary_state(dir: &Path) {
        fs::create_dir_all(dir.join(".wannabuild/spec")).unwrap();
        fs::write(dir.join(".wannabuild/spec/design.md"), "design").unwrap();
        fs::write(dir.join(".wannabuild/spec/tasks.md"), "tasks").unwrap();
        let mut value = state::ensure_state(dir).unwrap();
        state::set_str(&mut value, "public_stage", "plan").unwrap();
        state::set_str(&mut value, "phase_status", "complete").unwrap();
        state::save_state(dir, &value).unwrap();
    }

    #[test]
    fn adapter_pauses_at_guided_boundary_without_approval() {
        let dir = tempdir().unwrap();
        plan_boundary_state(dir.path());

        let ctx = adapter_context(dir.path(), "codex", "bootstrap", None).unwrap();

        assert!(ctx.pause_required, "guided boundary must pause");
        assert!(ctx.runtime_context.guided_boundary_pause);
        assert!(!ctx.approval_acknowledged);
    }

    #[test]
    fn adapter_clears_guided_boundary_pause_on_approval() {
        let dir = tempdir().unwrap();
        plan_boundary_state(dir.path());

        let ctx = adapter_context(dir.path(), "codex", "bootstrap", Some("go")).unwrap();

        assert!(
            !ctx.pause_required,
            "approval must release the guided boundary pause"
        );
        assert!(ctx.approval_acknowledged);
    }

    #[test]
    fn adapter_recognizes_multiple_approval_words() {
        for word in ["proceed", "approved", "lgtm", "do it", "continue", "next"] {
            let dir = tempdir().unwrap();
            plan_boundary_state(dir.path());

            let ctx = adapter_context(dir.path(), "codex", "bootstrap", Some(word)).unwrap();

            assert!(
                !ctx.pause_required,
                "approval word `{word}` should release the boundary pause"
            );
            assert!(ctx.approval_acknowledged, "`{word}` should be acknowledged");
        }
    }

    #[test]
    fn adapter_treats_ship_it_as_ship_route_not_boundary_approval() {
        // "ship it" routes to wb-ship via the classifier, so it must not clear
        // a guided boundary pause (which would conflict with final delivery).
        let dir = tempdir().unwrap();
        plan_boundary_state(dir.path());

        let ctx = adapter_context(dir.path(), "codex", "bootstrap", Some("ship it")).unwrap();

        assert!(
            ctx.pause_required,
            "`ship it` must not release the boundary pause"
        );
        assert!(!ctx.approval_acknowledged);
    }

    #[test]
    fn adapter_does_not_acknowledge_without_pending_boundary() {
        // No boundary pending (fresh discover, in progress): an approval-like
        // word must not be acknowledged as a boundary advance.
        let dir = tempdir().unwrap();
        state::ensure_state(dir.path()).unwrap();

        let ctx = adapter_context(dir.path(), "codex", "bootstrap", Some("continue")).unwrap();

        assert!(!ctx.pause_required);
        assert!(
            !ctx.approval_acknowledged,
            "no pending boundary means nothing to acknowledge"
        );
    }

    #[test]
    fn adapter_does_not_clear_explicit_pause_on_approval() {
        let dir = tempdir().unwrap();
        plan_boundary_state(dir.path());
        let mut value = state::load_state(dir.path()).unwrap().unwrap();
        state::set_str(&mut value, "pause_reason", "user requested hold").unwrap();
        state::save_state(dir.path(), &value).unwrap();

        let ctx = adapter_context(dir.path(), "codex", "bootstrap", Some("go")).unwrap();

        assert!(
            ctx.pause_required,
            "an explicit pause must not be cleared by an approval prompt"
        );
        assert!(!ctx.runtime_context.guided_boundary_pause);
        assert!(!ctx.approval_acknowledged);
    }
}
