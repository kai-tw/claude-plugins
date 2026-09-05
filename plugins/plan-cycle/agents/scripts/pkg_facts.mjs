#!/usr/bin/env node
// pub.dev fact sheet — the deterministic half of a package decision.
//
// WHY THIS EXISTS. `package-explorer` used to read every one of these facts off
// a rendered pub.dev page and restate it in prose. Six of its ten Phase-3 rows
// and both Phase-2 filter thresholds are exact fields in pub.dev's JSON API, so
// restating them was asking a model to be a worse HTTP client. This is the same
// move `tool/version_diff.sh` makes for the migration criterion: a real command,
// so the output is INSPECTABLE and the author and the reviewer resolve the same
// surface instead of each deriving their own.
//
// What stays judgment, deliberately NOT here: whether the package satisfies the
// design contract (that needs reading its source), API ergonomics, whether the
// repo is archived, and whether the README says "experimental". This tool
// settles the facts; `package-explorer` still has to think.
//
// Usage:
//   pkg-facts show <name>[@<version>] [--require ios,android] [--stale-months N]
//   pkg-facts search <query> [--limit N] [--stale-months N]
//   pkg-facts installed [<name>] [--project <dir>]
//   (any) [--json] [--no-cache]
//
// Exit: 0 = facts printed, 1 = lookup failed (network, 404, no lockfile),
//       2 = bad usage. A failure is LOUD: this never prints a partial sheet
//       that reads like a verified one.

import { readFileSync, existsSync, mkdirSync, writeFileSync, statSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { tmpdir } from 'node:os';

const API = 'https://pub.dev/api';
const CACHE_DIR = join(tmpdir(), 'pkg-facts-cache');
const CACHE_TTL_MS = 6 * 60 * 60 * 1000; // 6h — pub.dev metadata is not fast-moving

// Copyleft / commercial licences the caller is told to flag. `license:` tags
// come from pub.dev's own scoring, so this list matches what it actually emits.
const COPYLEFT = ['gpl', 'agpl', 'lgpl', 'gpl-2.0', 'gpl-3.0', 'agpl-3.0', 'lgpl-3.0'];

function die(msg, code = 1) {
  console.error(`pkg-facts: ${msg}`);
  process.exit(code);
}

function usage() {
  console.error(`usage:
  pkg-facts show <name>[@<version>] [--require <platforms>] [--stale-months N]
  pkg-facts search <query> [--limit N] [--stale-months N]
  pkg-facts installed [<name>] [--project <dir>]
options: --json  --no-cache`);
  process.exit(2);
}

// ── args ─────────────────────────────────────────────────────────────────────
const argv = process.argv.slice(2);
if (argv.length === 0) usage();

const cmd = argv[0];
const positional = [];
const opt = { json: false, cache: true, limit: 5, staleMonths: null, require: [], project: null };

for (let i = 1; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--json') opt.json = true;
  else if (a === '--no-cache') opt.cache = false;
  else if (a === '--limit') opt.limit = parseInt(argv[++i], 10);
  else if (a === '--stale-months') opt.staleMonths = parseInt(argv[++i], 10);
  else if (a === '--require') opt.require = (argv[++i] || '').split(',').map(s => s.trim()).filter(Boolean);
  else if (a === '--project') opt.project = argv[++i];
  else if (a.startsWith('-')) die(`unknown option "${a}"`, 2);
  else positional.push(a);
}
if (Number.isNaN(opt.limit) || opt.limit < 1) die('--limit takes a positive integer', 2);

// ── fetch, with a cache so a cycle does not hammer pub.dev ───────────────────
if (typeof fetch !== 'function') {
  die('this node has no global fetch (needs node >= 18) — install a newer node or run the lookup by hand');
}

async function getJSON(path) {
  const key = path.replace(/[^A-Za-z0-9]+/g, '_');
  const file = join(CACHE_DIR, `${key}.json`);
  if (opt.cache && existsSync(file) && Date.now() - statSync(file).mtimeMs < CACHE_TTL_MS) {
    try { return JSON.parse(readFileSync(file, 'utf8')); } catch { /* fall through to refetch */ }
  }
  let res;
  try {
    res = await fetch(`${API}${path}`, { headers: { accept: 'application/json' } });
  } catch (e) {
    // Loud, not silent: a plan citing "checked, looks fine" on a failed fetch is
    // exactly the false-confidence this tool exists to remove.
    die(`could not reach pub.dev (${e.message}). NOT a verdict — the lookup did not happen.`);
  }
  if (res.status === 404) return null;
  if (!res.ok) die(`pub.dev returned HTTP ${res.status} for ${path} — the lookup did not happen.`);
  const body = await res.json();
  if (opt.cache) {
    try { mkdirSync(CACHE_DIR, { recursive: true }); writeFileSync(file, JSON.stringify(body)); } catch { /* cache is best-effort */ }
  }
  return body;
}

// ── fact extraction ──────────────────────────────────────────────────────────
function monthsSince(iso) {
  if (!iso) return null;
  const then = new Date(iso);
  if (Number.isNaN(then.getTime())) return null;
  return Math.floor((Date.now() - then.getTime()) / (1000 * 60 * 60 * 24 * 30.44));
}

function tagValues(tags, prefix) {
  return (tags || []).filter(t => t.startsWith(`${prefix}:`)).map(t => t.slice(prefix.length + 1));
}

async function facts(name) {
  const [pkg, score] = await Promise.all([
    getJSON(`/packages/${encodeURIComponent(name)}`),
    getJSON(`/packages/${encodeURIComponent(name)}/score`),
  ]);
  if (!pkg) return null;

  const latest = pkg.latest || {};
  const spec = latest.pubspec || {};
  const tags = (score && score.tags) || [];
  const licenses = tagValues(tags, 'license');
  const age = monthsSince(latest.published);
  const staleAt = opt.staleMonths ?? (cmd === 'search' ? 18 : 12);

  const flags = [];
  if (age !== null && age > staleAt) flags.push(`STALE (${age}mo > ${staleAt}mo)`);
  if (score && score.grantedPoints < 60) flags.push(`LOW-POINTS (${score.grantedPoints}/${score.maxPoints})`);
  if (licenses.some(l => COPYLEFT.includes(l))) flags.push(`LICENSE-COPYLEFT (${licenses.join(', ')})`);
  else if (licenses.length && !licenses.includes('osi-approved')) flags.push(`LICENSE-NOT-OSI (${licenses.join(', ')})`);
  if (!licenses.length) flags.push('LICENSE-UNKNOWN (no license tag)');
  if (!tags.includes('is:dart3-compatible')) flags.push('NOT-DART3');
  const platforms = tagValues(tags, 'platform');
  const missing = opt.require.filter(p => !platforms.includes(p));
  if (missing.length) flags.push(`PLATFORM-MISSING (${missing.join(', ')})`);

  return {
    name: pkg.name,
    version: latest.version ?? null,
    published: latest.published ?? null,
    age_months: age,
    sdk: (spec.environment && spec.environment.sdk) ?? null,
    flutter: (spec.environment && spec.environment.flutter) ?? null,
    dependencies: spec.dependencies ? Object.keys(spec.dependencies).sort() : [],
    dependency_constraints: spec.dependencies ?? {},
    repository: spec.repository ?? spec.homepage ?? null,
    issue_tracker: spec.issue_tracker ?? null,
    granted_points: score ? score.grantedPoints : null,
    max_points: score ? score.maxPoints : null,
    likes: score ? score.likeCount : null,
    downloads_30d: score ? score.downloadCount30Days : null,
    platforms,
    licenses,
    dart3: tags.includes('is:dart3-compatible'),
    null_safe: tags.includes('is:null-safe'),
    flags,
  };
}

function printFacts(f) {
  console.log(`## ${f.name} @ ${f.version}   (pub.dev API — re-runnable: pkg-facts show ${f.name})`);
  console.log(`  version           ${f.version}`);
  console.log(`  published         ${f.published}  (${f.age_months} months ago)`);
  console.log(`  sdk               ${f.sdk ?? '—'}${f.flutter ? `   flutter ${f.flutter}` : ''}`);
  console.log(`  pub points        ${f.granted_points ?? '—'}/${f.max_points ?? '—'}   likes ${f.likes ?? '—'}   30d downloads ${f.downloads_30d ?? '—'}`);
  console.log(`  platforms         ${f.platforms.length ? f.platforms.join(', ') : '—'}`);
  console.log(`  license           ${f.licenses.length ? f.licenses.join(', ') : '—'}`);
  console.log(`  dart3 / null-safe ${f.dart3 ? 'yes' : 'NO'} / ${f.null_safe ? 'yes' : 'NO'}`);
  console.log(`  direct deps       ${f.dependencies.length ? f.dependencies.join(', ') : '(none)'}`);
  console.log(`  repo              ${f.repository ?? '—'}`);
  console.log(f.flags.length ? `  FLAGS             ${f.flags.join(' · ')}` : '  FLAGS             none');
  console.log('');
  console.log('  NOT settled here (still yours): does it satisfy the contract clause (read the');
  console.log('  source), API ergonomics, is the repo archived, does the README say experimental.');
}

// ── pubspec.lock — the corpus pub.dev cannot answer for ──────────────────────
// "Do we already depend on something that does this" is criterion 10's question
// in package form, and it had no tooling at all — the cheaper half to get wrong,
// because a redundant dependency arrives looking like ordinary work.
function findLockfile(startDir) {
  let dir = resolve(startDir);
  for (;;) {
    const candidate = join(dir, 'pubspec.lock');
    if (existsSync(candidate)) return candidate;
    const parent = dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

// pub writes this file, so the shape is fixed: two-space indent under
// `packages:`, one block per package. Parsed line-wise rather than with a YAML
// dependency — but only the three fields below are read, and a shape change
// shows up as "0 packages", which is reported rather than passed off as "none".
function parseLock(path) {
  const lines = readFileSync(path, 'utf8').split('\n');
  const out = [];
  let inPackages = false;
  let current = null;
  for (const line of lines) {
    if (/^[A-Za-z_]/.test(line)) { inPackages = line.startsWith('packages:'); current = null; continue; }
    if (!inPackages) continue;
    const pkg = line.match(/^ {2}([A-Za-z0-9_]+):\s*$/);
    if (pkg) { current = { name: pkg[1], dependency: null, version: null, source: null }; out.push(current); continue; }
    if (!current) continue;
    const dep = line.match(/^ {4}dependency:\s*"?([^"]+)"?\s*$/);
    if (dep) { current.dependency = dep[1]; continue; }
    const ver = line.match(/^ {4}version:\s*"?([^"]+)"?\s*$/);
    if (ver) { current.version = ver[1]; continue; }
    const src = line.match(/^ {4}source:\s*"?([^"]+)"?\s*$/);
    if (src) current.source = src[1];
  }
  return out;
}

// ── commands ─────────────────────────────────────────────────────────────────
async function cmdShow() {
  const arg = positional[0];
  if (!arg) usage();
  const name = arg.split('@')[0];
  const f = await facts(name);
  if (!f) die(`no such package on pub.dev: ${name}`);
  if (opt.json) console.log(JSON.stringify(f, null, 2));
  else printFacts(f);
}

async function cmdSearch() {
  const q = positional.join(' ');
  if (!q) usage();
  const res = await getJSON(`/search?q=${encodeURIComponent(q)}`);
  const names = ((res && res.packages) || []).slice(0, opt.limit).map(p => p.package);
  if (!names.length) {
    console.log(`no pub.dev results for "${q}" — that is a result, not an error: nothing matched.`);
    return;
  }
  const all = [];
  for (const n of names) {
    const f = await facts(n);
    if (f) all.push(f);
  }
  if (opt.json) { console.log(JSON.stringify(all, null, 2)); return; }

  console.log(`## pub.dev search "${q}" — top ${all.length}   (re-runnable: pkg-facts search "${q}")`);
  console.log('');
  console.log('| package | version | age | points | likes | platforms | license | flags |');
  console.log('|---|---|---|---|---|---|---|---|');
  for (const f of all) {
    console.log(`| ${f.name} | ${f.version} | ${f.age_months}mo | ${f.granted_points}/${f.max_points} | ${f.likes} | ${f.platforms.join(' ') || '—'} | ${f.licenses.join(' ') || '—'} | ${f.flags.length ? f.flags.join(' · ') : '—'} |`);
  }
  console.log('');
  console.log('Flags are computed, not judged. A flagged row is not automatically out, and an');
  console.log('unflagged row is NOT a recommendation — the contract check is still unread.');
}

function cmdInstalled() {
  const lock = findLockfile(opt.project || process.cwd());
  if (!lock) die(`no pubspec.lock found from ${opt.project || process.cwd()} upward — cannot answer "do we already depend on this".`);
  const pkgs = parseLock(lock);
  if (!pkgs.length) die(`parsed 0 packages out of ${lock} — the lockfile shape is not what this expects. Treat the reuse question as UNANSWERED, not as "no".`);

  const wanted = positional[0];
  if (wanted) {
    const hit = pkgs.find(p => p.name === wanted);
    if (opt.json) { console.log(JSON.stringify(hit ?? null, null, 2)); return; }
    console.log(`## ${wanted} in ${lock}`);
    if (hit) console.log(`  ALREADY A DEPENDENCY — ${hit.version} (${hit.dependency}, source ${hit.source})`);
    else console.log('  not in the resolved dependency set');
    return;
  }

  const direct = pkgs.filter(p => (p.dependency || '').startsWith('direct main'));
  const dev = pkgs.filter(p => (p.dependency || '').startsWith('direct dev'));
  if (opt.json) { console.log(JSON.stringify({ lockfile: lock, direct, dev, total: pkgs.length }, null, 2)); return; }
  console.log(`## resolved dependencies — ${lock}`);
  console.log(`  ${pkgs.length} packages total · ${direct.length} direct · ${dev.length} dev\n`);
  console.log('  direct:');
  for (const p of direct) console.log(`    ${p.name} ${p.version}`);
  console.log('\n  Before adding anything: the capability may already sit in one of these, and a');
  console.log('  second package covering it is the reuse defect criterion 10 exists to catch.');
}

const run = { show: cmdShow, search: cmdSearch, installed: cmdInstalled }[cmd];
if (!run) usage();
await run();
