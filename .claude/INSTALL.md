# WannaBuild for Claude Code

Install WannaBuild into Claude Code by linking the Claude-facing skills from this repository into your local Claude Code plugins directory.

## Fast Path

From the root of this repository, run:

```bash
./scripts/install-claude-skill.sh
```

Then reload plugins and use:

```text
/wannabuild
```

WannaBuild runs one standard workflow mode. There is no user-facing Full / Light / Spark choice.
For real work in a git repo, it should create an isolated workspace/worktree before discovery begins.

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

Then invoke:

```text
/wannabuild
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

Then start a new Claude Code session and invoke:

```text
/wannabuild
```

You should see the startup banner:

```
[WB-START] WannaBuild STARTED | intent=build | mode=standard
```

If the banner appears, WannaBuild is correctly installed and ready to use.

## Troubleshoot

If installation fails or WannaBuild doesn't start, run:

```bash
./scripts/wannabuild-doctor.sh
```

This validates your repo setup and plugin configuration, and provides detailed diagnostics.
