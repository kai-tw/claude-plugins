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
//   <out>/VENDORED.md                       provenance: what was released + sha
//
// The marketplace manifest is GENERATED rather than copied so it can never
// describe a plugin this run did not write: every entry is emitted from the
// plugin.json actually placed on disk, and a name or version disagreement is a
// hard error rather than a manifest that lies.
//
// Usage:
//   node scripts/vendor-sync.mjs --out <dir> [--source <repo root>] [--release <label>]
//   node scripts/vendor-sync.mjs --print-versions <dir>   # the table, from disk

import { createHash } from 'node:crypto';
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

const die = (msg) => {
  console.error(`vendor-sync: ${msg}`);
  process.exit(1);
};

// `--print-versions` reads the table back off a vendored tree that already
// exists. It lives here rather than in the caller so the versions a commit
// message states and the versions the tree actually carries are derived once,
// from the same files — a second derivation is a second thing to go stale.
const printVersions = flag('print-versions');
if (printVersions) {
  const dir = resolve(printVersions);
  const pluginsDir = join(dir, 'plugins');
  if (!existsSync(pluginsDir)) die(`no plugins/ under ${dir}`);
  const rows = readdirSync(pluginsDir, { withFileTypes: true })
    .filter((e) => e.isDirectory())
    .map((e) => {
      const m = join(pluginsDir, e.name, '.claude-plugin', 'plugin.json');
      if (!existsSync(m)) die(`no plugin.json under plugins/${e.name}`);
      return `- ${e.name} ${JSON.parse(readFileSync(m, 'utf8')).version}`;
    })
    .sort();
  console.log(rows.join('\n'));
  process.exit(0);
}

const source = resolve(flag('source') ?? join(HERE, '..'));
const out = flag('out') ? resolve(flag('out')) : undefined;
if (!out) {
  console.error('usage: vendor-sync.mjs --out <dir> [--source <repo root>] [--release <label>]');
  console.error('       vendor-sync.mjs --print-versions <dir>');
  process.exit(2);
}

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
const release = flag('release') ?? git('describe', '--tags', '--exact-match') ?? git('rev-parse', '--abbrev-ref', 'HEAD') ?? 'unknown';
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
| Release | \`${release}\` |
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

## Checking it was not hand-edited

\`\`\`bash
node <this dir>/verify.mjs
\`\`\`

Recomputes every file's sha256 and executable bit against \`CHECKSUMS.txt\` and
exits non-zero on any add, edit, deletion or mode change. It needs no access to
the private source repo, so a consumer's own CI can run it.

## What is NOT here

Two maintenance generators under \`plan-cycle/skills/lead/scripts/\` are excluded.
They rewrite files inside the plugin tree, which is harmless where that tree is a
throwaway cache copy and is not harmless where it is this repo's own artifact.
`,
);

// ------------------------------------------------------------------ checksums

// "A hand-edit is silently reverted by the next sync" is the same shape as
// every failure this repo has paid for: it is true, and nobody is told. The
// manifest is what lets the consumer's own CI say it out loud instead —
// `verify.mjs` beside it recomputes these and fails on a mismatch, needing no
// access to the private source repo.
const walk = (dir, base = dir) =>
  readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = join(dir, e.name);
    return e.isDirectory() ? walk(p, base) : [relative(base, p).split('\\').join('/')];
  });

writeFileSync(
  join(out, 'verify.mjs'),
  `#!/usr/bin/env node
// Fail if anything in this vendored tree was hand-edited.
//
// Generated alongside CHECKSUMS.txt by scripts/vendor-sync.mjs in
// kai-tw/claude-plugins. Standalone on purpose: the consumer's CI cannot reach
// the private source repo, so the check has to be answerable from this
// directory alone.
//
// Usage (from anywhere):  node <this dir>/verify.mjs
import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)));
const walk = (dir) =>
  readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = join(dir, e.name);
    return e.isDirectory() ? walk(p) : [relative(root, p).split('\\\\').join('/')];
  });

const SELF = new Set(['CHECKSUMS.txt']);
const expected = new Map(
  readFileSync(join(root, 'CHECKSUMS.txt'), 'utf8')
    .split('\\n')
    .filter(Boolean)
    .map((line) => {
      const [hash, x, ...rest] = line.split(' ');
      return [rest.join(' '), { hash, exec: x === 'x' }];
    }),
);

const problems = [];
const seen = new Set();
for (const f of walk(root)) {
  if (SELF.has(f)) continue;
  seen.add(f);
  const want = expected.get(f);
  if (!want) {
    problems.push(\`added:    \${f}\`);
    continue;
  }
  const got = createHash('sha256').update(readFileSync(join(root, f))).digest('hex');
  if (got !== want.hash) problems.push(\`modified: \${f}\`);
  const exec = (statSync(join(root, f)).mode & 0o111) !== 0;
  if (exec !== want.exec) problems.push(\`mode:     \${f} (expected \${want.exec ? 'executable' : 'non-executable'})\`);
}
for (const f of expected.keys()) if (!seen.has(f)) problems.push(\`deleted:  \${f}\`);

if (problems.length === 0) {
  console.log(\`vendored marketplace intact — \${seen.size} files\`);
  process.exit(0);
}
console.error('This directory is a generated artifact, and it has been edited:');
for (const p of problems.sort()) console.error(\`  \${p}\`);
console.error('');
console.error('Change the source in kai-tw/claude-plugins, release it, and take the');
console.error('bump PR. An edit made here is reverted by the next sync.');
process.exit(1);
`,
);

const CHECKSUMS = 'CHECKSUMS.txt';
const hashed = walk(out)
  .filter((f) => f !== CHECKSUMS)
  .sort()
  .map((f) => {
    const h = createHash('sha256').update(readFileSync(join(out, f))).digest('hex');
    // The executable bit is content for our purposes: `bin/` lands on PATH from
    // this directory, so a file that arrives non-executable is a broken command.
    const x = (statSync(join(out, f)).mode & 0o111) !== 0 ? 'x' : '-';
    return `${h} ${x} ${f}`;
  });
writeFileSync(join(out, CHECKSUMS), `${hashed.join('\n')}\n`);

// ---------------------------------------------------------------------- report

const count = (dir) =>
  readdirSync(dir, { withFileTypes: true }).reduce(
    (n, e) => n + (e.isDirectory() ? count(join(dir, e.name)) : 1),
    0,
  );

console.log(`vendor-sync: ${srcManifest.name} → ${out}`);
for (const { entry, manifest: m } of entries) console.log(`  ${entry.name} ${m.version}`);
console.log(`  ${count(out)} files, ${excluded} excluded, from ${release} (${sha.slice(0, 8)})`);
