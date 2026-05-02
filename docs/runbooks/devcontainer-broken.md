# Runbook: devcontainer won't build

## Symptom

- "Reopen in Container" hangs or fails.
- The container builds but `post-create.sh` errors out.
- A teammate can build it but you can't.
- CI's matrix job that uses the same image fails.

## Triage (≤ 5 min)

1. Open VS Code's **Dev Containers logs**: View → Output → "Dev Containers".
2. Scroll to the first error line. Most failures are obvious — a 404 on a
   package, a hash mismatch, a network timeout.
3. Identify which step failed:
   - Base image pull
   - Apt install
   - `shfmt` curl download
   - `bats-core` git clone
   - `pip install` of dev tools
   - `npm install -g`
   - `post-create.sh`

## Reproduce locally (without VS Code)

```bash
cd /path/to/wannabuild
docker build -f .devcontainer/Dockerfile -t wb-dev:local .
# If the build itself succeeds, run the post-create:
docker run --rm -it -v "$PWD":/workspaces/wannabuild -w /workspaces/wannabuild \
  wb-dev:local bash .devcontainer/post-create.sh
```

If `docker build` reproduces the failure, you've localized it.

## Common causes & fixes

| Cause | Symptom | Fix |
|---|---|---|
| Apt mirror outage | `apt-get update` hangs or returns 503. | Wait 5 min and retry; or `--build-arg APT_MIRROR=…` to a regional mirror. |
| Docker Hub rate limit | Base image pull fails with `toomanyrequests`. | `docker login`; or switch the base image to a GHCR mirror. |
| Base image moved/retired | `mcr.microsoft.com/devcontainers/base:ubuntu-22.04` 404. | Update `.devcontainer/Dockerfile` to a current tag from the [microsoft devcontainers index](https://github.com/devcontainers/images). |
| `shfmt` URL changed | `curl … shfmt_v3.10.0_linux_amd64` 404. | Bump the version pin to the current [shfmt release](https://github.com/mvdan/sh/releases). |
| `bats-core` clone fails | Network blocked. | Pre-vendor `bats-core` and copy it in instead. |
| `pip install` fails on `cryptography` build | Missing build deps. | Add `build-essential` to the apt install list. |
| `npm install -g` hits permission errors | Running as non-root after the feature switched users. | Move the `npm install -g` line BEFORE the user-switch features run. |
| `pre-commit install` fails in `post-create.sh` | Repo not initialized as git in the container. | Run `git init` first, or skip the hook install when `.git` is missing. |
| Apple Silicon vs amd64 | A binary downloaded by URL is amd64 only. | Add `--platform=linux/amd64` to the `FROM` line, or branch on `$TARGETARCH`. |
| Disk full | Build OOMs or "no space left". | `docker system prune -a` and rebuild. |

## Local fallback (no devcontainer)

If you cannot get the container to build, install the toolchain manually.
Minimum set is in [`../../.devcontainer/README.md`](../../.devcontainer/README.md)
under "Local fallback". Then run:

```bash
bash scripts/wannabuild-doctor.sh
```

If the doctor passes, you can develop without the container.

## Escalation

- **Owner**: PR author for self-incurred breakage; repo maintainers for a
  failing build on `main`.
- **When**: build broken on `main` for > 30 min, or > 2 contributors blocked.
- **Channel**: `#wannabuild-help`; GitHub Issue with `area:devcontainer`.

## Post-incident

- Pin floating versions that caused the break.
- Add a smoke build to CI if this break wouldn't have been caught by an
  existing job.
- Update the troubleshooting table above with the new failure mode.

## Cross-references

- [`../../.devcontainer/README.md`](../../.devcontainer/README.md) — what's
  installed.
- [`../build.md`](../build.md) — local commands.
- [`ci-failure.md`](ci-failure.md) — generic CI failure triage.
