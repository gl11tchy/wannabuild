# Host Capability Matrix

WannaBuild is repo-native first.

Priority order:
- Codex
- Claude Code
- Cursor

## Shared Core

Host-agnostic:

- condensed workflow contract
- `.wannabuild/` artifact contract
- schemas, validation, checkpoints, and review routing
- phase prompts and specialist prompt contracts
- repo-native scripts and examples

## Canonical Entry Point

The canonical path is:
- root [AGENTS.md](../AGENTS.md)
- `scripts/`
- shared contracts and prompt files in the repo

If it only exists in adapter packaging, it is not core.

## Adapters

### Codex

Primary adapter.

Provides:
- `AGENTS.md` guidance
- script-first workflows
- local and web/cloud repo usage docs

### Cursor

Secondary adapter.

Provides:
- `.cursor/rules`
- optional custom modes
- repo-native usage docs

### Claude Code

Primary adapter.

Provides:
- Marketplace install: `/plugin install wannabuild@gl11tchy`
- Repo install: `scripts/install-claude-skill.sh`
- Slash command: `/wannabuild`
- Getting-started: `.claude/INSTALL.md`
- Full adapter guide: `adapters/claude-code/README.md`

## Capability Table

| Capability | Core | Codex | Cursor | Claude Code |
|---|---|---|---|---|
| Workflow contract | Yes | Primary | Reference | Primary |
| `.wannabuild/` artifacts | Yes | Yes | Yes | Yes |
| Validator script | Yes | Yes | Yes | Yes |
| `AGENTS.md`-driven usage | No | Yes | Optional | Optional |
| Rules files | No | Optional | Yes | Optional |
| Slash commands / invocation | No | `$wannabuild` | No | `/wannabuild` |
| Plugin install path | No | Script symlink | No | Marketplace or script |
| Repo-only usage | Yes | Yes | Yes | Yes |
| Getting-started doc | No | Yes | No | Yes |

## Rule

If it does not work from a raw repo checkout in either Codex or Claude Code, it does not define the core architecture.
