# Claude Code Adapter

WannaBuild for Claude Code. Supports marketplace install and repo-based local install.

## Install

### Marketplace (recommended)

```
/plugin marketplace add gl11tchy/wannabuild
/plugin install wannabuild@gl11tchy
```

Restart Claude Code, then:

```
/wannabuild
```

### From Repo

```bash
./scripts/install-claude-skill.sh
```

Run `/reload-plugins`, then:

```
/wannabuild
```

## Usage

Start with a natural description:

```
I wanna build a Stripe billing flow for my SaaS
```

WannaBuild responds with the start banner and enters Discover.

Advisor escalation is repo-native and model-agnostic in core. Claude Code should use a read-only advisor subagent when available; Claude Platform API adapters may map the same contract to the native `advisor_20260301` tool.

For a full getting-started walkthrough, see [.claude/INSTALL.md](../../.claude/INSTALL.md).

## What's Installed

| Surface | Path |
|---|---|
| Slash command | `commands/wannabuild.md` → `/wannabuild` |
| Orchestrator skill | `skills/wannabuild/` |
| Phase skills | `skills/build/`, `skills/requirements/`, etc. |
| Specialist agents | `agents/wb-*.md` |
| Utility scripts | `scripts/` (optional, for repo installs) |

## Verification

```bash
./scripts/wannabuild-doctor.sh
```
