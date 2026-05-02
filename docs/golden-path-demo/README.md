# Golden Path Demo

This directory is a small, committed WannaBuild project state that proves the daily-use trust contract without requiring Claude Code or Codex to be running.

Run it from the repository root:

```bash
scripts/validate-wannabuild-artifacts.sh docs/golden-path-demo document
scripts/wannabuild-gate-check.sh docs/golden-path-demo summary
scripts/validate-wannabuild-dry-runs.sh
```

The committed `.wannabuild/` tree represents a completed workflow:

1. Discover and control mode were recorded.
2. Requirements, design, and tasks were written.
3. Implementation left checkpoint evidence.
4. Review produced passing reviewer verdicts.
5. QA produced a summary.
6. Summary is allowed because Review and QA both passed.
