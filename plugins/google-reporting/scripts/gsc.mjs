#!/usr/bin/env node
// gsc.mjs — self-contained reader for Google Search Console (Search Console API).
// Auth + error-handling mechanics live in ../lib/google-auth.mjs; see that
// file's header for the impersonation chain. This file owns only the
// Search Console-specific request/response shapes.
//
// One wrinkle GA4 doesn't have: Search Console's resources split across TWO
// hostnames — searchAnalytics/sitemaps/sites live under the legacy
// `webmasters/v3` host, urlInspection lives under the newer `searchconsole/v1`
// host. Same bearer token, same scopes, different base URL per call.
//
// There is NO API to request indexing/recrawl of an ordinary URL. Search
// Console's own API has no such method, and Google's separate Indexing API is
// contractually restricted to JobPosting/BroadcastEvent pages — using it here
// would violate its terms. "Request indexing" stays a manual GSC UI action;
// this script deliberately does not attempt to script it.
//
// Usage:
//   node gsc.mjs check --site <url> --sa <email>
//   node gsc.mjs sites --sa <email>
//   node gsc.mjs performance --site <url> --sa <email> [-d DAYS] [--dimensions a,b] [--page URL] [--query STR] [-n N] [--type web|image|video|news|discover]
//   node gsc.mjs inspect <url> --site <url> --sa <email>
//   node gsc.mjs sitemaps --site <url> --sa <email>
//   node gsc.mjs submit-sitemap <sitemap-url> --site <url> --sa <email> [--commit]
//   node gsc.mjs report <json | @file.json> --site <url> --sa <email>
//   node gsc.mjs setup --project <gcp-project> --sa-name <name> [--grant-to <email>] [--commit]
//
// No env vars are read — --site/--sa (or --project/--sa-name for setup) are
// required flags every time. See lib/google-auth.mjs's header for why.

import { readFileSync } from "node:fs";
import { makeGoogleAuth, parseArgs, currentGcloudAccount } from "../lib/google-auth.mjs";

const NAMESPACE = "gsc";
const SCOPE_READ = "https://www.googleapis.com/auth/webmasters.readonly";
const SCOPE_WRITE = "https://www.googleapis.com/auth/webmasters";
const WEBMASTERS_BASE = "https://www.googleapis.com/webmasters/v3";
const SEARCHCONSOLE_BASE = "https://searchconsole.googleapis.com/v1";

const { fail, adcToken, saToken, describeApiFailure, runSetupLadder, httpsJson, safeParse } = makeGoogleAuth(NAMESPACE);

function requireFlag(args, name, example) {
  const val = args[name];
  if (!val) fail(`--${name} is required. Example: node gsc.mjs <command> --${name} ${example}`);
  return val;
}

// ---- Search Console API calls ----------------------------------------------
async function apiGet(sa, base, path, manualStepHint) {
  const { status, text } = await httpsJson("GET", `${base}${path}`, sa, null);
  if (status !== 200) fail(`GET ${path} failed.\n${describeApiFailure(status, text, { manualStepHint })}`);
  return safeParse(text);
}

async function apiSend(method, sa, base, path, body, manualStepHint) {
  const { status, text } = await httpsJson(method, `${base}${path}`, sa, body ?? {});
  if (status !== 200) fail(`${method} ${path} failed.\n${describeApiFailure(status, text, { manualStepHint })}`);
  return safeParse(text);
}

const NOT_A_USER_HINT =
  "The SA must be added as a User in Search Console → Settings → Users and permissions for the site " +
  "(Restricted is enough for every read command; Full is only needed for submit-sitemap --commit).";

function loadBody(arg) {
  if (!arg) fail("usage: report <json-body | @file.json> --site <url> --sa <email>");
  const raw = arg.startsWith("@") ? readFileSync(arg.slice(1), "utf8") : arg;
  const body = safeParse(raw);
  if (!body) fail("report body is not valid JSON (pass inline JSON or @path/to/body.json).");
  return body;
}

function isoDaysAgo(days) {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - days);
  return d.toISOString().slice(0, 10);
}

// ---- commands ----------------------------------------------------------------
async function main() {
  const args = parseArgs(process.argv.slice(2));
  const cmd = args._[0];
  if (!cmd || cmd === "help" || args.help) return printHelp();

  let out;

  switch (cmd) {
    case "setup": {
      const project = requireFlag(args, "project", "my-gcp-project");
      const saName = args["sa-name"] || "gsc-reader";
      const grantTo = args["grant-to"] || currentGcloudAccount();
      if (!grantTo) fail("--grant-to is required (could not infer your gcloud account — run `gcloud config get-value account`).");
      const saEmail = `${saName}@${project}.iam.gserviceaccount.com`;
      runSetupLadder(
        [
          { label: `create service account ${saName}`, argv: ["gcloud", "iam", "service-accounts", "create", saName, "--project", project, "--display-name", "Search Console reader (impersonated, keyless)"] },
          { label: "enable Search Console API", argv: ["gcloud", "services", "enable", "searchconsole.googleapis.com", "--project", project] },
          { label: `grant ${grantTo} impersonation rights on ${saEmail}`, argv: ["gcloud", "iam", "service-accounts", "add-iam-policy-binding", saEmail, "--member", `user:${grantTo}`, "--role", "roles/iam.serviceAccountTokenCreator", "--project", project] },
        ],
        { commit: args.commit }
      );
      if (args.commit) {
        console.log(
          `\nOne step this script cannot do (no API for it): add ${saEmail} as a User in\n` +
            `Search Console → your property → Settings → Users and permissions → Add user\n` +
            `→ Restricted. Then run \`node gsc.mjs sites --sa ${saEmail}\` to find the exact --site string.`
        );
      }
      return;
    }
    case "check": {
      const sa = await saToken(adcToken(), requireFlag(args, "sa", "gsc-reader@my-project.iam.gserviceaccount.com"), SCOPE_READ);
      const site = args.site;
      const data = await apiGet(sa, WEBMASTERS_BASE, "/sites", NOT_A_USER_HINT);
      const entries = data?.siteEntry ?? [];
      const found = site ? entries.find((e) => e.siteUrl === site) : null;
      out = {
        ok: true, cmd, sa: args.sa,
        visibleSites: entries.length,
        targetSiteVisible: site ? Boolean(found) : "no --site given — see `sites`",
        targetSitePermission: found?.permissionLevel,
      };
      break;
    }
    case "sites": {
      const sa = await saToken(adcToken(), requireFlag(args, "sa", "gsc-reader@my-project.iam.gserviceaccount.com"), SCOPE_READ);
      const data = await apiGet(sa, WEBMASTERS_BASE, "/sites", NOT_A_USER_HINT);
      out = { ok: true, cmd, sites: (data?.siteEntry ?? []).map((e) => ({ siteUrl: e.siteUrl, permissionLevel: e.permissionLevel })) };
      break;
    }
    case "performance": {
      const site = requireFlag(args, "site", "https://example.com/");
      const sa = await saToken(adcToken(), requireFlag(args, "sa", "gsc-reader@my-project.iam.gserviceaccount.com"), SCOPE_READ);
      const days = Number(args.days ?? 28);
      if (!Number.isFinite(days) || days <= 0) fail("--days must be a positive integer.");
      const dimensions = (args.dimensions ? String(args.dimensions) : "page,query").split(",").map((s) => s.trim()).filter(Boolean);
      const limit = Number(args.limit ?? 25);
      const filters = [];
      if (args.page) filters.push({ dimension: "page", operator: "equals", expression: args.page });
      if (args.query) filters.push({ dimension: "query", operator: "contains", expression: args.query });
      const body = {
        startDate: isoDaysAgo(days),
        endDate: isoDaysAgo(0),
        dimensions,
        type: args.type || "web",
        rowLimit: String(limit),
        ...(filters.length ? { dimensionFilterGroups: [{ groupType: "and", filters }] } : {}),
      };
      const data = await apiSend("POST", sa, WEBMASTERS_BASE, `/sites/${encodeURIComponent(site)}/searchAnalytics/query`, body, NOT_A_USER_HINT);
      out = { ok: true, cmd, site, days, dimensions, rows: data?.rows ?? [] };
      break;
    }
    case "inspect": {
      const site = requireFlag(args, "site", "https://example.com/");
      const inspectionUrl = args._[1];
      if (!inspectionUrl) fail("usage: inspect <url> --site <url> --sa <email>");
      const sa = await saToken(adcToken(), requireFlag(args, "sa", "gsc-reader@my-project.iam.gserviceaccount.com"), SCOPE_READ);
      const data = await apiSend("POST", sa, SEARCHCONSOLE_BASE, "/urlInspection/index:inspect", { inspectionUrl, siteUrl: site }, NOT_A_USER_HINT);
      out = { ok: true, cmd, site, inspectionUrl, result: data?.inspectionResult ?? data };
      break;
    }
    case "sitemaps": {
      const site = requireFlag(args, "site", "https://example.com/");
      const sa = await saToken(adcToken(), requireFlag(args, "sa", "gsc-reader@my-project.iam.gserviceaccount.com"), SCOPE_READ);
      const data = await apiGet(sa, WEBMASTERS_BASE, `/sites/${encodeURIComponent(site)}/sitemaps`, NOT_A_USER_HINT);
      out = { ok: true, cmd, site, sitemaps: data?.sitemap ?? [] };
      break;
    }
    case "submit-sitemap": {
      const site = requireFlag(args, "site", "https://example.com/");
      const feedpath = args._[1];
      if (!feedpath) fail("usage: submit-sitemap <sitemap-url> --site <url> --sa <email> [--commit]");
      requireFlag(args, "sa", "gsc-reader@my-project.iam.gserviceaccount.com");
      if (!args.commit) {
        out = {
          ok: true, cmd, dryRun: true, wouldSubmit: feedpath, site,
          note: "pass --commit to actually submit (needs Full permission on the SA's Search Console user, not just Restricted)",
        };
        break;
      }
      const sa = await saToken(adcToken(), args.sa, SCOPE_WRITE);
      await apiSend("PUT", sa, WEBMASTERS_BASE, `/sites/${encodeURIComponent(site)}/sitemaps/${encodeURIComponent(feedpath)}`, null, NOT_A_USER_HINT);
      out = { ok: true, cmd, committed: true, submitted: feedpath, site };
      break;
    }
    case "report": {
      const site = requireFlag(args, "site", "https://example.com/");
      const sa = await saToken(adcToken(), requireFlag(args, "sa", "gsc-reader@my-project.iam.gserviceaccount.com"), SCOPE_READ);
      const data = await apiSend("POST", sa, WEBMASTERS_BASE, `/sites/${encodeURIComponent(site)}/searchAnalytics/query`, loadBody(args._[1]), NOT_A_USER_HINT);
      out = { ok: true, cmd, site, data };
      break;
    }
    default:
      fail(`unknown command '${cmd}'. Try: setup | check | sites | performance | inspect <url> | sitemaps | submit-sitemap <url> | report <json|@file> | help`);
  }

  process.stdout.write(JSON.stringify(out, null, 2) + "\n");
}

function printHelp() {
  console.log(`gsc.mjs — read Google Search Console for a verified site

Auth: keyless SA impersonation — gcloud ADC token → generateAccessToken(<sa>,
webmasters[.readonly]) → Search Console API. No key file, no Python, no
node_modules, no env vars — every identifier is a required flag.

Commands:
  setup --project <gcp-project> [--sa-name gsc-reader] [--grant-to <email>] [--commit]
                                   provision the reader SA (dry-run by default)
  check --site <url> --sa <email>
                                   verify the auth chain reaches the account
  sites --sa <email>              list visible properties + exact siteUrl + permission level
  performance --site <url> --sa <email> [-d DAYS] [--dimensions page,query] [--page URL] [--query STR] [-n N] [--type web|image|video|news|discover]
                                   clicks / impressions / ctr / position
  inspect <url> --site <url> --sa <email>
                                   indexing status for one URL (verdict, coverage, last crawl, canonical)
  sitemaps --site <url> --sa <email>
                                   list submitted sitemaps + status/errors/warnings
  submit-sitemap <url> --site <url> --sa <email> [--commit]
                                   submit/resubmit a sitemap (write — dry-run by default, needs Full permission)
  report <json | @file.json> --site <url> --sa <email>
                                   raw searchAnalytics.query passthrough

There is NO command to request indexing/recrawl of a URL — no such API exists
for ordinary content (see the plugin's SKILL.md). That stays a manual click in
the Search Console UI (URL Inspection → Request Indexing).

Examples:
  node gsc.mjs setup --project my-project
  node gsc.mjs check --site https://example.com/ --sa gsc-reader@my-project.iam.gserviceaccount.com
  node gsc.mjs sites --sa gsc-reader@my-project.iam.gserviceaccount.com
  node gsc.mjs performance --site https://example.com/ --sa gsc-reader@my-project.iam.gserviceaccount.com -d 28
  node gsc.mjs inspect https://example.com/blog/post --site https://example.com/ --sa gsc-reader@my-project.iam.gserviceaccount.com

Output is JSON (the fetch layer); reading it as SEO signal is the skill's job.`);
}

main().catch((e) => fail(e?.message || String(e)));
