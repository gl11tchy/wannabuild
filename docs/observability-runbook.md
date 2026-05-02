# Observability runbook index

This page indexes all operational runbooks for WannaBuild. Every runbook
follows the same format so on-call humans (and agents) can act fast.

## Runbook format

Every runbook in [`runbooks/`](runbooks/) has these sections:

1. **Symptom** — what you'd see (CI red, Slack alert, error spike).
2. **Triage** — fast steps to identify the failing component.
3. **Reproduce locally** — exact commands.
4. **Common causes & fixes** — prioritized list with one-line fixes.
5. **Escalation** — who to ping, how to file an incident.
6. **Post-incident** — what to capture for the post-mortem.

A runbook without a clear "Reproduce locally" section is incomplete. Fix it.

## Available runbooks

| Topic | Path |
|---|---|
| CI is failing | [`runbooks/ci-failure.md`](runbooks/ci-failure.md) |
| Release-please failed | [`runbooks/release-failure.md`](runbooks/release-failure.md) |
| We leaked a secret | [`runbooks/secret-leak-incident.md`](runbooks/secret-leak-incident.md) |
| Orchestrator misbehaved in a target project | [`runbooks/agent-misbehavior.md`](runbooks/agent-misbehavior.md) |
| Dependabot/Renovate update is breaking CI | [`runbooks/dependency-update-failed.md`](runbooks/dependency-update-failed.md) |
| Devcontainer won't build | [`runbooks/devcontainer-broken.md`](runbooks/devcontainer-broken.md) |

## How runbooks are linked from alerts

Every alert defined for the framework's CI **must** include a runbook link in
its body. See [`alerting.md`](alerting.md) for the alert-to-runbook mapping
template.

## Adding a new runbook

1. Create `runbooks/<topic>.md` matching the format above.
2. Link it from this index.
3. If an alert maps to it, add a row in the alert-to-runbook table in
   [`alerting.md`](alerting.md).
