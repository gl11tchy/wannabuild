# Factory Adapter

WannaBuild for Factory Droid. Ships the self-contained plugin surface plus the
generated `wb-*` specialist droids.

Advisor escalation and delegation are model-agnostic in core. In Droid, map
WannaBuild capability tiers and reasoning effort to the available model controls;
otherwise rely on the `.wannabuild/outputs/` reports, `.wannabuild/decisions.md`,
and `state.json` contracts.

## Install

### npx (recommended)

```bash
npx wannabuild --factory
```

This links the self-contained `adapters/factory` plugin into Factory's plugin
cache, writes the generated `wb-*` droids to `~/.factory/droids/`, and places a
prebuilt, checksum-verified `wb-runtime` inside the plugin cache so Droid runs
the real Rust gates — no Rust or cargo required. The Factory hook is copied (not
symlinked) into the cache, so its binary lives at
`<plugin cache>/local/target/debug/wb-runtime`. Restart Droid, then start with
natural language:

```text
I want to build a Stripe billing flow for my SaaS
```

### From source (contributors)

```bash
./scripts/install-factory-plugin.sh
```

The installer registers the local marketplace/plugin, links the plugin into
Factory's plugin cache, and writes the generated `wb-*` droids. With a prebuilt
binary it copies that into the cache; from a dev clone, build `wb-runtime` with
`cargo build` first so the gate binary is present.

If you only need the packaged plugin commands and skills, you can install
through Droid's plugin manager instead:

```bash
droid plugin marketplace add https://github.com/gl11tchy/wannabuild
droid plugin install wannabuild@wannabuild
```

Use npx or the repo installer for the complete generated `wb-*` Droid specialist
set plus the prebuilt runtime.

## Usage

Droid should select the WannaBuild skill automatically when natural-language
prompts match build, planning, debug, review, QA, ship, or open-ended ideation
intent. Explicit `/wannabuild` and `/wb-*` plugin commands remain available as
shortcuts and phase entrypoints into the full loop. Runtime gates fail closed:
`assert-workflow-active` catches missing `.wannabuild/` runtime evidence, and
`assert-plan-ready` blocks implementation before Plan. If the gate binary is
absent, `npx wannabuild doctor` fails for this host rather than silently falling
back to the Python mirror.

## Verification

```bash
./scripts/wannabuild-doctor.sh
./scripts/validate-wannabuild-dry-runs.sh
```

See:

- [docs/host-capability-matrix.md](../../docs/host-capability-matrix.md)
