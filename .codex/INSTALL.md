# WannaBuild for Codex

Install WannaBuild into Codex by linking the Codex-facing skills from this repository into your local Codex skills directory.

## Fast Path

From the root of this repository, run:

```bash
./scripts/install-codex-skill.sh
```

Then restart Codex and use:

```text
$wannabuild
```

WannaBuild runs one standard workflow mode. There is no user-facing Full / Light / Spark choice.
For real work in a git repo, it should create an isolated workspace/worktree before discovery begins.

Optional intro skill:

```text
$using-wannabuild
```

## Manual Install

Create links in `~/.codex/skills/`:

```bash
mkdir -p ~/.codex/skills
ln -sfn "$PWD/skills/wannabuild" ~/.codex/skills/wannabuild
ln -sfn "$PWD/skills/using-wannabuild" ~/.codex/skills/using-wannabuild
```

## Verify

Run:

```bash
./scripts/wannabuild-doctor.sh
```

Then start a new Codex session and invoke:

```text
$wannabuild
```
