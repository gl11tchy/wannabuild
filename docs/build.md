# Build

WannaBuild is a documentation and framework repository. There is no compiled
binary, no bundled application, no published package artifact. The deliverables
are prompt files, schemas, shell scripts, and markdown contracts.

For this project, **"build" means: lint + tests + contract validation pass**.

## Local build

The full local build is three commands:

```bash
bash scripts/lint.sh
bash tests/run.sh
bash scripts/wannabuild-doctor.sh
```

If you only need a quick sanity check before pushing, run the doctor on its
own — it verifies that every required surface (skill folders, install scripts,
references, schemas) is present and wired correctly:

```bash
bash scripts/wannabuild-doctor.sh
```

## What the build verifies

| Stage | Tool | What it catches |
|---|---|---|
| Lint | `scripts/lint.sh` | shell, markdown, prose, duplication, complexity |
| Test | `tests/run.sh` | bats unit + integration suites |
| Contracts | `scripts/wannabuild-doctor.sh` | required files, install symlinks, contracts |
| Artifact validation | `scripts/validate-wannabuild-artifacts.sh` | `.wannabuild/` JSON shape against JSON Schema |
| Coverage (optional) | `tests/coverage.sh` | bash coverage threshold via kcov |

## CI parity

CI (`.github/workflows/ci.yml`) runs the same commands in the same order on
Ubuntu and macOS, so a clean local build should produce a clean CI run. See
`docs/ci.md` for a per-workflow breakdown.

## Generated documentation

Some pages under `docs/generated/` are produced by `scripts/generate-docs.sh`.
Regenerate them locally with:

```bash
bash scripts/generate-docs.sh
```

CI verifies these are up to date on every pull request, and a scheduled
workflow opens an automated PR if `main` falls out of sync.
