---
name: gsc
description: |
  Google Search Console reader for a verified site — indexing status
  (is a URL actually indexed, coverage state, last crawl), search
  performance (clicks/impressions/ctr/position by page or query), and
  sitemap health (submitted, errors, warnings, submitted-vs-indexed
  counts). Read-only by default via keyless service-account
  impersonation — no key file, no OAuth consent screen, no env vars.
  Use whenever the user wants a real GSC check instead of "go look in
  the browser".
  TRIGGER when: "/gsc", "check search console", "check gsc", "is this
  page indexed", "gsc check", "search console check", "indexing
  status", "search performance", "impressions and clicks", "sitemap
  status", "查一下 GSC", "查 search console", "這頁有沒有被收錄",
  "收錄狀態", "搜尋成效", "曝光跟點擊", "sitemap 狀態", "GSC 週查".
  NOT for: requesting indexing/recrawl of a URL — no API exists for
  this (see "What this is not" below), it is always a manual click in
  the Search Console UI; changing site verification or adding/removing
  users on the property (manual GSC UI only, no API); Google Analytics
  / GA4 usage data (that's the sibling `ga4` skill in this same
  plugin — a different product, different script); ad-hoc keyword
  research (this reads a property's own historical performance, it
  doesn't suggest new keywords).
allowed-tools:
  - Bash
  - Read
---

# Google Search Console reader

Read production indexing + performance data for a **verified Search Console
property** and report it — as a real check, not a browser round-trip. This is
read-only by default; the one write command (`submit-sitemap --commit`) is
explicitly gated.

## How it reads (mechanism)

`webmasters`/`webmasters.readonly` are ordinary sensitive (non-restricted)
Google scopes, so `gsc` uses **keyless service-account impersonation** — no
key file, no Python, no node_modules, no env vars:

```
gcloud ADC token (your user creds)
  → IAM generateAccessToken(<reader-SA>, webmasters[.readonly])
  → Search Console API
```

One wrinkle GA4 doesn't have: Search Console's resources split across **two
hostnames** — `searchAnalytics`/`sitemaps`/`sites` live under
`www.googleapis.com/webmasters/v3`, `urlInspection` lives under
`searchconsole.googleapis.com/v1`. The script handles both; you don't need to
think about it.

Every identifier (which site, which SA) is a **required CLI flag**, never an
env var — nothing to export, nothing to leak across terminal sessions or
projects. The script is the reliable **fetch** layer; reading the numbers as
SEO signal is your job.

## First time on a new property — run `setup`, then resolve the site string

```bash
gsc setup --project <gcp-project>              # dry run — prints the gcloud commands
gsc setup --project <gcp-project> --commit      # actually provisions the reader SA
```

This provisions the scriptable half (service account, API enablement, IAM
impersonation grant). It prints the **one step it cannot do** — no API exists
for it: add the SA as a **User** in Search Console → your property →
Settings → Users and permissions → Add user → **Restricted** (enough for
every read command; **Full** only if you'll use `submit-sitemap --commit`).

Once that manual step lands, resolve the exact `--site` string — its format
differs by verification type (URL-prefix: `https://example.com/`, trailing
slash, exact; Domain property: `sc-domain:example.com`, no scheme) — **don't
guess it**:

```bash
gsc sites --sa <the SA email setup printed>
```

## Running it

```bash
gsc <command> --site <siteUrl> --sa <email> [flags]
```

| Command | What it returns |
|---|---|
| `setup --project <id> [--sa-name] [--grant-to] [--commit]` | Provision the reader SA (dry-run by default) |
| `check --site <url> --sa <email>` | Verify the auth chain reaches the account, and whether `--site` is visible to the SA |
| `sites --sa <email>` | Every property the SA can see, with its **exact** `siteUrl` string + `permissionLevel` |
| `performance --site <url> --sa <email> [-d DAYS] [--dimensions page,query] [--page URL] [--query STR] [-n N] [--type web\|image\|video\|news\|discover]` | clicks / impressions / ctr / position, by page and/or query |
| `inspect <url> --site <url> --sa <email>` | Indexing verdict, coverage state, last crawl time, Google's chosen canonical, for one URL |
| `sitemaps --site <url> --sa <email>` | Every submitted sitemap's status: last downloaded, warnings, errors, submitted-vs-indexed counts |
| `submit-sitemap <url> --site <url> --sa <email> [--commit]` | Submit/resubmit a sitemap — **dry-run by default**, needs Full permission to actually commit |
| `report <json \| @file> --site <url> --sa <email>` | Raw `searchAnalytics.query` passthrough for anything the wrapped command doesn't cover |

Output is JSON.

## Reading the numbers

- **Indexing first.** `inspect` on a URL you expect to rank is the ground
  truth — a page can't get impressions if `indexStatusResult.coverageState`
  isn't a healthy indexed state, regardless of how good the content is.
  `Discovered - currently not indexed` (Google knows the URL, hasn't crawled
  it yet) is an earlier, distinct state from "crawled but not indexed" —
  don't conflate them.
- **New / low-authority sites index slowly, and that's not automatically a
  bug.** A page that's been live under two weeks with no crawl yet is often
  just waiting its turn — check `sitemaps` for real errors before assuming
  something is broken.
- **`performance` trends over single-day spikes.** Prefer `-d 28` or wider;
  a few clicks a day is noise at low-authority-site volume. Zero impressions
  for a query you're targeting, sustained over weeks, is the real signal —
  not a one-day dip.
- **`sitemaps`' submitted-vs-indexed gap** is a legitimate site-health metric
  independent of any one page — a growing gap across many URLs points at a
  structural crawl problem (robots.txt, noindex, thin content, crawl budget),
  not "give it more time". This field is also known to lag real-time
  `inspect` status by days — don't treat a stale-looking 0 as contradicting a
  fresher `inspect` result for the same URL.

## What this is not

- **Cannot request indexing or a recrawl of a URL.** Confirmed, not assumed:
  Search Console's own API has no such method anywhere in its resources, and
  Google's separate Indexing API is contractually restricted to `JobPosting`/
  `BroadcastEvent` structured-data pages only — using it for ordinary content
  would violate its terms. This stays a manual click: Search Console UI → URL
  Inspection → **Request Indexing**. Don't re-investigate this later; it was
  checked.
- **Cannot add the reader SA as a Search Console user.** That ACL lives
  inside the product, not GCP IAM, and has no API — `setup` provisions
  everything scriptable and then tells you the one manual step by name.
- Not a keyword-research tool — it reads a property's own historical data,
  it doesn't suggest new keywords or estimate search volume for terms you
  don't already rank for.
- Not Google Analytics — GA4 is a different product with its own sibling
  skill (`ga4`, same plugin, same auth mechanism, different script). Use
  that for users/sessions/engagement; use this for indexing/impressions/
  clicks/rank.

## Troubleshooting

- **`gcloud did not return an ADC token`** → run `gcloud auth
  application-default login` (the plain login; the `webmasters` scope is
  added by the SA via impersonation, not by you).
- **`impersonating … failed`** → your account needs
  `roles/iam.serviceAccountTokenCreator` on the reader SA; run `gsc setup`
  if you haven't, or grant the role directly. A fresh SA can take ~1 min to
  propagate.
- **API call fails with a message about the SA lacking access, or the site
  missing from `sites`** → the SA has not been added as a **User** in
  Search Console → Settings → Users and permissions for that property. This
  is the one step `setup` cannot do — an existing Owner must add the SA's
  email there by hand.
- **API call fails saying the API is disabled** → `gsc setup --commit`
  enables it as part of provisioning; if you set this up by hand instead,
  run `gcloud services enable searchconsole.googleapis.com --project=<project>`.
- **`--site is required` / `--sa is required`** → run `sites` to find the
  exact `--site` string; don't hand-construct it from the domain name.
- **`inspect` returns `verdict: NEUTRAL` / no crawl data** → the URL likely
  hasn't been crawled yet. Not a bug — check `sitemaps` for real errors
  before concluding something is broken.
