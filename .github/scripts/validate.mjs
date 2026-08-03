#!/usr/bin/env node
// Repo-level checks that `claude plugin validate` does not perform.
//
// It validates one manifest at a time against the schema, and it does catch a
// dangling `skills[]` path. It does NOT catch: a marketplace `source` pointing
// at a directory that does not exist, a marketplace entry whose name disagrees
// with the plugin's own, a skill shipped without the description that is its
// only trigger, or an absolute machine path baked into a manifest.
//
// Pure Node, no dependencies. Run locally with:  node .github/scripts/validate.mjs

import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const errors = [];
const fail = (where, msg) => errors.push(`${where}: ${msg}`);

const readJson = (path, where) => {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (e) {
    fail(where, `unreadable or invalid JSON — ${e.message}`);
    return null;
  }
};

// Frontmatter parser for simple `key: value` scalars, which is all a SKILL.md
// header uses. Values may be quoted; anything else is left verbatim.
const frontmatter = (text) => {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!m) return null;
  const out = {};
  for (const line of m[1].split(/\r?\n/)) {
    const kv = line.match(/^([A-Za-z_][\w-]*):\s*(.*)$/);
    if (kv) out[kv[1]] = kv[2].trim().replace(/^(['"])(.*)\1$/, '$2');
  }
  return out;
};

// ---------------------------------------------------------------- marketplace

const marketplacePath = join(root, '.claude-plugin/marketplace.json');
if (!existsSync(marketplacePath)) {
  fail('.claude-plugin/marketplace.json', 'missing');
  report();
}
const marketplace = readJson(marketplacePath, '.claude-plugin/marketplace.json');
if (!marketplace) report();

const entries = Array.isArray(marketplace.plugins) ? marketplace.plugins : [];
if (entries.length === 0) fail('marketplace.json', 'declares no plugins');

const declared = new Set();

for (const entry of entries) {
  const where = `marketplace.json › ${entry.name ?? '(unnamed)'}`;
  if (!entry.name) {
    fail(where, 'entry has no name');
    continue;
  }
  declared.add(entry.name);

  if (typeof entry.source !== 'string') {
    fail(where, 'entry has no string `source`');
    continue;
  }

  // GAP 1 — validate passes a source that points nowhere.
  const dir = resolve(root, entry.source);
  if (!existsSync(dir) || !statSync(dir).isDirectory()) {
    fail(where, `source "${entry.source}" does not exist — nobody can install this plugin`);
    continue;
  }

  const manifestPath = join(dir, '.claude-plugin/plugin.json');
  if (!existsSync(manifestPath)) {
    fail(where, `source "${entry.source}" has no .claude-plugin/plugin.json`);
    continue;
  }

  const plugin = readJson(manifestPath, `${entry.source}/.claude-plugin/plugin.json`);
  if (!plugin) continue;

  // GAP 2 — validate passes a name disagreement; the install then resolves to
  // a plugin calling itself something else.
  if (plugin.name !== entry.name) {
    fail(where, `name disagrees with its plugin.json ("${entry.name}" vs "${plugin.name}")`);
  }

  checkSkills(plugin, dir, entry.source);
}

// -------------------------------------------------------------- orphan check

const pluginsDir = join(root, 'plugins');
if (existsSync(pluginsDir)) {
  for (const name of readdirSync(pluginsDir)) {
    const dir = join(pluginsDir, name);
    if (!statSync(dir).isDirectory()) continue;
    const manifestPath = join(dir, '.claude-plugin/plugin.json');
    if (!existsSync(manifestPath)) continue;
    const plugin = readJson(manifestPath, `plugins/${name}`);
    if (plugin && !declared.has(plugin.name)) {
      fail(`plugins/${name}`, `not listed in marketplace.json — it ships but is invisible`);
    }
  }
}

// -------------------------------------------------------------------- skills

function checkSkills(plugin, dir, source) {
  for (const rel of plugin.skills ?? []) {
    const skillDir = resolve(dir, rel);
    const skillFile = join(skillDir, 'SKILL.md');
    const where = `${source} › ${rel}`;

    // `claude plugin validate` already fails on a missing path; this catches the
    // case where the directory exists but carries no SKILL.md.
    if (!existsSync(skillFile)) {
      fail(where, 'has no SKILL.md');
      continue;
    }

    const fm = frontmatter(readFileSync(skillFile, 'utf8'));
    if (!fm) {
      fail(where, 'SKILL.md has no YAML frontmatter');
      continue;
    }
    if (!fm.name) fail(where, 'SKILL.md frontmatter has no `name`');

    // GAP 3 — validate only warns. A skill without a description never
    // triggers, so it costs context tokens every session and does nothing.
    if (!fm.description) {
      fail(where, 'SKILL.md has no `description` — it can never trigger, yet still costs tokens');
    }
  }
}

// ------------------------------------------------ absolute paths in manifests

const manifestFiles = [marketplacePath];
for (const entry of entries) {
  const p = join(resolve(root, entry.source ?? ''), '.claude-plugin/plugin.json');
  if (existsSync(p)) manifestFiles.push(p);
}

// GAP 4 — a machine-specific path is valid JSON and a valid string, so nothing
// upstream objects; it just fails on every machine that is not the author's.
for (const path of manifestFiles) {
  const text = readFileSync(path, 'utf8');
  const hit = text.match(/(\/Users\/[^"\s]+|\/home\/[^"\s]+|[A-Za-z]:\\\\[^"\s]+)/);
  if (hit) {
    fail(path.slice(root.length + 1), `contains an absolute machine path (${hit[1]}) — it will not resolve for anyone else`);
  }
}

// ------------------------------------------------------- README install docs

const readmePath = join(root, 'README.md');
if (existsSync(readmePath)) {
  const readme = readFileSync(readmePath, 'utf8');

  for (const [, pluginName, mkt] of readme.matchAll(/plugin install\s+(\S+)@(\S+)/g)) {
    if (mkt !== marketplace.name) {
      fail('README.md', `documents "@${mkt}" but the marketplace is named "${marketplace.name}"`);
    }
    if (!declared.has(pluginName)) {
      fail('README.md', `documents installing "${pluginName}", which no marketplace entry declares`);
    }
  }
}

report();

function report() {
  if (errors.length === 0) {
    console.log('✔ repo checks passed');
    process.exit(0);
  }
  console.error(`✘ ${errors.length} problem(s):\n`);
  for (const e of errors) console.error(`  • ${e}`);
  process.exit(1);
}
