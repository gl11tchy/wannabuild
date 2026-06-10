# Host Capability Matrix

WannaBuild is repo-native first.

Host priority:

- Co-primary: Codex, Claude Code
- Secondary: Cursor

## Shared Core

Host-agnostic:

- condensed workflow contract
- `.wannabuild/` artifact contract
- schemas, validation, checkpoints, and review routing
- daily-use trust harness and golden path demo
- phase prompts and specialist prompt contracts
- full-loop and phase entrypoint invocation contracts
- advisor escalation state contract and report validation
- adaptive capability-tier and reasoning-effort policy
- repo-native scripts and examples

## Canonical Entry Point

The canonical path is:

- root [AGENTS.md](../AGENTS.md)
- `scripts/`
- `commands/`
- shared contracts and prompt files in the repo

If it only exists in adapter packaging, it is not core.

## Adapters

### Codex

Co-primary adapter.

Provides:

- `AGENTS.md` guidance
- script-first workflows
- Rust `wb-runtime` install through `scripts/install-codex-skill.sh`
- local and web/cloud repo usage docs
- full loop via `$wannabuild`; phase entry via phase-specific prompts
- model-agnostic advisor escalation via read-only advisor equivalent when available
- host mapping from core capability tiers to available models/reasoning controls

### Cursor

Secondary adapter.

Provides:

- `.cursor/rules`
- optional custom modes
- repo-native usage docs
- prompt/report fallback for advisor escalation
- prompt/report fallback for capability-tier decisions when explicit model controls are unavailable

### Claude Code

Co-primary adapter.

Provides:

- Marketplace install: `/plugin install wannabuild@gl11tchy`
- Repo install: `scripts/install-claude-skill.sh`
- Natural-language autorouting for the full loop and phase skill entrypoints
- Command shortcuts: `/wannabuild`, `/wb-discover`, `/wb-plan`, `/wb-build`, `/wb-debug`, `/wb-review`, `/wb-qa`, `/wb-ship`
- Autorouting hooks: `SessionStart` and `UserPromptSubmit` inject routing context so natural feature, ideation, planning, debug, review, QA, and ship prompts can select the matching skill without a command
- Getting-started: `.claude/INSTALL.md`
- Full adapter guide: `adapters/claude-code/README.md`
- read-only advisor subagent fallback; Claude API adapters may map to native `advisor_20260301`
- host mapping from core capability tiers to current Claude models via agent frontmatter: strong → Fable 5 (`fable`), standard → Opus 4.8 (`opus`), lightweight → Haiku 4.5 (`haiku`); see `adapters/claude-code/README.md`

## Capability Table

| Capability | Core | Codex | Cursor | Claude Code |
|---|---|---|---|---|
| Workflow contract | Yes | Co-primary | Reference | Co-primary |
| `.wannabuild/` artifacts | Yes | Yes | Yes | Yes |
| Validator script | Yes | Yes | Yes | Yes |
| Rust workflow runtime | Yes | Installed by script | Repo/manual | Installed by repo script |
| Daily-use dry runs | Yes | Yes | Reference | Yes |
| Golden path demo | Yes | Yes | Yes | Yes |
| `AGENTS.md`-driven usage | No | Yes | Optional | Optional |
| Rules files | No | Optional | Yes | Optional |
| Full-loop invocation | Yes | Natural prompt, `$wannabuild` shortcut | Prompt/rules | Natural prompt, `/wannabuild` shortcut |
| Phase entrypoint usage | Phase contract | Phase prompts | Prompt/rules | Natural prompt, `/wb-*` shortcuts |
| Natural-language autorouting | Yes | Skill descriptions | Rules-driven | `SessionStart` + `UserPromptSubmit` hooks |
| Plugin install path | No | Script skill links + runtime copy | No | Marketplace or script |
| Repo-only usage | Yes | Yes | Yes | Yes |
| Getting-started doc | No | Yes | No | Yes |
| Advisor escalation | State/report contract | Read-only advisor equivalent | Prompt/report fallback | Read-only subagent or native Claude API advisor |
| Capability tier mapping | Tier/effort contract | Host mapped | Prompt/report fallback | Agent frontmatter: `fable`/`opus`/`haiku` |

## Rule

If it does not work from a raw repo checkout in either Codex or Claude Code, it does not define the core architecture.
