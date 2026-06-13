# Cursor Adapter

Secondary WannaBuild adapter.

## Install

### npx (recommended)

```bash
npx wannabuild --cursor
```

Cursor is rules-only and invokes no runtime, so the installer refreshes the
`.cursor/rules/wannabuild.mdc` pointer and prints guidance — no binary is
placed. You can also load `.cursor/rules/wannabuild.mdc` directly from a clone
of this repo, then describe the feature in chat.

Reuse the shared contracts:

- `.wannabuild/`
- repo scripts
- shared prompts

Planned surfaces:

- `.cursor/rules`
- optional custom modes
- repo-native usage guidance

See:

- [docs/host-capability-matrix.md](../../docs/host-capability-matrix.md)
