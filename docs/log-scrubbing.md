# Log Scrubbing

WannaBuild ships a small logging library, [`scripts/wb-log.sh`](../scripts/wb-log.sh), and
a standalone scrubber, [`scripts/scrub-log.sh`](../scripts/scrub-log.sh), that redact
common secret-shaped patterns from log output before they reach disk, stdout, or CI.

## Why this matters

CI logs are commonly:

- Persisted on the runner provider (GitHub Actions, etc.) for weeks or months.
- Forwarded to log aggregators that may have broader access than the source repo.
- Pasted into bug reports, Slack threads, support tickets, and AI assistants.

Any one of those surfaces leaking a token (or PII like an end-user email) is the
common path to a real incident. Catching obvious secret shapes at log-emit time is
cheap insurance.

## Patterns scrubbed

*(Token prefixes are defanged in this doc — `ghp[_]` represents `ghp_`. The actual scrubber matches the un-defanged forms.)*

| Pattern                     | Example input                                       | Replaced with                |
| --------------------------- | --------------------------------------------------- | ---------------------------- |
| `token`/`secret`/`password`/`api_key`/`api-key`/`bearer` `=`/`:` value | `token: hunter2value`                               | `token: <redacted>`          |
| GitHub tokens (`ghp[_]`, `gho[_]`, `ghu[_]`, `ghs[_]`, `ghr[_]`)                | `ghp[_]abcdef0123456789ABCDEF0123456789abcd`          | `<github-token-redacted>`    |
| AWS access keys             | `AKIAIOSFODNN7EXAMPLE`                              | `<aws-access-key-redacted>`  |
| JWTs                        | `eyJhbGciOi....SflKxwR....`                         | `<jwt-redacted>`             |
| `Bearer` auth headers       | `Authorization: Bearer abc-def_123`                 | `Bearer <redacted>`          |
| Email addresses             | `alice@example.com`                                 | `<email-redacted>`           |
| Long high-entropy strings (32+ chars) | `value=abcdefghijklmnopqrstuvwxyz0123456789ABCDEF` | `<high-entropy-redacted>` |

40-character lowercase hex git SHAs are explicitly preserved by a split-and-restore
pre-pass, so commit references in logs are not mangled.

## Using `wb-log.sh` in new scripts

Source it from your script and call the level functions:

```bash
. "$(dirname -- "${BASH_SOURCE[0]}")/wb-log.sh"

wb_log_info  "starting phase $phase"
wb_log_warn  "config missing: $key"
wb_log_error "validator failed for $artifact"
wb_log_debug "internal state: $blob"
```

Environment knobs:

- `WB_LOG_LEVEL` — `debug` | `info` (default) | `warn` | `error`
- `WB_LOG_FORMAT` — `text` (default) | `json`

JSON mode emits one object per line: `{"ts":"...","level":"info","msg":"..."}`.

The library is `set +e` safe: sourcing it does not enable `set -e`/`set -u`/`pipefail`
or alter the host script's traps, working directory, or environment beyond the
documented `WB_LOG_*` variables.

## Scrubbing existing logs after the fact

For raw log files generated outside the framework:

```bash
cat raw-log.txt | scripts/scrub-log.sh > clean-log.txt
scripts/scrub-log.sh build.log                    # writes scrubbed text to stdout
scripts/scrub-log.sh --in-place build.log         # rewrites in place; .bak kept
scripts/scrub-log.sh --dry-run build.log          # shows a unified diff
```

Use `--in-place` only on files you can afford to mutate; a `.bak` copy is left
beside the original.

## Limitations

Scrubbing is heuristic. Expect both directions of error:

- **False positives**: any 32+ character alphanumeric run is treated as
  high-entropy and redacted, including some legitimate identifiers (e.g., long
  S3 object keys, base64-encoded request IDs). The scrubber goes out of its way
  to keep 40-char git SHAs intact, but other long IDs may be redacted.
- **False negatives**: novel token formats, secrets split across newlines, or
  base64-wrapped credentials shorter than 32 characters will pass through.

Scrubbing is **not** a substitute for not logging secrets in the first place.
Treat it as defence in depth.

## Self-test

`scripts/wb-log.sh --self-test` runs a redaction-rule test suite. All rules must
pass; CI runs this on every PR. If you change `wb_log_scrub`, rerun it locally.

## Extending the patterns

To add a new redaction rule:

1. Add a `-e` clause to `wb_log_scrub` in [`scripts/wb-log.sh`](../scripts/wb-log.sh)
   using `sed -E` syntax that works under both BSD and GNU sed.
2. Add a positive `_check` and, where appropriate, a negative `_refute` case to
   `_wb_log_self_test` in the same file.
3. Run `bash scripts/wb-log.sh --self-test` until clean.
4. Update the patterns table above.

For target projects that adopt WannaBuild and need extra patterns specific to
their stack (Stripe live keys, internal service signatures, etc.), copy
`wb-log.sh` into the project and append rules; do not modify the framework copy
in your downstream repo.

## See also

- [`docs/secrets-management.md`](secrets-management.md)
- [`docs/security.md`](security.md)
