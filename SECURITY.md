# Security Policy

## Reporting a vulnerability

**Please do not file public issues for security reports.** Public issues create
a window of exposure between disclosure and a fix.

Use one of the following private channels:

1. **Preferred — GitHub security advisory.** Open a private advisory directly
   from the repository's Security tab:

   <https://github.com/gl11tchy/wannabuild/security/advisories/new>

   Or, from the CLI:

   ```bash
   gh security advisory create --repo gl11tchy/wannabuild
   ```

   This creates a private collaboration space with the maintainers and is the
   only channel guaranteed to reach us. Please include:

   - A description of the issue and its impact.
   - Reproduction steps or a minimal proof of concept.
   - The commit SHA / release where you observed the behaviour.
   - Whether you have already disclosed the issue elsewhere.

2. **Fallback — direct contact via GitHub.** If you cannot use a security
   advisory (e.g. you do not have a GitHub account), reach the maintainer at
   <https://github.com/gl11tchy> and request a private channel. Do **not**
   include vulnerability details in a public issue, discussion, or comment.

> A dedicated `security@` mailbox is planned but not yet active. Until it is
> announced here, please use the GitHub advisory flow above.

We aim for a **best-effort initial response within five business days**.
Holidays and conference weeks may extend that. If you have not heard back in
ten business days, please ping the channel you originally used.

## Supported versions

WannaBuild ships from `main`. Security fixes are issued for the latest minor
release line only.

| Version | Status      |
| ------- | ----------- |
| latest  | ✅ Supported |
| older   | ❌ Unsupported |

If you need a backport to an older line, open a discussion describing the
constraint that prevents you from upgrading.

## Disclosure policy

We follow **coordinated disclosure** with a default 90-day window:

- Day 0: report received and acknowledged.
- Day 0–14: triage, severity assessment, fix scoping.
- Day 14–60: fix developed and reviewed in private.
- Day 60–90: coordinated release; advisory published; reporter credited.

We will work with you on shorter or longer windows where the situation
warrants — for example, immediate disclosure for a fix already in the wild,
or an extended embargo for issues that affect downstream packagers.

## Scope

In scope:

- The contents of this repository (scripts, prompts, schemas, docs).
- The published install paths (`scripts/install-codex-skill.sh`,
  `scripts/install-claude-skill.sh`, marketplace plugin manifests).
- The artifact contracts that target projects rely on.

Out of scope:

- Vulnerabilities in unmaintained forks.
- Issues in third-party hosts (Codex, Claude Code, Cursor) themselves —
  please report those upstream. We are happy to coordinate where the bug
  lies on the boundary.
- Social-engineering attacks against maintainers.

## Acknowledgements

Reporters who follow this policy are credited (with their consent) in the
relevant security advisory and in this section once a public advisory ships.

<!-- BEGIN ACKNOWLEDGEMENTS -->
<!-- Add reporter credits here as advisories are published. -->
<!-- END ACKNOWLEDGEMENTS -->

## See also

- [`docs/security.md`](docs/security.md) — overall threat model
- [`docs/secrets-management.md`](docs/secrets-management.md)
- [`docs/supply-chain.md`](docs/supply-chain.md)
- [`docs/log-scrubbing.md`](docs/log-scrubbing.md)
