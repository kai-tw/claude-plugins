#!/usr/bin/env node
// Release a plugin: bump → validate → commit → tag → push → update → VERIFY.
//
// The verify step is the point. A bump that is not installed is invisible, and
// that failure is silent: dart-lsp once shipped without its skill because the
// version had not moved, so the installer compared versions, saw no change, and
// served a stale cache forever. Nothing complained. This compares the installed
// cache against the source tree and fails loudly when they disagree.
//
// Dry run by default. Pass --commit to actually release.
//
// Usage: node .claude/skills/plugin-release/scripts/release.mjs <plugin> <major|minor|patch> [--commit]

import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { join, resolve, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const [plugin, level] = process.argv.slice(2);
const commit = process.argv.includes('--commit');

const die = (msg) => {
  console.error(`✘ ${msg}`);
  process.exit(1);
};
const run = (cmd, args, opts = {}) =>
  execFileSync(cmd, args, { cwd: root, encoding: 'utf8', ...opts }).trim();
const step = (n, msg) => console.log(`\n[${n}] ${msg}`);

if (!plugin || !['major', 'minor', 'patch'].includes(level)) {
  die('usage: release.mjs <plugin> <major|minor|patch> [--commit]');
}

const manifestPath = join(root, `plugins/${plugin}/.claude-plugin/plugin.json`);
if (!existsSync(manifestPath)) die(`no such plugin: plugins/${plugin}`);

const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
const marketplace = JSON.parse(
  readFileSync(join(root, '.claude-plugin/marketplace.json'), 'utf8'),
);

const [maj, min, pat] = manifest.version.split('.').map(Number);
if ([maj, min, pat].some(Number.isNaN)) die(`unparseable version: ${manifest.version}`);
const next = { major: `${maj + 1}.0.0`, minor: `${maj}.${min + 1}.0`, patch: `${maj}.${min}.${pat + 1}` }[level];

console.log(`${plugin}: ${manifest.version} → ${next}  (${level})`);
console.log(`marketplace: ${marketplace.name}   tag: ${plugin}--v${next}`);

// What is actually being released — the reason to pick this level.
const lastTag = (() => {
  try {
    return run('git', ['describe', '--tags', '--abbrev=0', '--match', `${plugin}--v*`], {
      stdio: ['ignore', 'pipe', 'ignore'],
    });
  } catch {
    return null;
  }
})();
const changed = lastTag
  ? run('git', ['diff', '--name-only', `${lastTag}..HEAD`, '--', `plugins/${plugin}/`]).split('\n').filter(Boolean)
  : [];
console.log(`\nchanged since ${lastTag ?? '(never tagged)'}:`);
if (changed.length) changed.forEach((f) => console.log(`  ${f}`));
else console.log(lastTag ? '  (nothing — is this release necessary?)' : '  (no prior tag to diff against)');

if (!commit) {
  console.log('\nDRY RUN — nothing changed. Re-run with --commit to release.');
  process.exit(0);
}

// A release must not sweep up unrelated edits.
const dirty = run('git', ['status', '--porcelain']);
if (dirty) die(`working tree is dirty — commit or stash first:\n${dirty}`);

step(1, `bump plugin.json to ${next}`);
manifest.version = next;
writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);

step(2, 'run repo checks before anything is published');
for (const script of ['validate.mjs', 'check-version-bump.mjs']) {
  try {
    console.log(run('node', [`.github/scripts/${script}`]));
  } catch (e) {
    run('git', ['checkout', '--', relative(root, manifestPath)]); // leave the tree as found
    die(`${script} failed — bump reverted:\n${e.stdout ?? e.message}`);
  }
}

step(3, 'commit');
run('git', ['add', relative(root, manifestPath)]);
run('git', ['commit', '-m', `release(${plugin}): ${next}`]);

step(4, 'tag + push');
// `claude plugin tag` also checks plugin.json agrees with the marketplace entry.
console.log(run('claude', ['plugin', 'tag', '--push', `plugins/${plugin}`]));
run('git', ['push', 'origin', 'HEAD']);

step(5, 'update the locally installed copy');
console.log(run('claude', ['plugin', 'update', `${plugin}@${marketplace.name}`]));

step(6, 'VERIFY the installed cache matches source');
const cache = join(
  process.env.HOME,
  `.claude/plugins/cache/${marketplace.name}/${plugin}/${next}`,
);
if (!existsSync(cache)) die(`nothing installed at ${cache} — the update did not land`);

const list = (dir, base = dir) =>
  readdirSync(dir).flatMap((n) => {
    if (n === '.in_use' || n === '.orphaned_at' || n === '.DS_Store') return [];
    const p = join(dir, n);
    return statSync(p).isDirectory() ? list(p, base) : [relative(base, p)];
  });

const inSource = new Set(list(join(root, `plugins/${plugin}`)));
const inCache = new Set(list(cache));
const missing = [...inSource].filter((f) => !inCache.has(f));

if (missing.length) {
  die(
    `installed copy is missing ${missing.length} file(s) that exist in source:\n` +
      missing.map((f) => `      ${f}`).join('\n') +
      `\n    the release did not reach the cache at ${cache}`,
  );
}

console.log(`  ✔ ${inCache.size} file(s) match source`);
console.log(`\n✔ ${plugin} ${next} released, tagged, installed and verified`);
