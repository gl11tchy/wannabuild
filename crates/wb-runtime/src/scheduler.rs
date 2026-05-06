use std::fs::OpenOptions;
use std::io::Write;
use std::path::Path;

use crate::errors::Result;
use crate::state;
use crate::tasks::{self, NextTask};

pub fn next(project_root: &Path) -> Result<NextTask> {
    tasks::next_task(project_root)
}

pub fn record_decision(project_root: &Path, next: &NextTask) -> Result<()> {
    state::ensure_runtime_layout(project_root)?;
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(state::decisions_path(project_root))?;
    writeln!(file, "## Scheduler Decision - {}", state::now()?)?;
    writeln!(file)?;
    writeln!(file, "- command: `wb-runtime tasks next`")?;
    writeln!(file, "- scheduler: {}", next.scheduler)?;
    writeln!(file, "- rationale: {}", next.rationale)?;
    writeln!(file, "- next_task: {} {}", next.task.id, next.task.title)?;
    writeln!(file)?;
    Ok(())
}
