# wannabuild

One command to install [WannaBuild](https://github.com/gl11tchy/wannabuild)
into every coding-agent host you use — Claude Code, Codex, Factory, and Cursor —
and wire each one to the **real Rust `wb-runtime` gate engine**, never a
degraded fallback.

```bash
npx wannabuild
```

That auto-detects which hosts are present (`~/.claude`, `~/.codex`,
`~/.factory`, `~/.cursor`), clones the WannaBuild repo at the latest release,
downloads the prebuilt `wb-runtime` archive for your platform, verifies its
sha256 against the release's signed checksum manifest, extracts the binary, and
runs each host's install script. No Rust
toolchain required (`tar` is used to unpack — preinstalled on macOS, Linux, and
Windows 10+).

## Usage

```bash
npx wannabuild [install] [hosts] [options]   # install into detected/selected hosts
npx wannabuild doctor                         # verify every host's runtime is wired
npx wannabuild uninstall [--purge]            # show removal steps (or remove the checkout)
npx wannabuild version                        # package + checkout + runtime versions
npx wannabuild help
```

### Host selection

Pass any of these to install a specific set (passing any disables auto-detect):

```bash
npx wannabuild --claude --codex
npx wannabuild --cursor
```

| Flag | Host | Runtime |
|---|---|---|
| `--claude` | Claude Code | Rust `wb-runtime` (via the cache → checkout symlink) |
| `--codex` | Codex | Rust `wb-runtime` copied to `~/.codex/bin` |
| `--factory` | Factory | Rust `wb-runtime` copied into the Factory plugin cache |
| `--cursor` | Cursor | rules-only, no runtime |

### Options

| Option | Default | Meaning |
|---|---|---|
| `--dir <path>` | `~/.wannabuild/checkout` | Where the WannaBuild checkout lives |
| `--ref <git-ref>` | latest release tag | Pins **both** the checkout and the downloaded binary |
| `--yes`, `-y` | off | Non-interactive; do not prompt before updating an existing checkout |
| `--purge` | off | With `uninstall`: remove the checkout directory |
| `--version`, `-v` | — | Print the installer version |
| `--help`, `-h` | — | Show help |

After install, the CLI runs `wb-runtime --version` on the placed binary to
confirm it executes on this platform (a liveness check); a binary that cannot
run aborts the install. `wb-runtime` is versioned `0.1.0` independent of the
release tag — integrity comes from the mandatory signed-checksum verification
above, not a version match.

## Security stance

This package installs a privileged native gate-enforcer and runs host-mutating
bash scripts. To keep every install-time line auditable:

- **Zero dependencies** — runtime *and* dev. Node built-ins only
  (`node:https`, `node:fs`, `node:path`, `node:os`, `node:child_process`,
  `node:crypto`, `node:readline`). No transitive code runs at install time.
- **No lifecycle scripts** — there is no `postinstall`/`preinstall`/`install`.
  Nothing happens until you *run* `npx wannabuild`.
- **Signed-checksum verification is mandatory** — the downloaded `wb-runtime`
  archive's sha256 is checked against the release's `SHA256SUMS` manifest, and
  that manifest's detached minisign (Ed25519) signature is verified against the
  public key shipped in this package (`wannabuild-release.pub`) *before any
  binary is downloaded*. The binary is then installed atomically (staged then
  renamed). A bad or missing signature, or a checksum mismatch, aborts the
  install; it never falls back to an unverified binary.
- **Trust boundary** — integrity rests on the signed manifest plus the
  per-archive sha256: the signing key never travels with the release, so this
  defends against corrupted/MITM'd downloads *and* a single tampered or
  substituted release asset — rewriting an archive and its checksum line still
  cannot forge the signature. What remains trusted is the public key shipped here
  and that the offline signing key stays uncompromised. Releases that predate
  signing carry no manifest and are refused unless you explicitly pin one with
  `--ref` (which verifies the legacy unsigned `.sha256` only, with a warning).

## Windows

The host install scripts are bash. On Windows the CLI locates bash in this
order: `$WANNABUILD_BASH`, `bash` on `PATH`, Git for Windows
(`C:\Program Files\Git\bin\bash.exe` and the x86 variant), then `wsl.exe`. If
none is found it errors with install guidance — it never degrades. Install
[Git for Windows](https://git-scm.com/download/win) or enable WSL.

## Uninstall

```bash
npx wannabuild uninstall            # prints host-managed entries + exact removal commands
npx wannabuild uninstall --purge    # also removes the ~/.wannabuild/checkout directory
```

Uninstall never deletes anything outside the checkout, `~/.codex/bin`, or the
documented host caches. Host JSON registrations are listed for you to remove
deliberately.

## For maintainers

Releases are cut by `.github/workflows/release-please.yml` on push to `main`.
When release-please marks a release created, its `release-binaries` and
`npm-publish` jobs run (gated on `releases_created`) to build the cross-platform
binaries and publish to npm. npm publishing uses `--provenance`, which requires:

- the `NPM_TOKEN` repository secret (publishing is skipped with a clear log if
  it is unset), and
- `id-token: write` permission on the publish job (already configured).

## License

MIT
