#!/usr/bin/env node
// Wait for a PR to merge, then do everything a merge owes: update every install
// of each plugin the PR changed (consumers.mjs) and verify it, uninstall every
// install of a plugin the PR deleted, sync the main checkout, and remove the PR's
// local worktree and branch.
//
// Start it with the Bash tool's `run_in_background: true` once the PR is ready:
// it exits when the PR merges or closes, and the exit wakes the session — nobody
// has to say "merged". The app's PR monitor wakes a session on CI failures,
// conflicts and review comments, never on a merge. The wait is a push, not
// polling: `gh webhook forward` (the cli/gh-webhook extension) streams GitHub's
// pull_request events over a websocket.
//
// One run per PR, any number of PRs at once: the runs share one forwarder
// (the assistant plugin's hub.mjs, which asst-pr watch uses too), and the work
// after a merge runs one PR at a time.
//
// Usage: node .claude/skills/plugin-release/scripts/after-merge.mjs <pr>
// Exit: 0 merged and every install verified (or no plugin to install) · 1 closed
// unmerged, already running for this PR, the forwarder failed, or a check
// failed — the reason on stderr.

import { execFileSync } from 'node:child_process';
import { watch } from 'node:fs';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { marketplaceSource, removeConsumers, slug, updateConsumers } from './consumers.mjs';
import { claim, joinHub, owner, release, repoDir } from '../../../../plugins/assistant/skills/assistant/scripts/hub.mjs';

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
const mine = join(repoDir(repo), `merge-${pr}.pid`);
const turnFile = join(repoDir(repo), 'after-merge.lock');
process.on('exit', () => { release(mine); release(turnFile); });
for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(sig, () => process.exit(130));
if (!claim(mine)) die(`after-merge is already running for #${pr} (pid ${owner(mine)})`);
let hub;
const failed = await new Promise((settle) => {
  hub = joinHub({
    repo,
    events: 'pull_request',
    pick: (ev) => (ev.action === 'closed' ? { closed: ev.number } : null),
    onEvent: (ev) => { if (String(ev.closed) === pr) settle(''); },
    onConnected: () => { if (view().state !== 'OPEN') settle(''); },
    onFail: settle,
  });
});
await hub.stop();
if (failed) die(failed);

// Two merges close together would sync the main checkout and rewrite the same
// install records at once, and git refuses a second writer of one index — so
// steps 2 and 3 run one PR at a time.
while (!claim(turnFile)) {
  await new Promise((r) => {
    const done = () => { w.close(); clearTimeout(t); r(); };
    const w = watch(dirname(turnFile), done);
    const t = setTimeout(done, 5000);
  });
}
const pull = view();
if (pull.state !== 'MERGED') die(`${pull.url} was closed without merging — nothing to install`);
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
const changed = [...new Set(pull.files.map((f) => f.path.match(/^plugins\/([^/]+)\//)?.[1]).filter(Boolean))];
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
