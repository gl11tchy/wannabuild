use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;

use serde_json::Value;

use crate::errors::{Result, RuntimeError};
use crate::events;
use crate::state::{has_complete, load_state};

const REQUIRED_REVIEWERS: &[&str] = &[
    "wb-security-reviewer",
    "wb-performance-reviewer",
    "wb-architecture-reviewer",
    "wb-testing-reviewer",
    "wb-integration-tester",
    "wb-code-simplifier",
];
const INTEGRATION_TESTER: &str = "wb-integration-tester";
const DISCOVERY_REQUIRED_ARTIFACTS: &[(&str, &[&str], &str)] = &[
    (
        "feasibility",
        &["research", "feasibility"],
        ".wannabuild/outputs/discovery/feasibility.md",
    ),
    (
        "alternatives_competition",
        &["research", "alternatives_competition"],
        ".wannabuild/outputs/discovery/alternatives-competition.md",
    ),
    (
        "failure_forecast",
        &["research", "failure_forecast"],
        ".wannabuild/outputs/discovery/failure-forecast.md",
    ),
    (
        "followup_questions",
        &["followup_questions"],
        ".wannabuild/outputs/discovery/followup-questions.md",
    ),
    (
        "synthesis",
        &["synthesis"],
        ".wannabuild/spec/requirements.md",
    ),
];

#[derive(Debug, Clone)]
struct ReviewVerdict {
    agent: String,
    status: String,
    source: String,
    iteration: u64,
    timestamp: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GatePass {
    pub gate: &'static str,
    pub evidence: Vec<String>,
}

impl GatePass {
    pub fn message(&self) -> String {
        if self.evidence.is_empty() {
            format!("Gate OK: {}", self.gate)
        } else {
            format!("{} gate OK: {}", title(self.gate), self.evidence.join(", "))
        }
    }
}

fn title(value: &str) -> String {
    let mut chars = value.chars();
    match chars.next() {
        Some(first) => format!("{}{}", first.to_uppercase(), chars.as_str()),
        None => String::new(),
    }
}

pub fn assert_concrete_task(project_root: &Path) -> Result<GatePass> {
    let state = load_state(project_root)?.unwrap_or(Value::Object(Default::default()));
    let spec = project_root.join(".wannabuild/spec/requirements.md");
    let mut evidence = Vec::new();
    if spec.is_file() && !fs::read_to_string(&spec)?.trim().is_empty() {
        evidence.push("requirements.md".to_string());
    }
    if state.get("concrete_task").and_then(Value::as_bool) == Some(true) {
        evidence.push("state.concrete_task".to_string());
    }
    for key in ["goal", "task", "user_request"] {
        if state
            .get(key)
            .and_then(Value::as_str)
            .map(|value| !value.trim().is_empty())
            .unwrap_or(false)
        {
            evidence.push(format!("state.{key}"));
        }
    }
    if has_complete(state.get("public_stage_history"), "stage", "discover") {
        evidence.push("public_stage_history.discover".to_string());
    }
    if evidence.is_empty() {
        return Err(RuntimeError::message(
            "Concrete task gate failed: Tell me what you want to build or change.",
        ));
    }
    Ok(GatePass {
        gate: "concrete-task",
        evidence,
    })
}

pub fn assert_workflow_active(project_root: &Path) -> Result<GatePass> {
    let wb_dir = project_root.join(".wannabuild");
    let mut missing = Vec::new();
    for artifact in [
        ".wannabuild",
        ".wannabuild/spec",
        ".wannabuild/checkpoints",
        ".wannabuild/review",
        ".wannabuild/outputs",
        ".wannabuild/state.json",
    ] {
        let path = project_root.join(artifact);
        if !path.exists() {
            missing.push(artifact.to_string());
        }
    }
    if !missing.is_empty() {
        return Err(RuntimeError::message(format!(
            "WannaBuild workflow inactive: missing runtime artifacts: {}. Run wb-runtime init --project <project_root> before planning or implementation.",
            missing.join(", ")
        )));
    }

    let state = load_state(project_root)?
        .ok_or_else(|| RuntimeError::message("WannaBuild workflow inactive: state.json missing"))?;
    let mut invalid = Vec::new();
    for key in ["public_stage", "workflow_status"] {
        if state
            .get(key)
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .is_none()
        {
            invalid.push(format!("state.{key}"));
        }
    }
    if !invalid.is_empty() {
        return Err(RuntimeError::message(format!(
            "WannaBuild workflow inactive: invalid runtime state: {}",
            invalid.join(", ")
        )));
    }

    let mut evidence = vec![
        wb_dir.display().to_string(),
        "state.json".to_string(),
        "spec/".to_string(),
        "checkpoints/".to_string(),
        "review/".to_string(),
        "outputs/".to_string(),
    ];
    if let Some(stage) = state.get("public_stage").and_then(Value::as_str) {
        evidence.push(format!("public_stage={stage}"));
    }
    if let Some(status) = state.get("workflow_status").and_then(Value::as_str) {
        evidence.push(format!("workflow_status={status}"));
    }

    Ok(GatePass {
        gate: "workflow-active",
        evidence,
    })
}

pub fn assert_discovery_ready(project_root: &Path) -> Result<GatePass> {
    let state = load_state(project_root)?
        .ok_or_else(|| RuntimeError::message("Discovery gate failed: state.json missing"))?;
    let discovery = state
        .get("discovery")
        .ok_or_else(|| RuntimeError::message("Discovery gate failed: state.discovery missing"))?;
    let mut evidence = Vec::new();
    let mut missing = Vec::new();

    require_discovery_status(
        discovery,
        "interview",
        &["interview"],
        &mut evidence,
        &mut missing,
    );
    for (label, path, artifact) in DISCOVERY_REQUIRED_ARTIFACTS {
        require_discovery_status(discovery, label, path, &mut evidence, &mut missing);
        require_discovery_artifact(
            project_root,
            discovery,
            label,
            path,
            artifact,
            &mut evidence,
            &mut missing,
        )?;
    }

    if !missing.is_empty() {
        return Err(RuntimeError::message(format!(
            "Discovery gate failed: complete Discovery before Plan (missing: {})",
            missing.join(", ")
        )));
    }

    Ok(GatePass {
        gate: "discovery",
        evidence,
    })
}

pub fn assert_plan_ready(project_root: &Path) -> Result<GatePass> {
    let state = load_state(project_root)?.unwrap_or(Value::Object(Default::default()));
    let real_evidence = plan_completion_evidence(project_root, &state);
    let public_plan_complete = has_complete(state.get("public_stage_history"), "stage", "plan");
    let mut evidence = real_evidence;
    if public_plan_complete && !evidence.is_empty() {
        evidence.push("public_stage_history.plan".to_string());
    }
    if evidence.is_empty() {
        return Err(RuntimeError::message(
            "Plan gate failed: complete Plan before implementation (requires .wannabuild/spec/design.md and .wannabuild/spec/tasks.md, or completed design and tasks phase history in .wannabuild/state.json)",
        ));
    }
    Ok(GatePass {
        gate: "plan",
        evidence,
    })
}

pub fn assert_plan_completion_evidence(project_root: &Path, state: &Value) -> Result<GatePass> {
    let evidence = plan_completion_evidence(project_root, state);
    if evidence.is_empty() {
        return Err(RuntimeError::message(
            "Plan completion denied: real plan evidence is required before marking Plan complete (requires .wannabuild/spec/design.md and .wannabuild/spec/tasks.md, or completed design and tasks phase history)",
        ));
    }
    Ok(GatePass {
        gate: "plan-completion",
        evidence,
    })
}

pub(crate) fn plan_completion_evidence(project_root: &Path, state: &Value) -> Vec<String> {
    let spec = project_root.join(".wannabuild/spec");
    let artifacts_ready = spec.join("design.md").is_file() && spec.join("tasks.md").is_file();
    let phase_plan_complete = has_complete(state.get("phase_history"), "phase", "design")
        && has_complete(state.get("phase_history"), "phase", "tasks");
    let mut evidence = Vec::new();
    if artifacts_ready {
        evidence.push("design.md+tasks.md".to_string());
    }
    if phase_plan_complete {
        evidence.push("phase_history.design+tasks".to_string());
    }
    evidence
}

fn require_discovery_status(
    discovery: &Value,
    label: &str,
    path: &[&str],
    evidence: &mut Vec<String>,
    missing: &mut Vec<String>,
) {
    if status_complete(value_at_path(discovery, path)) {
        evidence.push(format!("state.discovery.{label}.status"));
    } else {
        missing.push(format!("state.discovery.{label}.status=complete"));
    }
}

fn require_discovery_artifact(
    project_root: &Path,
    discovery: &Value,
    label: &str,
    path: &[&str],
    artifact: &str,
    evidence: &mut Vec<String>,
    missing: &mut Vec<String>,
) -> Result<()> {
    let configured = value_at_path(discovery, path)
        .and_then(|value| value.get("artifact"))
        .and_then(Value::as_str);
    if configured == Some(artifact) {
        evidence.push(format!("state.discovery.{label}.artifact"));
    } else {
        missing.push(format!("state.discovery.{label}.artifact={artifact}"));
    }

    let artifact_path = project_root.join(artifact);
    if artifact_path.is_file() && !fs::read_to_string(&artifact_path)?.trim().is_empty() {
        evidence.push(artifact.to_string());
    } else {
        missing.push(artifact.to_string());
    }
    Ok(())
}

fn value_at_path<'a>(value: &'a Value, path: &[&str]) -> Option<&'a Value> {
    let mut current = value;
    for key in path {
        current = current.get(*key)?;
    }
    Some(current)
}

fn status_complete(value: Option<&Value>) -> bool {
    value
        .and_then(|item| item.get("status"))
        .and_then(Value::as_str)
        == Some("complete")
}

pub fn assert_review_ready(project_root: &Path) -> Result<GatePass> {
    let mut required = required_reviewers(project_root);
    required.insert(INTEGRATION_TESTER.to_string());
    let mut verdicts = latest_loop_state_verdicts(project_root)?
        .map(|(active_reviewers, verdicts)| {
            if !active_reviewers.is_empty() {
                required = active_reviewers;
                required.insert(INTEGRATION_TESTER.to_string());
            }
            verdicts
        })
        .unwrap_or_default();
    if verdicts.is_empty() || required.iter().any(|agent| !verdicts.contains_key(agent)) {
        let file_verdicts = latest_file_verdicts(project_root)?;
        for agent in &required {
            if let Some(verdict) = file_verdicts.get(agent) {
                verdicts
                    .entry(agent.clone())
                    .or_insert_with(|| verdict.clone());
            }
        }
    }

    let seen = verdicts.keys().cloned().collect::<BTreeSet<_>>();
    let mut failures = Vec::new();
    for agent in &required {
        if let Some(verdict) = verdicts.get(agent) {
            if !verdict.status.eq_ignore_ascii_case("PASS") {
                failures.push(format!(
                    "{}:{}:{}",
                    verdict.source, verdict.agent, verdict.status
                ));
            }
        }
    }
    let missing = required.difference(&seen).cloned().collect::<Vec<_>>();
    if !missing.is_empty() {
        return Err(RuntimeError::message(format!(
            "Review gate failed: Missing required review verdicts: {}",
            missing.join(", ")
        )));
    }
    if !failures.is_empty() {
        return Err(RuntimeError::message(format!(
            "Review gate failed: Non-passing review verdicts: {}",
            failures.join(", ")
        )));
    }
    Ok(GatePass {
        gate: "review",
        evidence: vec!["latest review verdicts PASS".to_string()],
    })
}

fn latest_loop_state_verdicts(
    project_root: &Path,
) -> Result<Option<(BTreeSet<String>, BTreeMap<String, ReviewVerdict>)>> {
    let loop_state = project_root.join(".wannabuild/loop-state.json");
    if !loop_state.is_file() {
        return Ok(None);
    }
    let value = serde_json::from_str::<Value>(&fs::read_to_string(loop_state)?)?;
    let Some(latest) = value
        .get("iterations")
        .and_then(Value::as_array)
        .and_then(|iterations| {
            iterations
                .iter()
                .max_by_key(|item| item.get("iteration").and_then(Value::as_u64).unwrap_or(0))
        })
    else {
        return Ok(None);
    };
    let active_reviewers = latest
        .get("active_reviewers")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(Value::as_str)
                .map(ToString::to_string)
                .collect::<BTreeSet<_>>()
        })
        .unwrap_or_default();
    let iteration = latest
        .get("iteration")
        .and_then(Value::as_u64)
        .unwrap_or_default();
    let timestamp = latest
        .get("timestamp")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    let verdicts = latest
        .get("verdicts")
        .and_then(Value::as_object)
        .map(|items| {
            items
                .iter()
                .filter_map(|(agent, payload)| {
                    review_verdict_from_payload(
                        payload,
                        agent,
                        format!("loop-state.json:iteration-{iteration}"),
                        iteration,
                        timestamp.clone(),
                    )
                })
                .map(|verdict| (verdict.agent.clone(), verdict))
                .collect::<BTreeMap<_, _>>()
        })
        .unwrap_or_default();
    if verdicts.is_empty() {
        Ok(None)
    } else {
        Ok(Some((active_reviewers, verdicts)))
    }
}

fn latest_file_verdicts(project_root: &Path) -> Result<BTreeMap<String, ReviewVerdict>> {
    let review_dir = project_root.join(".wannabuild/review");
    if !review_dir.is_dir() {
        return Err(RuntimeError::message(format!(
            "Review gate failed: Missing review directory: {}",
            review_dir.display()
        )));
    }
    let files = fs::read_dir(&review_dir)?
        .filter_map(|entry| entry.ok().map(|entry| entry.path()))
        .filter(|path| path.extension().and_then(|value| value.to_str()) == Some("json"))
        .collect::<Vec<_>>();
    if files.is_empty() {
        return Err(RuntimeError::message(format!(
            "Review gate failed: No review verdict files found in {}",
            review_dir.display()
        )));
    }

    let mut verdicts = BTreeMap::<String, ReviewVerdict>::new();
    for path in files {
        let payload: Value = serde_json::from_str(&fs::read_to_string(&path)?)?;
        let source = path
            .file_name()
            .and_then(|value| value.to_str())
            .unwrap_or("review.json")
            .to_string();
        let iteration = payload
            .get("iteration")
            .and_then(Value::as_u64)
            .unwrap_or_else(|| iteration_from_path(&path));
        let timestamp = payload
            .get("timestamp")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string();
        let Some(verdict) =
            review_verdict_from_payload(&payload, "unknown", source, iteration, timestamp)
        else {
            continue;
        };
        let replace = verdicts.get(&verdict.agent).is_none_or(|existing| {
            (
                verdict.iteration,
                verdict.timestamp.as_str(),
                verdict.source.as_str(),
            ) >= (
                existing.iteration,
                existing.timestamp.as_str(),
                existing.source.as_str(),
            )
        });
        if replace {
            verdicts.insert(verdict.agent.clone(), verdict);
        }
    }
    Ok(verdicts)
}

fn review_verdict_from_payload(
    payload: &Value,
    fallback_agent: &str,
    source: String,
    iteration: u64,
    timestamp: String,
) -> Option<ReviewVerdict> {
    let agent = payload
        .get("agent")
        .and_then(Value::as_str)
        .unwrap_or(fallback_agent);
    if agent == "unknown" || agent.trim().is_empty() {
        return None;
    }
    Some(ReviewVerdict {
        agent: agent.to_string(),
        status: payload
            .get("status")
            .and_then(Value::as_str)
            .unwrap_or("UNKNOWN")
            .to_string(),
        source,
        iteration,
        timestamp,
    })
}

fn iteration_from_path(path: &Path) -> u64 {
    let Some(name) = path.file_name().and_then(|value| value.to_str()) else {
        return 0;
    };
    for marker in ["iter-", "iter_"] {
        if let Some(index) = name.find(marker) {
            let digits = name[index + marker.len()..]
                .chars()
                .take_while(|ch| ch.is_ascii_digit())
                .collect::<String>();
            if let Ok(iteration) = digits.parse::<u64>() {
                return iteration;
            }
        }
    }
    0
}

pub fn assert_qa_ready(project_root: &Path) -> Result<GatePass> {
    let qa_summary = project_root.join(".wannabuild/outputs/qa-summary.md");
    if !qa_summary.is_file() {
        return Err(RuntimeError::message(format!(
            "QA gate failed: Missing QA summary: {}",
            qa_summary.display()
        )));
    }
    if let Some(reason) = qa_failure_reason(project_root, &qa_summary)? {
        return Err(RuntimeError::message(format!("QA gate failed: {reason}")));
    }
    let evidence = qa_pass_evidence(project_root, &qa_summary)?;
    Ok(GatePass {
        gate: "qa",
        evidence,
    })
}

fn qa_failure_reason(project_root: &Path, qa_summary: &Path) -> Result<Option<String>> {
    if let Some(state) = load_state(project_root)? {
        if qa_current_state_failed(&state) {
            return Ok(Some(
                "QA state is failed or blocked; resolve QA before shipping".to_string(),
            ));
        }
        if let Some(status) =
            latest_history_status(state.get("public_stage_history"), "stage", "qa")
                .or_else(|| latest_history_status(state.get("phase_history"), "phase", "qa"))
        {
            if is_failure_status(status) {
                return Ok(Some(format!("latest QA history status is {status}")));
            }
        }
    }
    if let Some(marker) = qa_summary_failure_marker(qa_summary)? {
        return Ok(Some(marker));
    }
    let latest_qa_event = events::list_events(project_root, None)?
        .into_iter()
        .filter(|event| matches!(event.event_type.as_str(), "qa_failed" | "qa_passed"))
        .last();
    if let Some(event) = latest_qa_event {
        if event.event_type == "qa_failed" {
            return Ok(Some(format!("latest QA event is qa_failed ({})", event.id)));
        }
    }
    Ok(None)
}

fn qa_pass_evidence(project_root: &Path, qa_summary: &Path) -> Result<Vec<String>> {
    let mut evidence = vec!["qa-summary.md".to_string()];
    let latest_qa_event = events::list_events(project_root, None)?
        .into_iter()
        .filter(|event| matches!(event.event_type.as_str(), "qa_failed" | "qa_passed"))
        .last();
    if qa_summary_has_pass_evidence(qa_summary)? {
        if let Some(event) = latest_qa_event {
            if event.event_type == "qa_passed" {
                evidence.push(format!("latest QA event is qa_passed ({})", event.id));
            }
        }
        evidence
            .push("qa-summary PASS marker with acceptance and integration coverage".to_string());
        return Ok(evidence);
    }
    Err(RuntimeError::message(
        "QA gate failed: QA summary lacks positive PASS evidence with acceptance and integration coverage",
    ))
}

fn qa_current_state_failed(state: &Value) -> bool {
    let qa_active = state.get("public_stage").and_then(Value::as_str) == Some("qa")
        || state.get("current_phase").and_then(Value::as_str) == Some("qa");
    qa_active
        && (state
            .get("phase_status")
            .and_then(Value::as_str)
            .is_some_and(is_failure_status)
            || state
                .get("workflow_status")
                .and_then(Value::as_str)
                .is_some_and(is_failure_status))
}

fn latest_history_status<'a>(
    history: Option<&'a Value>,
    key: &str,
    value: &str,
) -> Option<&'a str> {
    history.and_then(Value::as_array).and_then(|items| {
        items.iter().rev().find_map(|item| {
            if item.get(key).and_then(Value::as_str) == Some(value) {
                item.get("status").and_then(Value::as_str)
            } else {
                None
            }
        })
    })
}

fn is_failure_status(status: &str) -> bool {
    matches!(status, "blocked" | "failed" | "fail" | "failure")
}

fn qa_summary_failure_marker(qa_summary: &Path) -> Result<Option<String>> {
    let raw = fs::read_to_string(qa_summary)?;
    for line in raw.lines() {
        let Some((field, value)) = qa_summary_field(line) else {
            continue;
        };
        if is_status_field(&field)
            && value
                .split(|ch: char| !ch.is_ascii_alphanumeric())
                .any(|token| is_failure_status(token.to_ascii_lowercase().as_str()))
        {
            return Ok(Some(format!(
                "QA summary marks {} as {}",
                field,
                value.trim()
            )));
        }
    }
    Ok(None)
}

fn qa_summary_has_pass_evidence(qa_summary: &Path) -> Result<bool> {
    let raw = fs::read_to_string(qa_summary)?;
    let mut pass_marker = false;
    let mut acceptance_coverage = false;
    let mut integration_coverage = false;
    for line in raw.lines() {
        let Some((field, value)) = qa_summary_field(line) else {
            continue;
        };
        if is_status_field(&field) && value_is_positive(&value) {
            pass_marker = true;
        }
        let normalized = normalized_field(&field);
        if normalized.contains("acceptance") && value_is_positive(&value) {
            acceptance_coverage = true;
        }
        if normalized.contains("integration") && value_is_positive(&value) {
            integration_coverage = true;
        }
    }
    Ok(pass_marker && acceptance_coverage && integration_coverage)
}

fn qa_summary_field(line: &str) -> Option<(String, String)> {
    let line = line.trim().trim_start_matches(['-', '*', '#', ' ']).trim();
    let (field, value) = line.split_once(':')?;
    Some((field.trim().to_ascii_lowercase(), value.trim().to_string()))
}

fn is_status_field(field: &str) -> bool {
    matches!(
        normalized_field(field).as_str(),
        "status" | "qastatus" | "result" | "verdict"
    )
}

fn normalized_field(field: &str) -> String {
    field
        .chars()
        .filter(|ch| ch.is_ascii_alphanumeric())
        .collect::<String>()
        .to_ascii_lowercase()
}

fn value_is_positive(value: &str) -> bool {
    let tokens = value
        .split(|ch: char| !ch.is_ascii_alphanumeric())
        .filter(|token| !token.is_empty())
        .map(str::to_ascii_lowercase)
        .collect::<Vec<_>>();
    let negative = tokens.iter().any(|token| {
        matches!(
            token.as_str(),
            "blocked"
                | "fail"
                | "failed"
                | "failure"
                | "missing"
                | "no"
                | "none"
                | "not"
                | "pending"
                | "todo"
        )
    });
    !negative
        && tokens.iter().any(|token| {
            matches!(
                token.as_str(),
                "checked"
                    | "complete"
                    | "covered"
                    | "ok"
                    | "pass"
                    | "passed"
                    | "success"
                    | "successful"
                    | "validated"
                    | "verified"
            )
        })
}

pub fn assert_summary_ready(project_root: &Path) -> Result<GatePass> {
    assert_review_ready(project_root)?;
    assert_qa_ready(project_root)?;
    if let Some(state) = load_state(project_root)? {
        let blocked = state
            .get("blocked_reason")
            .is_some_and(|value| !value.is_null())
            || state
                .get("phase_status")
                .and_then(Value::as_str)
                .is_some_and(|value| value == "blocked")
            || state
                .get("workflow_status")
                .and_then(Value::as_str)
                .is_some_and(|value| value == "blocked");
        if blocked {
            return Err(RuntimeError::message(
                "Summary gate failed: workflow is blocked; resolve the blocker before summary",
            ));
        }
    }
    Ok(GatePass {
        gate: "summary",
        evidence: vec!["review ready".to_string(), "qa ready".to_string()],
    })
}

fn required_reviewers(project_root: &Path) -> BTreeSet<String> {
    let loop_state = project_root.join(".wannabuild/loop-state.json");
    if let Ok(raw) = fs::read_to_string(loop_state) {
        if let Ok(value) = serde_json::from_str::<Value>(&raw) {
            if let Some(iterations) = value.get("iterations").and_then(Value::as_array) {
                if let Some(latest) = iterations
                    .iter()
                    .max_by_key(|item| item.get("iteration").and_then(Value::as_u64).unwrap_or(0))
                {
                    if let Some(active) = latest.get("active_reviewers").and_then(Value::as_array) {
                        let required = active
                            .iter()
                            .filter_map(Value::as_str)
                            .map(ToString::to_string)
                            .collect::<BTreeSet<_>>();
                        if !required.is_empty() {
                            return required;
                        }
                    }
                }
            }
        }
    }
    REQUIRED_REVIEWERS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
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
        fs::write(
            project_root.join(".wannabuild/state.json"),
            r#"{
  "discovery": {
    "interview": {"status": "complete"},
    "research": {
      "feasibility": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/feasibility.md"},
      "alternatives_competition": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/alternatives-competition.md"},
      "failure_forecast": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/failure-forecast.md"}
    },
    "followup_questions": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/followup-questions.md"},
    "synthesis": {"status": "complete", "artifact": ".wannabuild/spec/requirements.md"}
  }
}"#,
        )
        .unwrap();
    }

    #[test]
    fn discovery_gate_fails_without_interview_evidence() {
        let dir = tempdir().unwrap();
        fs::create_dir_all(dir.path().join(".wannabuild")).unwrap();
        fs::write(
            dir.path().join(".wannabuild/state.json"),
            r#"{"discovery":{}}"#,
        )
        .unwrap();

        let err = assert_discovery_ready(dir.path()).unwrap_err().to_string();

        assert!(err.contains("state.discovery.interview.status=complete"));
    }

    #[test]
    fn discovery_gate_requires_research_artifacts() {
        let dir = tempdir().unwrap();
        write_discovery_ready(dir.path());
        fs::remove_file(
            dir.path()
                .join(".wannabuild/outputs/discovery/feasibility.md"),
        )
        .unwrap();

        let err = assert_discovery_ready(dir.path()).unwrap_err().to_string();

        assert!(err.contains(".wannabuild/outputs/discovery/feasibility.md"));
    }

    #[test]
    fn discovery_gate_requires_followup_and_synthesis() {
        let dir = tempdir().unwrap();
        write_discovery_ready(dir.path());
        fs::write(
            dir.path().join(".wannabuild/state.json"),
            r#"{
  "discovery": {
    "interview": {"status": "complete"},
    "research": {
      "feasibility": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/feasibility.md"},
      "alternatives_competition": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/alternatives-competition.md"},
      "failure_forecast": {"status": "complete", "artifact": ".wannabuild/outputs/discovery/failure-forecast.md"}
    }
  }
}"#,
        )
        .unwrap();

        let err = assert_discovery_ready(dir.path()).unwrap_err().to_string();

        assert!(err.contains("state.discovery.followup_questions.status=complete"));
        assert!(err.contains("state.discovery.synthesis.status=complete"));
    }

    #[test]
    fn discovery_gate_passes_with_required_bundle() {
        let dir = tempdir().unwrap();
        write_discovery_ready(dir.path());

        let pass = assert_discovery_ready(dir.path()).unwrap();

        assert_eq!(pass.gate, "discovery");
        assert!(
            pass.evidence
                .contains(&".wannabuild/spec/requirements.md".to_string())
        );
    }

    #[test]
    fn plan_gate_passes_with_artifacts() {
        let dir = tempdir().unwrap();
        fs::create_dir_all(dir.path().join(".wannabuild/spec")).unwrap();
        fs::write(dir.path().join(".wannabuild/spec/design.md"), "design").unwrap();
        fs::write(dir.path().join(".wannabuild/spec/tasks.md"), "tasks").unwrap();

        let pass = assert_plan_ready(dir.path()).unwrap();

        assert_eq!(pass.evidence, vec!["design.md+tasks.md"]);
    }

    #[test]
    fn plan_gate_fails_without_evidence() {
        let dir = tempdir().unwrap();

        let err = assert_plan_ready(dir.path()).unwrap_err().to_string();

        assert!(err.contains("Plan gate failed"));
    }

    #[test]
    fn plan_gate_rejects_public_marker_without_real_evidence() {
        let dir = tempdir().unwrap();
        fs::create_dir_all(dir.path().join(".wannabuild")).unwrap();
        fs::write(
            dir.path().join(".wannabuild/state.json"),
            r#"{"public_stage_history":[{"stage":"plan","status":"complete"}]}"#,
        )
        .unwrap();

        let err = assert_plan_ready(dir.path()).unwrap_err().to_string();

        assert!(err.contains("Plan gate failed"));
    }

    #[test]
    fn qa_gate_requires_summary() {
        let dir = tempdir().unwrap();

        let err = assert_qa_ready(dir.path()).unwrap_err().to_string();

        assert!(err.contains("Missing QA summary"));
    }

    #[test]
    fn qa_gate_rejects_failed_summary_marker() {
        let dir = tempdir().unwrap();
        fs::create_dir_all(dir.path().join(".wannabuild/outputs")).unwrap();
        fs::write(
            dir.path().join(".wannabuild/outputs/qa-summary.md"),
            "# QA\n\nstatus: failed\n",
        )
        .unwrap();

        let err = assert_qa_ready(dir.path()).unwrap_err().to_string();

        assert!(err.contains("QA summary marks status as failed"));
    }

    #[test]
    fn qa_gate_rejects_summary_without_positive_evidence() {
        let dir = tempdir().unwrap();
        fs::create_dir_all(dir.path().join(".wannabuild/outputs")).unwrap();
        fs::write(dir.path().join(".wannabuild/outputs/qa-summary.md"), "# QA").unwrap();

        let err = assert_qa_ready(dir.path()).unwrap_err().to_string();

        assert!(err.contains("lacks positive PASS evidence"));
    }

    #[test]
    fn qa_gate_accepts_structured_pass_summary() {
        let dir = tempdir().unwrap();
        fs::create_dir_all(dir.path().join(".wannabuild/outputs")).unwrap();
        fs::write(
            dir.path().join(".wannabuild/outputs/qa-summary.md"),
            "# QA\n\nstatus: PASS\nacceptance_coverage: covered\nintegration_coverage: covered\n",
        )
        .unwrap();

        assert!(assert_qa_ready(dir.path()).is_ok());
    }

    #[test]
    fn qa_gate_rejects_latest_failed_qa_event() {
        let dir = tempdir().unwrap();
        fs::create_dir_all(dir.path().join(".wannabuild/outputs")).unwrap();
        fs::write(dir.path().join(".wannabuild/outputs/qa-summary.md"), "# QA").unwrap();
        events::append_event(
            dir.path(),
            "qa_failed",
            serde_json::json!({"reason": "bad"}),
        )
        .unwrap();

        let err = assert_qa_ready(dir.path()).unwrap_err().to_string();

        assert!(err.contains("latest QA event is qa_failed"));
        events::append_event(dir.path(), "qa_passed", serde_json::json!({})).unwrap();
        let err = assert_qa_ready(dir.path()).unwrap_err().to_string();
        assert!(err.contains("lacks positive PASS evidence"));
    }

    #[test]
    fn review_gate_uses_latest_file_verdict_per_reviewer() {
        let dir = tempdir().unwrap();
        fs::create_dir_all(dir.path().join(".wannabuild/review")).unwrap();
        for agent in REQUIRED_REVIEWERS {
            fs::write(
                dir.path()
                    .join(format!(".wannabuild/review/{agent}-iter-1.json")),
                format!(r#"{{"agent":"{agent}","status":"FAIL","summary":"old","issues":[]}}"#),
            )
            .unwrap();
            fs::write(
                dir.path()
                    .join(format!(".wannabuild/review/{agent}-iter-2.json")),
                format!(r#"{{"agent":"{agent}","status":"PASS","summary":"new","issues":[]}}"#),
            )
            .unwrap();
        }

        assert!(assert_review_ready(dir.path()).is_ok());
    }

    #[test]
    fn review_gate_uses_latest_loop_state_iteration_verdicts() {
        let dir = tempdir().unwrap();
        fs::create_dir_all(dir.path().join(".wannabuild")).unwrap();
        fs::write(
            dir.path().join(".wannabuild/loop-state.json"),
            r#"{
  "current_iteration": 2,
  "max_iterations": 3,
  "base_reviewer_count": 2,
  "status": "approved",
  "iterations": [
    {
      "iteration": 1,
      "timestamp": "2026-05-06T10:00:00Z",
      "active_reviewers": ["wb-security-reviewer", "wb-integration-tester"],
      "verdicts": {
        "wb-security-reviewer": {"agent":"wb-security-reviewer","status":"FAIL","summary":"old","issues":[]},
        "wb-integration-tester": {"agent":"wb-integration-tester","status":"PASS","summary":"ok","issues":[]}
      },
      "pass_count": 1,
      "fail_count": 1
    },
    {
      "iteration": 2,
      "timestamp": "2026-05-06T10:05:00Z",
      "active_reviewers": ["wb-security-reviewer", "wb-integration-tester"],
      "verdicts": {
        "wb-security-reviewer": {"agent":"wb-security-reviewer","status":"PASS","summary":"fixed","issues":[]},
        "wb-integration-tester": {"agent":"wb-integration-tester","status":"PASS","summary":"ok","issues":[]}
      },
      "pass_count": 2,
      "fail_count": 0
    }
  ]
}"#,
        )
        .unwrap();

        assert!(assert_review_ready(dir.path()).is_ok());
    }

    #[test]
    fn review_gate_blocks_latest_integration_failure() {
        let dir = tempdir().unwrap();
        fs::create_dir_all(dir.path().join(".wannabuild/review")).unwrap();
        for agent in REQUIRED_REVIEWERS {
            let status = if *agent == INTEGRATION_TESTER {
                "FAIL"
            } else {
                "PASS"
            };
            fs::write(
                dir.path()
                    .join(format!(".wannabuild/review/{agent}-iter-2.json")),
                format!(r#"{{"agent":"{agent}","status":"{status}","summary":"new","issues":[]}}"#),
            )
            .unwrap();
        }

        let err = assert_review_ready(dir.path()).unwrap_err().to_string();

        assert!(err.contains("wb-integration-tester"));
    }
}
