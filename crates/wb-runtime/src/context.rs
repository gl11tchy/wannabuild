use std::path::Path;

use serde::Serialize;
use serde_json::Value;

use crate::gates;
use crate::state::{get_str, load_state, state_path};

#[derive(Debug, Clone, Serialize)]
pub struct RuntimeContext {
    pub runtime_active: bool,
    pub workflow_status: String,
    pub public_stage: String,
    pub current_phase: String,
    pub phase_status: String,
    pub allowed_next_action: String,
    pub forbidden_actions: Vec<String>,
    pub required_gates: Vec<String>,
    pub required_evidence: Vec<String>,
    pub next_handoff: String,
    pub control_mode: String,
    pub pause_required: bool,
    pub vague_acknowledgment_policy: String,
    pub state_file: String,
}

pub fn build_context(project_root: &Path) -> RuntimeContext {
    let state = load_state(project_root).ok().flatten();
    let runtime_active = state
        .as_ref()
        .and_then(|value| value.get("workflow_status"))
        .and_then(Value::as_str)
        .map(|status| status != "complete")
        .unwrap_or(false);
    let workflow_status = state
        .as_ref()
        .and_then(|value| get_str(value, "workflow_status"))
        .unwrap_or("not_started")
        .to_string();
    let public_stage = state
        .as_ref()
        .and_then(|value| get_str(value, "public_stage"))
        .unwrap_or("none")
        .to_string();
    let current_phase = state
        .as_ref()
        .and_then(|value| get_str(value, "current_phase"))
        .unwrap_or("none")
        .to_string();
    let phase_status = state
        .as_ref()
        .and_then(|value| get_str(value, "phase_status"))
        .unwrap_or("none")
        .to_string();
    let workflow_active = gates::assert_workflow_active(project_root).is_ok();
    let discovery_ready = gates::assert_discovery_ready(project_root).is_ok();
    let plan_ready = gates::assert_plan_ready(project_root).is_ok();
    let review_ready = gates::assert_review_ready(project_root).is_ok();
    let qa_ready = gates::assert_qa_ready(project_root).is_ok();
    let control_mode = state
        .as_ref()
        .and_then(|value| get_str(value, "control_mode"))
        .unwrap_or("guided")
        .to_string();
    // Guided mode forces a pause only when the current phase is actually
    // complete (a real boundary to approve), not for every active guided
    // state. A freshly initialized, not-yet-ready phase must not be paused,
    // or it would stall the work that should still be running (e.g. the
    // Discover interview). Explicit pause_reason/paused state always pauses.
    let at_boundary = at_phase_boundary(
        &public_stage,
        discovery_ready,
        plan_ready,
        review_ready,
        qa_ready,
    );
    let pause_required = state
        .as_ref()
        .is_some_and(|value| pause_required_from_state(value))
        || (runtime_active && control_mode == "guided" && at_boundary);
    let mut forbidden_actions = Vec::new();
    let mut required_gates = Vec::new();
    if !workflow_active {
        forbidden_actions.push("host_only_wannabuild_claim".to_string());
        required_gates.push("assert-workflow-active".to_string());
    }
    if matches!(public_stage.as_str(), "discover" | "research") && !discovery_ready {
        forbidden_actions.push("plan_before_discovery_ready".to_string());
        required_gates.push("assert-discovery-ready".to_string());
    }
    if !plan_ready && !matches!(public_stage.as_str(), "discover" | "research") {
        forbidden_actions.push("implement_before_plan".to_string());
        forbidden_actions.push("edit_code_before_plan_gate".to_string());
        required_gates.push("assert-plan-ready".to_string());
    }
    if matches!(public_stage.as_str(), "review" | "qa" | "ship" | "summary")
        && gates::assert_review_ready(project_root).is_err()
    {
        forbidden_actions.push("advance_without_review_ready".to_string());
        required_gates.push("assert-review-ready".to_string());
    }
    if matches!(public_stage.as_str(), "qa" | "ship" | "summary")
        && gates::assert_qa_ready(project_root).is_err()
    {
        forbidden_actions.push("advance_without_qa_ready".to_string());
        required_gates.push("assert-qa-ready".to_string());
    }
    RuntimeContext {
        runtime_active,
        workflow_status,
        public_stage: public_stage.clone(),
        current_phase,
        phase_status,
        allowed_next_action: allowed_next_action(
            &public_stage,
            workflow_active,
            discovery_ready,
            plan_ready,
        )
        .to_string(),
        forbidden_actions,
        required_gates,
        required_evidence: required_evidence(
            &public_stage,
            workflow_active,
            discovery_ready,
            plan_ready,
        ),
        next_handoff: next_handoff(&public_stage, workflow_active, discovery_ready, plan_ready)
            .to_string(),
        control_mode,
        pause_required,
        vague_acknowledgment_policy: "continue current phase; do not skip required gates or phases"
            .to_string(),
        state_file: state_path(project_root).display().to_string(),
    }
}

/// A guided phase boundary is reached when the current phase has produced a
/// result that the user can approve before advancing. This is true once the
/// phase's readiness gate passes. Phases that are still in progress (gate not
/// yet satisfied) are not boundaries: the work should continue, not pause.
fn at_phase_boundary(
    public_stage: &str,
    discovery_ready: bool,
    plan_ready: bool,
    review_ready: bool,
    qa_ready: bool,
) -> bool {
    match public_stage {
        "discover" | "research" => discovery_ready,
        "plan" => plan_ready,
        // Implement has no dedicated readiness gate here; reaching the
        // implement stage with a satisfied plan gate is the boundary before
        // Validate.
        "implement" => plan_ready,
        "review" => review_ready,
        "qa" => qa_ready,
        // Summary/ship are terminal-facing; gating happens upstream.
        _ => false,
    }
}

fn pause_required_from_state(state: &Value) -> bool {
    state
        .get("pause_reason")
        .is_some_and(|value| !value.is_null())
        || state
            .get("workflow_status")
            .and_then(Value::as_str)
            .is_some_and(|status| status == "paused")
}

fn allowed_next_action(
    public_stage: &str,
    workflow_active: bool,
    discovery_ready: bool,
    plan_ready: bool,
) -> &'static str {
    if !workflow_active {
        return "run_runtime_bootstrap";
    }
    match public_stage {
        "discover" | "research" if !discovery_ready => "complete_discovery_research_then_qualify",
        "discover" => "continue_discover_then_plan",
        "research" => "finish_research_then_plan",
        "plan" if plan_ready => "transition_to_implement",
        "plan" => "complete_plan_before_implementation",
        "implement" if plan_ready => "run_planning_gate_then_implement_smallest_slice",
        "implement" => "complete_plan_before_implementation",
        "review" => "validate_and_fix_actionable_findings",
        "qa" => "run_acceptance_and_integration_qa",
        "ship" => "prepare_verified_delivery_path",
        "summary" => "prepare_handoff_summary",
        _ => "start_or_resume_workflow",
    }
}

fn required_evidence(
    public_stage: &str,
    workflow_active: bool,
    discovery_ready: bool,
    plan_ready: bool,
) -> Vec<String> {
    let evidence: Vec<&str> = if !workflow_active {
        vec!["active .wannabuild/state.json runtime state"]
    } else {
        match public_stage {
            "discover" | "research" if !discovery_ready => vec![
                "requirements direction",
                "feasibility research",
                "alternatives/competition research",
                "failure forecast",
                "qualifying questions recorded or resolved",
            ],
            "discover" => vec!["requirements direction", "discovery readiness gate"],
            "research" => vec!["bounded research synthesis", "discovery readiness gate"],
            "plan" if !plan_ready => vec![
                ".wannabuild/spec/design.md",
                ".wannabuild/spec/tasks.md",
                "implementation verification plan",
            ],
            "plan" => vec!["plan readiness gate"],
            "implement" => vec![
                "assert-plan-ready pass",
                "task checkpoints",
                "task verification commands",
            ],
            "review" => vec![
                "review verdicts",
                "actionable findings fixed or accepted",
                "assert-review-ready pass",
            ],
            "qa" => vec![
                "QA summary",
                "acceptance criteria coverage",
                "integration behavior evidence",
                "assert-qa-ready pass",
            ],
            "ship" => vec![
                "delivery mode decision",
                "post-delivery CI status",
                "summary gate pass",
            ],
            "summary" => vec!["review ready", "QA ready", "handoff summary"],
            _ => vec!["concrete task or exploratory idea intent"],
        }
    };
    evidence
        .into_iter()
        .map(std::string::ToString::to_string)
        .collect()
}

fn next_handoff(
    public_stage: &str,
    workflow_active: bool,
    discovery_ready: bool,
    plan_ready: bool,
) -> &'static str {
    if !workflow_active {
        return "wannabuild";
    }
    match public_stage {
        "discover" | "research" if !discovery_ready => "wb-discover",
        "discover" | "research" => "wb-plan",
        "plan" if plan_ready => "wb-build",
        "plan" => "wb-plan",
        "implement" if plan_ready => "wb-review",
        "implement" => "wb-plan",
        "review" => "wb-qa",
        "qa" => "wb-ship",
        "ship" => "wb-ship",
        "summary" => "complete",
        _ => "wannabuild",
    }
}

pub fn render_text(context: &RuntimeContext) -> String {
    let first = if context.runtime_active {
        "WannaBuild runtime state is active."
    } else {
        "WannaBuild runtime state is inactive."
    };
    let mut lines = vec![
        first.to_string(),
        format!("- workflow_status: {}", context.workflow_status),
        format!("- public_stage: {}", context.public_stage),
        format!("- current_phase: {}", context.current_phase),
        format!("- phase_status: {}", context.phase_status),
        format!("- allowed_next_action: {}", context.allowed_next_action),
        format!("- control_mode: {}", context.control_mode),
    ];
    if context.pause_required {
        lines.push(
            "- pause_required: true (guided mode: stop at this phase boundary and get explicit user approval before advancing)"
                .to_string(),
        );
    }
    if !context.forbidden_actions.is_empty() {
        lines.push(format!(
            "- forbidden: {}",
            context.forbidden_actions.join(", ")
        ));
    }
    if !context.required_gates.is_empty() {
        lines.push(format!(
            "- required_gates: {}",
            context.required_gates.join(", ")
        ));
    }
    if !context.required_evidence.is_empty() {
        lines.push(format!(
            "- required_evidence: {}",
            context.required_evidence.join(", ")
        ));
    }
    lines.push(format!("- next_handoff: {}", context.next_handoff));
    lines.push(format!(
        "- vague_acknowledgment_policy: {}",
        context.vague_acknowledgment_policy
    ));
    lines.join("\n")
}

#[cfg(test)]
mod tests {
    use std::fs;

    use tempfile::tempdir;

    use crate::state;

    use super::*;

    #[test]
    fn context_reports_runtime_bootstrap_when_state_is_missing() {
        let dir = tempdir().unwrap();

        let context = build_context(dir.path());

        assert!(
            context
                .required_gates
                .contains(&"assert-workflow-active".to_string())
        );
        assert!(
            context
                .forbidden_actions
                .contains(&"host_only_wannabuild_claim".to_string())
        );
        assert_eq!(context.allowed_next_action, "run_runtime_bootstrap");
        assert_eq!(context.next_handoff, "wannabuild");
        assert!(context
            .required_evidence
            .contains(&"active .wannabuild/state.json runtime state".to_string()));
    }

    #[test]
    fn context_reports_plan_gate_for_incomplete_plan() {
        let dir = tempdir().unwrap();
        let mut value = state::ensure_state(dir.path()).unwrap();
        state::set_str(&mut value, "public_stage", "plan").unwrap();
        state::save_state(dir.path(), &value).unwrap();

        let context = build_context(dir.path());

        assert!(
            context
                .required_gates
                .contains(&"assert-plan-ready".to_string())
        );
        assert_eq!(
            context.allowed_next_action,
            "complete_plan_before_implementation"
        );
        assert_eq!(context.next_handoff, "wb-plan");
        assert!(context
            .required_evidence
            .contains(&".wannabuild/spec/design.md".to_string()));
    }

    #[test]
    fn context_reports_discovery_gate_before_plan() {
        let dir = tempdir().unwrap();
        state::ensure_state(dir.path()).unwrap();

        let context = build_context(dir.path());

        assert!(
            context
                .required_gates
                .contains(&"assert-discovery-ready".to_string())
        );
        assert!(
            context
                .forbidden_actions
                .contains(&"plan_before_discovery_ready".to_string())
        );
        assert_eq!(
            context.allowed_next_action,
            "complete_discovery_research_then_qualify"
        );
        assert_eq!(context.next_handoff, "wb-discover");
        assert!(context
            .required_evidence
            .contains(&"failure forecast".to_string()));
    }

    #[test]
    fn context_requires_pause_for_guided_control_mode() {
        let dir = tempdir().unwrap();
        let mut value = state::ensure_state(dir.path()).unwrap();
        state::set_str(&mut value, "public_stage", "implement").unwrap();
        state::set_str(&mut value, "control_mode", "guided").unwrap();
        state::save_state(dir.path(), &value).unwrap();
        fs::write(dir.path().join(".wannabuild/spec/design.md"), "design").unwrap();
        fs::write(dir.path().join(".wannabuild/spec/tasks.md"), "tasks").unwrap();

        let context = build_context(dir.path());

        assert_eq!(context.control_mode, "guided");
        assert!(
            context.pause_required,
            "guided mode must require a pause at the phase boundary"
        );
        assert!(render_text(&context).contains("pause_required: true"));
    }

    #[test]
    fn context_does_not_pause_for_autonomous_control_mode() {
        let dir = tempdir().unwrap();
        let mut value = state::ensure_state(dir.path()).unwrap();
        state::set_str(&mut value, "public_stage", "implement").unwrap();
        state::set_str(&mut value, "control_mode", "autonomous").unwrap();
        state::save_state(dir.path(), &value).unwrap();
        fs::write(dir.path().join(".wannabuild/spec/design.md"), "design").unwrap();
        fs::write(dir.path().join(".wannabuild/spec/tasks.md"), "tasks").unwrap();

        let context = build_context(dir.path());

        assert_eq!(context.control_mode, "autonomous");
        assert!(
            !context.pause_required,
            "autonomous mode must not force a per-boundary pause"
        );
    }

    #[test]
    fn context_does_not_pause_guided_mid_phase_before_boundary() {
        // A freshly initialized guided workflow sits at discover with the
        // discovery gate not yet satisfied. That is not a boundary, so it
        // must not pause -- the Discover interview should keep running.
        let dir = tempdir().unwrap();
        state::ensure_state(dir.path()).unwrap();

        let context = build_context(dir.path());

        assert_eq!(context.control_mode, "guided");
        assert!(
            !context.pause_required,
            "guided mode must not pause before the current phase reaches a boundary"
        );
    }

    #[test]
    fn at_phase_boundary_only_true_when_current_phase_is_ready() {
        // Boundary is reached only once the current phase's readiness gate
        // passes (an approvable result exists); in-progress phases are not.
        assert!(super::at_phase_boundary("plan", false, true, false, false));
        assert!(super::at_phase_boundary("implement", false, true, false, false));
        assert!(super::at_phase_boundary("discover", true, false, false, false));
        assert!(super::at_phase_boundary("review", false, false, true, false));
        assert!(super::at_phase_boundary("qa", false, false, false, true));
        // Not boundaries: phase not yet ready, or terminal-facing stage.
        assert!(!super::at_phase_boundary("discover", false, false, false, false));
        assert!(!super::at_phase_boundary("plan", false, false, false, false));
        assert!(!super::at_phase_boundary("summary", true, true, true, true));
    }

    #[test]
    fn context_allows_implementation_after_plan_artifacts() {
        let dir = tempdir().unwrap();
        let mut value = state::ensure_state(dir.path()).unwrap();
        state::set_str(&mut value, "public_stage", "implement").unwrap();
        state::save_state(dir.path(), &value).unwrap();
        fs::write(dir.path().join(".wannabuild/spec/design.md"), "design").unwrap();
        fs::write(dir.path().join(".wannabuild/spec/tasks.md"), "tasks").unwrap();

        let context = build_context(dir.path());

        assert!(context.required_gates.is_empty());
        assert_eq!(
            context.allowed_next_action,
            "run_planning_gate_then_implement_smallest_slice"
        );
        assert_eq!(context.next_handoff, "wb-review");
        assert!(context
            .required_evidence
            .contains(&"task checkpoints".to_string()));
    }
}
