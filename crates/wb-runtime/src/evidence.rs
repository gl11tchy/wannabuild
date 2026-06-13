//! Runtime-recorded integration test evidence.
//!
//! The integration gate must not trust verdict JSON the orchestrating model can
//! write by hand. `record_test_evidence` runs the configured integration test
//! command itself, captures what actually happened (exit code, output digest,
//! spec digest, timing), and signs the record with a machine-local HMAC key kept
//! outside the project tree. Gate checks call `verify_integration_evidence`,
//! which fails closed on a missing record, a tampered record, a non-zero exit,
//! a spec that changed after the run, or a test command that no longer matches
//! the project config.
//!
//! Threat model: this defends against an agent taking shortcuts — skipping the
//! test run and fabricating artifacts. It is tamper-evident, not cryptographic
//! attestation: a hostile operator with shell access can read the key. See
//! docs/trust-model.md.

use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Instant;

use hmac::{Hmac, Mac};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

use crate::errors::{Result, RuntimeError};
use crate::{events, state};

type HmacSha256 = Hmac<Sha256>;

const INTEGRATION_TESTER: &str = "wb-integration-tester";
const FIXTURE_ENV: &str = "WB_EVIDENCE_MODE";
const KEY_FILE_ENV: &str = "WB_EVIDENCE_KEY_FILE";
const SPEC_FILES: &[&str] = &["requirements.md", "design.md", "tasks.md"];

#[derive(Debug)]
pub struct EvidenceRecord {
    pub path: PathBuf,
    pub iteration: u64,
    pub exit_code: i64,
    pub duration_ms: u64,
}

/// Fixture mode exists so committed example projects (docs/golden-path-demo)
/// and dry-run fixtures can be schema-validated without a machine-local key.
/// Every pass produced in fixture mode is loudly labeled in gate evidence and
/// in the event log; it is never silent.
pub fn fixture_mode() -> bool {
    std::env::var(FIXTURE_ENV).is_ok_and(|value| value == "fixture")
}

pub fn evidence_path(project_root: &Path, iteration: u64) -> PathBuf {
    project_root.join(format!(
        ".wannabuild/review/{INTEGRATION_TESTER}-iter-{iteration}.evidence.json"
    ))
}

fn evidence_log_path(project_root: &Path, iteration: u64) -> PathBuf {
    project_root.join(format!(
        ".wannabuild/review/{INTEGRATION_TESTER}-iter-{iteration}.evidence.log"
    ))
}

pub fn integration_test_command(project_root: &Path) -> Result<String> {
    let config_path = project_root.join(".wannabuild/config.json");
    let missing = || {
        RuntimeError::message(
            "integration_test_command is not set in .wannabuild/config.json; \
             set it during Plan so the runtime can execute and record the integration run",
        )
    };
    if !config_path.is_file() {
        return Err(missing());
    }
    let config: Value = serde_json::from_str(&fs::read_to_string(&config_path)?)?;
    config
        .get("integration_test_command")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToString::to_string)
        .ok_or_else(missing)
}

/// Runs the configured integration test command and writes a signed evidence
/// record for the given (or inferred) review iteration. The full combined
/// output goes to a sidecar `.evidence.log`; the JSON record carries only its
/// SHA-256 so secrets in test output never land in the structured artifact.
/// Returns an error after recording when the test run itself failed, so
/// callers surface the failure while the evidence of it is preserved.
pub fn record_test_evidence(
    project_root: &Path,
    iteration: Option<u64>,
) -> Result<EvidenceRecord> {
    let command = integration_test_command(project_root)?;
    let iteration = match iteration {
        Some(value) if value > 0 => value,
        Some(_) => return Err(RuntimeError::message("iteration must be >= 1")),
        None => current_iteration(project_root)?,
    };

    let started_at = state::now()?;
    let timer = Instant::now();
    let output = shell_command(&command).current_dir(project_root).output()?;
    let duration_ms = u64::try_from(timer.elapsed().as_millis()).unwrap_or(u64::MAX);
    let finished_at = state::now()?;
    let exit_code = i64::from(output.status.code().unwrap_or(-1));

    let mut combined = output.stdout;
    combined.extend_from_slice(&output.stderr);
    let log_path = evidence_log_path(project_root, iteration);
    if let Some(parent) = log_path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(&log_path, &combined)?;

    let mut payload = json!({
        "agent": INTEGRATION_TESTER,
        "command": command,
        "duration_ms": duration_ms,
        "exit_code": exit_code,
        "finished_at": finished_at,
        "iteration": iteration,
        "output_bytes": combined.len(),
        "output_sha256": sha256_hex(&combined),
        "recorder": format!("wb-runtime/{}", state::RUNTIME_VERSION),
        "spec_hash": spec_hash(project_root)?,
        "started_at": started_at,
    });
    let key = load_or_create_key()?;
    let mac = hmac_hex(&key, serde_json::to_string(&payload)?.as_bytes());
    payload
        .as_object_mut()
        .expect("evidence payload is an object")
        .insert("hmac".to_string(), json!(mac));

    let path = evidence_path(project_root, iteration);
    state::atomic_write_json(&path, &payload)?;
    events::append_event(
        project_root,
        "integration_evidence_recorded",
        json!({
            "iteration": iteration,
            "command": command,
            "exit_code": exit_code,
            "duration_ms": duration_ms,
        }),
    )?;

    let record = EvidenceRecord {
        path,
        iteration,
        exit_code,
        duration_ms,
    };
    if exit_code != 0 {
        return Err(RuntimeError::message(format!(
            "integration test command failed (exit {exit_code}); evidence recorded at {}",
            record.path.display()
        )));
    }
    Ok(record)
}

/// Verifies the runtime-recorded evidence backing an integration verdict for
/// `iteration`. Fails closed; returns human-readable evidence strings on pass.
pub fn verify_integration_evidence(project_root: &Path, iteration: u64) -> Result<Vec<String>> {
    if fixture_mode() {
        return Ok(vec![format!(
            "FIXTURE MODE: integration evidence verification skipped ({FIXTURE_ENV}=fixture)"
        )]);
    }

    let path = evidence_path(project_root, iteration);
    if !path.is_file() {
        return Err(RuntimeError::message(format!(
            "no runtime-recorded execution evidence for iteration {iteration} ({} missing); \
             run `wb-runtime record-test-evidence` — the runtime executes the integration test \
             command itself and signs the result, so a hand-written verdict cannot pass this gate",
            path.display()
        )));
    }
    let mut payload: Value = serde_json::from_str(&fs::read_to_string(&path)?)?;
    let object = payload
        .as_object_mut()
        .ok_or_else(|| RuntimeError::message("evidence record must be a JSON object"))?;
    let recorded_mac = object
        .remove("hmac")
        .and_then(|value| value.as_str().map(ToString::to_string))
        .ok_or_else(|| RuntimeError::message("evidence record has no hmac field"))?;
    let key = load_key()?;
    let expected_mac = hmac_hex(&key, serde_json::to_string(&payload)?.as_bytes());
    if !constant_time_eq(recorded_mac.as_bytes(), expected_mac.as_bytes()) {
        return Err(RuntimeError::message(
            "integration evidence failed verification (HMAC mismatch): the record was modified \
             after recording or was not produced by this machine's wb-runtime",
        ));
    }

    let exit_code = payload.get("exit_code").and_then(Value::as_i64).unwrap_or(-1);
    if exit_code != 0 {
        return Err(RuntimeError::message(format!(
            "recorded integration run failed (exit {exit_code}); rerun \
             `wb-runtime record-test-evidence` after fixing the tests"
        )));
    }

    let recorded_spec = payload.get("spec_hash").and_then(Value::as_str).unwrap_or("");
    let current_spec = spec_hash(project_root)?;
    if recorded_spec != current_spec {
        return Err(RuntimeError::message(
            "integration evidence is stale: the spec changed after the recorded run; \
             rerun `wb-runtime record-test-evidence`",
        ));
    }

    let recorded_command = payload.get("command").and_then(Value::as_str).unwrap_or("");
    let configured_command = integration_test_command(project_root)?;
    if recorded_command != configured_command {
        return Err(RuntimeError::message(
            "integration evidence command does not match config.integration_test_command; \
             rerun `wb-runtime record-test-evidence` against the current config",
        ));
    }

    Ok(vec![
        format!("runtime-recorded integration evidence verified (iteration {iteration})"),
        format!("command `{recorded_command}` exited 0"),
        "evidence HMAC valid and spec unchanged since the run".to_string(),
    ])
}

pub fn current_iteration(project_root: &Path) -> Result<u64> {
    let mut latest = 0u64;
    let loop_state = project_root.join(".wannabuild/loop-state.json");
    if loop_state.is_file() {
        let value: Value = serde_json::from_str(&fs::read_to_string(loop_state)?)?;
        if let Some(iterations) = value.get("iterations").and_then(Value::as_array) {
            for item in iterations {
                latest = latest.max(item.get("iteration").and_then(Value::as_u64).unwrap_or(0));
            }
        }
    }
    let review_dir = project_root.join(".wannabuild/review");
    if review_dir.is_dir() {
        for entry in fs::read_dir(review_dir)? {
            let Ok(entry) = entry else { continue };
            let name = entry.file_name();
            let Some(name) = name.to_str() else { continue };
            if let Some(index) = name.find("iter-") {
                let digits = name[index + "iter-".len()..]
                    .chars()
                    .take_while(char::is_ascii_digit)
                    .collect::<String>();
                if let Ok(iteration) = digits.parse::<u64>() {
                    latest = latest.max(iteration);
                }
            }
        }
    }
    Ok(latest.max(1))
}

fn shell_command(command: &str) -> Command {
    #[cfg(windows)]
    {
        let mut shell = Command::new("cmd");
        shell.arg("/C").arg(command);
        shell
    }
    #[cfg(not(windows))]
    {
        let mut shell = Command::new("sh");
        shell.arg("-c").arg(command);
        shell
    }
}

fn key_path() -> Result<PathBuf> {
    if let Ok(path) = std::env::var(KEY_FILE_ENV)
        && !path.trim().is_empty()
    {
        return Ok(PathBuf::from(path));
    }
    let home = std::env::var("HOME")
        .or_else(|_| std::env::var("USERPROFILE"))
        .map_err(|_| {
            RuntimeError::message(format!(
                "cannot locate the evidence key: HOME is unset and {KEY_FILE_ENV} is not provided"
            ))
        })?;
    Ok(PathBuf::from(home).join(".wannabuild/evidence.key"))
}

fn load_key() -> Result<Vec<u8>> {
    let path = key_path()?;
    if !path.is_file() {
        return Err(RuntimeError::message(format!(
            "no evidence key at {}; run `wb-runtime record-test-evidence` first \
             (recording creates the key)",
            path.display()
        )));
    }
    let raw = fs::read_to_string(&path)?;
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Err(RuntimeError::message(format!(
            "evidence key at {} is empty",
            path.display()
        )));
    }
    Ok(trimmed.as_bytes().to_vec())
}

fn load_or_create_key() -> Result<Vec<u8>> {
    use std::io::Write;

    let path = key_path()?;
    if path.is_file() {
        return load_key_waiting(&path);
    }
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let mut bytes = [0u8; 32];
    getrandom::fill(&mut bytes)
        .map_err(|error| RuntimeError::message(format!("cannot generate evidence key: {error}")))?;
    let encoded = hex(&bytes);
    // create_new makes first-writer-wins explicit: a concurrent creator loses the
    // race and loads the winner's key instead of clobbering it.
    match fs::OpenOptions::new().write(true).create_new(true).open(&path) {
        Ok(mut file) => {
            file.write_all(encoded.as_bytes())?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                fs::set_permissions(&path, fs::Permissions::from_mode(0o600))?;
            }
            Ok(encoded.into_bytes())
        }
        Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => {
            load_key_waiting(&path)
        }
        Err(error) => Err(error.into()),
    }
}

/// Loads the key, briefly waiting out a concurrent creator that has opened the
/// file but not finished writing its 64 bytes yet.
fn load_key_waiting(path: &Path) -> Result<Vec<u8>> {
    for _ in 0..50 {
        let raw = fs::read_to_string(path)?;
        let trimmed = raw.trim();
        if !trimmed.is_empty() {
            return Ok(trimmed.as_bytes().to_vec());
        }
        std::thread::sleep(std::time::Duration::from_millis(10));
    }
    Err(RuntimeError::message(format!(
        "evidence key at {} is empty",
        path.display()
    )))
}

fn spec_hash(project_root: &Path) -> Result<String> {
    let mut hasher = Sha256::new();
    for name in SPEC_FILES {
        let path = project_root.join(".wannabuild/spec").join(name);
        if path.is_file() {
            let body = fs::read(&path)?;
            hasher.update(name.as_bytes());
            hasher.update(body.len().to_le_bytes());
            hasher.update(&body);
        }
    }
    Ok(hex(&hasher.finalize()))
}

fn sha256_hex(data: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(data);
    hex(&hasher.finalize())
}

fn hmac_hex(key: &[u8], data: &[u8]) -> String {
    let mut mac = HmacSha256::new_from_slice(key).expect("HMAC accepts any key length");
    mac.update(data);
    hex(&mac.finalize().into_bytes())
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

fn constant_time_eq(left: &[u8], right: &[u8]) -> bool {
    if left.len() != right.len() {
        return false;
    }
    left.iter()
        .zip(right.iter())
        .fold(0u8, |acc, (a, b)| acc | (a ^ b))
        == 0
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::path::Path;

    use tempfile::tempdir;

    use super::*;

    fn write_project(project_root: &Path, test_command: &str) {
        fs::create_dir_all(project_root.join(".wannabuild/spec")).unwrap();
        fs::create_dir_all(project_root.join(".wannabuild/review")).unwrap();
        fs::write(
            project_root.join(".wannabuild/config.json"),
            format!(r#"{{"integration_test_command": "{test_command}"}}"#),
        )
        .unwrap();
        fs::write(
            project_root.join(".wannabuild/spec/requirements.md"),
            "# Requirements\n\n## Acceptance Criteria\n\n- works\n",
        )
        .unwrap();
    }

    #[test]
    fn record_then_verify_round_trips() {
        let dir = tempdir().unwrap();
        write_project(dir.path(), "true");

        let record = record_test_evidence(dir.path(), Some(1)).unwrap();
        assert_eq!(record.exit_code, 0);

        let evidence = verify_integration_evidence(dir.path(), 1).unwrap();
        assert!(evidence.iter().any(|line| line.contains("verified")));
    }

    #[test]
    fn verify_fails_without_record() {
        let dir = tempdir().unwrap();
        write_project(dir.path(), "true");

        let err = verify_integration_evidence(dir.path(), 1).unwrap_err().to_string();

        assert!(err.contains("no runtime-recorded execution evidence"));
    }

    #[test]
    fn verify_fails_on_tampered_record() {
        let dir = tempdir().unwrap();
        write_project(dir.path(), "true");
        record_test_evidence(dir.path(), Some(1)).unwrap();

        let path = evidence_path(dir.path(), 1);
        let tampered = fs::read_to_string(&path)
            .unwrap()
            .replace("\"exit_code\": 0", "\"exit_code\": 0, \"forged\": true");
        fs::write(&path, tampered).unwrap();

        let err = verify_integration_evidence(dir.path(), 1).unwrap_err().to_string();

        assert!(err.contains("HMAC mismatch"));
    }

    #[test]
    fn record_keeps_failure_evidence_and_verify_rejects_it() {
        let dir = tempdir().unwrap();
        write_project(dir.path(), "exit 3");

        let err = record_test_evidence(dir.path(), Some(1)).unwrap_err().to_string();
        assert!(err.contains("exit 3"));
        assert!(evidence_path(dir.path(), 1).is_file());

        let err = verify_integration_evidence(dir.path(), 1).unwrap_err().to_string();
        assert!(err.contains("recorded integration run failed"));
    }

    #[test]
    fn verify_fails_when_spec_changes_after_recording() {
        let dir = tempdir().unwrap();
        write_project(dir.path(), "true");
        record_test_evidence(dir.path(), Some(1)).unwrap();

        fs::write(
            dir.path().join(".wannabuild/spec/requirements.md"),
            "# Requirements\n\n## Acceptance Criteria\n\n- works\n- and more\n",
        )
        .unwrap();

        let err = verify_integration_evidence(dir.path(), 1).unwrap_err().to_string();

        assert!(err.contains("stale"));
    }

    #[test]
    fn verify_fails_when_config_command_changes_after_recording() {
        let dir = tempdir().unwrap();
        write_project(dir.path(), "true");
        record_test_evidence(dir.path(), Some(1)).unwrap();

        fs::write(
            dir.path().join(".wannabuild/config.json"),
            r#"{"integration_test_command": "echo different"}"#,
        )
        .unwrap();

        let err = verify_integration_evidence(dir.path(), 1).unwrap_err().to_string();

        assert!(err.contains("does not match config.integration_test_command"));
    }
}
