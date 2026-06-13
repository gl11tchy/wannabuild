use std::fs::{self, OpenOptions};
use std::path::{Path, PathBuf};

use serde_json::{Map, Value, json};
use time::{OffsetDateTime, format_description::well_known::Rfc3339};

use crate::errors::{Result, RuntimeError};

pub const RUNTIME_VERSION: &str = env!("CARGO_PKG_VERSION");

pub fn now() -> Result<String> {
    Ok(OffsetDateTime::now_utc().format(&Rfc3339)?)
}

pub fn wb_dir(project_root: &Path) -> PathBuf {
    project_root.join(".wannabuild")
}

pub fn state_path(project_root: &Path) -> PathBuf {
    wb_dir(project_root).join("state.json")
}

pub fn events_path(project_root: &Path) -> PathBuf {
    wb_dir(project_root).join("events.jsonl")
}

pub fn tasks_path(project_root: &Path) -> PathBuf {
    wb_dir(project_root).join("tasks.json")
}

pub fn decisions_path(project_root: &Path) -> PathBuf {
    wb_dir(project_root).join("decisions.md")
}

pub fn ensure_runtime_layout(project_root: &Path) -> Result<()> {
    let root = wb_dir(project_root);
    fs::create_dir_all(root.join("spec"))?;
    fs::create_dir_all(root.join("checkpoints"))?;
    fs::create_dir_all(root.join("review"))?;
    fs::create_dir_all(root.join("outputs"))?;
    fs::create_dir_all(root.join("outputs/discovery"))?;
    OpenOptions::new()
        .create(true)
        .append(true)
        .open(root.join("runtime.db"))?;
    ensure_runtime_gitignore(&root)?;
    Ok(())
}

// Evidence logs hold raw integration-test output, which can contain secrets;
// the local runtime DB and lock are machine-specific. Write a .gitignore into
// .wannabuild/ so a target project never commits them by accident. Only
// created once and never overwritten, so a project can customize it.
fn ensure_runtime_gitignore(wb_root: &Path) -> Result<()> {
    let path = wb_root.join(".gitignore");
    if path.exists() {
        return Ok(());
    }
    fs::write(
        &path,
        "# Machine-local runtime state and raw evidence logs (may contain secrets).\n\
         # Spec, verdicts, and signed evidence records are safe to commit.\n\
         review/*.evidence.log\n\
         runtime.db\n\
         runtime.lock\n\
         events.jsonl\n",
    )?;
    Ok(())
}

pub fn project_name(project_root: &Path) -> String {
    project_root
        .file_name()
        .and_then(|value| value.to_str())
        .unwrap_or("project")
        .to_string()
}

pub fn load_state(project_root: &Path) -> Result<Option<Value>> {
    let path = state_path(project_root);
    if !path.is_file() {
        return Ok(None);
    }
    let raw = fs::read_to_string(path)?;
    let value: Value = serde_json::from_str(&raw)?;
    if !value.is_object() {
        return Err(RuntimeError::message("state.json must be a JSON object"));
    }
    Ok(Some(value))
}

pub fn ensure_state(project_root: &Path) -> Result<Value> {
    ensure_runtime_layout(project_root)?;
    let mut state = load_state(project_root)?.unwrap_or_else(|| json!({}));
    let changed = merge_defaults(&mut state, project_root)?;
    if changed {
        save_state(project_root, &state)?;
    }
    Ok(state)
}

pub fn merge_defaults(state: &mut Value, project_root: &Path) -> Result<bool> {
    let ts = now()?;
    let map = state
        .as_object_mut()
        .ok_or_else(|| RuntimeError::message("state.json must be a JSON object"))?;
    let mut changed = false;
    changed |= insert_default(map, "project", json!(project_name(project_root)));
    changed |= insert_default(map, "mode", json!("standard"));
    changed |= insert_default(map, "current_phase", json!("requirements"));
    changed |= insert_default(map, "phase_status", json!("pending"));
    changed |= insert_default(map, "public_stage", json!("discover"));
    changed |= insert_default(map, "workflow_status", json!("in_progress"));
    changed |= insert_default(map, "control_mode", json!("guided"));
    changed |= insert_default(map, "started_at", json!(ts));
    changed |= insert_default(map, "updated_at", json!(now()?));
    changed |= insert_default(map, "artifacts", json!({}));
    changed |= insert_default(map, "phase_history", json!([]));
    changed |= insert_default(map, "public_stage_history", json!([]));
    changed |= insert_default(map, "pause_reason", Value::Null);
    changed |= insert_default(map, "blocked_reason", Value::Null);
    changed |= insert_default(map, "active_task_ids", json!([]));
    changed |= insert_default(map, "runtime_version", json!(RUNTIME_VERSION));
    Ok(changed)
}

fn insert_default(map: &mut Map<String, Value>, key: &str, value: Value) -> bool {
    if map.contains_key(key) {
        return false;
    }
    map.insert(key.to_string(), value);
    true
}

pub fn save_state(project_root: &Path, state: &Value) -> Result<()> {
    ensure_runtime_layout(project_root)?;
    let path = state_path(project_root);
    atomic_write_json(&path, state)
}

pub fn atomic_write_json(path: &Path, value: &Value) -> Result<()> {
    let parent = path
        .parent()
        .ok_or_else(|| RuntimeError::message("cannot write file without parent directory"))?;
    fs::create_dir_all(parent)?;
    let temp = parent.join(format!(
        ".{}.tmp.{}",
        path.file_name()
            .and_then(|value| value.to_str())
            .unwrap_or("state.json"),
        std::process::id()
    ));
    fs::write(&temp, {
        let mut raw = serde_json::to_vec_pretty(value)?;
        raw.push(b'\n');
        raw
    })?;
    fs::rename(temp, path)?;
    Ok(())
}

pub fn get_str<'a>(state: &'a Value, key: &str) -> Option<&'a str> {
    state.get(key).and_then(Value::as_str)
}

pub fn has_complete(history: Option<&Value>, key: &str, value: &str) -> bool {
    history
        .and_then(Value::as_array)
        .map(|items| {
            items.iter().any(|item| {
                item.get(key).and_then(Value::as_str) == Some(value)
                    && item.get("status").and_then(Value::as_str) == Some("complete")
            })
        })
        .unwrap_or(false)
}

pub fn append_public_stage_history(
    state: &mut Value,
    stage: &str,
    status: &str,
    timestamp: &str,
) -> Result<()> {
    append_history(
        state,
        "public_stage_history",
        "stage",
        stage,
        status,
        timestamp,
    )
}

pub fn append_phase_history(
    state: &mut Value,
    phase: &str,
    status: &str,
    timestamp: &str,
) -> Result<()> {
    append_history(state, "phase_history", "phase", phase, status, timestamp)
}

fn append_history(
    state: &mut Value,
    key: &str,
    field: &str,
    value: &str,
    status: &str,
    timestamp: &str,
) -> Result<()> {
    let map = state
        .as_object_mut()
        .ok_or_else(|| RuntimeError::message("state.json must be a JSON object"))?;
    let history = map.entry(key.to_string()).or_insert_with(|| json!([]));
    let items = history
        .as_array_mut()
        .ok_or_else(|| RuntimeError::message(format!("{key} must be an array")))?;
    items.push(json!({ field: value, "status": status, "timestamp": timestamp }));
    Ok(())
}

pub fn set_str(state: &mut Value, key: &str, value: &str) -> Result<()> {
    let map = state
        .as_object_mut()
        .ok_or_else(|| RuntimeError::message("state.json must be a JSON object"))?;
    map.insert(key.to_string(), json!(value));
    Ok(())
}

pub fn set_value(state: &mut Value, key: &str, value: Value) -> Result<()> {
    let map = state
        .as_object_mut()
        .ok_or_else(|| RuntimeError::message("state.json must be a JSON object"))?;
    map.insert(key.to_string(), value);
    Ok(())
}

#[cfg(test)]
mod tests {
    use serde_json::json;
    use tempfile::tempdir;

    use super::*;

    #[test]
    fn ensure_state_adds_required_fields_and_preserves_unknowns() {
        let dir = tempdir().unwrap();
        let wb = dir.path().join(".wannabuild");
        fs::create_dir_all(&wb).unwrap();
        fs::write(wb.join("state.json"), "{\"custom\":true}\n").unwrap();

        let state = ensure_state(dir.path()).unwrap();

        assert_eq!(state["custom"], json!(true));
        assert_eq!(state["workflow_status"], json!("in_progress"));
        assert_eq!(state["runtime_version"], json!(RUNTIME_VERSION));
        assert!(wb.join("runtime.db").is_file());
    }

    #[test]
    fn has_complete_matches_history_entries() {
        let state = json!({
            "public_stage_history": [
                {"stage": "plan", "status": "complete"}
            ]
        });
        assert!(has_complete(
            state.get("public_stage_history"),
            "stage",
            "plan"
        ));
        assert!(!has_complete(
            state.get("public_stage_history"),
            "stage",
            "implement"
        ));
    }
}
