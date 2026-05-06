use std::fs;
use std::path::{Path, PathBuf};

use crate::errors::{Result, RuntimeError};

pub fn validate_checkpoint_path(project_root: &Path, checkpoint: &Path) -> Result<PathBuf> {
    let checkpoint_root = project_root.join(".wannabuild/checkpoints");
    fs::create_dir_all(&checkpoint_root)?;
    let checkpoint_root = checkpoint_root.canonicalize()?;
    let path = if checkpoint.is_absolute() {
        checkpoint.to_path_buf()
    } else {
        project_root.join(checkpoint)
    };
    if !path.is_file() {
        return Err(RuntimeError::message(format!(
            "Checkpoint not found: {}",
            path.display()
        )));
    }
    let path = path.canonicalize()?;
    if !path.starts_with(&checkpoint_root) {
        return Err(RuntimeError::message(format!(
            "Checkpoint path must be inside {}: {}",
            checkpoint_root.display(),
            path.display()
        )));
    }
    Ok(path)
}

#[cfg(test)]
mod tests {
    use std::fs;

    use tempfile::tempdir;

    use super::*;

    #[test]
    fn checkpoint_path_must_be_inside_project_checkpoints() {
        let dir = tempdir().unwrap();
        let inside = dir.path().join(".wannabuild/checkpoints/task-1-step-1.md");
        fs::create_dir_all(inside.parent().unwrap()).unwrap();
        fs::write(&inside, "checkpoint").unwrap();
        let outside = dir.path().join("checkpoint.md");
        fs::write(&outside, "outside").unwrap();

        let accepted = validate_checkpoint_path(dir.path(), &inside).unwrap();
        assert_eq!(accepted, inside.canonicalize().unwrap());

        let err = validate_checkpoint_path(dir.path(), &outside)
            .unwrap_err()
            .to_string();
        assert!(err.contains("Checkpoint path must be inside"));
    }
}
