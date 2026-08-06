# google-reporting

**Google Analytics 4** and **Google Search Console** readers for Claude Code
— usage, indexing status, search performance, and sitemap health, without
opening a browser tab.

Two scripts (`ga4`, `gsc`) sharing one auth module. Zero npm dependencies,
zero downloaded key files, **zero environment variables** — every identifier
(property, site, service account) is a required CLI flag, so nothing gets
exported into a shell profile and leaks across terminal sessions or projects.

```bash
claude plugin marketplace add kai-tw/claude-plugins
claude plugin install google-reporting@kai-tw
```

**Requirements:** the Google Cloud SDK (`gcloud`), with `gcloud auth
application-default login` run once. A one-time, per-property GCP + product
setup is required before the first real call — see below.

---

## The problem it solves

"Is this page actually indexed?", "is our search traffic trending up?", "what
does GA4 say about last week?" have always meant tabbing over to a Google
console and eyeballing it. That's fine once. It stops being fine as a
**recurring** check — a weekly SEO review, a roadmap-triage pass — because a
manual browser check can't be scripted into a workflow, can't be diffed
against last week, and depends on whoever's doing the check remembering to.

This plugin makes both a real, scriptable check: `gsc inspect <url> --site
... --sa ...` either returns a real indexing verdict or fails loudly — no
"let me go look."

## One-time setup, per GCP project

Both tools ship a `setup` command that provisions the scriptable half — no
hand-typed `gcloud` invocations required:

```bash
gsc setup --project <your-project>              # or: ga4 setup --project <your-project>
gsc setup --project <your-project> --commit      # actually run it
```

This creates a reader service account, enables the relevant API, and grants
your own account impersonation rights on it. `--sa-name` defaults to
`gsc-reader`/`ga4-reader`; `--grant-to` defaults to whatever `gcloud config
get-value account` reports.

It then prints **the one step it cannot do — no API exists for it**:

- **GSC**: add the SA as a **User** in Search Console → your property →
  Settings → Users and permissions → Add user → **Restricted** (enough for
  every read command; **Full** only for `submit-sitemap --commit`).
- **GA4**: add the SA as a **Viewer** on the property — Admin → Property
  Access Management → Add users.

Finally, for GSC, resolve the exact `--site` string — it differs for a
URL-prefix vs a Domain property, so don't guess it:

```bash
gsc sites --sa <the SA email setup printed>
```

## Usage

```bash
gsc check --site https://example.com/ --sa gsc-reader@my-project.iam.gserviceaccount.com
gsc performance --site https://example.com/ --sa gsc-reader@my-project.iam.gserviceaccount.com -d 28
gsc inspect https://example.com/blog/post --site https://example.com/ --sa gsc-reader@my-project.iam.gserviceaccount.com

ga4 check --property 123456789 --sa ga4-reader@my-project.iam.gserviceaccount.com
ga4 overview --property 123456789 --sa ga4-reader@my-project.iam.gserviceaccount.com
```

Full command reference and read-the-numbers guidance live in the two skills
(`skills/gsc/SKILL.md`, `skills/ga4/SKILL.md`) — install the plugin and ask
Claude to check Search Console or GA4 for a property.

## Why one plugin, two scripts

`gsc.mjs` and `ga4.mjs` are two different Google APIs behind the *identical*
keyless-impersonation auth chain — the boilerplate (`lib/google-auth.mjs`) is
shared so a fix or improvement (like the setup ladder or the API-failure
message parsing) lands once, not twice.

They stay **thin fetch layers only** — no product-specific judgment (which
GA4 events matter, which SEO signals are worth acting on) lives here. That
judgment belongs in each consuming project's own skill, layered on top by
calling `ga4`/`gsc` as a bare command (this plugin's `bin/` is on `PATH`
whenever it's enabled) — keeping business-specific reasoning out of a shared,
public plugin.

## What it can't do

**There is no way to request indexing or a recrawl of an ordinary URL via
API.** Search Console's own API has no such method; Google's separate
Indexing API is contractually restricted to `JobPosting`/`BroadcastEvent`
pages. That action stays a manual click in the Search Console UI (URL
Inspection → Request Indexing) — this plugin reads and reports, it doesn't
attempt to script that step.

**There is no API to add a service account as a product-level user** on
either Search Console or GA4 — `setup` provisions everything scriptable and
then names the one manual click by hand.

## Privacy & data

Nothing is stored, and no environment variables are ever read or written.
Every command is a live read (or an explicitly `--commit`-gated write)
straight to Google's API; there is no local cache, no telemetry, no second
destination for the data, and no business-identifying default baked into the
plugin — every property/site/SA identifier comes from the caller's own flags.

## License

MIT — see [LICENSE](../../LICENSE).
