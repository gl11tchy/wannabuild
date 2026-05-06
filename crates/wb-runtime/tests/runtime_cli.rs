use std::fs;
use std::path::Path;

use assert_cmd::Command;
use serde_json::Value;
use tempfile::tempdir;

fn wb_runtime() -> Command {
    Command::cargo_bin("wb-runtime").expect("wb-runtime binary")
}

fn project_arg(path: &Path) -> String {
    path.display().to_string()
}

fn output_text(output: std::process::Output) -> String {
    format!(
        "{}{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    )
}

fn write(path: impl AsRef<Path>, value: &str) {
    if let Some(parent) = path.as_ref().parent() {
        fs::create_dir_all(parent).unwrap();
    }
    fs::write(path, value).unwrap();
}

fn write_reviews(project: &Path, status: &str) {
    for agent in [
        "wb-security-reviewer",
        "wb-performance-reviewer",
        "wb-architecture-reviewer",
        "wb-testing-reviewer",
        "wb-integration-tester",
        "wb-code-simplifier",
    ] {
        write(
            project.join(format!(".wannabuild/review/{agent}-iter-1.json")),
            &format!(r#"{{"agent":"{agent}","status":"{status}","summary":"ok","issues":[]}}"#),
        );
    }
}

#[test]
fn help_exposes_runtime_command_groups() {
    let output = wb_runtime().arg("--help").output().unwrap();
    let text = output_text(output);

    assert!(text.contains("status"));
    assert!(text.contains("assert-plan-ready"));
    assert!(text.contains("event"));
    assert!(text.contains("tasks"));
    assert!(text.contains("adapter"));
}

#[test]
fn no_task_blocks_planning() {
    let dir = tempdir().unwrap();

    let output = wb_runtime()
        .args([
            "transition",
            "--project",
            &project_arg(dir.path()),
            "--to",
            "plan",
        ])
        .output()
        .unwrap();

    assert!(!output.status.success());
    assert!(output_text(output).contains("Concrete task gate failed"));
}

#[test]
fn plan_gate_blocks_and_allows_implementation() {
    let dir = tempdir().unwrap();
    write(
        dir.path().join(".wannabuild/spec/requirements.md"),
        "requirements",
    );

    wb_runtime()
        .args([
            "transition",
            "--project",
            &project_arg(dir.path()),
            "--to",
            "plan",
        ])
        .assert()
        .success();

    let blocked = wb_runtime()
        .args([
            "transition",
            "--project",
            &project_arg(dir.path()),
            "--to",
            "implement",
        ])
        .output()
        .unwrap();
    assert!(!blocked.status.success());
    assert!(output_text(blocked).contains("Plan gate failed"));

    write(dir.path().join(".wannabuild/spec/design.md"), "design");
    write(dir.path().join(".wannabuild/spec/tasks.md"), "tasks");

    wb_runtime()
        .args([
            "transition",
            "--project",
            &project_arg(dir.path()),
            "--to",
            "implement",
        ])
        .assert()
        .success();
}

#[test]
fn plan_complete_transition_requires_real_plan_evidence() {
    let dir = tempdir().unwrap();
    write(
        dir.path().join(".wannabuild/spec/requirements.md"),
        "requirements",
    );

    wb_runtime()
        .args([
            "transition",
            "--project",
            &project_arg(dir.path()),
            "--to",
            "plan",
            "--status",
            "in_progress",
        ])
        .assert()
        .success();

    let denied = wb_runtime()
        .args([
            "transition",
            "--project",
            &project_arg(dir.path()),
            "--to",
            "plan",
            "--status",
            "complete",
        ])
        .output()
        .unwrap();
    assert!(!denied.status.success());
    assert!(output_text(denied).contains("Plan completion denied"));

    let gate = wb_runtime()
        .args(["assert-plan-ready", "--project", &project_arg(dir.path())])
        .output()
        .unwrap();
    assert!(!gate.status.success());
    assert!(output_text(gate).contains("Plan gate failed"));

    write(dir.path().join(".wannabuild/spec/design.md"), "design");
    write(dir.path().join(".wannabuild/spec/tasks.md"), "tasks");
    wb_runtime()
        .args([
            "transition",
            "--project",
            &project_arg(dir.path()),
            "--to",
            "plan",
            "--status",
            "complete",
        ])
        .assert()
        .success();
}

#[test]
fn design_and_tasks_transitions_record_internal_phase_history() {
    let dir = tempdir().unwrap();
    write(
        dir.path().join(".wannabuild/spec/requirements.md"),
        "requirements",
    );

    wb_runtime()
        .args([
            "transition",
            "--project",
            &project_arg(dir.path()),
            "--to",
            "design",
            "--status",
            "complete",
        ])
        .assert()
        .success();
    let state: Value = serde_json::from_str(
        &fs::read_to_string(dir.path().join(".wannabuild/state.json")).unwrap(),
    )
    .unwrap();
    assert_eq!(state["public_stage"], "plan");
    assert_eq!(state["current_phase"], "design");
    assert!(
        state["phase_history"]
            .as_array()
            .unwrap()
            .iter()
            .any(|item| item["phase"] == "design" && item["status"] == "complete")
    );
    assert!(
        !state["public_stage_history"]
            .as_array()
            .unwrap()
            .iter()
            .any(|item| item["stage"] == "plan" && item["status"] == "complete")
    );

    wb_runtime()
        .args([
            "transition",
            "--project",
            &project_arg(dir.path()),
            "--to",
            "tasks",
            "--status",
            "complete",
        ])
        .assert()
        .success();
    let state: Value = serde_json::from_str(
        &fs::read_to_string(dir.path().join(".wannabuild/state.json")).unwrap(),
    )
    .unwrap();
    assert_eq!(state["public_stage"], "plan");
    assert_eq!(state["current_phase"], "tasks");
    assert!(
        state["phase_history"]
            .as_array()
            .unwrap()
            .iter()
            .any(|item| item["phase"] == "tasks" && item["status"] == "complete")
    );
    assert!(
        state["public_stage_history"]
            .as_array()
            .unwrap()
            .iter()
            .any(|item| item["stage"] == "plan" && item["status"] == "complete")
    );
}

#[test]
fn events_append_list_and_replay() {
    let dir = tempdir().unwrap();

    wb_runtime()
        .args([
            "event",
            "append",
            "--project",
            &project_arg(dir.path()),
            "--type",
            "checkpoint",
            "--json",
            r#"{"checkpoint":"one"}"#,
        ])
        .assert()
        .success();

    let listed = wb_runtime()
        .args(["event", "list", "--project", &project_arg(dir.path())])
        .output()
        .unwrap();
    let text = output_text(listed);
    assert!(text.contains("checkpoint"));
    assert!(text.contains("events.jsonl") || dir.path().join(".wannabuild/events.jsonl").is_file());

    let replayed = wb_runtime()
        .args(["event", "replay", "--project", &project_arg(dir.path())])
        .output()
        .unwrap();
    let replayed_json: Value = serde_json::from_slice(&replayed.stdout).unwrap();
    assert_eq!(replayed_json["events_replayed"], 1);
    assert!(replayed_json["last_event_id"].as_str().is_some());
}

#[test]
fn events_redact_sensitive_payloads_when_appended_and_listed() {
    let dir = tempdir().unwrap();

    let appended = wb_runtime()
        .args([
            "event",
            "append",
            "--project",
            &project_arg(dir.path()),
            "--type",
            "runtime_context_emitted",
            "--json",
            r#"{"token":"raw-token","message":"password=hunter2","nested":{"api_key":"raw-key","safe":"ok","items":["token=raw-nested","AKIAIOSFODNN7EXAMPLE"]}}"#,
        ])
        .output()
        .unwrap();

    let appended_text = output_text(appended);
    assert!(appended_text.contains("[REDACTED]"));
    assert!(!appended_text.contains("raw-token"));
    assert!(!appended_text.contains("raw-key"));
    assert!(!appended_text.contains("hunter2"));
    assert!(!appended_text.contains("raw-nested"));
    assert!(!appended_text.contains("AKIAIOSFODNN7EXAMPLE"));

    let listed = wb_runtime()
        .args(["event", "list", "--project", &project_arg(dir.path())])
        .output()
        .unwrap();
    let listed_text = output_text(listed);
    assert!(listed_text.contains("[REDACTED]"));
    assert!(!listed_text.contains("raw-token"));
    assert!(!listed_text.contains("raw-key"));
    assert!(!listed_text.contains("hunter2"));
    assert!(!listed_text.contains("raw-nested"));
    assert!(!listed_text.contains("AKIAIOSFODNN7EXAMPLE"));
}

#[test]
fn tasks_can_resume_from_checkpoint_and_prevent_double_claim() {
    let dir = tempdir().unwrap();
    let tasks_md = dir.path().join(".wannabuild/spec/tasks.md");
    write(
        &tasks_md,
        r#"# Tasks

## Task T-001: First

- Phase: implement
- Dependencies: none
- Acceptance criteria:
  - First complete.

## Task T-002: Second

- Phase: implement
- Dependencies: T-001
- Acceptance criteria:
  - Second ready after first.
"#,
    );
    write(dir.path().join(".wannabuild/spec/design.md"), "design");

    wb_runtime()
        .args([
            "tasks",
            "import",
            "--project",
            &project_arg(dir.path()),
            "--from",
            &project_arg(&tasks_md),
        ])
        .assert()
        .success();

    fs::remove_file(dir.path().join(".wannabuild/spec/design.md")).unwrap();
    let plan_blocked_claim = wb_runtime()
        .args([
            "tasks",
            "claim",
            "--project",
            &project_arg(dir.path()),
            "--task",
            "T-001",
            "--owner",
            "owner-a",
        ])
        .output()
        .unwrap();
    assert!(!plan_blocked_claim.status.success());
    assert!(output_text(plan_blocked_claim).contains("Plan gate failed"));
    write(dir.path().join(".wannabuild/spec/design.md"), "design");

    let dependency_claim = wb_runtime()
        .args([
            "tasks",
            "claim",
            "--project",
            &project_arg(dir.path()),
            "--task",
            "T-002",
            "--owner",
            "owner-a",
        ])
        .output()
        .unwrap();
    assert!(!dependency_claim.status.success());
    assert!(output_text(dependency_claim).contains("dependencies are not complete"));

    let direct_complete = wb_runtime()
        .args([
            "tasks",
            "complete",
            "--project",
            &project_arg(dir.path()),
            "--task",
            "T-002",
        ])
        .output()
        .unwrap();
    assert!(!direct_complete.status.success());
    assert!(output_text(direct_complete).contains("cannot be completed from status pending"));

    let next = wb_runtime()
        .args(["tasks", "next", "--project", &project_arg(dir.path())])
        .output()
        .unwrap();
    assert!(output_text(next).contains("next_task: T-001"));
    let decisions = fs::read_to_string(dir.path().join(".wannabuild/decisions.md")).unwrap();
    assert!(decisions.contains("Scheduler Decision"));
    assert!(decisions.contains("- scheduler: single-owner"));
    assert!(decisions.contains("- rationale: defaulting to the smallest dependency-ready task"));
    assert!(decisions.contains("- next_task: T-001 First"));

    wb_runtime()
        .args([
            "tasks",
            "claim",
            "--project",
            &project_arg(dir.path()),
            "--task",
            "T-001",
            "--owner",
            "owner-a",
        ])
        .assert()
        .success();

    let double_claim = wb_runtime()
        .args([
            "tasks",
            "claim",
            "--project",
            &project_arg(dir.path()),
            "--task",
            "T-001",
            "--owner",
            "owner-b",
        ])
        .output()
        .unwrap();
    assert!(!double_claim.status.success());
    assert!(output_text(double_claim).contains("already claimed"));

    let missing_checkpoint = wb_runtime()
        .args([
            "tasks",
            "complete",
            "--project",
            &project_arg(dir.path()),
            "--task",
            "T-001",
        ])
        .output()
        .unwrap();
    assert!(!missing_checkpoint.status.success());
    assert!(output_text(missing_checkpoint).contains("requires --checkpoint"));

    let checkpoint = dir.path().join(".wannabuild/checkpoints/task-1-step-1.md");
    write(&checkpoint, "checkpoint");
    let completed = wb_runtime()
        .args([
            "tasks",
            "complete",
            "--project",
            &project_arg(dir.path()),
            "--task",
            "T-001",
            "--checkpoint",
            &project_arg(&checkpoint),
        ])
        .output()
        .unwrap();
    assert!(completed.status.success());
    let completed_json: Value = serde_json::from_slice(&completed.stdout).unwrap();
    assert_eq!(
        completed_json["checkpoint_path"],
        checkpoint.canonicalize().unwrap().display().to_string()
    );
    let events = fs::read_to_string(dir.path().join(".wannabuild/events.jsonl")).unwrap();
    assert!(events.contains("checkpoint_written"));
    assert!(events.contains(&checkpoint.canonicalize().unwrap().display().to_string()));

    let next_after_checkpoint = wb_runtime()
        .args(["tasks", "next", "--project", &project_arg(dir.path())])
        .output()
        .unwrap();
    assert!(output_text(next_after_checkpoint).contains("next_task: T-002"));
}

#[test]
fn tasks_block_records_reason_and_checkpoint_paths_are_confined() {
    let dir = tempdir().unwrap();
    let tasks_md = dir.path().join(".wannabuild/spec/tasks.md");
    write(
        &tasks_md,
        r#"# Tasks

## Task T-001: First

- Phase: implement
- Dependencies: none
- Acceptance criteria:
  - First complete.
"#,
    );
    write(dir.path().join(".wannabuild/spec/design.md"), "design");

    wb_runtime()
        .args([
            "tasks",
            "import",
            "--project",
            &project_arg(dir.path()),
            "--from",
            &project_arg(&tasks_md),
        ])
        .assert()
        .success();
    wb_runtime()
        .args([
            "tasks",
            "claim",
            "--project",
            &project_arg(dir.path()),
            "--task",
            "T-001",
            "--owner",
            "owner-a",
        ])
        .assert()
        .success();

    let outside_checkpoint = dir.path().join("checkpoint.md");
    write(&outside_checkpoint, "outside");
    let rejected_checkpoint = wb_runtime()
        .args([
            "tasks",
            "complete",
            "--project",
            &project_arg(dir.path()),
            "--task",
            "T-001",
            "--checkpoint",
            &project_arg(&outside_checkpoint),
        ])
        .output()
        .unwrap();
    assert!(!rejected_checkpoint.status.success());
    assert!(output_text(rejected_checkpoint).contains("Checkpoint path must be inside"));

    let blocked = wb_runtime()
        .args([
            "tasks",
            "block",
            "--project",
            &project_arg(dir.path()),
            "--task",
            "T-001",
            "--reason",
            "waiting on API",
        ])
        .output()
        .unwrap();
    assert!(blocked.status.success());
    let blocked_json: Value = serde_json::from_slice(&blocked.stdout).unwrap();
    assert_eq!(blocked_json["status"], "blocked");
    assert_eq!(blocked_json["blocked_reason"], "waiting on API");
    assert!(
        fs::read_to_string(dir.path().join(".wannabuild/events.jsonl"))
            .unwrap()
            .contains("task_blocked")
    );
}

#[test]
fn review_qa_and_summary_gates_block_missing_or_failing_evidence() {
    let dir = tempdir().unwrap();
    write(
        dir.path().join(".wannabuild/outputs/qa-summary.md"),
        "# QA\n\nstatus: PASS\nacceptance_coverage: covered\nintegration_coverage: covered\n",
    );

    let missing_review = wb_runtime()
        .args([
            "assert-summary-ready",
            "--project",
            &project_arg(dir.path()),
        ])
        .output()
        .unwrap();
    assert!(!missing_review.status.success());
    assert!(output_text(missing_review).contains("Review gate failed"));

    write_reviews(dir.path(), "FAIL");
    let failing_review = wb_runtime()
        .args([
            "assert-summary-ready",
            "--project",
            &project_arg(dir.path()),
        ])
        .output()
        .unwrap();
    assert!(!failing_review.status.success());
    assert!(output_text(failing_review).contains("Non-passing review verdicts"));

    write_reviews(dir.path(), "PASS");
    write(
        dir.path()
            .join(".wannabuild/review/wb-security-reviewer-iter-0.json"),
        r#"{"agent":"wb-security-reviewer","status":"FAIL","summary":"old","issues":[]}"#,
    );
    wb_runtime()
        .args(["assert-review-ready", "--project", &project_arg(dir.path())])
        .assert()
        .success();

    write_reviews(dir.path(), "PASS");
    fs::remove_file(dir.path().join(".wannabuild/outputs/qa-summary.md")).unwrap();
    let missing_qa = wb_runtime()
        .args([
            "assert-summary-ready",
            "--project",
            &project_arg(dir.path()),
        ])
        .output()
        .unwrap();
    assert!(!missing_qa.status.success());
    assert!(output_text(missing_qa).contains("QA gate failed"));

    write(
        dir.path().join(".wannabuild/outputs/qa-summary.md"),
        "# QA\n\nstatus: failed\n",
    );
    let failed_marker = wb_runtime()
        .args(["assert-qa-ready", "--project", &project_arg(dir.path())])
        .output()
        .unwrap();
    assert!(!failed_marker.status.success());
    assert!(output_text(failed_marker).contains("QA summary marks status as failed"));

    write(dir.path().join(".wannabuild/outputs/qa-summary.md"), "# QA");
    let ambiguous_summary = wb_runtime()
        .args(["assert-qa-ready", "--project", &project_arg(dir.path())])
        .output()
        .unwrap();
    assert!(!ambiguous_summary.status.success());
    assert!(output_text(ambiguous_summary).contains("lacks positive PASS evidence"));

    wb_runtime()
        .args([
            "event",
            "append",
            "--project",
            &project_arg(dir.path()),
            "--type",
            "qa_failed",
            "--json",
            r#"{"reason":"integration failed"}"#,
        ])
        .assert()
        .success();
    let failed_event = wb_runtime()
        .args(["assert-qa-ready", "--project", &project_arg(dir.path())])
        .output()
        .unwrap();
    assert!(!failed_event.status.success());
    assert!(output_text(failed_event).contains("latest QA event is qa_failed"));

    wb_runtime()
        .args([
            "event",
            "append",
            "--project",
            &project_arg(dir.path()),
            "--type",
            "qa_passed",
        ])
        .assert()
        .success();
    let passed_event_without_coverage = wb_runtime()
        .args(["assert-qa-ready", "--project", &project_arg(dir.path())])
        .output()
        .unwrap();
    assert!(!passed_event_without_coverage.status.success());
    assert!(output_text(passed_event_without_coverage).contains("lacks positive PASS evidence"));
    write(
        dir.path().join(".wannabuild/outputs/qa-summary.md"),
        "# QA\n\nstatus: PASS\nacceptance_coverage: covered\nintegration_coverage: covered\n",
    );
    wb_runtime()
        .args([
            "assert-summary-ready",
            "--project",
            &project_arg(dir.path()),
        ])
        .assert()
        .success();
}

#[test]
fn qa_gate_accepts_structured_summary_without_event() {
    let dir = tempdir().unwrap();
    write(
        dir.path().join(".wannabuild/outputs/qa-summary.md"),
        "# QA\n\nverdict: PASS\nacceptance criteria: verified\nintegration behavior: verified\n",
    );

    wb_runtime()
        .args(["assert-qa-ready", "--project", &project_arg(dir.path())])
        .assert()
        .success();
}

#[test]
fn status_is_read_only_when_state_is_missing() {
    let dir = tempdir().unwrap();

    let status = wb_runtime()
        .args(["status", "--project", &project_arg(dir.path())])
        .output()
        .unwrap();

    assert!(status.status.success());
    assert!(!dir.path().join(".wannabuild/state.json").exists());
}

#[test]
fn context_and_adapter_route_are_read_only_when_state_is_missing() {
    let dir = tempdir().unwrap();

    wb_runtime()
        .args([
            "context",
            "--project",
            &project_arg(dir.path()),
            "--format",
            "json",
        ])
        .assert()
        .success();
    assert!(!dir.path().join(".wannabuild").exists());

    wb_runtime()
        .args([
            "adapter",
            "context",
            "--project",
            &project_arg(dir.path()),
            "--host",
            "claude-code",
            "--event",
            "SessionStart",
        ])
        .assert()
        .success();
    assert!(!dir.path().join(".wannabuild").exists());

    wb_runtime()
        .args([
            "adapter",
            "route",
            "--project",
            &project_arg(dir.path()),
            "--host",
            "codex",
            "--prompt",
            "Plan this",
        ])
        .assert()
        .success();
    assert!(!dir.path().join(".wannabuild").exists());
}

#[test]
fn resume_after_fresh_cli_invocation_updates_state_and_emits_event() {
    let dir = tempdir().unwrap();

    wb_runtime()
        .args(["init", "--project", &project_arg(dir.path())])
        .assert()
        .success();
    wb_runtime()
        .args([
            "pause",
            "--project",
            &project_arg(dir.path()),
            "--reason",
            "operator requested pause",
        ])
        .assert()
        .success();
    wb_runtime()
        .args(["resume", "--project", &project_arg(dir.path())])
        .assert()
        .success();

    let state: Value = serde_json::from_str(
        &fs::read_to_string(dir.path().join(".wannabuild/state.json")).unwrap(),
    )
    .unwrap();
    assert_eq!(state["workflow_status"], "in_progress");
    assert_eq!(state["phase_status"], "in_progress");
    assert!(state["pause_reason"].is_null());
    let events = fs::read_to_string(dir.path().join(".wannabuild/events.jsonl")).unwrap();
    assert!(events.contains(r#""type":"phase_paused""#));
    assert!(events.contains(r#""type":"workflow_resumed""#));
}

#[test]
fn adapter_context_and_routes_are_host_equivalent() {
    let dir = tempdir().unwrap();
    wb_runtime()
        .args(["init", "--project", &project_arg(dir.path())])
        .assert()
        .success();

    let claude = wb_runtime()
        .args([
            "adapter",
            "context",
            "--project",
            &project_arg(dir.path()),
            "--host",
            "claude-code",
            "--event",
            "SessionStart",
        ])
        .output()
        .unwrap();
    let codex = wb_runtime()
        .args([
            "adapter",
            "context",
            "--project",
            &project_arg(dir.path()),
            "--host",
            "codex",
            "--event",
            "bootstrap",
        ])
        .output()
        .unwrap();
    let cursor = wb_runtime()
        .args([
            "adapter",
            "context",
            "--project",
            &project_arg(dir.path()),
            "--host",
            "cursor",
            "--event",
            "bootstrap",
        ])
        .output()
        .unwrap();
    let claude_json: Value = serde_json::from_slice(&claude.stdout).unwrap();
    let codex_json: Value = serde_json::from_slice(&codex.stdout).unwrap();
    let cursor_json: Value = serde_json::from_slice(&cursor.stdout).unwrap();
    assert_eq!(
        claude_json["allowed_next_action"],
        codex_json["allowed_next_action"]
    );
    assert_eq!(
        claude_json["allowed_next_action"],
        cursor_json["allowed_next_action"]
    );
    assert_eq!(
        claude_json["forbidden_actions"],
        codex_json["forbidden_actions"]
    );
    assert_eq!(
        claude_json["forbidden_actions"],
        cursor_json["forbidden_actions"]
    );
    assert_eq!(claude_json["required_gates"], codex_json["required_gates"]);
    assert_eq!(claude_json["required_gates"], cursor_json["required_gates"]);
    assert_eq!(claude_json["pause_required"], codex_json["pause_required"]);
    assert_eq!(claude_json["pause_required"], cursor_json["pause_required"]);
    assert!(
        claude_json["required_gates"]
            .as_array()
            .unwrap()
            .contains(&Value::String("assert-plan-ready".to_string()))
    );

    let route = wb_runtime()
        .args([
            "adapter",
            "route",
            "--project",
            &project_arg(dir.path()),
            "--host",
            "cursor",
            "--prompt",
            "I want to add team invitations",
        ])
        .output()
        .unwrap();
    let route_json: Value = serde_json::from_slice(&route.stdout).unwrap();
    assert_eq!(route_json["route"], "wannabuild");

    let ack = wb_runtime()
        .args([
            "adapter",
            "route",
            "--project",
            &project_arg(dir.path()),
            "--host",
            "shell",
            "--prompt",
            "ok",
        ])
        .output()
        .unwrap();
    let ack_json: Value = serde_json::from_slice(&ack.stdout).unwrap();
    assert_eq!(ack_json["route"], "continue-current-phase");
    assert_eq!(ack_json["vague_acknowledgment"], true);

    for host in ["claude-code", "codex", "cursor"] {
        for (prompt, expected) in [
            ("Brainstorming-only: talk through onboarding", "wb-discover"),
            ("Plan the architecture", "wb-plan"),
            ("Implement the next planned slice", "wb-build"),
            ("ok", "continue-current-phase"),
        ] {
            let routed = wb_runtime()
                .args([
                    "adapter",
                    "route",
                    "--project",
                    &project_arg(dir.path()),
                    "--host",
                    host,
                    "--prompt",
                    prompt,
                ])
                .output()
                .unwrap();
            let routed_json: Value = serde_json::from_slice(&routed.stdout).unwrap();
            assert_eq!(routed_json["route"], expected);
        }
    }
}
