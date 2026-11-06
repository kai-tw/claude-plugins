#!/usr/bin/env node
// Look once at a PR; once it has merged, do everything that has to happen after a
// merge: update every install of each plugin the PR changed (consumers.mjs) and
// verify it, uninstall every install of a plugin the PR deleted, sync the main
// checkout, and remove the PR's local worktree and branch.
//
// Nothing here waits. While the PR is still open it says so and exits 3; the user
// says when the PR can merge, and nothing is scheduled for it.
//
// Usage: node .claude/skills/plugin-release/scripts/after-merge.mjs <pr>
// Exit: 0 merged and every install verified (or no plugin to install) · 1 closed
// unmerged, or a check failed — the reason on stderr · 3 still open.

import { execFileSync } from 'node:child_process';
import { readFileSync, unlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marketplaceSource, removeConsumers, slug, updateConsumers } from './consumers.mjs';

const pr = process.argv[2];
const die = (msg) => {
  console.error(`✘ ${msg}`);
  process.exit(1);
};
if (!/^\d+$/.test(pr ?? '')) die('usage: after-merge.mjs <pr>');

const here = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const git = (args, cwd = main) => execFileSync('git', args, { cwd, encoding: 'utf8' }).trim();
// The main checkout, never the worktree this may run from — the worktree is removed below.
const main = git(['worktree', 'list', '--porcelain'], here).match(/^worktree (.*)$/m)[1];
const view = () => {
  try {
    return JSON.parse(execFileSync('gh', ['pr', 'view', pr, '--json', 'state,mergeCommit,headRefName,url'], { cwd: main, encoding: 'utf8' }));
  } catch (e) {
    die(`gh pr view ${pr} failed — ${(e.stderr || e.message).trim()}`);
  }
};
// Every path the PR touched, old names of renamed files included. `gh pr view --json
// files` stops at 100 files, so a large PR (#88 touched 350) lost most of its plugins.
const files = () => {
  try {
    return execFileSync('gh', ['api', '--paginate', `repos/{owner}/{repo}/pulls/${pr}/files`, '--jq', '.[] | .filename, (.previous_filename // empty)'], { cwd: main, encoding: 'utf8' })
      .split('\n').filter(Boolean);
  } catch (e) {
    die(`gh api pulls/${pr}/files failed — ${(e.stderr || e.message).trim()}`);
  }
};
// 1. One look at the PR.
const pull = view();
if (pull.state === 'OPEN') {
  console.log(`#${pr} is still open — ${pull.url}`);
  console.log(`next: wait for the user to say the PR can merge`);
  process.exit(3);
}
if (pull.state !== 'MERGED') die(`${pull.url} was closed without merging — nothing to install`);

// Two merges looked at close together would sync the main checkout and rewrite
// the same install records at once, and git refuses a second writer of one
// index — so the work below runs one PR at a time. A lock whose owner has died
// is taken over.
const repo = slug(git(['remote', 'get-url', 'origin']));
const lock = join(tmpdir(), `after-merge-${repo.replace('/', '__')}.lock`);
const alive = (pid) => { try { process.kill(pid, 0); return true; } catch { return false; } };
for (;;) {
  try {
    writeFileSync(lock, `${process.pid}\n`, { flag: 'wx' });
    break;
  } catch {
    const owner = Number(readFileSync(lock, 'utf8').trim()) || 0;
    if (owner && !alive(owner)) { try { unlinkSync(lock); } catch {} continue; }
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1000);
  }
}
process.on('exit', () => { try { unlinkSync(lock); } catch {} });
const ref = pull.mergeCommit.oid;
console.log(`✔ ${pull.url} merged as ${ref.slice(0, 7)}`);

// 2. Sync the main checkout, then clear the PR's worktree and branch.
// Something else fetches this checkout the moment a PR merges (measured: "cannot
// lock ref 'refs/remotes/origin/main'"), so a lost ref lock is retried once.
try {
  git(['fetch', '--quiet', 'origin']);
} catch (e) {
  if (!/cannot lock ref/.test(e.stderr ?? '')) throw e;
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1000);
  git(['fetch', '--quiet', 'origin']);
}
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

// 3. Install what the PR changed, then uninstall what it deleted — in that order,
// so a plugin that moved into another is never missing in between.
const changed = [...new Set(files().map((f) => f.match(/^plugins\/([^/]+)\//)?.[1]).filter(Boolean))];
const exists = (plugin) => {
  try {
    git(['cat-file', '-e', `${ref}:plugins/${plugin}/.claude-plugin/plugin.json`]);
    return true;
  } catch {
    return false;
  }
};
const plugins = changed.filter(exists);
const removed = changed.filter((p) => !exists(p));
const marketplace = JSON.parse(git(['show', `${ref}:.claude-plugin/marketplace.json`])).name;
const src = marketplaceSource(marketplace);
const failures = [];
if (changed.length === 0) {
  console.log(`  no plugin in #${pr} — nothing to install`);
} else if (!src || slug(src.url ?? src.repo) !== slug(git(['remote', 'get-url', 'origin']))) {
  console.log(`  ⚠ "${marketplace}" does not install from this repo here — nothing local to update`);
} else {
  for (const plugin of plugins) {
    const version = JSON.parse(git(['show', `${ref}:plugins/${plugin}/.claude-plugin/plugin.json`])).version;
    console.log(`\n${plugin} ${version}`);
    failures.push(...updateConsumers({ root: main, marketplace, plugin, version, ref }).map((f) => `${plugin}: ${f}`));
  }
  for (const plugin of removed) {
    console.log(`\n${plugin} — deleted`);
    failures.push(...removeConsumers({ marketplace, plugin }).map((f) => `${plugin}: ${f}`));
  }
}

notes.forEach((n) => console.log(`  ⚠ ${n}`));
if (failures.length) die(`#${pr} merged, but:\n${failures.map((f) => `    ${f}`).join('\n')}`);
console.log(
  `\n✔ #${pr} merged${plugins.length ? ` — ${plugins.join(', ')} installed and verified everywhere; running sessions switch to it on their own` : ''}${removed.length ? ` — ${removed.join(', ')} uninstalled everywhere` : ''}`,
);
