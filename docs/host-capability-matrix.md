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
- phase prompts and specialist prompt contracts
- advisor escalation state contract and report validation
- repo-native scripts and examples

## Canonical Entry Point

The canonical path is:
- root [AGENTS.md](../AGENTS.md)
- `scripts/`
- shared contracts and prompt files in the repo

If it only exists in adapter packaging, it is not core.

## Adapters

### Codex

Co-primary adapter.

Provides:
- `AGENTS.md` guidance
- script-first workflows
- local and web/cloud repo usage docs
- model-agnostic advisor escalation via read-only advisor equivalent when available

### Cursor

Secondary adapter.

Provides:
- `.cursor/rules`
- optional custom modes
- repo-native usage docs
- prompt/report fallback for advisor escalation

### Claude Code

Co-primary adapter.

Provides:
- Marketplace install: `/plugin install wannabuild@gl11tchy`
- Repo install: `scripts/install-claude-skill.sh`
- Slash command: `/wannabuild`
- Getting-started: `.claude/INSTALL.md`
- Full adapter guide: `adapters/claude-code/README.md`
- read-only advisor subagent fallback; Claude API adapters may map to native `advisor_20260301`

## Capability Table

| Capability | Core | Codex | Cursor | Claude Code |
|---|---|---|---|---|
| Workflow contract | Yes | Co-primary | Reference | Co-primary |
| `.wannabuild/` artifacts | Yes | Yes | Yes | Yes |
| Validator script | Yes | Yes | Yes | Yes |
| `AGENTS.md`-driven usage | No | Yes | Optional | Optional |
| Rules files | No | Optional | Yes | Optional |
| Slash commands / invocation | No | `$wannabuild` | No | `/wannabuild` |
| Plugin install path | No | Script symlink | No | Marketplace or script |
| Repo-only usage | Yes | Yes | Yes | Yes |
| Getting-started doc | No | Yes | No | Yes |
| Advisor escalation | State/report contract | Read-only advisor equivalent | Prompt/report fallback | Read-only subagent or native Claude API advisor |

## Rule

If it does not work from a raw repo checkout in either Codex or Claude Code, it does not define the core architecture.
