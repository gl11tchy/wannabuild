# WannaBuild for Codex

Install WannaBuild into Codex by linking the Codex-facing skills from this repository into your local Codex skills directory.

## Fast Path

From the root of this repository, run:

```bash
./scripts/install-codex-skill.sh
```

Then restart Codex and use:

```text
I want to build a Stripe billing flow for my SaaS
```

Natural prompts should route automatically. Use `$wannabuild` only when you want an explicit shortcut for the full loop: Discover -> Plan -> Implement -> Validate -> QA -> Summary.

The installed `wb-*` skills are phase entrypoints into the full loop by default. For one-stage work, make the limit explicit, such as "run discovery only", "plan only; do not implement", or "QA only".
Codex does not use Claude Code hooks; this installer builds and copies the host-neutral Rust `wb-runtime` into `~/.codex/bin` by default. Before implementation, use `scripts/wannabuild-session.sh assert-plan-ready <project_root>`; it fails closed if `wb-runtime` cannot execute. Add `~/.codex/bin` to `PATH` if Codex cannot find `wb-runtime`.
Installed skill UI metadata uses friendly display names such as `WannaBuild: Build`, `WannaBuild: Review`, and `WannaBuild: Ship`; `$wb-*` remains the stable invocation shortcut.

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
mkdir -p ~/.codex/bin
ln -sfn "$PWD/skills/wannabuild" ~/.codex/skills/wannabuild
ln -sfn "$PWD/skills/using-wannabuild" ~/.codex/skills/using-wannabuild
for skill in wb-build wb-debug wb-discover wb-plan wb-qa wb-review wb-ship; do
  ln -sfn "$PWD/skills/$skill" ~/.codex/skills/$skill
done
cargo build --quiet --manifest-path "$PWD/Cargo.toml" --bin wb-runtime
cp "$PWD/target/debug/wb-runtime" ~/.codex/bin/wb-runtime
chmod +x ~/.codex/bin/wb-runtime
```

## Verify

Run:

```bash
./scripts/wannabuild-doctor.sh
```

Then start a new Codex session and type a natural feature request:

```text
I want to build a small onboarding flow
```
