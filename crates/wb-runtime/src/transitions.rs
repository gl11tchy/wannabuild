use std::path::Path;

use serde::Serialize;
use serde_json::json;

use crate::errors::{Result, RuntimeError};
use crate::{events, gates, state};

#[derive(Debug, Clone, Serialize)]
pub struct TransitionOutcome {
    pub from: String,
    pub to: String,
    pub status: String,
    pub accepted: bool,
}

struct TransitionTarget {
    requested: String,
    public_stage: String,
    phase: String,
    internal_phase: bool,
}

pub fn transition(project_root: &Path, to: &str, status: &str) -> Result<TransitionOutcome> {
    validate_status(status)?;
    let mut current_state = state::ensure_state(project_root)?;
    let from = state::get_str(&current_state, "public_stage")
        .unwrap_or("discover")
        .to_string();
    let target = normalize_target(to)?;
    events::append_event(
        project_root,
        "transition_requested",
        json!({
            "from": from,
            "to": target.requested,
            "public_stage": target.public_stage,
            "phase": target.phase,
            "status": status
        }),
    )?;

    if let Err(error) = validate_transition(project_root, &current_state, &from, &target, status) {
        events::append_event(
            project_root,
            "transition_denied",
            json!({
                "from": from,
                "to": target.requested,
                "public_stage": target.public_stage,
                "phase": target.phase,
                "status": status,
                "reason": error.to_string()
            }),
        )?;
        return Err(error);
    }

    let timestamp = state::now()?;
    if target.requested == "complete" {
        state::set_str(&mut current_state, "workflow_status", "complete")?;
        state::set_str(&mut current_state, "phase_status", "complete")?;
        state::set_str(&mut current_state, "updated_at", &timestamp)?;
        state::append_public_stage_history(&mut current_state, "summary", "complete", &timestamp)?;
        events::append_event(
            project_root,
            "workflow_completed",
            json!({"status": status}),
        )?;
        state::save_state(project_root, &current_state)?;
        return Ok(TransitionOutcome {
            from,
            to: target.requested,
            status: status.to_string(),
            accepted: true,
        });
    }

    state::set_str(&mut current_state, "public_stage", &target.public_stage)?;
    state::set_str(
        &mut current_state,
        "workflow_status",
        workflow_status_for(status),
    )?;
    state::set_str(&mut current_state, "phase_status", status)?;
    state::set_str(&mut current_state, "current_phase", &target.phase)?;
    state::set_str(&mut current_state, "updated_at", &timestamp)?;
    if status != "blocked" {
        state::set_value(
            &mut current_state,
            "blocked_reason",
            serde_json::Value::Null,
        )?;
    }
    state::append_phase_history(&mut current_state, &target.phase, status, &timestamp)?;
    let public_status = public_history_status(project_root, &target, status, &current_state);
    state::append_public_stage_history(
        &mut current_state,
        &target.public_stage,
        &public_status,
        &timestamp,
    )?;
    state::save_state(project_root, &current_state)?;
    events::append_event(
        project_root,
        "transition_accepted",
        json!({
            "from": from,
            "to": target.requested,
            "public_stage": target.public_stage,
            "phase": target.phase,
            "status": status
        }),
    )?;
    Ok(TransitionOutcome {
        from,
        to: target.requested,
        status: status.to_string(),
        accepted: true,
    })
}

fn validate_transition(
    project_root: &Path,
    current_state: &serde_json::Value,
    from: &str,
    target: &TransitionTarget,
    status: &str,
) -> Result<()> {
    if blocked(current_state) && target.public_stage != from {
        return Err(RuntimeError::message(
            "Transition denied: current phase is blocked; resume or resolve blocker first",
        ));
    }
    if matches!(target.public_stage.as_str(), "plan" | "implement") {
        gates::assert_concrete_task(project_root)?;
    }
    if target.public_stage == "plan" && matches!(from, "discover" | "research") {
        gates::assert_discovery_ready(project_root)?;
    }
    if target.requested == "plan" && status == "complete" {
        gates::assert_plan_completion_evidence(project_root, current_state)?;
    }
    match target.phase.as_str() {
        "requirements" => return Ok(()),
        "design" | "tasks" if matches!(from, "discover" | "research" | "plan") => return Ok(()),
        "document" if matches!(from, "ship" | "summary") => {
            gates::assert_summary_ready(project_root)?;
            return Ok(());
        }
        _ => {}
    }
    match target.public_stage.as_str() {
        "discover" => Ok(()),
        "research" if matches!(from, "discover" | "research") => Ok(()),
        "plan" if matches!(from, "discover" | "research" | "plan") => Ok(()),
        "implement" if matches!(from, "plan" | "implement" | "review" | "qa") => {
            gates::assert_plan_ready(project_root)?;
            Ok(())
        }
        "review" if matches!(from, "implement" | "review") => Ok(()),
        "qa" if matches!(from, "review" | "qa") => {
            gates::assert_review_ready(project_root)?;
            Ok(())
        }
        "ship" if matches!(from, "qa" | "ship") => {
            gates::assert_qa_ready(project_root)?;
            Ok(())
        }
        "summary" if matches!(from, "ship" | "summary") => {
            gates::assert_summary_ready(project_root)?;
            Ok(())
        }
        "complete" if matches!(from, "summary") => {
            gates::assert_summary_ready(project_root)?;
            Ok(())
        }
        _ if from == target.public_stage => Ok(()),
        _ => Err(RuntimeError::message(format!(
            "Transition denied: cannot transition from {from} to {}",
            target.requested
        ))),
    }
}

fn blocked(state: &serde_json::Value) -> bool {
    state
        .get("blocked_reason")
        .is_some_and(|value| !value.is_null())
        || state
            .get("phase_status")
            .and_then(serde_json::Value::as_str)
            .is_some_and(|status| status == "blocked")
}

fn validate_status(status: &str) -> Result<()> {
    match status {
        "pending" | "in_progress" | "complete" | "blocked" | "paused" => Ok(()),
        _ => Err(RuntimeError::message(format!(
            "Unknown transition status: {status}"
        ))),
    }
}

fn normalize_target(stage: &str) -> Result<TransitionTarget> {
    let (public_stage, phase, internal_phase) = match stage {
        "requirements" => ("discover", "requirements", true),
        "design" => ("plan", "design", true),
        "tasks" => ("plan", "tasks", true),
        "document" => ("summary", "document", true),
        "discover" => ("discover", "requirements", false),
        "research" => ("research", "research", false),
        "plan" => ("plan", "tasks", false),
        "implement" => ("implement", "implement", false),
        "review" => ("review", "review", false),
        "qa" => ("qa", "qa", false),
        "ship" => ("ship", "ship", false),
        "summary" => ("summary", "document", false),
        "complete" => ("complete", "complete", false),
        _ => {
            return Err(RuntimeError::message(format!(
                "Unknown stage or phase: {stage}"
            )));
        }
    };
    Ok(TransitionTarget {
        requested: stage.to_string(),
        public_stage: public_stage.to_string(),
        phase: phase.to_string(),
        internal_phase,
    })
}

fn public_history_status(
    project_root: &Path,
    target: &TransitionTarget,
    status: &str,
    current_state: &serde_json::Value,
) -> String {
    if !target.internal_phase {
        return status.to_string();
    }
    if matches!(status, "blocked" | "paused") {
        return status.to_string();
    }
    if target.public_stage == "plan"
        && status == "complete"
        && !gates::plan_completion_evidence(project_root, current_state).is_empty()
    {
        return "complete".to_string();
    }
    "in_progress".to_string()
}

fn workflow_status_for(status: &str) -> &'static str {
    match status {
        "paused" => "paused",
        "blocked" => "blocked",
        "complete" | "pending" | "in_progress" => "in_progress",
        _ => "in_progress",
    }
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::path::Path;

    use tempfile::tempdir;

    use super::*;

    fn write_discovery_ready(project_root: &Path) {
        fs::create_dir_all(project_root.join(".wannabuild/outputs/discovery")).unwrap();
        fs::create_dir_all(project_root.join(".wannabuild/spec")).unwrap();
        fs::write(
            project_root.join(".wannabuild/outputs/discovery/feasibility.md"),
            "feasible",
        )
        .unwrap();
        fs::write(
            project_root.join(".wannabuild/outputs/discovery/alternatives-competition.md"),
            "alternatives",
        )
        .unwrap();
        fs::write(
            project_root.join(".wannabuild/outputs/discovery/failure-forecast.md"),
            "forecast",
        )
        .unwrap();
        fs::write(
            project_root.join(".wannabuild/outputs/discovery/followup-questions.md"),
            "questions",
        )
        .unwrap();
        fs::write(
            project_root.join(".wannabuild/spec/requirements.md"),
            "requirements",
        )
        .unwrap();
        let mut value = state::ensure_state(project_root).unwrap();
        state::set_value(
            &mut value,
            "discovery",
            json!({
                "interview": {"status": "complete"},
                "research": {
                    "feasibility": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/feasibility.md"},
                    "alternatives_competition": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/alternatives-competition.md"},
                    "failure_forecast": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/failure-forecast.md"}
                },
                "followup_questions": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/followup-questions.md"},
                "synthesis": {"status": "complete", "artifact": ".wannabuild/spec/requirements.md"}
            }),
        )
        .unwrap();
        state::save_state(project_root, &value).unwrap();
    }

    #[test]
    fn transition_denies_plan_before_discovery_ready() {
        let dir = tempdir().unwrap();
        fs::create_dir_all(dir.path().join(".wannabuild/spec")).unwrap();
        fs::write(dir.path().join(".wannabuild/spec/requirements.md"), "req").unwrap();

        let err = transition(dir.path(), "plan", "in_progress")
            .unwrap_err()
            .to_string();

        assert!(err.contains("Discovery gate failed"));
    }

    #[test]
    fn transition_denies_implementation_before_plan() {
        let dir = tempdir().unwrap();
        fs::create_dir_all(dir.path().join(".wannabuild/spec")).unwrap();
        fs::write(dir.path().join(".wannabuild/spec/requirements.md"), "req").unwrap();
        let mut value = state::ensure_state(dir.path()).unwrap();
        state::set_str(&mut value, "public_stage", "plan").unwrap();
        state::save_state(dir.path(), &value).unwrap();

        let err = transition(dir.path(), "implement", "in_progress")
            .unwrap_err()
            .to_string();

        assert!(err.contains("Plan gate failed"));
    }

    #[test]
    fn transition_accepts_implementation_after_plan() {
        let dir = tempdir().unwrap();
        fs::create_dir_all(dir.path().join(".wannabuild/spec")).unwrap();
        fs::write(dir.path().join(".wannabuild/spec/requirements.md"), "req").unwrap();
        fs::write(dir.path().join(".wannabuild/spec/design.md"), "design").unwrap();
        fs::write(dir.path().join(".wannabuild/spec/tasks.md"), "tasks").unwrap();
        let mut value = state::ensure_state(dir.path()).unwrap();
        state::set_str(&mut value, "public_stage", "plan").unwrap();
        state::save_state(dir.path(), &value).unwrap();

        let outcome = transition(dir.path(), "implement", "in_progress").unwrap();

        assert!(outcome.accepted);
        assert_eq!(outcome.to, "implement");
    }

    #[test]
    fn transition_denies_plan_complete_without_real_plan_evidence() {
        let dir = tempdir().unwrap();
        write_discovery_ready(dir.path());

        let err = transition(dir.path(), "plan", "complete")
            .unwrap_err()
            .to_string();

        assert!(err.contains("Plan completion denied"));
        let state = state::load_state(dir.path()).unwrap().unwrap();
        assert!(!state::has_complete(
            state.get("public_stage_history"),
            "stage",
            "plan"
        ));
    }

    #[test]
    fn transition_allows_plan_in_progress_after_discovery_without_plan_evidence() {
        let dir = tempdir().unwrap();
        write_discovery_ready(dir.path());

        let outcome = transition(dir.path(), "plan", "in_progress").unwrap();

        assert!(outcome.accepted);
        assert_eq!(outcome.to, "plan");
    }

    #[test]
    fn internal_design_and_tasks_transitions_preserve_public_plan_stage() {
        let dir = tempdir().unwrap();
        write_discovery_ready(dir.path());

        let design = transition(dir.path(), "design", "complete").unwrap();
        assert_eq!(design.to, "design");
        let state = state::load_state(dir.path()).unwrap().unwrap();
        assert_eq!(state["public_stage"], "plan");
        assert_eq!(state["current_phase"], "design");
        assert!(state::has_complete(
            state.get("phase_history"),
            "phase",
            "design"
        ));
        assert!(!state::has_complete(
            state.get("public_stage_history"),
            "stage",
            "plan"
        ));

        let tasks = transition(dir.path(), "tasks", "complete").unwrap();
        assert_eq!(tasks.to, "tasks");
        let state = state::load_state(dir.path()).unwrap().unwrap();
        assert_eq!(state["public_stage"], "plan");
        assert_eq!(state["current_phase"], "tasks");
        assert!(state::has_complete(
            state.get("phase_history"),
            "phase",
            "tasks"
        ));
        assert!(state::has_complete(
            state.get("public_stage_history"),
            "stage",
            "plan"
        ));
    }
}
