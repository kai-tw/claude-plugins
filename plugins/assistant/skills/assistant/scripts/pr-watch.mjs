#!/usr/bin/env node
// pr-watch — wait for one PR to reach an end state, then exit with the verdict.
// `asst-pr watch` is the entry point; start it with run_in_background: true, and
// its exit wakes the session. Two modes:
//   ci     CI on the PR's head commit finished; the verdict is the check command's
//          (`asst-pr checks`)
//   merge  the PR merged or closed
//
// One watcher per PR and mode, any number of PRs at once: the watchers of one repo
// share one webhook forwarder (hub.mjs). Each reads the PR once when it joins and
// whenever a forwarder connects, so nothing that happened in between is missed.
// This repo's after-merge.mjs imports watchPr for its merge wait.
//
// Usage: node pr-watch.mjs ci    <owner/repo> <pr> <timeout-minutes> <head-sha> <check command…>
//        node pr-watch.mjs merge <owner/repo> <pr> <timeout-minutes>
// Exit: ci — the check command's own 0 passed · 1 failed · 2 unreadable · 3 still
// running at the timeout; merge — 0 merged · 1 closed without merging · 2 unreadable
// · 3 still open at the timeout; also 2 when the PR is already watched or the
// forwarder can't start.

import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { claim, joinHub, owner, release, repoDir } from './hub.mjs';

// One look at a PR's state, shaped like a spawnSync result: status 3 = not yet.
function mergeState(repo, pr) {
  const r = spawnSync('gh', ['pr', 'view', pr, '--repo', repo, '--json', 'state,mergeCommit', '--jq', '[.state, .mergeCommit.oid // ""] | join(" ")'], { encoding: 'utf8' });
  if (r.status !== 0) return { status: 2, stderr: `asst-pr: can't read #${pr} — ${(r.stderr || '').trim()}\n` };
  const [state, oid = ''] = r.stdout.trim().split(' ');
  if (state === 'OPEN') return { status: 3 };
  if (state === 'MERGED') return { status: 0, stdout: `asst-pr: #${pr} MERGED as ${oid.slice(0, 7)}\n` };
  return { status: 1, stdout: `asst-pr: #${pr} CLOSED without merging\n` };
}

// What each mode waits on: the webhook events that can end it, which of them
// concern this PR, one look at it, and what to say at the timeout. `name` labels
// a stopped watch.
const modes = {
  ci: ({ pr, sha, check }) => ({
    name: 'CI',
    events: 'check_suite,status',
    pick: (ev) => { const at = ev.check_suite?.head_sha || ev.sha; return at ? { sha: at } : null; },
    mine: (ev) => ev.sha === sha,
    look: () => spawnSync(check[0], check.slice(1), { encoding: 'utf8' }),
    late: (min) => `asst-pr: CI still running on #${pr} after ${min} min — watch again, or check the run\n`,
  }),
  merge: ({ repo, pr }) => ({
    name: 'merge',
    events: 'pull_request',
    pick: (ev) => (ev.action === 'closed' ? { closed: ev.number } : null),
    mine: (ev) => String(ev.closed) === pr,
    look: () => mergeState(repo, pr),
    late: (min) => `asst-pr: #${pr} still open after ${min} min — watch again\n`,
  }),
};

// Resolves { code, out } when the watch ends. timeoutMin may be Infinity.
export function watchPr({ mode, repo, pr, timeoutMin, sha, check }) {
  const m = modes[mode]({ repo, pr, sha, check });
  const mine = join(repoDir(repo), `${mode}-${pr}.pid`);
  if (!claim(mine)) return Promise.resolve({ code: 2, out: `asst-pr: #${pr} is already watched (pid ${owner(mine)}) — one watcher per PR\n` });
  return new Promise((resolve) => {
    let hub;
    let done = false;
    let again;
    let cap;
    async function finish(code, out = '') {
      if (done) return;
      done = true;
      clearTimeout(again);
      clearTimeout(cap);
      await hub?.stop();
      release(mine);
      resolve({ code, out });
    }
    for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.once(sig, () => finish(130));

    // One look. 3 = not yet; anything else ends the watch.
    function look() {
      if (done) return 0;
      const r = m.look();
      if (r.status !== 3) finish(r.status ?? 2, (r.stdout || '') + (r.stderr || ''));
      return r.status;
    }
    // GitHub sends a suite's completed event before its API shows it (measured: the
    // event a second after the suite finished, and the read still said running),
    // and no later event comes for that commit. So a read that still says not yet
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
      events: m.events,
      pick: m.pick,
      onEvent: (ev) => { if (m.mine(ev)) recheck(); },
      onConnected: look,
      onFail: (why) => finish(2, `asst-pr: ${m.name} watch stopped — ${why}\n`),
    });
    if (Number.isFinite(timeoutMin)) cap = setTimeout(() => finish(3, m.late(timeoutMin)), timeoutMin * 60000);
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [mode, repo, pr, timeoutMin, sha, ...check] = process.argv.slice(2);
  if (!modes[mode] || !repo || !/^\d+$/.test(pr ?? '') || !(Number(timeoutMin) > 0) || (mode === 'ci' && !(sha && check.length))) {
    console.error('Usage: pr-watch.mjs ci <owner/repo> <pr> <timeout-minutes> <head-sha> <check command…>\n       pr-watch.mjs merge <owner/repo> <pr> <timeout-minutes>');
    process.exit(2);
  }
  const { code, out } = await watchPr({ mode, repo, pr, timeoutMin: Number(timeoutMin), sha, check });
  if (out) process.stdout.write(out);
  process.exit(code);
}
