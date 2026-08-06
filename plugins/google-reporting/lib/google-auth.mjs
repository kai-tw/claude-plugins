// lib/google-auth.mjs — shared keyless service-account impersonation helpers
// for Google Cloud Platform read/report scripts (gsc.mjs, ga4.mjs, and future
// siblings).
//
// The auth chain every consumer follows:
//   1. gcloud ADC mints a cloud-platform token (operator's own login, no key file),
//   2. that token calls IAM Credentials `generateAccessToken` to impersonate a
//      purpose-built reader SA, requesting the target scope (no consent screen,
//      no downloaded key),
//   3. the resulting short-lived SA token calls the real API directly.
// Zero npm deps. Needs the Google Cloud SDK with a valid ADC login
// (`gcloud auth application-default login`).
//
// No env vars are read anywhere in this module or its consumers — every
// identifier (SA email, site/property) is a required CLI flag on the calling
// script. That is deliberate: an env var either has to be exported into the
// shell profile (pollutes every future terminal) or re-exported per command
// (no real benefit over a flag) — a flag is the only shape with zero ambient
// state.

import { spawnSync } from "node:child_process";
import https from "node:https";

// ---- factory: bind a namespace (the calling script's own name) to every ----
// helper that needs to name itself in an error message or a hint.
export function makeGoogleAuth(namespace) {
  function fail(msg) {
    console.error(`${namespace}: ${msg}`);
    process.exit(1);
  }

  function adcToken() {
    const r = spawnSync("gcloud", ["auth", "application-default", "print-access-token"], { encoding: "utf8" });
    if (r.error) fail(`could not run gcloud (${r.error.message}). Is the Google Cloud SDK installed and on PATH?`);
    const tok = (r.stdout || "").trim();
    if (!/^ya29\./.test(tok)) {
      fail(`gcloud did not return an ADC token.\n${(r.stderr || "").trim()}\nHint: run  gcloud auth application-default login`);
    }
    return tok;
  }

  async function saToken(adc, saEmail, scope) {
    const url = `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${saEmail}:generateAccessToken`;
    const { status, text } = await httpsJson("POST", url, adc, { scope: [scope] });
    if (status !== 200) {
      fail(
        `impersonating ${saEmail} failed (HTTP ${status}):\n${text}\n` +
          `Hint: your account needs roles/iam.serviceAccountTokenCreator on the SA, and the SA must exist. ` +
          `Run \`${namespace} setup\` to provision it, or grant the role directly.`
      );
    }
    const tok = safeParse(text)?.accessToken;
    if (!tok) fail(`no accessToken in impersonation response:\n${text}`);
    return tok;
  }

  // Turns a failed API call's JSON error body into a specific, actionable
  // message instead of a generic "something went wrong" — branches on the
  // error's actual `reason`/`status` rather than guessing from the HTTP code
  // alone, since 403 covers both "API disabled" and "SA lacks product ACL",
  // which need entirely different fixes.
  function describeApiFailure(status, text, { manualStepHint } = {}) {
    const body = safeParse(text);
    const details = body?.error?.details ?? [];
    const disabled = details.find((d) => d.reason === "SERVICE_DISABLED");
    if (disabled) {
      const api = disabled.metadata?.service;
      return (
        `HTTP ${status} — the API is not enabled on the project.\n` +
        (api
          ? `Fix: gcloud services enable ${api} --project=<project>\n`
          : `Fix: enable the relevant API (see the message below).\n`) +
        `Raw: ${body?.error?.message ?? text}`
      );
    }
    if (body?.error?.status === "PERMISSION_DENIED") {
      return (
        `HTTP ${status} — permission denied.\n` +
        (manualStepHint ||
          "The SA must be granted access inside the product's own permission page (not GCP IAM) — this has no API, it's a manual step.") +
        `\nRaw: ${body?.error?.message ?? text}`
      );
    }
    return `HTTP ${status}: ${body?.error?.message ?? text}`;
  }

  // Runs an ordered list of {label, argv} gcloud invocations. Dry-run by
  // default (prints what it would do); --commit runs each step via spawnSync
  // and stops at the first failure with that step's real stderr — never
  // swallows a bad exit code and keeps going.
  function runSetupLadder(steps, { commit }) {
    if (!commit) {
      console.log(`${namespace} setup — dry run (pass --commit to actually run these):\n`);
      for (const step of steps) console.log(`  [${step.label}]\n    ${step.argv.map(shellQuote).join(" ")}\n`);
      return;
    }
    const who = spawnSync("gcloud", ["config", "get-value", "account"], { encoding: "utf8" });
    if (who.status !== 0 || !(who.stdout || "").trim()) {
      fail("gcloud is not installed or not logged in. Run `gcloud auth login` first, then retry.");
    }
    for (const step of steps) {
      console.log(`→ ${step.label} ...`);
      const r = spawnSync(step.argv[0], step.argv.slice(1), { encoding: "utf8" });
      if (r.status !== 0) {
        fail(`step "${step.label}" failed:\n${(r.stderr || r.stdout || "").trim()}\nCommand: ${step.argv.join(" ")}`);
      }
      console.log(`  ok`);
    }
    console.log(`\n✓ all steps done. See this command's help for the one remaining manual step.`);
  }

  return { fail, adcToken, saToken, describeApiFailure, runSetupLadder, httpsJson, safeParse };
}

// Quotes an argv element for display only (the real spawnSync call below
// never goes through a shell, so this exists purely so a dry-run print is
// safe to copy-paste).
function shellQuote(s) {
  return /[\s"'$`\\]/.test(s) ? `"${s.replace(/(["\\$`])/g, "\\$1")}"` : s;
}

// ---- generic arg parser (shared shape across ga4.mjs / gsc.mjs) -----------
export function parseArgs(argv, extraAlias = {}) {
  const out = { _: [], json: false, commit: false };
  const alias = { d: "days", n: "limit", ...extraAlias };
  for (let i = 0; i < argv.length; i++) {
    let a = argv[i];
    if (a === "--json") { out.json = true; continue; }
    if (a === "--commit") { out.commit = true; continue; }
    if (a.startsWith("-")) {
      let key = a.replace(/^-+/, "");
      let val;
      if (key.includes("=")) [key, val] = key.split(/=(.*)/s);
      key = alias[key] || key;
      if (val === undefined) val = argv[++i];
      out[key] = val;
    } else out._.push(a);
  }
  return out;
}

// ---- minimal HTTPS JSON helper (no deps) -----------------------------------
export function httpsJson(method, urlStr, bearer, bodyObj) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const data = bodyObj != null ? JSON.stringify(bodyObj) : null;
    const headers = { Authorization: `Bearer ${bearer}` };
    if (data) { headers["Content-Type"] = "application/json"; headers["Content-Length"] = Buffer.byteLength(data); }
    const req = https.request({ method, hostname: url.hostname, path: url.pathname + url.search, headers }, (res) => {
      let buf = "";
      res.on("data", (c) => (buf += c));
      res.on("end", () => resolve({ status: res.statusCode, text: buf }));
    });
    req.on("error", reject);
    if (data) req.write(data);
    req.end();
  });
}

export function safeParse(t) {
  try { return JSON.parse(t); } catch { return null; }
}

// The gcloud account currently logged in, or null. Used by each script's
// `setup` command to default --grant-to to "yourself" without requiring it be
// typed for the common case.
export function currentGcloudAccount() {
  const r = spawnSync("gcloud", ["config", "get-value", "account"], { encoding: "utf8" });
  const out = (r.stdout || "").trim();
  return r.status === 0 && out && out !== "(unset)" ? out : null;
}
