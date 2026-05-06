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
    let plan_ready = gates::assert_plan_ready(project_root).is_ok();
    let pause_required = state
        .as_ref()
        .is_some_and(|value| pause_required_from_state(value));
    let mut forbidden_actions = Vec::new();
    let mut required_gates = Vec::new();
    if !plan_ready {
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
        allowed_next_action: allowed_next_action(&public_stage, plan_ready).to_string(),
        forbidden_actions,
        required_gates,
        pause_required,
        vague_acknowledgment_policy: "continue current phase; do not skip required gates or phases"
            .to_string(),
        state_file: state_path(project_root).display().to_string(),
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

fn allowed_next_action(public_stage: &str, plan_ready: bool) -> &'static str {
    match public_stage {
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
    ];
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
    }
}
