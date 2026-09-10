#!/usr/bin/env node
// Release a plugin: bump → validate → commit → push → update → VERIFY.
// The TAG is CI's (`.github/workflows/plugin-tag.yml`), not this script's.
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

step(2, 'structural checks on the working tree');
// Only validate.mjs can run here. check-version-bump.mjs reads git history, and
// at this point the bump exists solely in the working tree — it would compare
// the still-unbumped HEAD and fail every release by construction. It runs in
// step 4, once there is a commit for it to look at.
try {
  console.log(run('node', ['.github/scripts/validate.mjs']));
} catch (e) {
  run('git', ['checkout', '--', relative(root, manifestPath)]); // leave the tree as found
  die(`validate.mjs failed — bump reverted:\n${e.stdout ?? e.message}`);
}

step(3, 'commit');
run('git', ['add', relative(root, manifestPath)]);
run('git', ['commit', '-m', `release(${plugin}): ${next}`]);

step(4, 'confirm the commit records a bump');
try {
  console.log(run('node', ['.github/scripts/check-version-bump.mjs']));
} catch (e) {
  die(
    `check-version-bump.mjs failed AFTER committing — the release commit is in\n` +
      `    place but wrong. Inspect and fix by hand:\n${e.stdout ?? e.message}`,
  );
}

step(5, 'push');
// No tag from here. `.github/workflows/plugin-tag.yml` tags whatever version
// arrives on main; tagging locally would satisfy it, so it would find nothing
// to do and the version would ship untagged.
run('git', ['push', 'origin', 'HEAD']);

step(6, 'update the locally installed copy');
// FIRST: does this machine install FROM this repo at all? The marketplace is a
// `github` source pointing here, so the installer reads what step 5 just pushed
// — but only after the marketplace index is refreshed. `claude plugin update`
// compares against the index it already has, so without this it truthfully
// answers "already at the latest version" with the OLD number, and step 7 then
// dies on a cache directory that was never going to exist. That reads as a
// failed release when nothing failed, which trains the reader to ignore the one
// check that catches a real stale install.
// A marketplace pointing somewhere else entirely (another checkout, a mirror)
// cannot show this release at all; say so and stop rather than failing.
const marketplacesPath = join(process.env.HOME, '.claude/plugins/known_marketplaces.json');
const known = existsSync(marketplacesPath)
  ? JSON.parse(readFileSync(marketplacesPath, 'utf8'))[marketplace.name]
  : null;
const src = known?.source ?? {};
const originUrl = run('git', ['remote', 'get-url', 'origin']);
const originSlug = originUrl.replace(/^.*github\.com[/:]/, '').replace(/\.git$/, '');
const servesThisTree =
  (src.source === 'github' && src.repo === originSlug) ||
  (src.source === 'directory' && !relative(root, resolve(src.path)).startsWith('..'));

if (known && !servesThisTree) {
  const where = src.source === 'directory' ? resolve(src.path) : `${src.source}:${src.repo ?? '?'}`;
  console.log(`  ⚠ "${marketplace.name}" installs from ${where}, not from this repo (${originSlug}).`);
  console.log(`    Nothing here can show ${next}, and there is nothing local to verify.`);
  console.log(`\n✔ ${plugin} ${next} pushed — NOT installed anywhere from this run.`);
  process.exit(0);
}

// Refresh the index before asking for the update — see the note above.
try {
  run('claude', ['plugin', 'marketplace', 'update', marketplace.name]);
} catch (e) {
  die(`marketplace refresh failed — the release is pushed, but this machine\n` +
      `    cannot see it yet:\n    ${(e.stderr ?? e.message).trim()}`);
}

// `claude plugin update` defaults to user scope and errors out if the plugin
// lives anywhere else, so read the scope back rather than assuming it. A plugin
// may also be released without being installed here at all — that is a normal
// state, not a failure, but it means nothing local can be verified. The file
// itself can also be absent (no plugin ever installed on this machine), not
// just empty of this plugin — same non-failure, so treat it the same way.
const installedPath = join(process.env.HOME, '.claude/plugins/installed_plugins.json');
const installed = existsSync(installedPath) ? JSON.parse(readFileSync(installedPath, 'utf8')) : {};
const scopes = [
  ...new Set((installed.plugins?.[`${plugin}@${marketplace.name}`] ?? []).map((e) => e.scope)),
];

if (scopes.length === 0) {
  console.log(`  ⚠ not installed locally — released, but nothing here to update or verify`);
  console.log(`\n✔ ${plugin} ${next} released (not installed locally)`);
  process.exit(0);
}

for (const scope of scopes) {
  try {
    console.log(run('claude', ['plugin', 'update', `${plugin}@${marketplace.name}`, '--scope', scope]));
  } catch (e) {
    die(
      `update failed at scope "${scope}" — the release is pushed, but\n` +
        `    this machine still runs the old copy:\n    ${(e.stderr ?? e.message).trim()}`,
    );
  }
}

step(7, 'VERIFY the installed cache matches source');
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
console.log(`\n✔ ${plugin} ${next} released, installed and verified`);
