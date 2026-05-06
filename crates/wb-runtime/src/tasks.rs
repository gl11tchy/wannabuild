use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::errors::{Result, RuntimeError};
use crate::{events, state};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RuntimeTask {
    pub id: String,
    pub title: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub phase: String,
    #[serde(default)]
    pub dependencies: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub owner: Option<String>,
    #[serde(default)]
    pub expected_files: Vec<String>,
    #[serde(default)]
    pub acceptance_criteria: Vec<String>,
    #[serde(default)]
    pub verification_commands: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub checkpoint_path: Option<String>,
    pub status: String,
    #[serde(default)]
    pub retry_count: u32,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub blocked_reason: Option<String>,
    #[serde(default)]
    pub risk_level: String,
    #[serde(default)]
    pub parallelizable: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub updated_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct RuntimeTasks {
    #[serde(default)]
    pub tasks: Vec<RuntimeTask>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub updated_at: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct NextTask {
    pub scheduler: String,
    pub rationale: String,
    pub task: RuntimeTask,
}

pub fn import_tasks(project_root: &Path, from: &Path) -> Result<RuntimeTasks> {
    let raw = fs::read_to_string(from)?;
    let mut parsed = parse_tasks(&raw)?;
    let existing = load_tasks(project_root)?;
    let existing_by_id = existing
        .tasks
        .into_iter()
        .map(|task| (task.id.clone(), task))
        .collect::<BTreeMap<_, _>>();
    for task in &mut parsed {
        if let Some(previous) = existing_by_id.get(&task.id) {
            task.status = previous.status.clone();
            task.owner = previous.owner.clone();
            task.checkpoint_path = previous.checkpoint_path.clone();
            task.retry_count = previous.retry_count;
            task.blocked_reason = previous.blocked_reason.clone();
        }
    }
    let tasks = RuntimeTasks {
        tasks: parsed,
        updated_at: Some(state::now()?),
    };
    save_tasks(project_root, &tasks)?;
    events::append_event(
        project_root,
        "task_created",
        json!({"source": from.display().to_string(), "count": tasks.tasks.len()}),
    )?;
    Ok(tasks)
}

pub fn parse_tasks(raw: &str) -> Result<Vec<RuntimeTask>> {
    let mut tasks = Vec::new();
    let mut current: Option<RuntimeTask> = None;
    let mut list_field: Option<ListField> = None;

    for line in raw.lines() {
        if let Some(rest) = line.strip_prefix("## Task ") {
            if let Some(task) = current.take() {
                tasks.push(task);
            }
            current = Some(new_task(rest));
            list_field = None;
            continue;
        }
        let Some(task) = current.as_mut() else {
            continue;
        };
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        if let Some(value) = trimmed.strip_prefix("- Phase:") {
            task.phase = value.trim().to_string();
            list_field = None;
        } else if let Some(value) = trimmed.strip_prefix("- Dependencies:") {
            task.dependencies = parse_dependencies(value.trim());
            task.status = if task.dependencies.is_empty() {
                "ready".to_string()
            } else {
                "pending".to_string()
            };
            list_field = None;
        } else if trimmed == "- Expected files:" {
            list_field = Some(ListField::ExpectedFiles);
        } else if trimmed == "- Acceptance criteria:" {
            list_field = Some(ListField::AcceptanceCriteria);
        } else if trimmed == "- Verification commands:" {
            list_field = Some(ListField::VerificationCommands);
        } else if let Some(value) = trimmed.strip_prefix("- Risk:") {
            task.risk_level = value.trim().to_string();
            list_field = None;
        } else if let Some(value) = trimmed.strip_prefix("- Parallelizable:") {
            task.parallelizable = value.trim().eq_ignore_ascii_case("true");
            list_field = None;
        } else if let Some(value) = trimmed.strip_prefix("- ") {
            match list_field {
                Some(ListField::ExpectedFiles) => {
                    task.expected_files.push(value.trim().to_string())
                }
                Some(ListField::AcceptanceCriteria) => {
                    task.acceptance_criteria.push(value.trim().to_string());
                }
                Some(ListField::VerificationCommands) => {
                    task.verification_commands.push(value.trim().to_string());
                }
                None => {
                    if !task.description.is_empty() {
                        task.description.push('\n');
                    }
                    task.description.push_str(value.trim());
                }
            }
        } else {
            if !task.description.is_empty() {
                task.description.push('\n');
            }
            task.description.push_str(trimmed);
        }
    }
    if let Some(task) = current.take() {
        tasks.push(task);
    }
    if tasks.is_empty() {
        return Err(RuntimeError::message(
            "No tasks found; expected Markdown headings like '## Task WBRT-001: Title'",
        ));
    }
    Ok(tasks)
}

fn new_task(rest: &str) -> RuntimeTask {
    let (id, title) = rest
        .split_once(':')
        .map(|(id, title)| (id.trim(), title.trim()))
        .unwrap_or((rest.trim(), ""));
    RuntimeTask {
        id: id.to_string(),
        title: title.to_string(),
        description: String::new(),
        phase: String::new(),
        dependencies: Vec::new(),
        owner: None,
        expected_files: Vec::new(),
        acceptance_criteria: Vec::new(),
        verification_commands: Vec::new(),
        checkpoint_path: None,
        status: "ready".to_string(),
        retry_count: 0,
        blocked_reason: None,
        risk_level: String::new(),
        parallelizable: false,
        updated_at: None,
    }
}

fn parse_dependencies(value: &str) -> Vec<String> {
    if value.eq_ignore_ascii_case("none") || value.is_empty() {
        return Vec::new();
    }
    value
        .split([',', ' '])
        .map(str::trim)
        .filter(|part| !part.is_empty())
        .map(ToString::to_string)
        .collect()
}

#[derive(Debug, Copy, Clone)]
enum ListField {
    ExpectedFiles,
    AcceptanceCriteria,
    VerificationCommands,
}

pub fn load_tasks(project_root: &Path) -> Result<RuntimeTasks> {
    let path = state::tasks_path(project_root);
    if !path.is_file() {
        return Ok(RuntimeTasks::default());
    }
    Ok(serde_json::from_str(&fs::read_to_string(path)?)?)
}

pub fn save_tasks(project_root: &Path, tasks: &RuntimeTasks) -> Result<()> {
    state::ensure_runtime_layout(project_root)?;
    state::atomic_write_json(
        state::tasks_path(project_root).as_path(),
        &serde_json::to_value(tasks)?,
    )?;
    Ok(())
}

pub fn next_task(project_root: &Path) -> Result<NextTask> {
    let tasks = load_tasks(project_root)?;
    let by_id = tasks
        .tasks
        .iter()
        .map(|task| (task.id.as_str(), task))
        .collect::<BTreeMap<_, _>>();
    let task = tasks
        .tasks
        .iter()
        .find(|task| is_ready(task, &by_id))
        .cloned()
        .ok_or_else(|| RuntimeError::message("No ready tasks available"))?;
    Ok(NextTask {
        scheduler: "single-owner".to_string(),
        rationale: "defaulting to the smallest dependency-ready task".to_string(),
        task,
    })
}

fn is_ready(task: &RuntimeTask, by_id: &BTreeMap<&str, &RuntimeTask>) -> bool {
    matches!(task.status.as_str(), "pending" | "ready")
        && task.dependencies.iter().all(|dependency| {
            by_id
                .get(dependency.as_str())
                .is_some_and(|task| task.status == "complete")
        })
}

pub fn claim_task(project_root: &Path, task_id: &str, owner: &str) -> Result<RuntimeTask> {
    let loaded = load_tasks(project_root)?;
    let task = loaded
        .tasks
        .iter()
        .find(|task| task.id == task_id)
        .ok_or_else(|| RuntimeError::message(format!("Unknown task: {task_id}")))?;
    crate::gates::assert_plan_ready(project_root)?;
    let blockers = dependency_blockers(&loaded, task);
    if !blockers.is_empty() {
        return Err(RuntimeError::message(format!(
            "Task {task_id} dependencies are not complete: {}",
            blockers.join(", ")
        )));
    }
    match task.status.as_str() {
        "pending" | "ready" => {}
        "claimed" | "in_progress" if task.owner.as_deref() == Some(owner) => {}
        "claimed" | "in_progress" => {
            return Err(RuntimeError::message(format!(
                "Task {task_id} is already claimed by {}",
                task.owner.as_deref().unwrap_or("unknown")
            )));
        }
        "complete" => {
            return Err(RuntimeError::message(format!(
                "Task {task_id} is already complete"
            )));
        }
        status => {
            return Err(RuntimeError::message(format!(
                "Task {task_id} cannot be claimed from status {status}"
            )));
        }
    }
    update_one(project_root, task_id, |task| {
        task.owner = Some(owner.to_string());
        task.status = "in_progress".to_string();
        task.updated_at = Some(state::now()?);
        Ok(())
    })?;
    let task = find_task(project_root, task_id)?;
    events::append_event(
        project_root,
        "task_started",
        json!({"task": task_id, "owner": owner}),
    )?;
    update_active_task(project_root, task_id, true)?;
    Ok(task)
}

pub fn complete_task(
    project_root: &Path,
    task_id: &str,
    checkpoint: Option<PathBuf>,
) -> Result<RuntimeTask> {
    let loaded = load_tasks(project_root)?;
    let task = loaded
        .tasks
        .iter()
        .find(|task| task.id == task_id)
        .ok_or_else(|| RuntimeError::message(format!("Unknown task: {task_id}")))?;
    if !matches!(task.status.as_str(), "in_progress" | "verifying") {
        return Err(RuntimeError::message(format!(
            "Task {task_id} cannot be completed from status {}",
            task.status
        )));
    }
    let blockers = dependency_blockers(&loaded, task);
    if !blockers.is_empty() {
        return Err(RuntimeError::message(format!(
            "Task {task_id} dependencies are not complete: {}",
            blockers.join(", ")
        )));
    }
    let checkpoint = checkpoint
        .as_ref()
        .ok_or_else(|| {
            RuntimeError::message(format!(
                "Task {task_id} completion requires --checkpoint evidence"
            ))
        })
        .and_then(|path| crate::checkpoints::validate_checkpoint_path(project_root, path))?;
    let checkpoint_payload = Some(checkpoint.display().to_string());
    update_one(project_root, task_id, |task| {
        task.status = "complete".to_string();
        task.blocked_reason = None;
        task.checkpoint_path = checkpoint_payload.clone();
        task.updated_at = Some(state::now()?);
        Ok(())
    })?;
    let task = find_task(project_root, task_id)?;
    events::append_event(
        project_root,
        "task_completed",
        json!({"task": task_id, "checkpoint": checkpoint_payload}),
    )?;
    events::append_event(
        project_root,
        "checkpoint_written",
        json!({"task": task_id, "path": checkpoint.display().to_string()}),
    )?;
    update_active_task(project_root, task_id, false)?;
    Ok(task)
}

fn dependency_blockers(tasks: &RuntimeTasks, task: &RuntimeTask) -> Vec<String> {
    let by_id = tasks
        .tasks
        .iter()
        .map(|task| (task.id.as_str(), task))
        .collect::<BTreeMap<_, _>>();
    task.dependencies
        .iter()
        .filter_map(|dependency| match by_id.get(dependency.as_str()) {
            Some(dependency_task) if dependency_task.status == "complete" => None,
            Some(dependency_task) => Some(format!("{dependency}:{}", dependency_task.status)),
            None => Some(format!("{dependency}:missing")),
        })
        .collect()
}

pub fn block_task(project_root: &Path, task_id: &str, reason: &str) -> Result<RuntimeTask> {
    update_one(project_root, task_id, |task| {
        task.status = "blocked".to_string();
        task.blocked_reason = Some(reason.to_string());
        task.updated_at = Some(state::now()?);
        Ok(())
    })?;
    let task = find_task(project_root, task_id)?;
    events::append_event(
        project_root,
        "task_blocked",
        json!({"task": task_id, "reason": reason}),
    )?;
    update_active_task(project_root, task_id, false)?;
    Ok(task)
}

fn update_one<F>(project_root: &Path, task_id: &str, mut update: F) -> Result<()>
where
    F: FnMut(&mut RuntimeTask) -> Result<()>,
{
    let mut tasks = load_tasks(project_root)?;
    let task = tasks
        .tasks
        .iter_mut()
        .find(|task| task.id == task_id)
        .ok_or_else(|| RuntimeError::message(format!("Unknown task: {task_id}")))?;
    update(task)?;
    tasks.updated_at = Some(state::now()?);
    save_tasks(project_root, &tasks)
}

fn find_task(project_root: &Path, task_id: &str) -> Result<RuntimeTask> {
    load_tasks(project_root)?
        .tasks
        .into_iter()
        .find(|task| task.id == task_id)
        .ok_or_else(|| RuntimeError::message(format!("Unknown task: {task_id}")))
}

fn update_active_task(project_root: &Path, task_id: &str, active: bool) -> Result<()> {
    let mut workflow = state::ensure_state(project_root)?;
    let map = workflow
        .as_object_mut()
        .ok_or_else(|| RuntimeError::message("state.json must be a JSON object"))?;
    let value = map
        .entry("active_task_ids".to_string())
        .or_insert_with(|| json!([]));
    let items = value
        .as_array_mut()
        .ok_or_else(|| RuntimeError::message("active_task_ids must be an array"))?;
    if active {
        if !items.iter().any(|item| item.as_str() == Some(task_id)) {
            items.push(json!(task_id));
        }
    } else {
        items.retain(|item| item.as_str() != Some(task_id));
    }
    state::set_str(&mut workflow, "updated_at", &state::now()?)?;
    state::save_state(project_root, &workflow)
}

#[cfg(test)]
mod tests {
    use std::fs;

    use tempfile::tempdir;

    use super::*;

    const TASKS: &str = r#"# Tasks

## Task WBRT-001: First

- Phase: implement
- Dependencies: none
- Expected files:
  - `Cargo.toml`
- Acceptance criteria:
  - First passes.
- Verification commands:
  - `cargo test`
- Risk: medium
- Parallelizable: false

## Task WBRT-002: Second

- Phase: implement
- Dependencies: WBRT-001
- Acceptance criteria:
  - Second passes.
"#;

    fn write_plan_ready(project_root: &Path) {
        let spec = project_root.join(".wannabuild/spec");
        fs::create_dir_all(&spec).unwrap();
        fs::write(spec.join("design.md"), "design").unwrap();
        fs::write(spec.join("tasks.md"), TASKS).unwrap();
    }

    #[test]
    fn parses_task_markdown() {
        let tasks = parse_tasks(TASKS).unwrap();

        assert_eq!(tasks.len(), 2);
        assert_eq!(tasks[0].id, "WBRT-001");
        assert_eq!(tasks[1].dependencies, vec!["WBRT-001"]);
        assert_eq!(tasks[0].verification_commands, vec!["`cargo test`"]);
    }

    #[test]
    fn scheduler_respects_dependencies() {
        let dir = tempdir().unwrap();
        let tasks_file = dir.path().join("tasks.md");
        fs::write(&tasks_file, TASKS).unwrap();
        import_tasks(dir.path(), &tasks_file).unwrap();
        write_plan_ready(dir.path());

        let first = next_task(dir.path()).unwrap();
        assert_eq!(first.task.id, "WBRT-001");

        claim_task(dir.path(), "WBRT-001", "owner-a").unwrap();
        let err = claim_task(dir.path(), "WBRT-001", "owner-b")
            .unwrap_err()
            .to_string();
        assert!(err.contains("already claimed"));

        let checkpoint = dir.path().join(".wannabuild/checkpoints/task-1-step-1.md");
        fs::write(&checkpoint, "checkpoint").unwrap();
        complete_task(dir.path(), "WBRT-001", Some(checkpoint)).unwrap();
        let second = next_task(dir.path()).unwrap();
        assert_eq!(second.task.id, "WBRT-002");
    }

    #[test]
    fn direct_claim_requires_complete_dependencies() {
        let dir = tempdir().unwrap();
        let tasks_file = dir.path().join("tasks.md");
        fs::write(&tasks_file, TASKS).unwrap();
        import_tasks(dir.path(), &tasks_file).unwrap();
        write_plan_ready(dir.path());

        let err = claim_task(dir.path(), "WBRT-002", "owner-a")
            .unwrap_err()
            .to_string();

        assert!(err.contains("dependencies are not complete"));
        assert!(err.contains("WBRT-001"));
    }

    #[test]
    fn direct_claim_requires_plan_ready() {
        let dir = tempdir().unwrap();
        let tasks_file = dir.path().join("tasks.md");
        fs::write(&tasks_file, TASKS).unwrap();
        import_tasks(dir.path(), &tasks_file).unwrap();

        let err = claim_task(dir.path(), "WBRT-001", "owner-a")
            .unwrap_err()
            .to_string();

        assert!(err.contains("Plan gate failed"));
    }

    #[test]
    fn direct_complete_requires_in_progress_status() {
        let dir = tempdir().unwrap();
        let tasks_file = dir.path().join("tasks.md");
        fs::write(&tasks_file, TASKS).unwrap();
        import_tasks(dir.path(), &tasks_file).unwrap();

        let err = complete_task(dir.path(), "WBRT-001", None)
            .unwrap_err()
            .to_string();

        assert!(err.contains("cannot be completed from status ready"));
    }

    #[test]
    fn complete_requires_checkpoint_after_claim() {
        let dir = tempdir().unwrap();
        let tasks_file = dir.path().join("tasks.md");
        fs::write(&tasks_file, TASKS).unwrap();
        import_tasks(dir.path(), &tasks_file).unwrap();
        write_plan_ready(dir.path());
        claim_task(dir.path(), "WBRT-001", "owner-a").unwrap();

        let err = complete_task(dir.path(), "WBRT-001", None)
            .unwrap_err()
            .to_string();

        assert!(err.contains("requires --checkpoint"));
    }

    #[test]
    fn block_task_records_reason_and_removes_active_task() {
        let dir = tempdir().unwrap();
        let tasks_file = dir.path().join("tasks.md");
        fs::write(&tasks_file, TASKS).unwrap();
        import_tasks(dir.path(), &tasks_file).unwrap();
        write_plan_ready(dir.path());
        claim_task(dir.path(), "WBRT-001", "owner-a").unwrap();

        let task = block_task(dir.path(), "WBRT-001", "waiting on API").unwrap();

        assert_eq!(task.status, "blocked");
        assert_eq!(task.blocked_reason.as_deref(), Some("waiting on API"));
        let state = state::load_state(dir.path()).unwrap().unwrap();
        assert_eq!(state["active_task_ids"], json!([]));
    }
}
