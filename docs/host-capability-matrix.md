# Host Capability Matrix

WannaBuild is repo-native first.

Priority order:
- Codex
- Cursor
- Claude Code

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

Compatibility adapter.

Provides:
- `.claude-plugin/`
- plugin install docs
- Claude-oriented skill entry points

## Capability Table

| Capability | Core | Codex | Cursor | Claude |
|---|---|---|---|---|
| Workflow contract | Yes | Primary | Reference | Reference |
| `.wannabuild/` artifacts | Yes | Yes | Yes | Yes |
| Validator script | Yes | Yes | Yes | Yes |
| `AGENTS.md`-driven usage | No | Yes | Optional | Optional |
| Rules files | No | Optional | Yes | Optional |
| Custom modes | No | Optional | Yes | No |
| Slash commands | No | No | No | Yes |
| Plugin install path | No | No | No | Yes |
| Repo-only usage | Yes | Yes | Yes | Partial |

## Rule

If it does not work from a raw repo checkout in Codex, it does not define the core architecture.
