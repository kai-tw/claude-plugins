#!/usr/bin/env node
// pr-watch — wait for CI on one PR's head commit to finish, then exit with the
// verdict of `asst-pr checks`. `asst-pr watch` is the entry point; start it with
// run_in_background: true, and its exit wakes the session.
//
// One watcher per PR, any number of PRs at once: the watchers of one repo share
// one webhook forwarder (hub.mjs). Each reads CI once when it joins and whenever
// a forwarder connects, so nothing that finished in between is missed.
//
// Usage: node pr-watch.mjs <owner/repo> <pr> <head-sha> <timeout-minutes> <check command…>
// Exit: the check command's own 0 passed · 1 failed · 2 unreadable · 3 still
// running at the timeout; also 2 when the PR is already watched or the forwarder
// can't start.

import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { claim, joinHub, owner, release, repoDir } from './hub.mjs';

const [repo, pr, sha, timeoutMin, ...check] = process.argv.slice(2);
if (!repo || !/^\d+$/.test(pr ?? '') || !sha || !(Number(timeoutMin) > 0) || !check.length) {
  console.error('Usage: pr-watch.mjs <owner/repo> <pr> <head-sha> <timeout-minutes> <check command…>');
  process.exit(2);
}
const mine = join(repoDir(repo), `ci-${pr}.pid`);
if (!claim(mine)) {
  console.error(`asst-pr: #${pr} is already watched (pid ${owner(mine)}) — one watcher per PR`);
  process.exit(2);
}

let hub;
let done = false;
let again;
async function finish(code, out = '') {
  if (done) return;
  done = true;
  if (out) process.stdout.write(out);
  clearTimeout(again);
  await hub?.stop();
  release(mine);
  process.exit(code);
}
for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(sig, () => finish(130));

// One look at CI. 3 = still running; anything else ends the watch.
function look() {
  if (done) return 0;
  const r = spawnSync(check[0], check.slice(1), { encoding: 'utf8' });
  if (r.status !== 3) finish(r.status ?? 2, (r.stdout || '') + (r.stderr || ''));
  return r.status;
}
// GitHub sends a suite's completed event before its API shows it (measured: the
// event a second after the suite finished, and the read still said running),
// and no later event comes for that commit. So a read that still says running
// after an event is repeated a few times.
const LAGS = [2000, 10000, 30000];
function recheck() {
  clearTimeout(again);
  let i = 0;
  const go = () => { if (look() === 3 && i < LAGS.length) again = setTimeout(go, LAGS[i++]); };
  go();
}

hub = joinHub({
  repo,
  events: 'check_suite,status',
  pick: (ev) => { const at = ev.check_suite?.head_sha || ev.sha; return at ? { sha: at } : null; },
  onEvent: (ev) => { if (ev.sha === sha) recheck(); },
  onConnected: look,
  onFail: (why) => finish(2, `asst-pr: CI watch stopped — ${why}\n`),
});
setTimeout(() => finish(3, `asst-pr: CI still running on #${pr} after ${timeoutMin} min — watch again, or check the run\n`), Number(timeoutMin) * 60000);
