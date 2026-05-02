# WannaBuild Style Guide

This guide is the canonical reference for naming, formatting, and structural
conventions across the WannaBuild repo. Every rule is enforced by tooling so
the guide stays honest — if a rule is not listed in the **Enforced by**
column, treat it as advisory.

## 1. Repository conventions

| Rule | Example | Enforced by |
|---|---|---|
| UTF-8 + LF line endings | n/a | `.editorconfig`, pre-commit `mixed-line-ending` |
| Final newline on every file | n/a | `.editorconfig`, pre-commit `end-of-file-fixer`, markdownlint MD047 |
| 2-space indent for shell, JSON, YAML, markdown | n/a | `.editorconfig`, `shfmt -i 2`, prettier `tabWidth: 2` |
| No trailing whitespace (except markdown line breaks) | n/a | pre-commit `trailing-whitespace`, markdownlint MD009 |
| No tracked file > 500 KB | n/a | `scripts/check-large-files.sh`, pre-commit `check-added-large-files` |
| No tracked `*.sh`/`*.md` > 800 lines (700 for `skills/build/SKILL.md`) | n/a | `scripts/check-large-files.sh` |

## 2. File and directory naming

| Surface | Convention | Example | Enforced by |
|---|---|---|---|
| Shell scripts | kebab-case, verb-noun | `check-tech-debt.sh` | review |
| Skill directories | kebab-case | `skills/build/` | review |
| Skill manifests | uppercase | `SKILL.md` | review |
| Skill references | lowercase kebab in `references/` | `skills/build/references/loop-state.md` | review |
| Specialist agent prompts | `wb-<role>.md` | `agents/wb-integration-tester.md` | review |
| Adapters | `adapters/<host>/` | `adapters/codex/` | review |

## 3. Shell scripts (`scripts/*.sh`)

| Rule | Detail | Enforced by |
|---|---|---|
| Shebang | `#!/usr/bin/env bash` on line 1 | shellcheck SC2148, pre-commit `check-executables-have-shebangs` |
| Strict mode | `set -euo pipefail` near the top | shellcheck SC2086 (indirectly), review |
| Strict-mode exception | `scripts/lint.sh` deliberately omits `-e` so it can collect failures from every check before exiting; the rationale is documented inline at the top of that script. No other script may opt out. | review |
| Function names | `snake_case`; export-public functions prefixed `wb_` | review |
| Local variables | lowercase, declared with `local` | shellcheck SC2155, SC2034 |
| Constants / env vars | `ALL_CAPS`; mark immutable with `readonly` | shellcheck SC2155 |
| Conditionals | prefer `[[ ... ]]` over `[ ... ]` | shellcheck SC2292 (require-double-brackets) |
| Variable expansion | always braces: `${var}` | shellcheck SC2250 (require-variable-braces) |
| Quote command output | `"$(cmd)"`, never bare `$(cmd)` | shellcheck SC2046, SC2086 |
| Cyclomatic complexity ≤ 10 per function | n/a | `scripts/check-complexity.sh` (lizard) |
| Function length ≤ 80 NLOC | n/a | `scripts/check-complexity.sh` |
| Argument count ≤ 5 | n/a | `scripts/check-complexity.sh` |
| Formatting | `shfmt -i 2 -ci -bn` | `scripts/format.sh`, pre-commit `shfmt`, `lint.sh` |
| Static checks | shellcheck warnings clean | `.shellcheckrc`, pre-commit `shellcheck`, `lint.sh` |
| Dead functions disallowed | every defined function must be invoked | `scripts/check-dead-refs.sh` |

## 4. Markdown

| Rule | Detail | Enforced by |
|---|---|---|
| Heading style | ATX (`#`, `##`, ...) | markdownlint MD003 |
| Single H1 per document | n/a | markdownlint MD025 |
| Headings have surrounding blanks | n/a | markdownlint MD022 |
| Heading hash spacing | `# Title`, no extra spaces | markdownlint MD018, MD019, MD020, MD021 |
| Lists surrounded by blanks | n/a | markdownlint MD032 |
| Fenced code blocks have language | `` ```bash `` not `` ``` `` | markdownlint MD040 |
| Code block style is fenced | n/a | markdownlint MD046 |
| No bare URLs | use `<https://...>` or `[label](url)` | markdownlint MD034 |
| No multiple consecutive blank lines | n/a | markdownlint MD012 |
| Trailing whitespace controlled | only `` (2 spaces) for line breaks | markdownlint MD009 |
| No first-person plural marketing voice ("we", "our") | aim for neutral, declarative prose | review |
| Links resolve | every relative link points to an existing file | `scripts/check-dead-refs.sh` |

## 5. Tech-debt markers

Use one of `TODO`, `FIXME`, `XXX`, `HACK`. Every marker MUST carry attribution:

```markdown
<!-- TODO(@alex): wire this once the workspace gate is final -->
<!-- FIXME(#42): handle null state.json gracefully -->
<!-- TODO(WB-17): replace dry-run fixture once schema settles -->
```

| Form | Meaning | Enforced by |
|---|---|---|
| `TODO(name)` / `TODO(@handle)` | owner | `scripts/check-tech-debt.sh` |
| `FIXME(#NN)` | issue number | `scripts/check-tech-debt.sh` |
| `FIXME(ISSUE-NN)` / `TODO(WB-NN)` | tracker reference | `scripts/check-tech-debt.sh` |

Bare `TODO:` or `FIXME` (no parenthetical) fails the check.

## 6. Duplicate / dead code

| Rule | Detail | Enforced by |
|---|---|---|
| Cross-file duplication budget ≤ 5% (jscpd threshold) | min-tokens 50, min-lines 8 | `.jscpd.json`, `lint.sh` |
| Languages scanned | markdown + shellscript | `.jscpd.json` |
| Dead markdown links fail CI | n/a | `scripts/check-dead-refs.sh` |
| Unused shell functions fail CI | except `main`, `usage`, `help` | `scripts/check-dead-refs.sh` |

## 7. Pre-commit

`pre-commit install` wires the canonical hook chain (see
`.pre-commit-config.yaml`). The hooks run trailing-whitespace,
end-of-file-fixer, JSON/YAML validation, large-file detection, shellcheck,
shfmt, markdownlint-cli2, gitleaks, and the local WannaBuild checks
(`check-tech-debt`, `check-large-files`, `check-dead-refs`).

## 8. Editing the guide

When changing a rule:

1. Update this guide.
2. Update the corresponding tool config (`.shellcheckrc`,
   `.markdownlint-cli2.jsonc`, `.jscpd.json`, `.lizardrc`,
   `.pre-commit-config.yaml`) and/or the relevant `scripts/check-*.sh`.
3. Re-run `scripts/lint.sh` to confirm the rule actually fires.
