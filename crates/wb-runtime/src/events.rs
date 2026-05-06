use std::fs::{self, OpenOptions};
use std::io::{BufRead, BufReader, Write};
use std::path::Path;

use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use crate::errors::Result;
use crate::state::{ensure_runtime_layout, events_path, now};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuntimeEvent {
    pub id: String,
    pub timestamp: String,
    #[serde(rename = "type")]
    pub event_type: String,
    #[serde(default)]
    pub payload: Value,
}

pub fn append_event(
    project_root: &Path,
    event_type: impl Into<String>,
    payload: Value,
) -> Result<RuntimeEvent> {
    ensure_runtime_layout(project_root)?;
    let timestamp = now()?;
    let event = RuntimeEvent {
        id: format!(
            "{}-{}",
            timestamp
                .chars()
                .filter(|ch| ch.is_ascii_alphanumeric())
                .collect::<String>(),
            std::process::id()
        ),
        timestamp,
        event_type: event_type.into(),
        payload: redact_value(payload),
    };
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(events_path(project_root))?;
    serde_json::to_writer(&mut file, &event)?;
    file.write_all(b"\n")?;
    Ok(event)
}

pub fn redact_event(mut event: RuntimeEvent) -> RuntimeEvent {
    event.payload = redact_value(event.payload);
    event
}

pub fn redact_value(value: Value) -> Value {
    match value {
        Value::Object(map) => Value::Object(
            map.into_iter()
                .map(|(key, value)| {
                    if is_sensitive_key(&key) {
                        (key, Value::String("[REDACTED]".to_string()))
                    } else {
                        (key, redact_value(value))
                    }
                })
                .collect(),
        ),
        Value::Array(items) => Value::Array(items.into_iter().map(redact_value).collect()),
        Value::String(value) => Value::String(redact_string(&value)),
        value => value,
    }
}

fn redact_string(value: &str) -> String {
    if contains_sensitive_assignment(value)
        || contains_aws_access_key(value)
        || contains_private_key_pem(value)
    {
        "[REDACTED]".to_string()
    } else {
        value.to_string()
    }
}

fn contains_sensitive_assignment(value: &str) -> bool {
    let lower = value.to_ascii_lowercase();
    [
        "password",
        "passwd",
        "pwd",
        "token",
        "api_key",
        "api-key",
        "apikey",
        "access_key",
        "access-key",
        "accesskey",
        "secret",
        "secret_key",
        "secret-key",
        "secretkey",
        "private_key",
        "private-key",
        "authorization",
        "credential",
        "credentials",
    ]
    .iter()
    .any(|key| has_assignment_for_key(&lower, key))
}

fn has_assignment_for_key(value: &str, key: &str) -> bool {
    let mut offset = 0;
    while let Some(found) = value[offset..].find(key) {
        let after_key = offset + found + key.len();
        let after = value[after_key..].trim_start_matches(char::is_whitespace);
        let after = after
            .strip_prefix('"')
            .or_else(|| after.strip_prefix('\''))
            .unwrap_or(after)
            .trim_start_matches(char::is_whitespace);
        if after.starts_with('=') || after.starts_with(':') {
            return true;
        }
        offset = after_key;
    }
    false
}

fn contains_aws_access_key(value: &str) -> bool {
    value.as_bytes().windows(20).any(|window| {
        matches!(&window[..4], b"AKIA" | b"ASIA")
            && window[4..]
                .iter()
                .all(|byte| byte.is_ascii_uppercase() || byte.is_ascii_digit())
    })
}

fn contains_private_key_pem(value: &str) -> bool {
    let upper = value.to_ascii_uppercase();
    ["RSA", "EC", "DSA", "OPENSSH", ""]
        .iter()
        .map(|kind| private_key_pem_header(kind))
        .any(|header| upper.contains(&header))
}

fn private_key_pem_header(kind: &str) -> String {
    let mut header = "-----BEGIN ".to_string();
    if !kind.is_empty() {
        header.push_str(kind);
        header.push(' ');
    }
    header.push_str("PRIVATE");
    header.push_str(" KEY-----");
    header
}

fn is_sensitive_key(key: &str) -> bool {
    let normalized = key
        .chars()
        .filter(|ch| ch.is_ascii_alphanumeric())
        .collect::<String>()
        .to_ascii_lowercase();
    [
        "password",
        "passwd",
        "secret",
        "token",
        "apikey",
        "accesskey",
        "secretkey",
        "privatekey",
        "credential",
        "credentials",
        "authorization",
    ]
    .iter()
    .any(|needle| normalized.contains(needle))
}

pub fn list_events(project_root: &Path, since: Option<&str>) -> Result<Vec<RuntimeEvent>> {
    let path = events_path(project_root);
    if !path.is_file() {
        return Ok(Vec::new());
    }
    let file = fs::File::open(path)?;
    let mut events = Vec::new();
    for line in BufReader::new(file).lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        let event: RuntimeEvent = serde_json::from_str(&line)?;
        if since
            .map(|cursor| event.id.as_str() <= cursor)
            .unwrap_or(false)
        {
            continue;
        }
        events.push(event);
    }
    Ok(events)
}

pub fn replay(project_root: &Path) -> Result<Value> {
    let events = list_events(project_root, None)?;
    let last_event_id = events.last().map(|event| event.id.clone());
    Ok(json!({
        "events_replayed": events.len(),
        "last_event_id": last_event_id,
    }))
}

#[cfg(test)]
mod tests {
    use serde_json::json;
    use tempfile::tempdir;

    use super::*;

    #[test]
    fn append_and_list_events_uses_jsonl() {
        let dir = tempdir().unwrap();
        append_event(dir.path(), "gate_checked", json!({"gate": "plan"})).unwrap();
        append_event(dir.path(), "gate_passed", json!({"gate": "plan"})).unwrap();

        let events = list_events(dir.path(), None).unwrap();

        assert_eq!(events.len(), 2);
        assert_eq!(events[0].event_type, "gate_checked");
        assert_eq!(events[1].payload["gate"], json!("plan"));
    }

    #[test]
    fn append_event_redacts_sensitive_payload_keys() {
        let dir = tempdir().unwrap();
        append_event(
            dir.path(),
            "runtime_context_emitted",
            json!({
                "token": "raw-token-value",
                "nested": {
                    "api_key": "raw-api-key",
                    "safe": "visible",
                },
            }),
        )
        .unwrap();

        let events = list_events(dir.path(), None).unwrap();

        assert_eq!(events[0].payload["token"], json!("[REDACTED]"));
        assert_eq!(events[0].payload["nested"]["api_key"], json!("[REDACTED]"));
        assert_eq!(events[0].payload["nested"]["safe"], json!("visible"));
        let raw = fs::read_to_string(events_path(dir.path())).unwrap();
        assert!(!raw.contains("raw-token-value"));
        assert!(!raw.contains("raw-api-key"));
    }

    #[test]
    fn append_event_redacts_secret_patterns_in_string_values() {
        let dir = tempdir().unwrap();
        append_event(
            dir.path(),
            "runtime_context_emitted",
            json!({
                "message": "deploy password=hunter2",
                "nested": [
                    "token=raw-token-value",
                    "AKIAIOSFODNN7EXAMPLE",
                    "safe",
                ],
            }),
        )
        .unwrap();

        let events = list_events(dir.path(), None).unwrap();
        let raw = fs::read_to_string(events_path(dir.path())).unwrap();

        assert_eq!(events[0].payload["message"], json!("[REDACTED]"));
        assert_eq!(events[0].payload["nested"][0], json!("[REDACTED]"));
        assert_eq!(events[0].payload["nested"][1], json!("[REDACTED]"));
        assert_eq!(events[0].payload["nested"][2], json!("safe"));
        assert!(!raw.contains("hunter2"));
        assert!(!raw.contains("raw-token-value"));
        assert!(!raw.contains("AKIAIOSFODNN7EXAMPLE"));
    }

    #[test]
    fn append_event_redacts_json_style_secret_assignments_in_string_values() {
        let dir = tempdir().unwrap();
        append_event(
            dir.path(),
            "runtime_context_emitted",
            json!({
                "message": r#"{"api_key":"sk_live_raw_secret"}"#,
                "other": r#"{ "token" : "raw-token-value" }"#,
                "safe": "api key mentioned without an assignment",
            }),
        )
        .unwrap();

        let events = list_events(dir.path(), None).unwrap();
        let raw = fs::read_to_string(events_path(dir.path())).unwrap();

        assert_eq!(events[0].payload["message"], json!("[REDACTED]"));
        assert_eq!(events[0].payload["other"], json!("[REDACTED]"));
        assert_eq!(
            events[0].payload["safe"],
            json!("api key mentioned without an assignment")
        );
        assert!(!raw.contains("sk_live_raw_secret"));
        assert!(!raw.contains("raw-token-value"));
    }

    #[test]
    fn append_event_redacts_private_key_pem_patterns_in_nested_string_values() {
        let dir = tempdir().unwrap();
        let key_kinds = ["RSA", "EC", "DSA", "OPENSSH", ""];
        for kind in key_kinds {
            let header = private_key_pem_header(kind);
            append_event(
                dir.path(),
                "runtime_context_emitted",
                json!({
                    "nested": {
                        "message": format!("prefix\n{header}\nkey material"),
                        "safe": "visible",
                    },
                }),
            )
            .unwrap();
        }

        let events = list_events(dir.path(), None).unwrap();
        let raw = fs::read_to_string(events_path(dir.path())).unwrap();

        assert_eq!(events.len(), key_kinds.len());
        for event in events {
            assert_eq!(event.payload["nested"]["message"], json!("[REDACTED]"));
            assert_eq!(event.payload["nested"]["safe"], json!("visible"));
        }
        for kind in key_kinds {
            let header = private_key_pem_header(kind);
            assert!(!raw.contains(&header));
        }
    }
}
