use std::path::PathBuf;

use clap::{Args, Parser, Subcommand, ValueEnum};
use serde::Serialize;
use serde_json::{Value, json};

use crate::errors::{Result, RuntimeError};
use crate::{adapters, context, events, gates, locks, state, tasks, transitions};

#[derive(Debug, Parser)]
#[command(name = "wb-runtime")]
#[command(about = "CLI-first WannaBuild runtime kernel")]
pub struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Debug, Subcommand)]
enum Commands {
    Init(ProjectArgs),
    Status(StatusArgs),
    Context(ContextArgs),
    NextAction(ProjectArgs),
    Pause(PauseArgs),
    Resume(ProjectArgs),
    Complete(ProjectArgs),
    Transition(TransitionArgs),
    AssertWorkflowActive(ProjectArgs),
    AssertConcreteTask(ProjectArgs),
    AssertPlanReady(ProjectArgs),
    AssertReviewReady(ProjectArgs),
    AssertQaReady(ProjectArgs),
    AssertSummaryReady(ProjectArgs),
    Event(EventArgs),
    Tasks(TasksArgs),
    Adapter(AdapterArgs),
}

#[derive(Debug, Args, Clone)]
struct ProjectArgs {
    #[arg(long, default_value = ".")]
    project: PathBuf,
}

#[derive(Debug, Args)]
struct StatusArgs {
    #[command(flatten)]
    project: ProjectArgs,
    #[arg(long, value_enum, default_value_t = OutputFormat::Text)]
    format: OutputFormat,
}

#[derive(Debug, Args)]
struct ContextArgs {
    #[command(flatten)]
    project: ProjectArgs,
    #[arg(long, value_enum, default_value_t = OutputFormat::Text)]
    format: OutputFormat,
}

#[derive(Debug, Args)]
struct PauseArgs {
    #[command(flatten)]
    project: ProjectArgs,
    #[arg(long)]
    reason: String,
}

#[derive(Debug, Args)]
struct TransitionArgs {
    #[command(flatten)]
    project: ProjectArgs,
    #[arg(long)]
    to: String,
    #[arg(long, default_value = "in_progress")]
    status: String,
}

#[derive(Debug, Args)]
struct EventArgs {
    #[command(subcommand)]
    command: EventCommand,
}

#[derive(Debug, Subcommand)]
enum EventCommand {
    Append(EventAppendArgs),
    List(EventListArgs),
    Replay(ProjectArgs),
}

#[derive(Debug, Args)]
struct EventAppendArgs {
    #[command(flatten)]
    project: ProjectArgs,
    #[arg(long = "type")]
    event_type: String,
    #[arg(long)]
    json: Option<String>,
    #[arg(long)]
    path: Option<PathBuf>,
}

#[derive(Debug, Args)]
struct EventListArgs {
    #[command(flatten)]
    project: ProjectArgs,
    #[arg(long)]
    since: Option<String>,
}

#[derive(Debug, Args)]
struct TasksArgs {
    #[command(subcommand)]
    command: TasksCommand,
}

#[derive(Debug, Subcommand)]
enum TasksCommand {
    Import(TasksImportArgs),
    List(ProjectArgs),
    Next(ProjectArgs),
    Claim(TasksClaimArgs),
    Complete(TasksCompleteArgs),
    Block(TasksBlockArgs),
}

#[derive(Debug, Args)]
struct TasksImportArgs {
    #[command(flatten)]
    project: ProjectArgs,
    #[arg(long = "from")]
    from: PathBuf,
}

#[derive(Debug, Args)]
struct TasksClaimArgs {
    #[command(flatten)]
    project: ProjectArgs,
    #[arg(long)]
    task: String,
    #[arg(long)]
    owner: String,
}

#[derive(Debug, Args)]
struct TasksCompleteArgs {
    #[command(flatten)]
    project: ProjectArgs,
    #[arg(long)]
    task: String,
    #[arg(long)]
    checkpoint: Option<PathBuf>,
}

#[derive(Debug, Args)]
struct TasksBlockArgs {
    #[command(flatten)]
    project: ProjectArgs,
    #[arg(long)]
    task: String,
    #[arg(long)]
    reason: String,
}

#[derive(Debug, Args)]
struct AdapterArgs {
    #[command(subcommand)]
    command: AdapterCommand,
}

#[derive(Debug, Subcommand)]
enum AdapterCommand {
    Context(AdapterContextArgs),
    Route(AdapterRouteArgs),
}

#[derive(Debug, Args)]
struct AdapterContextArgs {
    #[command(flatten)]
    project: ProjectArgs,
    #[arg(long)]
    host: String,
    #[arg(long)]
    event: String,
    #[arg(long)]
    prompt: Option<String>,
}

#[derive(Debug, Args)]
struct AdapterRouteArgs {
    #[command(flatten)]
    project: ProjectArgs,
    #[arg(long)]
    host: String,
    #[arg(long)]
    prompt: String,
}

#[derive(Debug, Copy, Clone, PartialEq, Eq, ValueEnum)]
enum OutputFormat {
    Text,
    Json,
    Host,
}

pub fn run() -> Result<()> {
    let cli = Cli::parse();
    match cli.command {
        Commands::Init(args) => init(&project_root(args.project)?)?,
        Commands::Status(args) => status(&project_root(args.project.project)?, args.format)?,
        Commands::Context(args) => {
            runtime_context(&project_root(args.project.project)?, args.format)?
        }
        Commands::NextAction(args) => {
            let context = context::build_context(&project_root(args.project)?);
            println!("{}", context.allowed_next_action);
        }
        Commands::Pause(args) => pause(&project_root(args.project.project)?, &args.reason)?,
        Commands::Resume(args) => resume(&project_root(args.project)?)?,
        Commands::Complete(args) => complete(&project_root(args.project)?)?,
        Commands::Transition(args) => {
            let root = project_root(args.project.project)?;
            let _lock = locks::ProjectLock::acquire(&root)?;
            let outcome = transitions::transition(&root, &args.to, &args.status)?;
            print_json(&outcome)?;
        }
        Commands::AssertWorkflowActive(args) => run_gate(
            &project_root(args.project)?,
            "workflow-active",
            gates::assert_workflow_active,
        )?,
        Commands::AssertConcreteTask(args) => run_gate(
            &project_root(args.project)?,
            "concrete-task",
            gates::assert_concrete_task,
        )?,
        Commands::AssertPlanReady(args) => run_gate(
            &project_root(args.project)?,
            "plan",
            gates::assert_plan_ready,
        )?,
        Commands::AssertReviewReady(args) => run_gate(
            &project_root(args.project)?,
            "review",
            gates::assert_review_ready,
        )?,
        Commands::AssertQaReady(args) => {
            run_gate(&project_root(args.project)?, "qa", gates::assert_qa_ready)?
        }
        Commands::AssertSummaryReady(args) => run_gate(
            &project_root(args.project)?,
            "summary",
            gates::assert_summary_ready,
        )?,
        Commands::Event(args) => handle_event(args.command)?,
        Commands::Tasks(args) => handle_tasks(args.command)?,
        Commands::Adapter(args) => handle_adapter(args.command)?,
    }
    Ok(())
}

fn project_root(path: PathBuf) -> Result<PathBuf> {
    Ok(path.canonicalize()?)
}

fn init(project_root: &std::path::Path) -> Result<()> {
    let _lock = locks::ProjectLock::acquire(project_root)?;
    let mut state = state::ensure_state(project_root)?;
    let timestamp = state::now()?;
    if state
        .get("public_stage_history")
        .and_then(Value::as_array)
        .is_some_and(Vec::is_empty)
    {
        state::append_public_stage_history(&mut state, "discover", "in_progress", &timestamp)?;
    }
    state::set_str(&mut state, "updated_at", &timestamp)?;
    state::save_state(project_root, &state)?;
    events::append_event(
        project_root,
        "workflow_started",
        json!({"project": project_root.display().to_string()}),
    )?;
    println!(
        "Initialized WannaBuild runtime at {}",
        state::state_path(project_root).display()
    );
    Ok(())
}

fn status(project_root: &std::path::Path, format: OutputFormat) -> Result<()> {
    let state = state::load_state(project_root)?.unwrap_or_else(|| json!({}));
    match format {
        OutputFormat::Json => print_json(&state)?,
        OutputFormat::Text | OutputFormat::Host => {
            println!(
                "workflow_status: {}",
                state["workflow_status"].as_str().unwrap_or("unknown")
            );
            println!(
                "public_stage: {}",
                state["public_stage"].as_str().unwrap_or("unknown")
            );
            println!(
                "current_phase: {}",
                state["current_phase"].as_str().unwrap_or("unknown")
            );
            println!(
                "phase_status: {}",
                state["phase_status"].as_str().unwrap_or("unknown")
            );
        }
    }
    Ok(())
}

fn runtime_context(project_root: &std::path::Path, format: OutputFormat) -> Result<()> {
    let runtime_context = context::build_context(project_root);
    if runtime_context.runtime_active {
        let _lock = locks::ProjectLock::acquire(project_root)?;
        events::append_event(
            project_root,
            "runtime_context_emitted",
            serde_json::to_value(&runtime_context)?,
        )?;
    }
    match format {
        OutputFormat::Json => print_json(&runtime_context)?,
        OutputFormat::Text | OutputFormat::Host => {
            println!("{}", context::render_text(&runtime_context))
        }
    }
    Ok(())
}

fn pause(project_root: &std::path::Path, reason: &str) -> Result<()> {
    let _lock = locks::ProjectLock::acquire(project_root)?;
    let mut state = state::ensure_state(project_root)?;
    let timestamp = state::now()?;
    state::set_str(&mut state, "workflow_status", "paused")?;
    state::set_str(&mut state, "phase_status", "paused")?;
    state::set_value(&mut state, "pause_reason", json!(reason))?;
    state::set_str(&mut state, "updated_at", &timestamp)?;
    state::save_state(project_root, &state)?;
    events::append_event(project_root, "phase_paused", json!({"reason": reason}))?;
    println!("Paused WannaBuild workflow: {reason}");
    Ok(())
}

fn resume(project_root: &std::path::Path) -> Result<()> {
    let _lock = locks::ProjectLock::acquire(project_root)?;
    let mut state = state::ensure_state(project_root)?;
    let timestamp = state::now()?;
    state::set_str(&mut state, "workflow_status", "in_progress")?;
    if state.get("phase_status").and_then(Value::as_str) == Some("paused") {
        state::set_str(&mut state, "phase_status", "in_progress")?;
    }
    state::set_value(&mut state, "pause_reason", Value::Null)?;
    state::set_str(&mut state, "updated_at", &timestamp)?;
    state::save_state(project_root, &state)?;
    events::append_event(project_root, "workflow_resumed", json!({}))?;
    println!("Resumed WannaBuild workflow");
    Ok(())
}

fn complete(project_root: &std::path::Path) -> Result<()> {
    let _lock = locks::ProjectLock::acquire(project_root)?;
    gates::assert_summary_ready(project_root)?;
    let mut state = state::ensure_state(project_root)?;
    let timestamp = state::now()?;
    state::set_str(&mut state, "workflow_status", "complete")?;
    state::set_str(&mut state, "phase_status", "complete")?;
    state::set_str(&mut state, "updated_at", &timestamp)?;
    state::append_public_stage_history(&mut state, "summary", "complete", &timestamp)?;
    state::save_state(project_root, &state)?;
    events::append_event(project_root, "workflow_completed", json!({}))?;
    println!("WannaBuild workflow complete");
    Ok(())
}

fn run_gate(
    project_root: &std::path::Path,
    gate: &'static str,
    check: fn(&std::path::Path) -> Result<gates::GatePass>,
) -> Result<()> {
    let _lock = locks::ProjectLock::acquire(project_root)?;
    match check(project_root) {
        Ok(pass) => {
            events::append_event(project_root, "gate_checked", json!({"gate": gate}))?;
            events::append_event(
                project_root,
                "gate_passed",
                json!({"gate": gate, "evidence": pass.evidence}),
            )?;
            println!("{}", pass.message());
            Ok(())
        }
        Err(error) => {
            events::append_event(project_root, "gate_checked", json!({"gate": gate}))?;
            events::append_event(
                project_root,
                "gate_failed",
                json!({"gate": gate, "reason": error.to_string()}),
            )?;
            Err(error)
        }
    }
}

fn handle_event(command: EventCommand) -> Result<()> {
    match command {
        EventCommand::Append(args) => {
            let root = project_root(args.project.project)?;
            let _lock = locks::ProjectLock::acquire(&root)?;
            let event_type = args.event_type;
            let mut payload = args
                .json
                .map(|raw| serde_json::from_str::<Value>(&raw))
                .transpose()?
                .unwrap_or_else(|| json!({}));
            if let Some(path) = args.path {
                let path = if is_checkpoint_event(&event_type) {
                    crate::checkpoints::validate_checkpoint_path(&root, &path)?
                } else {
                    path
                };
                let object = payload
                    .as_object_mut()
                    .ok_or_else(|| RuntimeError::message("event payload must be a JSON object"))?;
                object.insert("path".to_string(), json!(path.display().to_string()));
            }
            normalize_checkpoint_payload_paths(&root, &event_type, &mut payload)?;
            let event = events::append_event(&root, event_type, payload)?;
            print_json(&event)?;
        }
        EventCommand::List(args) => {
            let root = project_root(args.project.project)?;
            for event in events::list_events(&root, args.since.as_deref())? {
                println!("{}", serde_json::to_string(&events::redact_event(event))?);
            }
        }
        EventCommand::Replay(args) => {
            print_json(&events::replay(&project_root(args.project)?)?)?;
        }
    }
    Ok(())
}

fn handle_tasks(command: TasksCommand) -> Result<()> {
    match command {
        TasksCommand::Import(args) => {
            let root = project_root(args.project.project)?;
            let from = if args.from.is_absolute() {
                args.from
            } else {
                root.join(args.from)
            };
            let _lock = locks::ProjectLock::acquire(&root)?;
            let imported = tasks::import_tasks(&root, &from)?;
            println!("Imported {} tasks", imported.tasks.len());
        }
        TasksCommand::List(args) => {
            let loaded = tasks::load_tasks(&project_root(args.project)?)?;
            for task in loaded.tasks {
                println!("{} [{}] {}", task.id, task.status, task.title);
            }
        }
        TasksCommand::Next(args) => {
            let root = project_root(args.project)?;
            let _lock = locks::ProjectLock::acquire(&root)?;
            let next = crate::scheduler::next(&root)?;
            crate::scheduler::record_decision(&root, &next)?;
            println!("scheduler: {}", next.scheduler);
            println!("rationale: {}", next.rationale);
            println!("next_task: {} {}", next.task.id, next.task.title);
        }
        TasksCommand::Claim(args) => {
            let root = project_root(args.project.project)?;
            let _lock = locks::ProjectLock::acquire(&root)?;
            let task = tasks::claim_task(&root, &args.task, &args.owner)?;
            print_json(&task)?;
        }
        TasksCommand::Complete(args) => {
            let root = project_root(args.project.project)?;
            let _lock = locks::ProjectLock::acquire(&root)?;
            let checkpoint = args
                .checkpoint
                .as_ref()
                .map(|checkpoint| crate::checkpoints::validate_checkpoint_path(&root, checkpoint))
                .transpose()?;
            let task = tasks::complete_task(&root, &args.task, checkpoint)?;
            print_json(&task)?;
        }
        TasksCommand::Block(args) => {
            let root = project_root(args.project.project)?;
            let _lock = locks::ProjectLock::acquire(&root)?;
            let task = tasks::block_task(&root, &args.task, &args.reason)?;
            print_json(&task)?;
        }
    }
    Ok(())
}

fn handle_adapter(command: AdapterCommand) -> Result<()> {
    match command {
        AdapterCommand::Context(args) => {
            let root = project_root(args.project.project)?;
            let adapter_context =
                adapters::adapter_context(&root, &args.host, &args.event, args.prompt.as_deref())?;
            if adapter_context.runtime_context.runtime_active {
                let _lock = locks::ProjectLock::acquire(&root)?;
                events::append_event(
                    &root,
                    "runtime_context_emitted",
                    json!({
                        "host": adapter_context.host.clone(),
                        "event": adapter_context.event.clone(),
                        "route": adapter_context.route.route.clone(),
                    }),
                )?;
            }
            print_json(&adapter_context)?;
        }
        AdapterCommand::Route(args) => {
            let root = project_root(args.project.project)?;
            let route = adapters::route_prompt(&args.host, &args.prompt)?;
            if runtime_active(&root)? {
                let _lock = locks::ProjectLock::acquire(&root)?;
                events::append_event(
                    &root,
                    "runtime_context_emitted",
                    json!({"host": args.host, "route": route.route.clone()}),
                )?;
            }
            print_json(&route)?;
        }
    }
    Ok(())
}

fn runtime_active(project_root: &std::path::Path) -> Result<bool> {
    Ok(state::load_state(project_root)?
        .and_then(|value| {
            value
                .get("workflow_status")
                .and_then(Value::as_str)
                .map(|status| status != "complete")
        })
        .unwrap_or(false))
}

fn is_checkpoint_event(event_type: &str) -> bool {
    matches!(event_type, "checkpoint" | "checkpoint_written")
}

fn normalize_checkpoint_payload_paths(
    project_root: &std::path::Path,
    event_type: &str,
    payload: &mut Value,
) -> Result<()> {
    if !is_checkpoint_event(event_type) {
        return Ok(());
    }
    let Some(object) = payload.as_object_mut() else {
        return Ok(());
    };
    for key in ["path", "checkpoint_path"] {
        let Some(path) = object.get(key).and_then(Value::as_str) else {
            continue;
        };
        let path =
            crate::checkpoints::validate_checkpoint_path(project_root, &PathBuf::from(path))?;
        object.insert(key.to_string(), json!(path.display().to_string()));
    }
    Ok(())
}

fn print_json<T: Serialize>(value: &T) -> Result<()> {
    println!("{}", serde_json::to_string_pretty(value)?);
    Ok(())
}
