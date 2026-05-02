# Product analytics

## Framework: not directly applicable

WannaBuild has no end users in the application sense — it's a CLI/skill set
consumed by AI agents and engineers. There is nothing to instrument with
PostHog or Mixpanel.

What we *do* track for adoption (informally):

- GitHub stars and watchers.
- Plugin install counts via Claude Code's marketplace and Codex's skill
  registry.
- CHANGELOG mentions and release-please PR cadence.
- Issues and PR open/close volume.

Future-work (TODO(@gl11tchy)): a small dashboard summarizing the above. Tracked but not
implemented; do not hand-roll without filing an issue first.

---

## Target projects: instrumentation guide

### Backends — quick comparison

| Backend | Pros | Cons | Use when |
|---|---|---|---|
| **PostHog** | OSS, self-hostable, session replay + flags + analytics in one. | Smaller community than Amplitude. | Default for new projects, especially privacy-sensitive ones. |
| **Mixpanel** | Best-in-class funnels and cohorts. | Pricey at scale. | Product-led growth motion. |
| **Amplitude** | Strong path/segment analysis. | Pricey at scale. | Enterprise B2C. |
| **GA4** | Free, ubiquitous. | Sampling, BigQuery export quirks, less developer-friendly. | Marketing teams need it anyway. |
| **Heap** | Auto-capture; less code work. | Auto-capture creates noise. | Teams that can't invest in instrumentation. |

For new projects: default to **PostHog** unless a stakeholder needs Amplitude
or Mixpanel specifically. Self-hosted PostHog avoids most GDPR concerns.

### Event taxonomy

Use three event categories:

1. **Pageview** — one per route. Required attributes: `path`, `referrer`.
2. **Action** — user-initiated UI events. Naming: `<noun>_<verb>` past tense.
   Examples: `button_clicked`, `signup_submitted`, `feature_x_enabled`.
3. **Conversion** — business outcomes that a stakeholder cares about. Examples:
   `subscription_started`, `payment_succeeded`, `trial_extended`.

Event naming rules:

- **Past tense, snake_case.** `button_clicked`, not `clickButton` or `click_button`.
- **`<noun>_<verb>`**, not `<verb>_<noun>`. `signup_submitted`, not
  `submitted_signup`. Easier to grep and group.
- **One event, many properties.** Use properties (`button_id`, `screen`) on
  one canonical event rather than 50 separate events.

### User identification

```js
// On login:
posthog.identify(userId, { email, plan });
// On logout:
posthog.reset();
```

Pre-login traffic gets an anonymous ID; PostHog/Amplitude/Mixpanel will alias
it to the user ID after login.

### GDPR & PII

- **Never send raw email addresses or names as event properties** unless
  legally cleared. Use a hashed user ID.
- **Use a server-side proxy** for the analytics SDK so you can scrub PII
  before it leaves your network.
- **Cookie consent** is required in EU jurisdictions; gate the SDK on
  consent.
- Cross-link: [`secrets-management.md`](secrets-management.md) and
  [`log-scrubbing.md`](log-scrubbing.md).

### Setup — Web (PostHog)

```js
import posthog from "posthog-js";

posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY, {
  api_host: process.env.NEXT_PUBLIC_POSTHOG_HOST,
  autocapture: false,        // prefer explicit events
  capture_pageview: true,
  loaded: (ph) => ph.opt_in_capturing(), // only after consent
});
```

### Setup — Backend (Node)

```js
import { PostHog } from "posthog-node";

const ph = new PostHog(process.env.POSTHOG_KEY, {
  host: process.env.POSTHOG_HOST,
});

ph.capture({ distinctId: userId, event: "subscription_started", properties: { plan } });
await ph.shutdown();
```

### Setup — Backend (Python)

```python
from posthog import Posthog
ph = Posthog(api_key=os.environ["POSTHOG_KEY"], host=os.environ["POSTHOG_HOST"])
ph.capture(distinct_id=user_id, event="subscription_started", properties={"plan": plan})
```

### How agents use product analytics

WannaBuild specialists can verify their own work by querying analytics after
ship:

1. The orchestrator records the feature name in the checkpoint (e.g.,
   `feature.name=onboarding_v2`).
2. The product-analytics tool fires the corresponding events
   (`onboarding_v2_started`, `_completed`).
3. Post-ship, the orchestrator (or a human) queries PostHog/Amplitude for the
   event series and confirms adoption is non-zero. If it's zero, that's a
   signal something broke in the rollout — open a ticket.

This closes the loop: agents ship → analytics confirms users actually used the
new code → agents iterate.

## Cross-references

- [`metrics.md`](metrics.md) — system metrics (different from product events).
- [`secrets-management.md`](secrets-management.md) — PII handling.
- [`log-scrubbing.md`](log-scrubbing.md) — scrubbing before egress.
- [`error-tracking.md`](error-tracking.md) — Sentry user context vs PostHog
  identify (don't double-instrument PII).
