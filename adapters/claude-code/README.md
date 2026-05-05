# Claude Code Adapter

WannaBuild for Claude Code. Supports marketplace install and repo-based local install.

## Install

### Marketplace (recommended)

```text
/plugin marketplace add gl11tchy/wannabuild
/plugin install wannabuild@gl11tchy
```

Restart Claude Code, then:

```text
/wannabuild
```

### From Repo

```bash
./scripts/install-claude-skill.sh
```

Run `/reload-plugins`, then:

```text
/wannabuild
```

## Usage

Start with a natural description:

```text
I wanna build a Stripe billing flow for my SaaS
```

WannaBuild responds with the start banner and enters a vision-first Discover interview. The Claude Code plugin declares `SessionStart` and `UserPromptSubmit` hooks so natural feature, planning, debug, review, QA, and ship prompts can route automatically without asking the user to type a slash command.

Advisor escalation and delegation are repo-native and model-agnostic in core. Claude Code should map WannaBuild capability tiers and reasoning effort to available host controls; Claude Platform API adapters may map the same contract to the native `advisor_20260301` tool when appropriate.

For a full getting-started walkthrough, see [.claude/INSTALL.md](../../.claude/INSTALL.md).

## What's Installed

| Surface | Path |
|---|---|
| Slash command | `commands/wannabuild.md` → `/wannabuild` |
| Autoroute hooks | `hooks/hooks.json` + `hooks/wannabuild-route.py` |
| Orchestrator skill | `skills/wannabuild/` |
| Phase skills | `skills/build/`, `skills/requirements/`, etc. |
| Specialist agents | `agents/wb-*.md` |
| Utility scripts | `scripts/` (optional, for repo installs) |

## Verification

```bash
./scripts/wannabuild-doctor.sh
./scripts/validate-wannabuild-dry-runs.sh
```
