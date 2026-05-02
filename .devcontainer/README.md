# WannaBuild Dev Container

A reproducible, ready-to-go environment for working on WannaBuild itself.
WannaBuild is a docs/framework repo, so the container provides shell, Markdown,
JSON/YAML, and CI tooling rather than a runtime application stack.

## One-command setup (recommended)

1. Install [Docker](https://www.docker.com/) and [Visual Studio Code](https://code.visualstudio.com/).
2. Install the **Dev Containers** extension (`ms-vscode-remote.remote-containers`).
3. Open this repo in VS Code.
4. Run **Dev Containers: Reopen in Container** from the command palette.

VS Code will build the image, install features, and run
[`post-create.sh`](./post-create.sh) (which installs `pre-commit` hooks and
runs `scripts/wannabuild-doctor.sh`). After the container is up,
[`post-start.sh`](./post-start.sh) runs every time you reopen it.

## What's installed

The base image is `mcr.microsoft.com/devcontainers/base:ubuntu-22.04`.

| Tool | Purpose |
|---|---|
| `shellcheck` | Shell linter (matches CI). |
| `shfmt` | Shell formatter (matches `.editorconfig`). |
| `jq` | JSON manipulation in scripts. |
| `ripgrep` (`rg`) | Fast search; required by helper scripts. |
| `bats-core` | Test runner used by `tests/run.sh`. |
| `kcov` | Coverage for shell scripts. |
| `pre-commit` | Hook runner (`.pre-commit-config.yaml`). |
| `lizard` | Cyclomatic complexity reports. |
| `yamllint` | YAML linter. |
| `detect-secrets` | Secret scanner (`.secrets.baseline`). |
| `markdownlint-cli2` | Markdown linter (`.markdownlint-cli2.jsonc`). |
| `jscpd` | Copy/paste detector (`.jscpd.json`). |
| `prettier` | Markdown / JSON / YAML formatter. |
| `gh` | GitHub CLI. |
| Python 3.11, Node 20 | Runtimes for the tools above. |

VS Code extensions (configured automatically) are listed in
[`devcontainer.json`](./devcontainer.json).

## Adding dependencies

1. Edit [`Dockerfile`](./Dockerfile) (or `devcontainer.json` features).
2. Run **Dev Containers: Rebuild Container**.
3. If the dependency is also needed in CI, mirror the change in the workflow
   that needs it (see `docs/ci.md`).

## Local fallback (no container)

If you cannot use the dev container, install the tooling manually. The minimal
required set with version floors lives in
[`tools-required.txt`](./tools-required.txt) — versions there are kept in sync
with what [`Dockerfile`](./Dockerfile) installs.

Then run `bash scripts/wannabuild-doctor.sh` to validate the environment.

## Environment variables

The container sets `WB_DEV_CONTAINER=1`. Repo scripts that change behavior
inside the container key off this variable. See
[`../.env.example`](../.env.example) for the full list of optional env vars
honored by repo scripts and CI.

## Troubleshooting

If the container fails to build, see
[`../docs/runbooks/devcontainer-broken.md`](../docs/runbooks/devcontainer-broken.md).
