#!/usr/bin/env node
// Wait for a PR to merge, then do everything a merge owes: update every install
// of each plugin the PR changed (consumers.mjs) and verify it, sync the main
// checkout, and remove the PR's local worktree and branch.
//
// Start it with the Bash tool's `run_in_background: true` once the PR is ready:
// it exits when the PR merges or closes, and the exit wakes the session — nobody
// has to say "merged". The app's PR monitor wakes a session on CI failures,
// conflicts and review comments, never on a merge. The wait is a push, not
// polling: `gh webhook forward` (the cli/gh-webhook extension) streams GitHub's
// pull_request events over a websocket.
//
// Usage: node .claude/skills/plugin-release/scripts/after-merge.mjs <pr>
// Exit: 0 merged and every install verified (or no plugin to install) · 1 closed
// unmerged, the forwarder failed or stopped, or a check failed — the reason on stderr.

import { execFileSync, spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marketplaceSource, slug, updateConsumers } from './consumers.mjs';

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
    return JSON.parse(execFileSync('gh', ['pr', 'view', pr, '--json', 'state,mergeCommit,headRefName,files,url'], { cwd: main, encoding: 'utf8' }));
  } catch (e) {
    die(`gh pr view ${pr} failed — ${(e.stderr || e.message).trim()}`);
  }
};
try {
  execFileSync('gh', ['webhook', '--help'], { stdio: 'ignore' });
} catch {
  die('gh webhook not installed — gh extension install cli/gh-webhook');
}

// 1. Wait. Connected first, then one state check, so a merge in between still
// arrives as an event and a merge before the start is not waited for forever.
const repo = slug(git(['remote', 'get-url', 'origin']));
const fwd = spawn('gh', ['webhook', 'forward', '--events=pull_request', `--repo=${repo}`], {
  cwd: main, detached: true, stdio: ['ignore', 'pipe', 'pipe'],
});
// Stop the whole group: killing only `gh` leaves the extension under it running.
const stop = () => { try { process.kill(-fwd.pid, 'SIGTERM'); } catch {} };
process.on('exit', stop);
let err = '';
const closed = await new Promise((settle) => {
  fwd.stderr.on('data', (d) => {
    const was = /^Forwarding/m.test(err);
    err += d;
    if (!was && /^Forwarding/m.test(err) && view().state !== 'OPEN') settle(true);
  });
  createInterface({ input: fwd.stdout }).on('line', (line) => {
    try {
      const ev = JSON.parse(line);
      if (ev.action === 'closed' && String(ev.number) === pr) settle(true);
    } catch {}
  });
  fwd.on('exit', () => settle(false));
});
stop();
if (!closed) die(`webhook forwarder for ${repo} stopped — ${err.trim().split('\n').slice(-2).join(' ')}`);
const pull = view();
if (pull.state !== 'MERGED') die(`${pull.url} was closed without merging — nothing to install`);
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
