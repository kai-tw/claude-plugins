#!/usr/bin/env node
// ga4.mjs — self-contained reader for Google Analytics 4 (GA4 Data API).
// Auth + error-handling mechanics live in ../lib/google-auth.mjs; see that
// file's header for the impersonation chain. This file owns only the GA4
// Data API's request/response shapes.
//
// GA4's `analytics.readonly` is a Google *sensitive* scope, so gcloud's shared
// OAuth client is barred from requesting it (the interactive user path is
// blocked) — keyless SA impersonation is required, not just convenient.
//
// It is a thin, reliable FETCH layer: it mints the token and runs reports.
// Deciding which reports matter, reading the numbers as roadmap signal, and
// filing candidates is a consuming project's judgment (see e.g. a
// project-local `ga-triage` skill), never this script's.
//
// Usage:
//   node ga4.mjs check   --property <id> --sa <email>
//   node ga4.mjs overview --property <id> --sa <email> [-d 7,28,90]
//   node ga4.mjs events   --property <id> --sa <email> [-d DAYS] [-n LIMIT]
//   node ga4.mjs report   --property <id> --sa <email> <json | @file.json>
//   node ga4.mjs setup --project <gcp-project> [--sa-name ga4-reader] [--grant-to <email>] [--commit]
//
// No env vars are read — --property/--sa (or --project/--sa-name for setup)
// are required flags every time. See lib/google-auth.mjs's header for why.

import { readFileSync } from "node:fs";
import { makeGoogleAuth, parseArgs, currentGcloudAccount } from "../lib/google-auth.mjs";

const NAMESPACE = "ga4";
const SCOPE = "https://www.googleapis.com/auth/analytics.readonly";
const OVERVIEW_METRICS = ["activeUsers", "newUsers", "sessions", "engagedSessions", "engagementRate", "screenPageViews", "eventCount"];

const { fail, adcToken, saToken, describeApiFailure, runSetupLadder, httpsJson, safeParse } = makeGoogleAuth(NAMESPACE);

function requireFlag(args, name, example) {
  const val = args[name];
  if (!val) fail(`--${name} is required. Example: node ga4.mjs <command> --${name} ${example}`);
  return val;
}

const NOT_A_VIEWER_HINT =
  "The SA must be a Viewer on the GA4 property (GA4 Admin → Property Access Management) — " +
  "this has no API, it's a manual step. Also confirm the Analytics Data API is enabled on the project.";

async function runReport(sa, propertyId, body) {
  const url = `https://analyticsdata.googleapis.com/v1beta/properties/${propertyId}:runReport`;
  const { status, text } = await httpsJson("POST", url, sa, body);
  if (status !== 200) fail(`GA4 runReport failed.\n${describeApiFailure(status, text, { manualStepHint: NOT_A_VIEWER_HINT })}`);
  return safeParse(text);
}

function loadBody(arg) {
  if (!arg) fail("usage: report <json-body | @file.json> --property <id> --sa <email>");
  const raw = arg.startsWith("@") ? readFileSync(arg.slice(1), "utf8") : arg;
  const body = safeParse(raw);
  if (!body) fail("report body is not valid JSON (pass inline JSON or @path/to/body.json).");
  return body;
}

// ---- commands --------------------------------------------------------------
async function main() {
  const args = parseArgs(process.argv.slice(2));
  const cmd = args._[0];
  if (!cmd || cmd === "help" || args.help) return printHelp();

  if (cmd === "setup") {
    const project = requireFlag(args, "project", "my-gcp-project");
    const saName = args["sa-name"] || "ga4-reader";
    const grantTo = args["grant-to"] || currentGcloudAccount();
    if (!grantTo) fail("--grant-to is required (could not infer your gcloud account — run `gcloud config get-value account`).");
    const saEmail = `${saName}@${project}.iam.gserviceaccount.com`;
    runSetupLadder(
      [
        { label: `create service account ${saName}`, argv: ["gcloud", "iam", "service-accounts", "create", saName, "--project", project, "--display-name", "GA4 Data API reader (impersonated, keyless)"] },
        { label: "enable Analytics Data API", argv: ["gcloud", "services", "enable", "analyticsdata.googleapis.com", "--project", project] },
        { label: `grant ${grantTo} impersonation rights on ${saEmail}`, argv: ["gcloud", "iam", "service-accounts", "add-iam-policy-binding", saEmail, "--member", `user:${grantTo}`, "--role", "roles/iam.serviceAccountTokenCreator", "--project", project] },
      ],
      { commit: args.commit }
    );
    if (args.commit) {
      console.log(
        `\nOne step this script cannot do (no API for it): add ${saEmail} as a Viewer on the\n` +
          `GA4 property — Admin → Property Access Management → Add users → Restricted (or\n` +
          `Viewer role, whichever your console labels it).\n` +
          `Then run \`node ga4.mjs check --property <id> --sa ${saEmail}\` to confirm.`
      );
    }
    return;
  }

  const propertyId = requireFlag(args, "property", "123456789");
  const sa = await saToken(adcToken(), requireFlag(args, "sa", "ga4-reader@my-project.iam.gserviceaccount.com"), SCOPE);
  let out;

  switch (cmd) {
    case "check": {
      const data = await runReport(sa, propertyId, { dateRanges: [{ startDate: "28daysAgo", endDate: "today" }], metrics: [{ name: "activeUsers" }] });
      const wau = data?.rows?.[0]?.metricValues?.[0]?.value ?? "0";
      out = { ok: true, cmd, property: propertyId, sa: args.sa, note: `auth chain reaches the property — 28d activeUsers=${wau}` };
      break;
    }
    case "overview": {
      const windows = (args.days ? String(args.days).split(",") : ["7", "28", "90"]).map((s) => Number(s.trim())).filter((n) => Number.isFinite(n) && n > 0);
      if (!windows.length) fail("--days must be positive integers, comma-separated (e.g. 7,28,90).");
      const body = {
        dateRanges: windows.map((w) => ({ startDate: `${w}daysAgo`, endDate: "today", name: `${w}d` })),
        metrics: OVERVIEW_METRICS.map((name) => ({ name })),
      };
      out = { ok: true, cmd, property: propertyId, windows, data: await runReport(sa, propertyId, body) };
      break;
    }
    case "events": {
      const days = Number(args.days ?? 28);
      const limit = Number(args.limit ?? 25);
      if (!Number.isFinite(days) || days <= 0) fail("--days must be a positive integer.");
      const body = {
        dateRanges: [{ startDate: `${days}daysAgo`, endDate: "today" }],
        dimensions: [{ name: "eventName" }],
        metrics: [{ name: "eventCount" }, { name: "totalUsers" }],
        orderBys: [{ metric: { metricName: "eventCount" }, desc: true }],
        limit: String(limit),
      };
      out = { ok: true, cmd, property: propertyId, days, data: await runReport(sa, propertyId, body) };
      break;
    }
    case "report": {
      out = { ok: true, cmd, property: propertyId, data: await runReport(sa, propertyId, loadBody(args._[1])) };
      break;
    }
    default:
      fail(`unknown command '${cmd}'. Try: setup | check | overview | events | report <json|@file> | help`);
  }

  process.stdout.write(JSON.stringify(out, null, 2) + "\n");
}

function printHelp() {
  console.log(`ga4.mjs — read Google Analytics 4 for a GA4 property

Auth: keyless SA impersonation — gcloud ADC token → generateAccessToken(<sa>,
analytics.readonly) → GA4 Data API. No key file, no Python, no node_modules,
no env vars — every identifier is a required flag.

Commands:
  setup --project <gcp-project> [--sa-name ga4-reader] [--grant-to <email>] [--commit]
                                 provision the reader SA (dry-run by default)
  check   --property <id> --sa <email>
                                 verify the auth chain reaches the property
  overview --property <id> --sa <email> [-d 7,28,90]
                                 activeUsers / newUsers / sessions / engagement / views / events, per window
  events  --property <id> --sa <email> [-d DAYS] [-n N]
                                 top events by count (feature adoption) — default 28d, 25 rows
  report  --property <id> --sa <email> <json | @file.json>
                                 raw GA4 runReport passthrough (any metrics/dimensions/cohortSpec)

Examples:
  node ga4.mjs setup --project my-project
  node ga4.mjs check --property 123456789 --sa ga4-reader@my-project.iam.gserviceaccount.com
  node ga4.mjs overview --property 123456789 --sa ga4-reader@my-project.iam.gserviceaccount.com
  node ga4.mjs events --property 123456789 --sa ga4-reader@my-project.iam.gserviceaccount.com -d 90 -n 40

Output is JSON (the fetch layer); reading it as roadmap signal is a consuming
skill's job — see e.g. a project-local "ga-triage"-style skill.`);
}

main().catch((e) => fail(e?.message || String(e)));
