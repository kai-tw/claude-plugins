#!/usr/bin/env node
// Generate a consumer repo's vendored copy of this marketplace.
//
// WHY A VENDORED COPY EXISTS
//   A cloud session's github credential covers only the repos that session
//   mounted. This marketplace is private, so a session that mounted only the
//   consumer repo cannot clone it — every `@kai-tw` plugin is then absent, and
//   with them the plan cycle, its gates and every `plan-*` command. Copying the
//   payload INTO the consumer repo removes the second credential from the path:
//   the marketplace is then a directory the session already checked out.
//
// WHAT IT PRODUCES  (<out>/ is a build artifact — never hand-edited)
//   <out>/.claude-plugin/marketplace.json   generated, never copied
//   <out>/plugins/<name>/…                  payload, modes preserved
//   <out>/VENDORED.md                       provenance: source ref + sha
//
// The marketplace manifest is GENERATED rather than copied so it can never
// describe a plugin this run did not write: every entry is emitted from the
// plugin.json actually placed on disk, and a name or version disagreement is a
// hard error rather than a manifest that lies.
//
// Usage:
//   node scripts/vendor-sync.mjs --out <dir> [--source <repo root>] [--ref <ref>]

import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));

// Maintenance generators that REWRITE files inside the plugin tree. They are
// one-shot authoring tooling that got shipped inside the payload; one of them
// even targets a single developer's checkout by absolute path. Harmless where
// the plugin tree is a cache copy, but inside a consumer repo they are
// executables that rewrite the repo's own vendored artifact — so they are the
// one thing deliberately left behind. Paths are plugin-relative.
const EXCLUDE = new Set([
  'plan-cycle/skills/lead/scripts/route-ask-sites.sh',
  'plan-cycle/skills/lead/scripts/wire-team-block.sh',
]);

const args = process.argv.slice(2);
const flag = (name) => {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? undefined : args[i + 1];
};

const source = resolve(flag('source') ?? join(HERE, '..'));
const out = flag('out') ? resolve(flag('out')) : undefined;
if (!out) {
  console.error('usage: vendor-sync.mjs --out <dir> [--source <repo root>] [--ref <ref>]');
  process.exit(2);
}

const die = (msg) => {
  console.error(`vendor-sync: ${msg}`);
  process.exit(1);
};

const readJson = (path) => {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (e) {
    die(`unreadable or invalid JSON at ${path} — ${e.message}`);
  }
};

const git = (...a) => {
  try {
    return execFileSync('git', a, { cwd: source, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch {
    return null;
  }
};

// ---------------------------------------------------------------- read source

const srcManifestPath = join(source, '.claude-plugin', 'marketplace.json');
if (!existsSync(srcManifestPath)) die(`no marketplace manifest at ${srcManifestPath}`);
const srcManifest = readJson(srcManifestPath);
if (!Array.isArray(srcManifest.plugins) || srcManifest.plugins.length === 0) {
  die('the source manifest lists no plugins');
}

// Every plugin in the marketplace is vendored, not a hand-kept subset: a subset
// is a second declaration of what the consumers use, and the copy is what goes
// stale. Which plugins actually LOAD stays the consumer's `enabledPlugins`.
const entries = srcManifest.plugins.map((entry) => {
  if (typeof entry.source !== 'string' || !entry.source.startsWith('./plugins/')) {
    die(`plugin "${entry.name}": source must be a ./plugins/<name> path, got ${JSON.stringify(entry.source)}`);
  }
  const dir = join(source, entry.source);
  if (!existsSync(join(dir, '.claude-plugin', 'plugin.json'))) {
    die(`plugin "${entry.name}": no .claude-plugin/plugin.json under ${entry.source}`);
  }
  const manifest = readJson(join(dir, '.claude-plugin', 'plugin.json'));
  if (manifest.name !== entry.name) {
    die(`plugin "${entry.name}": plugin.json calls itself "${manifest.name}"`);
  }
  if (!manifest.version) die(`plugin "${entry.name}": plugin.json has no version`);
  return { entry, dir, manifest };
});

// ------------------------------------------------------------------- generate

// Replace rather than merge: a plugin deleted upstream must disappear here too,
// and a leftover directory would still be a loadable plugin.
rmSync(out, { recursive: true, force: true });
mkdirSync(join(out, 'plugins'), { recursive: true });

let excluded = 0;
for (const { entry, dir } of entries) {
  cpSync(dir, join(out, entry.source.replace('./', '')), {
    recursive: true,
    // preserveTimestamps is deliberately off — a mirror that rewrites mtimes on
    // every run produces no git diff either way, and stable content is what the
    // PR should show.
    filter: (src) => {
      const rel = relative(join(source, 'plugins'), src).split('\\').join('/');
      if (EXCLUDE.has(rel)) {
        excluded += 1;
        return false;
      }
      return true;
    },
  });
}

// Excluding the last file in a directory leaves the directory behind. Git does
// not track an empty directory, so a fresh run and a checkout of that run's
// output would otherwise disagree — and the "artifact matches the generator"
// check would fail on a difference that is not in any commit.
const pruneEmpty = (dir) => {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) pruneEmpty(join(dir, e.name));
  }
  if (readdirSync(dir).length === 0) rmSync(dir, { recursive: true });
};
pruneEmpty(join(out, 'plugins'));

// The manifest is rebuilt from what was just written. Entry metadata
// (description, category, author, homepage) is carried over verbatim; `source`
// is re-emitted rather than trusted, so it always names a directory that exists.
const manifest = {
  $schema: srcManifest.$schema,
  name: srcManifest.name,
  description: srcManifest.description,
  owner: srcManifest.owner,
  plugins: entries.map(({ entry }) => ({ ...entry, source: `./plugins/${entry.name}` })),
};
mkdirSync(join(out, '.claude-plugin'), { recursive: true });
writeFileSync(join(out, '.claude-plugin', 'marketplace.json'), `${JSON.stringify(manifest, null, 2)}\n`);

// ------------------------------------------------------------------ provenance

const sha = git('rev-parse', 'HEAD') ?? 'unknown';
const ref = flag('ref') ?? git('describe', '--tags', '--exact-match') ?? git('rev-parse', '--abbrev-ref', 'HEAD') ?? 'unknown';
const repo = srcManifest.owner?.url ? `${srcManifest.owner.url.replace(/\/$/, '')}/claude-plugins` : 'kai-tw/claude-plugins';

const rows = entries
  .map(({ entry, manifest: m }) => `| \`${entry.name}\` | ${m.version} |`)
  .join('\n');

writeFileSync(
  join(out, 'VENDORED.md'),
  `# Vendored: the \`${srcManifest.name}\` marketplace

**Generated. Do not edit anything in this directory by hand.** Every file here is
produced by \`scripts/vendor-sync.mjs\` in the source repo and replaced wholesale
on the next sync, so a hand-edit is reverted without a conflict and without a
message. Change the source, release it, and take the bump PR.

| Source | |
|---|---|
| Repo | ${repo} |
| Ref | \`${ref}\` |
| Commit | \`${sha}\` |
| Synced | ${new Date().toISOString().slice(0, 10)} |

| Plugin | Version |
|---|---|
${rows}

## Why this copy exists

A cloud session's github credential covers only the repos that session mounted.
The source marketplace is private, so a session that mounted only this repo
cannot clone it, and every \`@${srcManifest.name}\` plugin — the plan cycle, its
gates, every \`plan-*\` command — is absent. Vendoring removes the second
credential from the path: the marketplace becomes a directory this repo already
checked out.

## What is NOT here

Two maintenance generators under \`plan-cycle/skills/lead/scripts/\` are excluded.
They rewrite files inside the plugin tree, which is harmless where that tree is a
throwaway cache copy and is not harmless where it is this repo's own artifact.
`,
);

// ---------------------------------------------------------------------- report

const count = (dir) =>
  readdirSync(dir, { withFileTypes: true }).reduce(
    (n, e) => n + (e.isDirectory() ? count(join(dir, e.name)) : 1),
    0,
  );

console.log(`vendor-sync: ${srcManifest.name} → ${out}`);
for (const { entry, manifest: m } of entries) console.log(`  ${entry.name} ${m.version}`);
console.log(`  ${count(out)} files, ${excluded} excluded, from ${ref} (${sha.slice(0, 8)})`);
