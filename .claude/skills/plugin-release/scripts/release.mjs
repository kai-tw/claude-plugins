#!/usr/bin/env node
// Release a plugin: evals → bump → validate → commit → push → update and VERIFY every install.
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
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, resolve, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marketplaceSource, slug, updateConsumers } from './consumers.mjs';

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

step(0, `evals for ${plugin}`);
// Before the bump, so a failing release leaves nothing to revert.
try {
  console.log(run('node', ['.github/scripts/run-evals.mjs', plugin]));
} catch (e) {
  die(`evals failed — nothing released:\n${e.stdout ?? ''}${e.stderr ?? e.message}`);
}

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

step(6, 'update every install');
// FIRST: does this machine install FROM this repo at all? A marketplace pointing
// somewhere else (another checkout, a mirror) cannot show this release; say so
// and stop rather than failing a check that could not have passed.
const src = marketplaceSource(marketplace.name);
const originSlug = slug(run('git', ['remote', 'get-url', 'origin']));
const servesThisTree =
  ((src?.source === 'git' || src?.source === 'github') && slug(src.url ?? src.repo) === originSlug) ||
  (src?.source === 'directory' && !relative(root, resolve(src.path)).startsWith('..'));

if (src && !servesThisTree) {
  const where = src.source === 'directory' ? resolve(src.path) : `${src.source}:${src.url ?? src.repo ?? '?'}`;
  console.log(`  ⚠ "${marketplace.name}" installs from ${where}, not from this repo (${originSlug}).`);
  console.log(`    Nothing here can show ${next}, and there is nothing local to verify.`);
  console.log(`\n✔ ${plugin} ${next} pushed — NOT installed anywhere from this run.`);
  process.exit(0);
}

// A git/github marketplace serves the repo's DEFAULT branch, so a release pushed
// on any other branch cannot be installed until it merges — and this repo's rule
// of one bump per PR, at close-out, puts the release commit on the PR branch
// every time. A `directory` marketplace is exempt: it serves the working tree.
if (src?.source === 'git' || src?.source === 'github') {
  let defaultBranch = null;
  try {
    defaultBranch = run('git', ['symbolic-ref', '--short', 'refs/remotes/origin/HEAD']).replace(/^origin\//, '');
  } catch {
    // No symref recorded — cannot tell, so don't block.
  }
  const branch = run('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
  if (defaultBranch && branch !== defaultBranch) {
    console.log(`  ⚠ on branch "${branch}", but "${marketplace.name}" serves ${originSlug}@${defaultBranch}.`);
    console.log(`    ${next} is pushed and cannot be installed until it merges — nothing is wrong.`);
    console.log(`\n    Once the PR is ready, start with run_in_background — it waits for the merge,`);
    console.log(`    then updates and verifies every install:`);
    console.log(`      node .claude/skills/plugin-release/scripts/after-merge.mjs <pr>`);
    console.log(`\n✔ ${plugin} ${next} committed and pushed on ${branch} — install after merge.`);
    process.exit(0);
  }
}

const failures = updateConsumers({ root, marketplace: marketplace.name, plugin, version: next, ref: 'HEAD' });
if (failures.length) die(`${plugin} ${next} is pushed, but:\n${failures.map((f) => `    ${f}`).join('\n')}`);
console.log(`\n✔ ${plugin} ${next} released, installed and verified everywhere`);
