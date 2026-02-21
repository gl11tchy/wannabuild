# WannaBuild — Project State

## Overview
WannaBuild is a **Spec-Driven Development framework** packaged as a Claude Code plugin for indie builders. It orchestrates a 7-phase AI workflow through 20 specialist markdown-defined agents and 8 phase-specific skills (build + requirements + design + tasks + implement + review + ship + document).

## Architecture
- **Stack:** Documentation-first framework repository (Markdown + JSON), orchestrated by Claude Code skill system.
- **Frontend:** N/A (no user-facing web app in this repo)
- **Backend/API:** N/A (no server/service code in this repo)
- **Database:** N/A
- **Auth:** N/A
- **Hosting/Distribution:** GitHub repo + Claude plugin marketplace metadata (`.claude-plugin/`)
- **Repo:** `https://github.com/gl11tchy/wannabuild`
- **Package Manager:** N/A (no `package.json` / dependency graph)

## Data Model
No runtime database model in this repo. Runtime state is generated in target projects under:
- `.wannabuild/state.json`
- `.wannabuild/spec/requirements.md`
- `.wannabuild/spec/design.md`
- `.wannabuild/spec/tasks.md`
- `.wannabuild/loop-state.json`
- `.wannabuild/decisions.md`
- review output files under `.wannabuild/review/` and implementation outputs under `.wannabuild/outputs/`

## Key Files
- `README.md` — Public project overview, usage philosophy, and slash command references.
- `.claude-plugin/plugin.json` — Plugin manifest (name/version/metadata for Claude plugin system).
- `.claude-plugin/marketplace.json` — Marketplace metadata and plugin registration info.
- `CLAUDE.md` — Agent-facing guidance and project conventions.
- `AGENTS.md` — High-level framework rules, phase flow, and structure.
- `skills/build/SKILL.md` — Core orchestrator skill (7-phase control loop + quality loop mechanics).
- `skills/requirements/SKILL.md` — Requirements phase behavior and outputs.
- `skills/design/SKILL.md` — Design phase orchestration and outputs.
- `skills/tasks/SKILL.md` — Task decomposition phase behavior.
- `skills/implement/SKILL.md` — Implement phase behavior.
- `skills/review/SKILL.md` — 6-specialist review loop / hard-gate logic.
- `skills/ship/SKILL.md` — PR + CI phase orchestration.
- `skills/document/SKILL.md` — Documentation phase orchestration.
- `agents/wb-*.md` (20 files) — Specialist agent prompts and behavior.
- `docs/philosophy.md` — Core framework philosophy and quality principles.
- `CONTRIBUTING.md` — Contribution norms.
- `LICENSE` — MIT license.

## Routes / Pages / Commands
No web routes in this repository. Primary usage is via conversational phrases / slash commands:
- `/wannabuild:build`
- `/wannabuild:requirements`
- `/wannabuild:design`
- `/wannabuild:tasks`
- `/wannabuild:implement`
- `/wannabuild:review`
- `/wannabuild:ship`
- `/wannabuild:document`

## Scripts
No build/runtime scripts defined in repo metadata.
- `npm test` → fails because repository has no `package.json`.
- `npm run build` → fails because repository has no `package.json`.

## Environment
No application env vars in repo (documentation-only). `.env*` values are intentionally absent.

## Tests
- **Framework:** none (no test harness included)
- **Count:** not applicable
- **Last run attempt:** `npm test` and `npm run build` were executed; both fail due to missing `package.json`.

## Deploy
- Local/CI deploy is not applicable as this is a plugin/documentation repo.
- Distribution is via GitHub repo + Claude plugin system/marketplace metadata.
- Install path in docs: `plugin add gl11tchy/wannabuild` / `plugin install wannabuild@gl11tchy`.

## Known Issues / TODOs
- No TODO/FIXME/HACK markers found during scan.
- No `.github` workflows or CI config checked in this project.
- No test/build pipeline is defined in-repo.

## Last Scanned
2026-02-21
