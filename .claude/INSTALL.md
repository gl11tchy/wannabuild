# WannaBuild for Claude Code

Install WannaBuild into Claude Code by linking the Claude-facing skills and commands from this repository into your local Claude Code plugins directory.

## Fast Path

From the root of this repository, run:

```bash
./scripts/install-claude-skill.sh
```

Then reload plugins and use:

```text
I want to build a Stripe billing flow for my SaaS
```

Natural prompts should route automatically. Use `/wannabuild` only when you want an explicit shortcut for the full loop: Discover -> Plan -> Implement -> Validate -> QA -> Summary.

Use natural toolbox prompts when you only want one stage, for example "plan this", "debug this failure", "review this change", or "QA this against the requirements". Command shortcuts remain available:

```text
/wb-discover
/wb-plan
/wb-build
/wb-debug
/wb-review
/wb-qa
/wb-ship
```

WannaBuild runs one standard workflow mode. There is no user-facing Full / Light / Spark choice.
For real work in a git repo, discovery and planning run in the current checkout. Isolated worktrees are only for implementation-time isolation when selected.

Optional intro skill:

```text
/using-wannabuild
```

## Marketplace Install

To install from the Claude Code marketplace:

```bash
/plugin marketplace add gl11tchy/wannabuild
/plugin install wannabuild@gl11tchy
/reload-plugins
```

Then start with natural language:

```text
I want to build a small onboarding flow
```

## Manual Install

Create a link in `~/.claude/plugins/cache/gl11tchy/wannabuild/`:

```bash
mkdir -p ~/.claude/plugins/cache/gl11tchy/wannabuild
ln -sfn "$PWD" ~/.claude/plugins/cache/gl11tchy/wannabuild/local
```

Then register and enable in Claude Code by running the install script or manually updating:

- `~/.claude/plugins/installed_plugins.json` to add the plugin entry
- `~/.claude/settings.json` to enable `wannabuild@gl11tchy`

Finally, reload plugins:

```text
/reload-plugins
```

## Verify

Run:

```bash
./scripts/wannabuild-doctor.sh
```

Then start a new Claude Code session and type a natural feature request:

```text
I want to build a small onboarding flow
```

The session-start and prompt-submit hooks should route the prompt to WannaBuild. You should see the startup banner:

```text
[WB-START] WannaBuild STARTED | intent=build | mode=standard
```

If the banner appears, WannaBuild is correctly installed and ready to use.

## Troubleshoot

If installation fails or WannaBuild doesn't start, run:

```bash
./scripts/wannabuild-doctor.sh
```

This validates your repo setup and plugin configuration, and provides detailed diagnostics.
