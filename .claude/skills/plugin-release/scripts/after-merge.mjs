#!/usr/bin/env node
// Wait for a PR to merge, then do everything a merge owes: update every install
// of each plugin the PR changed (consumers.mjs) and verify it, sync the main
// checkout, and remove the PR's local worktree and branch.
//
// Start it with the Bash tool's `run_in_background: true` once the PR is ready:
// it exits when the PR merges or closes, and the exit wakes the session — nobody
// has to say "merged". The app's PR monitor wakes a session on CI failures,
// conflicts and review comments, never on a merge.
//
// Usage: node .claude/skills/plugin-release/scripts/after-merge.mjs <pr> [--every <seconds>] [--hours <n>]
//   --every  how often to ask GitHub (default 60)   --hours  give up after (default 24)
// Exit: 0 merged and every install verified (or no plugin to install) · 1 closed
// unmerged, gave up, or a check failed — the reason on stderr.

import { execFileSync } from 'node:child_process';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marketplaceSource, slug, updateConsumers } from './consumers.mjs';

const arg = (k, d) => {
  const i = process.argv.indexOf(k);
  return i > 0 ? Number(process.argv[i + 1]) : d;
};
const pr = process.argv[2];
const every = arg('--every', 60);
const hours = arg('--hours', 24);
const die = (msg) => {
  console.error(`✘ ${msg}`);
  process.exit(1);
};
if (!/^\d+$/.test(pr ?? '') || !(every > 0) || !(hours > 0)) {
  die('usage: after-merge.mjs <pr> [--every <seconds>] [--hours <n>]');
}

const here = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const git = (args, cwd = main) => execFileSync('git', args, { cwd, encoding: 'utf8' }).trim();
// The main checkout, never the worktree this may run from — the worktree is removed below.
const main = git(['worktree', 'list', '--porcelain'], here).match(/^worktree (.*)$/m)[1];
const sleep = (s) => new Promise((r) => setTimeout(r, s * 1000));

// 1. Wait. A few failed reads in a row are the network; many are a real fault.
let pull;
for (let t = Date.now(), misses = 0; ; ) {
  try {
    pull = JSON.parse(execFileSync('gh', ['pr', 'view', pr, '--json', 'state,mergeCommit,headRefName,files,url'], { cwd: main, encoding: 'utf8' }));
    misses = 0;
  } catch (e) {
    if (++misses >= 10) die(`gh pr view ${pr} failed ${misses} times in a row — ${(e.stderr || e.message).trim()}`);
  }
  if (pull?.state === 'MERGED') break;
  if (pull?.state === 'CLOSED') die(`${pull.url} was closed without merging — nothing to install`);
  if (Date.now() - t > hours * 3600e3) die(`#${pr} not merged after ${hours} h — gave up; start me again to keep waiting`);
  await sleep(every);
}
const ref = pull.mergeCommit.oid;
console.log(`✔ ${pull.url} merged as ${ref.slice(0, 7)}`);

// 2. Sync the main checkout, then clear the PR's worktree and branch.
git(['fetch', '--quiet', 'origin']);
const notes = [];
const branchHere = git(['rev-parse', '--abbrev-ref', 'HEAD']);
const defaultBranch = git(['symbolic-ref', '--short', 'refs/remotes/origin/HEAD']).replace(/^origin\//, '');
if (branchHere !== defaultBranch) notes.push(`${main} is on ${branchHere}, not ${defaultBranch} — not synced`);
else if (git(['status', '--porcelain'])) notes.push(`${main} has uncommitted changes — not synced`);
else git(['merge', '--quiet', '--ff-only', `origin/${defaultBranch}`]);
const wt = git(['worktree', 'list', '--porcelain'])
  .split('\n\n')
  .find((b) => b.includes(`\nbranch refs/heads/${pull.headRefName}`))
  ?.match(/^worktree (.*)$/m)[1];
try {
  if (wt) git(['worktree', 'remove', wt]); // refuses a dirty tree — that work is reported, not lost
  if (git(['branch', '--list', pull.headRefName])) git(['branch', '-D', pull.headRefName]);
} catch (e) {
  notes.push(`${wt ?? pull.headRefName} kept — ${(e.stderr || e.message).trim()}`);
}

// 3. Install what the PR changed.
const plugins = [...new Set(pull.files.map((f) => f.path.match(/^plugins\/([^/]+)\//)?.[1]).filter(Boolean))];
const marketplace = JSON.parse(git(['show', `${ref}:.claude-plugin/marketplace.json`])).name;
const src = marketplaceSource(marketplace);
const failures = [];
if (plugins.length === 0) {
  console.log(`  no plugin in #${pr} — nothing to install`);
} else if (!src || slug(src.url ?? src.repo) !== slug(git(['remote', 'get-url', 'origin']))) {
  console.log(`  ⚠ "${marketplace}" does not install from this repo here — nothing local to update`);
} else {
  for (const plugin of plugins) {
    const version = JSON.parse(git(['show', `${ref}:plugins/${plugin}/.claude-plugin/plugin.json`])).version;
    console.log(`\n${plugin} ${version}`);
    failures.push(...updateConsumers({ root: main, marketplace, plugin, version, ref }).map((f) => `${plugin}: ${f}`));
  }
}

notes.forEach((n) => console.log(`  ⚠ ${n}`));
if (failures.length) die(`#${pr} merged, but:\n${failures.map((f) => `    ${f}`).join('\n')}`);
console.log(
  `\n✔ #${pr} merged${plugins.length ? ` — ${plugins.join(', ')} installed and verified everywhere; a running session loads it only after a restart` : ''}`,
);
