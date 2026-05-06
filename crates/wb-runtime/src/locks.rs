use std::fs::{self, File, OpenOptions};
use std::path::Path;

use fs2::FileExt;

use crate::errors::Result;

pub struct ProjectLock {
    file: File,
}

impl ProjectLock {
    pub fn acquire(project_root: &Path) -> Result<Self> {
        let wb_dir = project_root.join(".wannabuild");
        fs::create_dir_all(&wb_dir)?;
        let file = OpenOptions::new()
            .create(true)
            .read(true)
            .write(true)
            .open(wb_dir.join("runtime.lock"))?;
        file.lock_exclusive()?;
        Ok(Self { file })
    }
}

impl Drop for ProjectLock {
    fn drop(&mut self) {
        let _ = self.file.unlock();
    }
}
