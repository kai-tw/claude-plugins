---
name: ga4
description: |
  Google Analytics 4 reader for a GA4 property — activeUsers, sessions,
  engagement, and per-event counts, via keyless service-account
  impersonation. No key file, no OAuth consent screen, no env vars.
  This is a thin fetch layer only — it returns raw numbers. Turning
  usage data into roadmap/product judgment is a consuming project's
  own skill (e.g. a project-local "ga-triage"-style skill that anchors
  on that project's own event catalog and files backlog candidates).
  TRIGGER when: "/ga4", "check ga4", "check google analytics", "ga4
  data", "active users", "ga4 events", "analytics numbers", "查一下
  GA4", "查 google analytics", "使用者數據", "ga4 事件".
  NOT for: turning usage into product-roadmap candidates (that's a
  project-specific skill layered on top of this — see e.g.
  `ga-triage`); Search Console / SEO / indexing data (that's the
  sibling `gsc` skill in this same plugin — a different product,
  different script); writing GA4 config or creating events (read-only).
allowed-tools:
  - Bash
  - Read
---

# Google Analytics 4 reader

Read production GA4 usage data for a **GA4 property** and return it as JSON —
a thin fetch layer. Reading the numbers as signal (adoption, retention,
roadmap candidates) is a consuming project's job, not this skill's — see the
sibling note in "What this is not".

## How it reads (mechanism)

`analytics.readonly` is a Google *sensitive* scope, so gcloud's shared OAuth
client is barred from requesting it — the interactive user path is blocked,
making **keyless service-account impersonation** required, not just
convenient, and identical in shape to the sibling `gsc` skill's mechanism:

```
gcloud ADC token (your user creds)
  → IAM generateAccessToken(<reader-SA>, analytics.readonly)
  → GA4 Data API runReport
```

Every identifier (which property, which SA) is a **required CLI flag**, never
an env var — nothing to export, nothing to leak across terminal sessions or
projects.

## First time on a new property — run `setup`

```bash
ga4 setup --project <gcp-project>              # dry run — prints the gcloud commands
ga4 setup --project <gcp-project> --commit      # actually provisions the reader SA
```

Provisions the scriptable half (service account, API enablement, IAM
impersonation grant). It prints the **one step it cannot do** — no API exists
for it: add the SA as a **Viewer** on the GA4 property — Admin → Property
Access Management → Add users.

## Running it

```bash
ga4 <command> --property <id> --sa <email> [flags]
```

| Command | What it returns |
|---|---|
| `setup --project <id> [--sa-name] [--grant-to] [--commit]` | Provision the reader SA (dry-run by default) |
| `check --property <id> --sa <email>` | Verify the auth chain reaches the property (a 28d activeUsers count) |
| `overview --property <id> --sa <email> [-d 7,28,90]` | activeUsers / newUsers / sessions / engagement / views / events, per window |
| `events --property <id> --sa <email> [-d DAYS] [-n N]` | Top events by count = feature adoption (default 28d, 25 rows) |
| `report --property <id> --sa <email> <json \| @file>` | Raw `runReport` passthrough (any metrics / dimensions / cohortSpec) |

Output is JSON.

## Reading the numbers — a starting point, not the full picture

- **Low-traffic properties**: prefer 28d/90d windows and event-level
  aggregates over 7d or per-day breakdowns, which are noise at low N.
- **Absolute zero is the strongest signal** ("event X: 0 uses in 90d") —
  trust it more than ratio/trend deltas, which are soft at low volume.
- Deciding what counts as a meaningful adoption signal, mapping events to
  product areas, and filing roadmap candidates is **out of scope for this
  skill** — that judgment belongs in a project-specific skill that knows the
  project's own event catalog and backlog conventions (this plugin
  deliberately ships none of that).

## What this is not

- **Not a roadmap-judgment tool.** It returns numbers; deciding which numbers
  matter, mapping events to features, and filing backlog candidates is a
  consuming project's own layer (project-local skill, not this plugin —
  keeping business judgment out of a shared, public plugin is deliberate).
- **Not Search Console** — GSC is a different product with its own sibling
  skill (`gsc`, same plugin, same auth mechanism, different script). Use
  that for indexing/impressions/clicks/rank; use this for GA4
  users/sessions/engagement/events.
- **Cannot add the reader SA as a property Viewer.** That ACL lives inside
  GA4's own Property Access Management, not GCP IAM, and has no API —
  `setup` provisions everything scriptable and then tells you the one
  manual step by name.
- Not a config writer — read-only.

## Troubleshooting

- **`gcloud did not return an ADC token`** → run `gcloud auth
  application-default login` (the plain login; the `analytics.readonly`
  scope is added by the SA via impersonation, not by you — do NOT try to add
  it to the gcloud login itself, Google blocks that path).
- **`impersonating … failed`** → your account needs
  `roles/iam.serviceAccountTokenCreator` on the reader SA; run `ga4 setup`
  if you haven't, or grant the role directly. A fresh SA can take ~1 min to
  propagate.
- **`runReport failed` citing permission** → the SA must be a **Viewer** on
  the GA4 property (GA4 Admin → Property Access Management) — the one manual
  step `setup` cannot do.
- **`runReport failed` citing the API being disabled** → `ga4 setup --commit`
  enables it as part of provisioning; if you set this up by hand instead,
  run `gcloud services enable analyticsdata.googleapis.com --project=<project>`.
- **Empty rows** → no data in the window; widen `-d`. An empty result is a
  real answer, not a bug.
