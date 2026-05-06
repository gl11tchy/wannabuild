# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Beginning with the next release, this file is maintained automatically by
[release-please](https://github.com/googleapis/release-please) — do not edit
the auto-generated sections by hand.

## [Unreleased]

## [2.2.5] - 2026-05-06

### Fixes

- unwrap `hooks/hooks.json` so Claude Code's plugin loader can iterate hook groups without crashing `/reload-plugins` with `TypeError: X?.reduce is not a function`

### Refactor

- consolidate python3 invocations and fix TOCTOU in install script (e0ba27b)

### Features

- add dry-run fixtures and checks for gates, advisor, and QA loop (467e600)

### Fixes

- register gl11tchy as own marketplace namespace in install script (ebddcec)
- use claude-plugins-official namespace in install script (d74b330)

### Chores

- compress SKILL.md and fix contract gaps from session audit (5b88428)

## [2.2.3] - 2025-04-15

### Cleanup

- v2.2.4 cleanup: reconcile schemas, remove spark agents, add config+workspace
  validation (340e75b)

### Docs

- add advisor escalation workflow (89c3db3)
- align host positioning and contract consistency (3ca88ec)
- use single agent wording and prevent duplicate gate prompts (d3f6cce)
- add operator mental model and align workflow copy (b10c6c6)
- tighten AGENTS operator contract (adad0df)

### Chores

- standardize mode contracts and refresh dry-run fixtures (99ee4aa)
- ignore local worktrees directory (94d1296)
- bump claude plugin version and expand doctor coverage (6b74ab5)

### Fixes

- align claude workflow state contract and bootstrap flow (2358498)
- update using-wannabuild command for Claude Code parity (37d42b7)

## [2.2.2] - 2025-04-15

### Docs

- update positioning — Claude Code is co-primary, not compatibility packaging
  (ff9471e)
- elevate Claude Code install to co-primary in README (08599c4)
- elevate Claude Code to co-primary in host capability matrix (394229b)
- add claude-code-getting-started.md (85103c0)
- rewrite Claude Code adapter README as a proper install guide (d258386)
- add .claude/INSTALL.md for Claude Code getting-started (656ad58)

### Features

- add install-claude-skill.sh for local Claude Code plugin install (ca29312)

## [2.2.1] - 2025-04-15

### Fixes

- clarify timestamp format, variable substitution, verdict rules, and failure
  cleanup in wannabuild skill (9cf193c)
- replace script path references with inline equivalents in wannabuild skill
  (2db49fd)
- clarify workspace bootstrap ordering in wannabuild command (1375f24)
- rewrite wannabuild command for Claude Code — drop Codex $skill syntax
  (ddcf279)

### Docs

- add Claude Code co-primary parity implementation plan (e06d4b0)
- add Claude Code co-primary parity design (767c639)

## [Initial]

- Make WannaBuild usable now as a Codex-first workflow plugin (7e27a95)

[Unreleased]: https://github.com/gl11tchy/wannabuild/compare/v2.2.3...HEAD
[2.2.3]: https://github.com/gl11tchy/wannabuild/compare/v2.2.2...v2.2.3
[2.2.2]: https://github.com/gl11tchy/wannabuild/compare/v2.2.1...v2.2.2
[2.2.1]: https://github.com/gl11tchy/wannabuild/releases/tag/v2.2.1
