# Claude Code Co-Primary Parity — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make WannaBuild work fully in Claude Code via marketplace install, with Claude Code treated as a co-primary host alongside Codex.

**Architecture:** Fix two broken runtime gaps (Codex-syntax command, broken script paths), add a parallel Claude Code install path (marketplace + from-repo), and strip all "compatibility packaging" framing from docs and config files. Skills and agents stay shared; only the adapter layer changes.

**Tech Stack:** Bash, JSON, Markdown. No new dependencies.

---

## Index

The full plan is split into thematic sub-pages so each task is self-contained and independently reviewable:

| Task(s) | Page | Scope |
|---|---|---|
| 1 | [`task-1-command.md`](2026-04-06-claude-code-parity/task-1-command.md) | Rewrite `commands/wannabuild.md` to drop Codex `$skill` syntax. |
| 2 | [`task-2-skill-paths.md`](2026-04-06-claude-code-parity/task-2-skill-paths.md) | Replace broken `../../scripts/` references in `skills/wannabuild/SKILL.md` with inline equivalents. |
| 3 | [`task-3-install-script.md`](2026-04-06-claude-code-parity/task-3-install-script.md) | Add `scripts/install-claude-skill.sh` for repo-based local install. |
| 4 + 5 | [`tasks-4-5-install-docs.md`](2026-04-06-claude-code-parity/tasks-4-5-install-docs.md) | Create `.claude/INSTALL.md`; rewrite `adapters/claude-code/README.md`. |
| 6 + 7 | [`tasks-6-7-host-docs.md`](2026-04-06-claude-code-parity/tasks-6-7-host-docs.md) | Add `docs/claude-code-getting-started.md`; update `docs/host-capability-matrix.md`. |
| 8 + 9 | [`tasks-8-9-positioning.md`](2026-04-06-claude-code-parity/tasks-8-9-positioning.md) | Update `README.md`, `CLAUDE.md`, `AGENTS.md`, `skills/internal/build/SKILL.md` positioning. |
| 10 | [`task-10-verification.md`](2026-04-06-claude-code-parity/task-10-verification.md) | End-to-end verification. |

## Execution Notes

- Tasks 1, 2, 3 are independent and can be implemented in any order; 4–9 build on them.
- Each sub-page includes its own commit-message suggestion.
- Re-run `scripts/wannabuild-doctor.sh` between phases to catch regressions early.
- The companion design note lives in [`2026-04-06-claude-code-parity-design.md`](2026-04-06-claude-code-parity-design.md).
