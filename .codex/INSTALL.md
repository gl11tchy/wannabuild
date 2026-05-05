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

Use `$wannabuild` for the full loop: Discover -> Control mode -> optional Research -> Plan -> Implement -> Review -> QA -> Summary.

For toolbox work, ask for one phase directly, such as "run discovery only", "plan this", "debug this failure", "review this change", "QA this", or "prepare the final handoff".

WannaBuild runs one standard workflow mode. There is no user-facing Full / Light / Spark choice.
For real work in a git repo, discovery and planning run in the current checkout. Isolated worktrees are only for implementation-time isolation when selected.

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
for skill in wb-build wb-debug wb-discover wb-plan wb-qa wb-review wb-ship; do
  ln -sfn "$PWD/skills/$skill" ~/.codex/skills/$skill
done
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
