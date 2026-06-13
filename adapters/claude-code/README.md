# Claude Code Adapter

WannaBuild for Claude Code. Supports the npx installer, marketplace install, and repo-based local install.

## Install

### npx (recommended)

```bash
npx wannabuild --claude
```

This downloads a prebuilt, checksum-verified `wb-runtime` for your platform,
places it at `~/.wannabuild/target/debug/wb-runtime` (where the plugin cache
symlink resolves it), and runs the repo install script so Claude Code runs the
real Rust gates. Run `/reload-plugins`, then start with natural language:

```text
I wanna build a Stripe billing flow for my SaaS
```

### Marketplace

Installs the skills and commands only — no prebuilt runtime.

```text
/plugin marketplace add gl11tchy/wannabuild
/plugin install wannabuild@gl11tchy
```

Restart Claude Code, then start with natural language:

```text
I wanna build a Stripe billing flow for my SaaS
```

### From source (contributors)

```bash
./scripts/install-claude-skill.sh
```

Run `/reload-plugins`, then start with natural language:

```text
I wanna build a Stripe billing flow for my SaaS
```

This path expects a built `wb-runtime` at `target/debug/wb-runtime` (npx
provides the prebuilt binary; from a dev clone, `cargo build` produces it). The
installer warns if it is missing.

## Usage

Start with a natural description:

```text
I wanna build a Stripe billing flow for my SaaS
```

WannaBuild enters a vision-first Discover interview. The Claude Code plugin declares `SessionStart` and `UserPromptSubmit` hooks so natural feature, planning, debug, review, QA, ship, and open-ended ideation prompts can route automatically without asking the user to type a slash command. The same hook reinjects active `.wannabuild/state.json` runtime state across turns and forbids implementation until the Plan gate is satisfied. `/wb-*` shortcuts are phase entrypoints into the full loop by default.

Advisor escalation and delegation are repo-native and model-agnostic in core. Claude Code should map WannaBuild capability tiers and reasoning effort to available host controls; Claude Platform API adapters may map the same contract to the native `advisor_20260301` tool when appropriate.

## Model Tier Mapping

Core contracts describe capability tiers only; this adapter maps them to current Claude models via the `model:` key in each specialist agent's frontmatter (`agents/wb-*.md`):

| Core capability tier | Claude model | Frontmatter value | Agents |
|---|---|---|---|
| Strong / high-reasoning | Fable 5 | `model: claude-fable-5` | architect, tech-advisor, risk-assessor, plan-options, implementer-escalated, integration-tester, security-reviewer, architecture-reviewer |
| Standard | Opus 4.8 | `model: opus` | implementer, performance/testing reviewers, code-simplifier, discovery analysts, task-decomposer, dependency-mapper, pr-craftsman, ci-guardian |
| Lightweight / fast | Haiku 4.5 | `model: haiku` | readme-updater, api-doc-generator, changelog-writer, scope-validator |

The orchestrator and skills inherit the session model (run Claude Code on Fable 5 for the strongest orchestration). This mapping is adapter packaging: other hosts ignore the `model:` key, and the core contracts remain model-agnostic.

For a full getting-started walkthrough, see [.claude/INSTALL.md](../../.claude/INSTALL.md).

## What's Installed

| Surface | Path |
|---|---|
| Slash command | `commands/wannabuild.md` → `/wannabuild` |
| Autoroute hooks | `hooks/hooks.json` + `hooks/wannabuild-route.py` |
| Orchestrator skill | `skills/wannabuild/` |
| Phase skills | `skills/internal/build/`, `skills/internal/requirements/`, etc. |
| Specialist agents | `agents/wb-*.md` |
| Utility scripts | `scripts/` (optional, for repo installs) |

## Verification

```bash
./scripts/wannabuild-doctor.sh
./scripts/validate-wannabuild-dry-runs.sh
```
